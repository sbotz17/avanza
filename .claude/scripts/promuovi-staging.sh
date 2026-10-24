#!/usr/bin/env bash
# PROMOZIONE AUTOMATICA staging -> main (produzione), solo se TUTTI i controlli sono verdi. Usato dal job `unione` di promozione.yml.
# Perche' esiste: una fusione fatta con GITHUB_TOKEN NON fa partire altri workflow (nemmeno il push su main), quindi dopo l'unione si avvia
# esplicitamente rilascio-produzione.yml con `gh workflow run ... --ref main` (workflow_dispatch e' l'eccezione prevista da GitHub).
# Il rilascio resta l'ULTIMA barriera e rifa' tutti i suoi controlli (testa di main, contenuto identico a staging, CI con test obbligatori,
# build, prerequisiti, smoke test, ritorno automatico, tocco di Andrea se SVILUPPI_RICHIEDONO_APPROVAZIONE non e' vuota/no): questo script non li sostituisce.
#
# Uso: dentro un checkout della TESTA di staging con storia completa (HEAD = testa di staging).
# Variabili: GH_TOKEN, GITHUB_REPOSITORY (owner/repo), SQUADRA_CI_ATTIVA ('si' per agire), BLOCCO_SQUADRA, TEST_RILASCIO_NON_OBBLIGATORI,
#            CONTROLLO_STAGING (passata a verifica-da-staging.sh), PROMOZIONE_SOLO_VERIFICA ('si' = controlla ma NON unisce),
#            PROMOZIONE_ATTESA (secondi tra i tentativi, default 10), GITHUB_OUTPUT, GITHUB_STEP_SUMMARY.
# Esito 0 = tutto in regola (anche quando non si unisce per un controllo non ancora verde: "riprova al prossimo evento", niente rosso);
# esito 1 = situazione anomala che richiede una persona (blocco di emergenza attivo, conflitti, main diverso da staging, unione o avvio rilascio falliti).
# Scrive in GITHUB_OUTPUT: esito=spenta|non-ora|niente|solo-verifica|unita-da-altri|unita-e-rilascio-avviato|bloccata|anomalia
# Regole: l'unione e' un merge commit (mai squash: il rilascio deve poter ricostruire cosa esce), solo se la testa di staging e' quella della pull
# request (--match-head-commit); mai --delete-branch; nessun segreto viene stampato; permessi minimi (vedi promozione.yml).
# Concorrenza: una sola promozione alla volta (gruppo di concorrenza del workflow) e mai due rilasci in parallelo (gruppo `produzione` del rilascio;
# qui in piu' non si riavvia un rilascio gia' in coda/in corso per lo stesso commit).
# NON PROVATO su GitHub: provato in locale con un gh finto in .claude/scripts/prova-promozione.sh.
set -uo pipefail
OUT="${GITHUB_OUTPUT:-/dev/null}"; SUM="${GITHUB_STEP_SUMMARY:-/dev/null}"
ATTESA="${PROMOZIONE_ATTESA:-10}"
export GITHUB_REPOSITORY="${GITHUB_REPOSITORY:?GITHUB_REPOSITORY mancante}"
RILASCIO="rilascio-produzione.yml"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

esito()   { echo "esito=$1" >> "$OUT"; }
riga()    { echo "- $*" >> "$SUM"; }
non_ora() { echo "::notice::Promozione non eseguita ora: $1 (si riprova al prossimo evento)"; esito non-ora; riga "Non unita ora: $1."; exit 0; }
anomalia() { echo "::error::$1"; esito anomalia; riga "ANOMALIA, serve una persona: $1"; exit 1; }
blocco_file() { [ -f "$1" ] && head -n1 "$1" | grep -qi '^ATTIVO'; }

echo "### Promozione automatica staging -> main" >> "$SUM"

# 1. interruttori
if [ "${SQUADRA_CI_ATTIVA:-}" != "si" ]; then
  echo "SQUADRA_CI_ATTIVA non e' 'si': promozione automatica spenta."; esito spenta; riga "Spenta (SQUADRA_CI_ATTIVA diversa da si)."; exit 0
