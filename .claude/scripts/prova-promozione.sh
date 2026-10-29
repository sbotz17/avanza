#!/usr/bin/env bash
# Prova in locale della promozione automatica (promuovi-staging.sh + verifica-da-staging.sh) con un repository git VERO (origine locale)
# e un `gh` FINTO che risponde con file JSON di scenario. Non tocca GitHub, non usa segreti. Esito 0 = tutti i casi si comportano come atteso.
# Casi: CI verde / rossa / in corso, deploy rosso, test rossi, blocco attivo (variabile e file), testa di staging diversa dalla PR o avanzata,
#       PR gia' unita / assente, nessuna differenza, controlli della PR rossi / in corso / regole del ramo non soddisfatte, conflitti,
#       main con modifiche estranee, unione con contenuto diverso, avvio del rilascio fallito o gia' in coda, solo verifica, interruttore spento.
# Uso: bash .claude/scripts/prova-promozione.sh        (dalla radice del repository)
# LIMITE: il gh finto riproduce la FORMA documentata delle risposte di GitHub, non il comportamento reale (nomi dei job di un workflow richiamato,
# stato dei passi con continue-on-error, mergeStateStatus): quelli restano da osservare al primo giro vero.
set -uo pipefail
RADICE="$(git rev-parse --show-toplevel)"
BASE_TMP="$(mktemp -d)"; trap 'rm -rf "$BASE_TMP"' EXIT
FALLITI=0; TOTALE=0
# prova ermetica: nessuna impostazione git dell'utente (firma dei commit, protocolli speciali)
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
export GIT_AUTHOR_NAME=prova GIT_AUTHOR_EMAIL=prova@example.com GIT_COMMITTER_NAME=prova GIT_COMMITTER_EMAIL=prova@example.com

# ---------------------------------------------------------------- gh finto
BIN="$BASE_TMP/bin"; mkdir -p "$BIN"
cat > "$BIN/gh" <<'STUB'
#!/usr/bin/env bash
# gh finto: legge i file di scenario in $SC. Registra ogni chiamata in $SC/calls.log.
echo "gh $*" >> "$SC/calls.log"
JQ=""; ARGS=("$@"); for i in "${!ARGS[@]}"; do [ "${ARGS[$i]}" = "--jq" ] && JQ="${ARGS[$((i+1))]}"; done
emit() { if [ -n "$JQ" ]; then jq -r "$JQ" "$1"; else cat "$1"; fi; }
case "$1 $2" in
  "label create") exit 0 ;;
  "pr list")   emit "$SC/pr_list.json" ;;
  "pr edit"|"pr create")
     for i in "${!ARGS[@]}"; do [ "${ARGS[$i]}" = "--body-file" ] && cp "${ARGS[$((i+1))]}" "$SC/body.md"; done; exit 0 ;;
  "pr view")
     if [ -f "$SC/gia_unita" ]; then jq '.state="MERGED"' "$SC/pr_view.json" > "$SC/pr_view_now.json"
     elif [ -f "$SC/merged" ]; then
       jq --arg sha "$(cat "$SC/merge_sha")" '.state="MERGED" | .mergeCommit={oid:$sha}' "$SC/pr_view.json" > "$SC/pr_view_now.json"
     else cp "$SC/pr_view.json" "$SC/pr_view_now.json"; fi
     emit "$SC/pr_view_now.json" ;;
  "pr merge")
     if [ -f "$SC/merge_fail" ]; then echo "merge non consentito" >&2; [ -f "$SC/unita_da_altri" ] && touch "$SC/gia_unita"; exit 1; fi
     # unione vera nel repository di origine (merge commit), come farebbe GitHub
     M="$SC/mergeclone"; rm -rf "$M"; git clone -q "$SC/origin.git" "$M"; cd "$M" || exit 1
     git checkout -q main && git merge -q --no-ff origin/staging -m "Merge pull request #7 from sbotz17/staging" >/dev/null
     [ -f "$SC/merge_extra" ] && { echo extra > extra.txt; git add extra.txt; git commit -q -m extra --amend; }
     git push -q origin main; git rev-parse HEAD > "$SC/merge_sha"; touch "$SC/merged"; exit 0 ;;
  "run list")
     # con "run_in_coda" un rilascio per lo stesso commit di unione risulta gia' in coda; altrimenti compare solo dopo l'avvio
     [ -f "$SC/run_in_coda" ] && [ -f "$SC/merge_sha" ] && jq -n --arg s "$(cat "$SC/merge_sha")" '[{headSha:$s,status:"queued"}]' > "$SC/run_list.json"
     emit "$SC/run_list.json" ;;
  "workflow run")
     [ -f "$SC/dispatch_fail" ] && { echo "dispatch negato" >&2; exit 1; }
     jq -n --arg s "$(cat "$SC/merge_sha")" '[{headSha:$s,status:"queued"}]' > "$SC/run_list.json"; exit 0 ;;
  "api "*)
     case "$2" in
       *"/actions/workflows/deploy.yml/runs"*) emit "$SC/runs.json" ;;
       *"/actions/runs/"*"/jobs"*) emit "$SC/jobs.json" ;;
       *"/commits/"*"/pulls"*) echo '[]' ;;
       *) echo '{}' ;;
     esac ;;
  *) echo "gh finto: comando non previsto: $*" >&2; exit 2 ;;
