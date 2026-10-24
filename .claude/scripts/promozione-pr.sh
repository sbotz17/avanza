#!/usr/bin/env bash
# Apre o aggiorna UNA pull request "staging -> main" con il riepilogo di cio' che staging ha in piu' di main e la classificazione
# (correzione o nuovo sviluppo). NON unisce nulla. Script UNICO usato dai due job di promozione.yml (prima il codice stava nel workflow).
# Uso: dentro il repository (HEAD = testa di staging, storia completa). Variabili: GH_TOKEN, REPO (owner/repo) o GITHUB_REPOSITORY, GITHUB_OUTPUT.
# Scrive in GITHUB_OUTPUT: n=<commit di staging non ancora in main>, tipo=correzione|sviluppo, motivo=..., file=<file cambiati>, regole=si|no
# (regole=si: firestore.rules o firestore.indexes.json differiscono; in quel caso la promozione automatica NON unisce, serve una persona).
# Il corpo della pull request riporta anche la DIMENSIONE del salto (commit, file, righe).
# Se non c'e' nulla da promuovere (n=0) non fa altro. Se la pull request non si riesce ad aprire/aggiornare: avviso, esito 0 (la promozione
# automatica, piu' avanti, trovera' "nessuna pull request" e non unira').
# NON PROVATO su GitHub (le chiamate gh non sono eseguibili qui): vedi .claude/scripts/prova-promozione.sh per la prova con un gh finto.
set -uo pipefail
OUT="${GITHUB_OUTPUT:-/dev/null}"
REPO="${REPO:-${GITHUB_REPOSITORY:-}}"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

git fetch --quiet origin main || { echo "ERRORE: impossibile leggere main"; exit 1; }
N="$(git rev-list --count origin/main..HEAD)"
echo "n=$N" >> "$OUT"
if [ "$N" = "0" ]; then echo "staging e main coincidono: niente da promuovere"; exit 0; fi

# pull request entrate in staging e non ancora in produzione (script condiviso con il rilascio; esclude la PR di promozione stessa)
bash .claude/scripts/pr-del-commit.sh origin/main..HEAD "$TMP/richieste.json" || { echo "ERRORE: elenco delle pull request non leggibile"; exit 1; }
jq -c '.pr[] | {numero, ramo, etichette}' "$TMP/richieste.json"

GITHUB_OUTPUT="$TMP/cls.out" python3 .claude/scripts/classifica-modifica.py origin/main "$TMP/richieste.json" .claude/zone-protette.json | tail -n 12
TIPO="$(grep '^tipo=' "$TMP/cls.out" 2>/dev/null | tail -1 | cut -d= -f2)"
MOTIVO="$(grep '^motivo=' "$TMP/cls.out" 2>/dev/null | tail -1 | cut -d= -f2-)"
[ "$TIPO" = "correzione" ] || TIPO=sviluppo
{ echo "tipo=$TIPO"; echo "motivo=$MOTIVO"; } >> "$OUT"

# dimensione del salto e regole/indici Firestore (se il confronto fallisce vale "differiscono": fail-closed)
FILE_CAMBIATI="$(git diff --name-only origin/main HEAD | wc -l | tr -d ' ')"
RIGHE="$(git diff --shortstat origin/main HEAD | sed 's/^ *//')"
git diff --quiet origin/main HEAD -- firestore.rules firestore.indexes.json 2>/dev/null; DR=$?
if [ "$DR" = "0" ]; then REGOLE=no; else REGOLE=si; fi
{ echo "file=$FILE_CAMBIATI"; echo "regole=$REGOLE"; } >> "$OUT"

{
  echo "## Promozione staging -> produzione"
  echo
  echo "**Tipo: $TIPO**"
  if [ "$TIPO" = "correzione" ]; then
    echo "Sono solo correzioni verificate."
  else
    echo "Contiene un **nuovo sviluppo** (motivo: $MOTIVO): accettato dalla squadra (tester e validatore indipendenti) e provato sul sito di test."
  fi
  echo
  echo "### Dimensione del salto"
  echo "- Commit di staging non ancora in produzione: **$N** (file cambiati: **$FILE_CAMBIATI**; ${RIGHE:-nessuna riga})"
  if [ "$REGOLE" = "si" ]; then
    echo "- **Regole o indici Firestore (\`firestore.rules\` / \`firestore.indexes.json\`) DIFFERISCONO: la promozione automatica NON unisce, serve una persona.** Il rilascio non pubblica le regole: vanno pubblicate con il workflow \"Setup Firestore\" da \`main\` (dopo il backup), poi si unisce questa pull request con un merge commit."
  else
    echo "- Regole e indici Firestore: identici a produzione."
    echo "- Si unisce da sola quando tutti i controlli sono verdi."
  fi
  echo
  echo "### Cosa cambia rispetto alla produzione"
  git log origin/main..HEAD --no-merges --pretty='- %s (%h)' | head -50
  echo
  echo "### Pull request incluse"
  jq -r '.pr[] | "- #\(.numero) \(.titolo) [\(.ramo)]"' "$TMP/richieste.json"
  echo
  echo "Quando la CI, il deploy di test e i controlli di questa pull request sono verdi sulla testa di staging, \`promozione.yml\` la unisce (merge commit) e avvia \`rilascio-produzione.yml\` (ambiente GitHub \`produzione\`)."
  echo "_Aperta in automatico da promozione.yml. Fermare tutto: variabile BLOCCO_SQUADRA = ATTIVO oppure SQUADRA_CI_ATTIVA = no (decisione di Andrea del 24/10/2026: non valida piu' gli sviluppi)._"
} > "$TMP/corpo.md"

TITOLO="Promozione staging -> main ($TIPO)"
gh label create "promozione" --color 5319e7 --description "Promozione da staging a produzione" 2>/dev/null || true
gh label create "tipo:$TIPO" --color 0e8a16 2>/dev/null || true
# repository pubblico: si considerano solo le PR dello stesso repository (una PR di un fork con ramo "staging" non va ne' modificata ne' unita)
ESISTENTE="$(gh pr list --base main --head staging --state open --json number,isCrossRepository --jq '[.[] | select(.isCrossRepository == false)] | .[0].number // empty')" \
  || { echo "ERRORE: impossibile leggere le pull request"; exit 1; }
if [ -n "$ESISTENTE" ]; then
  gh pr edit "$ESISTENTE" --title "$TITOLO" --body-file "$TMP/corpo.md" --add-label "promozione,tipo:$TIPO" \
    || echo "::warning::Pull request di promozione non aggiornata"
  echo "Aggiornata la pull request #$ESISTENTE"
else
  gh pr create --base main --head staging --title "$TITOLO" --body-file "$TMP/corpo.md" --label "promozione,tipo:$TIPO" \
    || echo "::warning::Non riesco ad aprire la pull request di promozione: abilita 'Allow GitHub Actions to create and approve pull requests' (Settings > Actions > General) oppure aprila a mano da staging a main."
fi
exit 0