fi
git fetch --quiet origin main staging || anomalia "impossibile leggere i rami main e staging"
BLOCCATO=no
[ "${BLOCCO_SQUADRA:-}" = "ATTIVO" ] && BLOCCATO=si
blocco_file BLOCCO-SQUADRA.md && BLOCCATO=si
git show origin/main:BLOCCO-SQUADRA.md > "$TMP/blocco-main" 2>/dev/null && blocco_file "$TMP/blocco-main" && BLOCCATO=si
if [ "$BLOCCATO" = si ]; then
  echo "::error::BLOCCO_SQUADRA / BLOCCO-SQUADRA.md attivo: promozione sospesa. Solo Andrea toglie il blocco."
  esito bloccata; riga "Sospesa per il blocco di emergenza di Andrea."; exit 1
fi

# 2. la testa di staging e' quella che stiamo valutando? (altrimenti ci pensa l'evento della testa piu' nuova)
X="$(git rev-parse HEAD)"; STAGING="$(git rev-parse origin/staging)"
[ "$X" = "$STAGING" ] || non_ora "staging e' avanzato ($STAGING): la valutazione della testa piu' nuova la sostituisce"
echo "Testa di staging valutata: $X"

# 3. c'e' qualcosa da promuovere?
N="$(git rev-list --count origin/main..origin/staging)"
if [ "$N" = "0" ]; then echo "staging e main coincidono: niente da promuovere"; esito niente; riga "Niente da promuovere."; exit 0; fi

# 4. l'unione dara' ESATTAMENTE il contenuto di staging? (altrimenti il rilascio la rifiuterebbe: meglio fermarsi prima, con un messaggio chiaro)
git merge-tree --write-tree origin/main origin/staging > "$TMP/mt.out" 2> "$TMP/mt.err"; MT=$?
TREE_UNIONE="$(head -n1 "$TMP/mt.out")"
if [ "$MT" != "0" ] || [ -z "$TREE_UNIONE" ]; then
  anomalia "main e staging non si uniscono senza conflitti ($(head -c 300 "$TMP/mt.out" "$TMP/mt.err" | tr '\n' ' '))"
fi
if [ "$TREE_UNIONE" != "$(git rev-parse 'origin/staging^{tree}')" ]; then
  anomalia "main contiene modifiche che staging non ha: l'unione non darebbe il contenuto provato su staging e il rilascio la rifiuterebbe"
fi

# 5. controlli verdi sulla testa di staging: CI (analisi, test, build, funzioni), pubblicazione di test per intero, test automatici passati
#    (stessi controlli del rilascio; se manca anche uno solo o e' in corso NON si unisce, senza errore rumoroso)
RICH=si; [ "${TEST_RILASCIO_NON_OBBLIGATORI:-}" = "si" ] && RICH=no
RICHIEDI_TEST_VERDI="$RICH" bash .claude/scripts/verifica-da-staging.sh > "$TMP/verifica.txt" 2>&1; RC=$?
sed 's/^/  /' "$TMP/verifica.txt"
[ "$RC" = "0" ] || non_ora "la testa di staging non ha ancora tutti i controlli verdi o il deploy di test completo ($(tail -n 1 "$TMP/verifica.txt" | head -c 200))"

# 6. la pull request di promozione esiste, ha la stessa testa di staging e le sue verifiche sono verdi
gh pr list --base main --head staging --state open --json number,headRefOid --jq '.[0] // empty' > "$TMP/pr.json" 2>"$TMP/pr.err" \
  || anomalia "impossibile leggere le pull request ($(head -c 200 "$TMP/pr.err"))"
[ -s "$TMP/pr.json" ] || non_ora "nessuna pull request staging -> main aperta (la apre promozione.yml; serve 'Allow GitHub Actions to create and approve pull requests')"
PR="$(jq -r .number "$TMP/pr.json")"; PRHEAD="$(jq -r .headRefOid "$TMP/pr.json")"
[ "$PRHEAD" = "$X" ] || non_ora "la pull request #$PR e' ancora alla testa $PRHEAD, non a quella di staging $X"