esac
STUB
chmod +x "$BIN/gh"

# ---------------------------------------------------------------- scenario di base: tutto verde
nuovo() {  # $1 nome scenario -> crea $SC con origine, clone sulla testa di staging e file JSON "tutto verde"
  SC="$BASE_TMP/$1"; export SC; mkdir -p "$SC"
  git init -q --bare -b main "$SC/origin.git"
  W="$SC/lavoro"; git clone -q "$SC/origin.git" "$W" 2>/dev/null; cd "$W" || exit 1
  git checkout -q -b main; mkdir -p .claude/scripts; cp "$RADICE"/.claude/scripts/{promuovi-staging.sh,verifica-da-staging.sh,promozione-pr.sh,pr-del-commit.sh,classifica-modifica.py} .claude/scripts/; cp "$RADICE"/.claude/zone-protette.json .claude/
  echo uno > a.txt; echo r1 > firestore.rules; echo "{}" > firestore.indexes.json; git add -A; git commit -q -m "A"; git push -q origin main
  git checkout -q -b staging; echo due > b.txt; git add b.txt; git commit -q -m "B (T-18)"; echo tre >> a.txt; git commit -q -am "C"; git push -q origin staging
  X="$(git rev-parse HEAD)"; export X
  echo '{"workflow_runs":[{"id":101,"conclusion":"success"}]}' > "$SC/runs.json"
  jq -n '{jobs:[
    {name:"controlli / controlli",steps:[{name:"Test",conclusion:"success"},{name:"Avviso test non superati",conclusion:"skipped"}]},
    {name:"deploy-test",steps:[{name:"Deploy Hosting (progetto di test)",conclusion:"success"},{name:"Regole e indici Firestore (progetto di test)",conclusion:"success"},{name:"Deploy funzione (progetto di test)",conclusion:"success"}]}]}' > "$SC/jobs.json"
  echo "[{\"number\":7,\"headRefOid\":\"$X\",\"isCrossRepository\":false}]" > "$SC/pr_list.json"
  jq -n --arg x "$X" '{state:"OPEN",headRefOid:$x,isCrossRepository:false,mergeable:"MERGEABLE",mergeStateStatus:"CLEAN",statusCheckRollup:[
    {__typename:"CheckRun",name:"blocco",workflowName:"controlli-pr",status:"COMPLETED",conclusion:"SUCCESS"},
    {__typename:"CheckRun",name:"controlli",workflowName:"ci",status:"COMPLETED",conclusion:"SUCCESS"},
    {__typename:"CheckRun",name:"promuovi",workflowName:"promozione",status:"IN_PROGRESS",conclusion:null},
    {__typename:"CheckRun",name:"altro-flusso",workflowName:"verifica-sito",status:"COMPLETED",conclusion:"FAILURE"}]}' > "$SC/pr_view.json"
  echo '[]' > "$SC/run_list.json"
  : > "$SC/calls.log"
  export PATH="$BIN:$PATH" GITHUB_REPOSITORY=sbotz17/avanza GH_TOKEN=finto PROMOZIONE_ATTESA=0
  export SQUADRA_CI_ATTIVA=si BLOCCO_SQUADRA="" TEST_RILASCIO_NON_OBBLIGATORI="" CONTROLLO_STAGING="" PROMOZIONE_SOLO_VERIFICA=no
  export GITHUB_OUTPUT="$SC/output" GITHUB_STEP_SUMMARY="$SC/summary"; : > "$GITHUB_OUTPUT"; : > "$GITHUB_STEP_SUMMARY"
}
esegui() { ( cd "$SC/lavoro" && bash .claude/scripts/promuovi-staging.sh > "$SC/log.txt" 2>&1 ); RC=$?; ESITO="$(grep '^esito=' "$SC/output" | tail -1 | cut -d= -f2)"; }
chiamato() { grep -q -- "$1" "$SC/calls.log"; }
verifica() {  # $1 descrizione, $2 esito atteso, $3 rc atteso, $4 unito (si/no), $5 rilascio avviato (si/no)
  TOTALE=$((TOTALE+1)); local ok=1 U=no R=no
  chiamato "pr merge" && U=si; chiamato "workflow run rilascio-produzione.yml --ref main" && R=si
  [ "$ESITO" = "$2" ] || ok=0; [ "$RC" = "$3" ] || ok=0; [ "$U" = "$4" ] || ok=0; [ "$R" = "$5" ] || ok=0
  if [ "$ok" = 1 ]; then echo "OK    $1  (esito=$ESITO rc=$RC unione=$U rilascio=$R)"
  else FALLITI=$((FALLITI+1)); echo "FALLITO $1: atteso esito=$2 rc=$3 unione=$4 rilascio=$5, ottenuto esito=$ESITO rc=$RC unione=$U rilascio=$R"; sed 's/^/      | /' "$SC/log.txt" | tail -n 15; fi
}