TENTATIVO=0
while :; do
  gh pr view "$PR" --json state,headRefOid,mergeable,mergeStateStatus,statusCheckRollup > "$TMP/prv.json" 2>"$TMP/pr.err" \
    || anomalia "impossibile leggere la pull request #$PR ($(head -c 200 "$TMP/pr.err"))"
  [ "$(jq -r .mergeable "$TMP/prv.json")" != "UNKNOWN" ] && [ "$(jq -r .mergeStateStatus "$TMP/prv.json")" != "UNKNOWN" ] && break
  TENTATIVO=$((TENTATIVO+1)); [ "$TENTATIVO" -ge 6 ] && non_ora "GitHub non ha ancora calcolato lo stato della pull request #$PR"
  sleep "$ATTESA"
done
[ "$(jq -r .state "$TMP/prv.json")" = "OPEN" ] || non_ora "la pull request #$PR non e' piu' aperta"
[ "$(jq -r .headRefOid "$TMP/prv.json")" = "$X" ] || non_ora "la testa della pull request #$PR non e' piu' quella di staging $X"
STATO="$(jq -r .mergeStateStatus "$TMP/prv.json")"; MERGEABLE="$(jq -r .mergeable "$TMP/prv.json")"
{ [ "$MERGEABLE" = "CONFLICTING" ] || [ "$STATO" = "DIRTY" ]; } && anomalia "la pull request #$PR ha conflitti"

# controlli della pull request: solo quelli dei workflow di controllo (ci, controlli-pr, Deploy Avanza Web); non conta la promozione stessa.
# Un controllo rosso o in corso => non si unisce; nessun controllo presente => decidono le regole del ramo (mergeStateStatus, sotto).
FILTRO='[.statusCheckRollup // [] | .[] | select(((.workflowName // "") == "") or ((.workflowName // "") | IN("ci","controlli-pr","Deploy Avanza Web")))]'
ROSSI="$(jq -r "$FILTRO"' | map(select((((.conclusion // "") | IN("FAILURE","CANCELLED","TIMED_OUT","ACTION_REQUIRED","STARTUP_FAILURE")) or ((.state // "") | IN("FAILURE","ERROR"))) )) | map(.name // .context) | unique | join(", ")' "$TMP/prv.json")"
IN_CORSO="$(jq -r "$FILTRO"' | map(select(((.status // "COMPLETED") != "COMPLETED") or ((.state // "") | IN("PENDING","EXPECTED")))) | map(.name // .context) | unique | join(", ")' "$TMP/prv.json")"
[ -z "$ROSSI" ] || non_ora "controlli della pull request #$PR non superati: $ROSSI"
[ -z "$IN_CORSO" ] || non_ora "controlli della pull request #$PR ancora in corso: $IN_CORSO"
case "$STATO" in
  BLOCKED) non_ora "le regole del ramo main non sono soddisfatte sulla pull request #$PR (controlli obbligatori mancanti o in corso, o approvazioni richieste)" ;;
  BEHIND)  non_ora "la pull request #$PR non e' aggiornata rispetto a main" ;;
esac
echo "Pull request #$PR: testa $X, stato '$STATO', controlli della PR senza rossi ne' in corso."

if [ "${PROMOZIONE_SOLO_VERIFICA:-}" = "si" ]; then
  echo "Solo verifica: TUTTO IN REGOLA, ma non unisco (PROMOZIONE_SOLO_VERIFICA=si)."; esito solo-verifica
  riga "Verifica superata sulla testa \`${X:0:7}\` (pull request #$PR): sarebbe stata unita. Modalita' solo verifica: nessuna unione."; exit 0
fi

# 7. unione (merge commit) SOLO se la testa della pull request e' ancora quella valutata
if ! gh pr merge "$PR" --merge --match-head-commit "$X" 2>"$TMP/merge.err"; then
  echo "Unione non riuscita: $(head -c 300 "$TMP/merge.err")"
  [ "$(gh pr view "$PR" --json state --jq .state 2>/dev/null)" = "MERGED" ] && { esito unita-da-altri; riga "La pull request #$PR risulta gia' unita da altri: niente da fare, nessun rilascio avviato da qui."; exit 0; }
  NUOVA="$(gh pr view "$PR" --json headRefOid --jq .headRefOid 2>/dev/null || true)"
  if [[ "$NUOVA" =~ ^[0-9a-f]{40}$ ]] && [ "$NUOVA" != "$X" ]; then non_ora "staging e' avanzato durante la verifica"; fi
  anomalia "unione della pull request #$PR non riuscita: $(head -c 200 "$TMP/merge.err" | tr '\n' ' ')"
fi
echo "Pull request #$PR unita (merge commit)."

SHA_UNIONE=""
for _ in 1 2 3 4 5 6; do
  gh pr view "$PR" --json state,mergeCommit --jq 'select(.state=="MERGED") | .mergeCommit.oid // empty' > "$TMP/mc.txt" 2>/dev/null || true
  SHA_UNIONE="$(head -n1 "$TMP/mc.txt")"; [ -n "$SHA_UNIONE" ] && break; sleep "$ATTESA"
done
[ -n "$SHA_UNIONE" ] || anomalia "la pull request #$PR risulta unita ma non trovo il commit di unione: NON avvio il rilascio, controllare main"
git fetch --quiet origin main || anomalia "impossibile rileggere main dopo l'unione"
if [ "$(git rev-parse "${SHA_UNIONE}^{tree}" 2>/dev/null)" != "$(git rev-parse 'origin/staging^{tree}')" ]; then
  anomalia "il commit di unione ${SHA_UNIONE:0:7} non ha lo stesso contenuto di staging: NON avvio il rilascio, controllare main"
fi
riga "Pull request #$PR unita in \`main\` (commit \`${SHA_UNIONE:0:7}\`, contenuto identico a staging \`${X:0:7}\`)."

# 8. avvio esplicito del rilascio (l'unione fatta con GITHUB_TOKEN non lo fa partire da sola), senza duplicarlo se e' gia' in coda/in corso
ATTIVI="$(gh run list --workflow "$RILASCIO" --branch main --limit 20 --json headSha,status \
  --jq "[.[] | select(.headSha==\"$SHA_UNIONE\" and (.status | IN(\"queued\",\"in_progress\",\"waiting\",\"pending\",\"requested\")))] | length" 2>/dev/null || echo 0)"
if [ "${ATTIVI:-0}" != "0" ]; then
  echo "Un rilascio per ${SHA_UNIONE:0:7} e' gia' in coda o in corso: non lo riavvio."; riga "Rilascio gia' in coda o in corso per questo commit."
else
  gh workflow run "$RILASCIO" --ref main 2>"$TMP/disp.err" \
    || { esito anomalia; riga "ANOMALIA: main e' stato unito (\`${SHA_UNIONE:0:7}\`) ma il rilascio NON e' partito. Avviarlo a mano: Actions > rilascio-produzione > Run workflow (ramo main)."
         echo "::error::Rilascio non avviato: $(head -c 200 "$TMP/disp.err")"; exit 1; }
  echo "Rilascio avviato (rilascio-produzione.yml, ref main)."; riga "Rilascio avviato."
  for _ in 1 2 3 4 5 6; do
    P="$(gh run list --workflow "$RILASCIO" --branch main --limit 10 --json headSha --jq "[.[] | select(.headSha==\"$SHA_UNIONE\")] | length" 2>/dev/null || echo 0)"
    [ "${P:-0}" != "0" ] && break; sleep "$ATTESA"
  done
  [ "${P:-0}" != "0" ] || echo "::warning::Rilascio richiesto ma non ancora visibile tra le esecuzioni: controllare la scheda Actions."
fi
esito unita-e-rilascio-avviato
exit 0