# ---------------------------------------------------------------- casi
cambia_staging() {  # $1 file, $2 contenuto: nuovo commit su staging, aggiorna X nei file di scenario
  local VECCHIO="$X"; ( cd "$SC/lavoro" && echo "$2" > "$1" && git add "$1" && git commit -q -m "cambia $1" && git push -q origin staging ); X="$(git -C "$SC/lavoro" rev-parse HEAD)"; export X
  sed -i "s/$VECCHIO/$X/g" "$SC"/*.json
}
pr_script() { ( cd "$SC/lavoro" && bash .claude/scripts/promozione-pr.sh > "$SC/log.txt" 2>&1 ); RC=$?; }
nuovo verde;           esegui; verifica "CI verde, deploy completo, PR verde -> unisce e avvia il rilascio" unita-e-rilascio-avviato 0 si si
chiamato "--merge --match-head-commit $X" || { FALLITI=$((FALLITI+1)); echo "FALLITO: l'unione deve essere un merge commit con --match-head-commit"; }
! grep -q -e "--squash\|--rebase\|--delete-branch\|--admin\|--auto" "$SC/calls.log" || { FALLITI=$((FALLITI+1)); echo "FALLITO: opzioni di unione vietate"; }
git -C "$SC/origin.git" cat-file -p main | grep -c '^parent' | grep -q 2 || { FALLITI=$((FALLITI+1)); echo "FALLITO: main non ha un commit di unione a due genitori"; }
[ "$(git -C "$SC/origin.git" rev-parse "main^{tree}")" = "$(git -C "$SC/origin.git" rev-parse "staging^{tree}")" ] || { FALLITI=$((FALLITI+1)); echo "FALLITO: contenuto di main diverso da staging dopo l'unione"; }
! grep -q "finto" "$SC/log.txt" "$SC/summary" || { FALLITI=$((FALLITI+1)); echo "FALLITO: il token compare nell'output"; }

nuovo ci-rossa;        echo '{"workflow_runs":[]}' > "$SC/runs.json"; esegui; verifica "CI rossa (nessuna esecuzione riuscita) -> non unisce, nessun errore" non-ora 0 no no
nuovo ci-in-corso;     echo '{"workflow_runs":[]}' > "$SC/runs.json"; esegui; verifica "CI/deploy ancora in corso -> non unisce, nessun errore" non-ora 0 no no
nuovo deploy-rosso;    jq '(.jobs[]|select(.name=="deploy-test")|.steps[]|select(.name=="Deploy funzione (progetto di test)")|.conclusion)="skipped"' "$SC/jobs.json" > "$SC/j" && mv "$SC/j" "$SC/jobs.json"; esegui
verifica "deploy di test non completo (passo saltato) -> non unisce" non-ora 0 no no
nuovo deploy-fallito;  jq '(.jobs[]|select(.name=="deploy-test")|.steps[]|select(.name=="Deploy Hosting (progetto di test)")|.conclusion)="failure"' "$SC/jobs.json" > "$SC/j" && mv "$SC/j" "$SC/jobs.json"; esegui
verifica "deploy di test fallito -> non unisce" non-ora 0 no no
nuovo test-rossi;      jq '(.jobs[]|select(.name=="controlli / controlli")|.steps[]|select(.name=="Avviso test non superati")|.conclusion)="success"' "$SC/jobs.json" > "$SC/j" && mv "$SC/j" "$SC/jobs.json"; esegui
verifica "test automatici rossi (CI verde ma tollerata) -> non unisce" non-ora 0 no no
TEST_RILASCIO_NON_OBBLIGATORI=si esegui; verifica "test rossi con la valvola TEST_RILASCIO_NON_OBBLIGATORI=si -> come il rilascio, unisce" unita-e-rilascio-avviato 0 si si
nuovo job-senza-nome;  jq '(.jobs[]|select(.name=="controlli / controlli")|.name)="altro"' "$SC/jobs.json" > "$SC/j" && mv "$SC/j" "$SC/jobs.json"; esegui
verifica "job dei test non riconosciuto -> non unisce (fallisce chiuso)" non-ora 0 no no
nuovo valvola-staging; echo '{"workflow_runs":[]}' > "$SC/runs.json"; CONTROLLO_STAGING=no esegui; verifica "valvola CONTROLLO_STAGING=no (come nel rilascio) -> controllo saltato" unita-e-rilascio-avviato 0 si si

nuovo blocco-var;      BLOCCO_SQUADRA=ATTIVO esegui; verifica "BLOCCO_SQUADRA=ATTIVO -> sospesa, nessuna unione" bloccata 1 no no
nuovo blocco-file;     printf 'ATTIVO\nmotivo\n' > "$SC/lavoro/BLOCCO-SQUADRA.md"; esegui; verifica "BLOCCO-SQUADRA.md attivo nel checkout -> sospesa" bloccata 1 no no
nuovo blocco-main;     ( cd "$SC/lavoro" && git checkout -q main && printf 'ATTIVO\n' > BLOCCO-SQUADRA.md && git add -A && git commit -q -m blocco && git push -q origin main && git checkout -q staging ); esegui
verifica "BLOCCO-SQUADRA.md attivo su main -> sospesa" bloccata 1 no no
nuovo spenta;          SQUADRA_CI_ATTIVA=no esegui; verifica "SQUADRA_CI_ATTIVA=no -> spenta, nessuna azione" spenta 0 no no
nuovo spenta-vuota;    SQUADRA_CI_ATTIVA="" esegui; verifica "SQUADRA_CI_ATTIVA non impostata -> spenta" spenta 0 no no

nuovo testa-diversa;   echo "[{\"number\":7,\"headRefOid\":\"0000000000000000000000000000000000000000\",\"isCrossRepository\":false}]" > "$SC/pr_list.json"; esegui
verifica "testa della PR diversa da quella di staging -> non unisce" non-ora 0 no no
nuovo staging-avanzato; ( cd "$SC/lavoro" && git checkout -q -b altro staging && echo nuovo > n.txt && git add n.txt && git commit -q -m D && git push -q origin altro:staging && git checkout -q staging ); esegui
verifica "staging avanzato durante la valutazione -> non unisce (ci pensa la testa nuova)" non-ora 0 no no
nuovo pr-assente;      echo '[]' > "$SC/pr_list.json"; : > "$SC/pr_list.json"; esegui; verifica "nessuna PR aperta -> non unisce" non-ora 0 no no
nuovo pr-gia-unita;    echo '[]' > "$SC/pr_list.json"; esegui; verifica "PR gia' unita (non piu' aperta) -> non fa nulla" non-ora 0 no no
nuovo unione-concorrente; touch "$SC/merge_fail" "$SC/unita_da_altri"; esegui
verifica "qualcuno unisce la PR mentre si controlla (l'unione fallisce, la PR risulta MERGED) -> nessun secondo rilascio" unita-da-altri 0 si no
nuovo unione-fallita;  touch "$SC/merge_fail"; esegui; verifica "unione rifiutata da GitHub per altri motivi -> anomalia, rilascio non avviato" anomalia 1 si no
nuovo niente;          ( cd "$SC/lavoro" && git push -q origin staging:main -f ); esegui; verifica "nessuna differenza staging/main -> niente da fare" niente 0 no no
nuovo secondo-evento;  esegui
# dopo una promozione riuscita, un secondo evento sulla stessa testa non deve fare nulla
: > "$SC/calls.log"; : > "$GITHUB_OUTPUT"; ( cd "$SC/lavoro" && git fetch -q origin ); esegui
verifica "secondo evento dopo l'unione (main contiene gia' staging) -> niente da fare" niente 0 no no

nuovo main-estraneo;   ( cd "$SC/lavoro" && git checkout -q main && echo hotfix > hot.txt && git add hot.txt && git commit -q -m hotfix && git push -q origin main && git checkout -q staging ); esegui
verifica "main ha una modifica che staging non ha -> anomalia, nessuna unione" anomalia 1 no no
nuovo conflitto;       ( cd "$SC/lavoro" && git checkout -q main && echo diverso > a.txt && git add a.txt && git commit -q -m conflitto && git push -q origin main && git checkout -q staging ); esegui
verifica "main e staging in conflitto -> anomalia, nessuna unione" anomalia 1 no no

nuovo pr-check-rosso;  jq '.statusCheckRollup += [{__typename:"CheckRun",name:"zone-protette",workflowName:"controlli-pr",status:"COMPLETED",conclusion:"FAILURE"}]' "$SC/pr_view.json" > "$SC/j" && mv "$SC/j" "$SC/pr_view.json"; esegui
verifica "controllo della PR rosso (controlli-pr) -> non unisce" non-ora 0 no no
nuovo pr-check-corso;  jq '.statusCheckRollup += [{__typename:"CheckRun",name:"regole",workflowName:"controlli-pr",status:"IN_PROGRESS",conclusion:null}]' "$SC/pr_view.json" > "$SC/j" && mv "$SC/j" "$SC/pr_view.json"; esegui
verifica "controllo della PR in corso -> non unisce" non-ora 0 no no
nuovo pr-stato-rosso;  jq '.statusCheckRollup += [{__typename:"StatusContext",context:"esterno",state:"FAILURE"}]' "$SC/pr_view.json" > "$SC/j" && mv "$SC/j" "$SC/pr_view.json"; esegui
verifica "stato esterno della PR in errore -> non unisce" non-ora 0 no no
nuovo pr-bloccata;     jq '.mergeStateStatus="BLOCKED"' "$SC/pr_view.json" > "$SC/j" && mv "$SC/j" "$SC/pr_view.json"; esegui
verifica "regole del ramo main non soddisfatte (BLOCKED) -> non unisce" non-ora 0 no no
nuovo pr-conflitti;    jq '.mergeable="CONFLICTING" | .mergeStateStatus="DIRTY"' "$SC/pr_view.json" > "$SC/j" && mv "$SC/j" "$SC/pr_view.json"; esegui
verifica "PR con conflitti secondo GitHub -> anomalia" anomalia 1 no no
nuovo pr-sconosciuta;  jq '.mergeable="UNKNOWN"' "$SC/pr_view.json" > "$SC/j" && mv "$SC/j" "$SC/pr_view.json"; esegui
verifica "stato della PR non ancora calcolato -> non unisce" non-ora 0 no no
nuovo pr-chiusa;       jq '.state="CLOSED"' "$SC/pr_view.json" > "$SC/j" && mv "$SC/j" "$SC/pr_view.json"; esegui; verifica "PR non aperta -> non unisce" non-ora 0 no no
nuovo pr-senza-check;  jq '.statusCheckRollup=[]' "$SC/pr_view.json" > "$SC/j" && mv "$SC/j" "$SC/pr_view.json"; esegui
verifica "PR senza alcun controllo (aperta dal bot) e ramo senza regole -> unisce (il resto e' garantito dagli altri controlli)" unita-e-rilascio-avviato 0 si si

# repository pubblico: una PR di un FORK con ramo "staging" non va ne' unita ne' modificata
nuovo fork-solo;       echo "[{\"number\":9,\"headRefOid\":\"$X\",\"isCrossRepository\":true}]" > "$SC/pr_list.json"; esegui
verifica "solo una PR di un fork con ramo 'staging' (stessa testa) -> non unisce" non-ora 0 no no
nuovo fork-prima;      echo "[{\"number\":9,\"headRefOid\":\"$X\",\"isCrossRepository\":true},{\"number\":7,\"headRefOid\":\"$X\",\"isCrossRepository\":false}]" > "$SC/pr_list.json"; esegui
verifica "PR di un fork per prima e PR vera dopo -> unisce la vera" unita-e-rilascio-avviato 0 si si
if ! chiamato "pr merge 7 " || chiamato "pr merge 9"; then FALLITI=$((FALLITI+1)); echo "FALLITO: doveva unire la #7 e mai la #9 del fork"; fi
nuovo fork-no-campo;   echo "[{\"number\":9,\"headRefOid\":\"$X\"}]" > "$SC/pr_list.json"; esegui
verifica "PR senza il campo isCrossRepository -> esclusa (fail-closed)" non-ora 0 no no
nuovo fork-vista;      jq '.isCrossRepository=true' "$SC/pr_view.json" > "$SC/j" && mv "$SC/j" "$SC/pr_view.json"; esegui
verifica "la PR letta da vicino risulta di un fork -> non unisce" non-ora 0 no no
nuovo fork-pr-script;  echo "[{\"number\":9,\"headRefOid\":\"$X\",\"isCrossRepository\":true}]" > "$SC/pr_list.json"; pr_script; TOTALE=$((TOTALE+1))
if [ "$RC" = 0 ] && chiamato "pr create" && ! chiamato "pr edit"; then echo "OK    promozione-pr.sh: PR di un fork non modificata, ne apre una vera"
else FALLITI=$((FALLITI+1)); echo "FALLITO promozione-pr.sh ha toccato la PR del fork"; fi
nuovo fork-pr-script2; echo "[{\"number\":9,\"headRefOid\":\"$X\",\"isCrossRepository\":true},{\"number\":7,\"headRefOid\":\"$X\",\"isCrossRepository\":false}]" > "$SC/pr_list.json"; pr_script; TOTALE=$((TOTALE+1))
if [ "$RC" = 0 ] && chiamato "pr edit 7 " && ! chiamato "pr edit 9" && ! chiamato "pr create"; then echo "OK    promozione-pr.sh: aggiorna la PR #7 e non la #9 del fork"
else FALLITI=$((FALLITI+1)); echo "FALLITO promozione-pr.sh: PR sbagliata"; fi

# forma imprevista delle risposte di GitHub: mai letta come "nessun controllo rosso"
nuovo json-rollup-str; jq '.statusCheckRollup="boh"' "$SC/pr_view.json" > "$SC/j" && mv "$SC/j" "$SC/pr_view.json"; esegui
verifica "statusCheckRollup e' una stringa (jq in errore) -> non unisce (fail-closed)" non-ora 0 no no
nuovo json-rollup-num; jq '.statusCheckRollup={"a":1}' "$SC/pr_view.json" > "$SC/j" && mv "$SC/j" "$SC/pr_view.json"; esegui
verifica "statusCheckRollup e' un oggetto -> non unisce (fail-closed)" non-ora 0 no no
nuovo json-voci-str;   jq '.statusCheckRollup=["x","y"]' "$SC/pr_view.json" > "$SC/j" && mv "$SC/j" "$SC/pr_view.json"; esegui
verifica "voci dei controlli non sono oggetti (jq in errore) -> non unisce" non-ora 0 no no
nuovo json-rotto;      echo '<html>502</html>' > "$SC/pr_view.json"; esegui; verifica "risposta non JSON da gh pr view -> non unisce" non-ora 0 no no
nuovo json-stato-manca; jq 'del(.mergeStateStatus)' "$SC/pr_view.json" > "$SC/j" && mv "$SC/j" "$SC/pr_view.json"; esegui
verifica "mergeStateStatus mancante -> non unisce" non-ora 0 no no
nuovo stato-strano;    jq '.mergeStateStatus="STRANO"' "$SC/pr_view.json" > "$SC/j" && mv "$SC/j" "$SC/pr_view.json"; esegui
verifica "mergeStateStatus non riconosciuto -> non unisce (si procede solo con stati noti)" non-ora 0 no no
nuovo lista-rotta;     echo '[{"number":"x","headRefOid":"y","isCrossRepository":false}]' > "$SC/pr_list.json"; esegui
verifica "numero della PR non numerico -> non unisce" non-ora 0 no no

# regole o indici Firestore diversi: la promozione automatica si ferma ("serve una persona")
nuovo regole-diverse;  cambia_staging firestore.rules r2; esegui
verifica "firestore.rules diverse tra staging e main -> si ferma: serve una persona" serve-persona 0 no no
nuovo indici-diversi;  cambia_staging firestore.indexes.json '{"indexes":[]}'; esegui
verifica "firestore.indexes.json diversi -> si ferma: serve una persona" serve-persona 0 no no
nuovo regole-uguali;   cambia_staging altro.txt x; esegui
verifica "regole e indici uguali (cambia solo altro) -> procede" unita-e-rilascio-avviato 0 si si

nuovo solo-verifica;   PROMOZIONE_SOLO_VERIFICA=si esegui; verifica "solo verifica -> tutto in regola ma NON unisce" solo-verifica 0 no no
nuovo extra-contenuto; touch "$SC/merge_extra"; esegui; verifica "unione con contenuto diverso da staging -> anomalia, rilascio NON avviato" anomalia 1 si no
nuovo disp-fallito;    touch "$SC/dispatch_fail"; esegui; verifica "avvio del rilascio fallito -> anomalia (main unito ma rilascio non partito)" anomalia 1 si si
nuovo rilascio-in-coda; touch "$SC/run_in_coda"; esegui
verifica "rilascio gia' in coda per lo stesso commit -> unisce ma non lo riavvia" unita-e-rilascio-avviato 0 si no

# apertura/aggiornamento della pull request di promozione (promozione-pr.sh)
verifica_pr() {  # $1 descrizione, $2 comando gh atteso, $3 n atteso
  TOTALE=$((TOTALE+1))
  if [ "$RC" = 0 ] && chiamato "$2" && grep -q "^n=$3$" "$GITHUB_OUTPUT" && ! chiamato "pr merge"; then echo "OK    $1"
  else FALLITI=$((FALLITI+1)); echo "FALLITO $1 (rc=$RC)"; sed 's/^/      | /' "$SC/log.txt" | tail -n 8; fi
}
nuovo pr-apre;     echo '[]' > "$SC/pr_list.json"; pr_script; verifica_pr "nessuna PR aperta -> la apre (gh pr create), senza unire" "pr create" 2
nuovo pr-aggiorna; pr_script; verifica_pr "PR gia' aperta -> la aggiorna (gh pr edit), senza unire" "pr edit 7" 2
nuovo pr-dimensione; pr_script; TOTALE=$((TOTALE+1))
if [ "$RC" = 0 ] && grep -q "Dimensione del salto" "$SC/body.md" && grep -q "non ancora in produzione: \*\*2\*\*" "$SC/body.md" && grep -q "file cambiati: \*\*2\*\*" "$SC/body.md" \
   && grep -q "^regole=no$" "$GITHUB_OUTPUT" && grep -q "identici a produzione" "$SC/body.md"; then echo "OK    corpo della PR: dimensione del salto (2 commit, 2 file) e regole identiche"
else FALLITI=$((FALLITI+1)); echo "FALLITO corpo della PR: dimensione o regole mancanti"; sed 's/^/      | /' "$SC/body.md" | head -20; fi
nuovo pr-regole-diverse; cambia_staging firestore.rules r2; pr_script; TOTALE=$((TOTALE+1))
if [ "$RC" = 0 ] && grep -q "^regole=si$" "$GITHUB_OUTPUT" && grep -q "DIFFERISCONO" "$SC/body.md" && ! grep -q "Si unisce da sola" "$SC/body.md"; then echo "OK    corpo della PR: regole Firestore diverse segnalate, nessuna promessa di unione automatica"
else FALLITI=$((FALLITI+1)); echo "FALLITO corpo della PR: regole diverse non segnalate"; fi
nuovo pr-niente;   ( cd "$SC/lavoro" && git push -q origin staging:main -f ); pr_script; TOTALE=$((TOTALE+1))
if [ "$RC" = 0 ] && grep -q "^n=0$" "$GITHUB_OUTPUT" && ! chiamato "pr create" && ! chiamato "pr edit"; then echo "OK    staging = main -> nessuna PR aperta o modificata"
else FALLITI=$((FALLITI+1)); echo "FALLITO staging = main: la PR non andava toccata"; fi

# T-20: storia LUNGA di staging (migliaia di commit con lo stesso albero della testa). Con `set -o pipefail` una pipeline `git log | awk '...exit'`
# muore per SIGPIPE (uscita 141) appena awk chiude: e' successo nel rilascio del 29/10/2026 PRIMA di toccare la produzione. Qui il caso e' deterministico:
# l'output di git log (> 64 KB) non entra tutto nel buffer della pipe, quindi git scrive ancora dopo che awk e' uscito.
storia_lunga() {  # $1 numero di commit "vuoti" (stesso albero) da aggiungere su staging; aggiorna X con la nuova testa nei file di scenario
  local VECCHIO="$X" NUM="$1"
  ( cd "$SC/lavoro" || exit 1
    { for i in $(seq 1 "$NUM"); do
        printf 'commit refs/heads/lunga\ncommitter prova <prova@example.com> %s +0000\ndata 2\nc\n' "$((1700000000 + i))"
        [ "$i" = 1 ] && printf 'from %s\n' "$VECCHIO"
        printf '\n'
      done; } | git fast-import --quiet && git push -q origin lunga:staging && git checkout -q -B staging lunga )
  X="$(git -C "$SC/lavoro" rev-parse lunga)"; export X
  sed -i "s/$VECCHIO/$X/g" "$SC"/*.json
}
nuovo storia-lunga; storia_lunga 3000; export STAGING_PROFONDITA=5000
# Il comportamento di `awk ... exit` dipende dall'implementazione: gawk chiude subito la pipe (SIGPIPE a monte, e' quello che e' successo nel rilascio),
# mawk 1.3.4-20240123 invece legge fino in fondo e non fallisce mai (per questo la prova sul PC era passata). La prova usa gawk se c'e'.
if command -v gawk >/dev/null 2>&1; then ln -sf "$(command -v gawk)" "$BIN/awk"; AWK_PROVA=gawk; else AWK_PROVA="$(awk --version 2>&1 | head -1)"; fi
echo "      (awk usato dalla prova: $AWK_PROVA)"
TOTALE=$((TOTALE+1))
# 1) la prova e' valida solo se la vecchia pipeline fallisce davvero con questo repository (altrimenti non dimostrerebbe nulla)
( cd "$SC/lavoro" && git fetch -q origin "+refs/heads/staging:refs/remotes/origin/staging" && T="$(git rev-parse 'HEAD^{tree}')" \
  && set -o pipefail && git log -n 5000 --format='%H %T' origin/staging | awk -v t="$T" '$2==t{print $1; exit}' >/dev/null ); RCV=$?
if [ "$RCV" = 141 ]; then echo "OK    premessa: la vecchia pipeline 'git log | awk ...exit' con pipefail esce con 141 (SIGPIPE) su una storia lunga"
elif [ "$AWK_PROVA" != gawk ]; then echo "NON VERIFICATA premessa: con questo awk ($AWK_PROVA) la vecchia pipeline non fallisce (installare gawk per riprodurre il 141); i casi seguenti non dimostrano la correzione"
else FALLITI=$((FALLITI+1)); echo "FALLITO premessa: la vecchia pipeline doveva uscire con 141, uscita $RCV (la prova non dimostrerebbe nulla)"; fi
# 2) verifica-da-staging.sh direttamente, con la testa di staging avanti di 3000 commit con lo stesso albero
TOTALE=$((TOTALE+1))
( cd "$SC/lavoro" && bash .claude/scripts/verifica-da-staging.sh > "$SC/log.txt" 2>&1 ); RC=$?
if [ "$RC" = 0 ] && grep -q "Contenuto identico al commit di staging $X" "$SC/log.txt" && grep -q "^OK: staging $X" "$SC/log.txt"; then
  echo "OK    verifica-da-staging.sh con storia lunga (3000 commit) -> uscita 0, sceglie la testa di staging"
else FALLITI=$((FALLITI+1)); echo "FALLITO verifica-da-staging.sh con storia lunga: uscita $RC (141 = SIGPIPE)"; sed 's/^/      | /' "$SC/log.txt" | tail -n 8; fi
# 3) lo stesso caso da `promuovi-staging.sh` (e' lui che chiama la verifica): deve unire e avviare il rilascio
esegui; verifica "promozione con storia lunga di staging (3000 commit, testa con lo stesso albero) -> unisce e avvia il rilascio" unita-e-rilascio-avviato 0 si si
unset STAGING_PROFONDITA

# T-20 (tester): HEAD con contenuto che NON esiste in staging (es. commit diretto su main) -> verifica-da-staging.sh deve fallire (1) senza interrogare GitHub.
nuovo albero-diverso; ( cd "$SC/lavoro" && echo extra > extra.txt && git add extra.txt && git commit -q -m "commit diretto" )
TOTALE=$((TOTALE+1)); : > "$SC/calls.log"
( cd "$SC/lavoro" && bash .claude/scripts/verifica-da-staging.sh > "$SC/log.txt" 2>&1 ); RC=$?
if [ "$RC" = 1 ] && grep -q "non coincide con nessuno" "$SC/log.txt" && ! chiamato "actions/workflows"; then echo "OK    verifica-da-staging.sh: contenuto assente da staging -> uscita 1, nessuna chiamata a GitHub"
else FALLITI=$((FALLITI+1)); echo "FALLITO verifica-da-staging.sh con contenuto assente da staging: uscita $RC (atteso 1)"; sed 's/^/      | /' "$SC/log.txt" | tail -n 6; fi

echo
echo "Casi: $TOTALE, falliti: $FALLITI"
[ "$FALLITI" = 0 ]
