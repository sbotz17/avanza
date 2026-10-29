#!/usr/bin/env bash
# Verifica che il commit che sta per andare in produzione (HEAD) sia ESATTAMENTE quello gia' provato su staging:
#   1. esiste su origin/staging un commit con lo STESSO albero di file (stesso SHA, oppure squash/merge che da' lo stesso contenuto);
#   2. su quel commit il flusso "Deploy Avanza Web" (deploy.yml, evento push) e' concluso con successo, cioe' controlli verdi E pubblicazione
#      sul progetto di TEST riuscita davvero (sito, regole e indici Firestore, funzione): i passi "saltati" (test non configurato) NON valgono.
# Se anche solo una cosa non torna: esito 1, il rilascio / la pubblicazione delle regole NON deve procedere (nel dubbio, NO-GO).
#
# Uso: verifica-da-staging.sh        (dentro il repository, HEAD = commit da rilasciare)
# Variabili: GH_TOKEN (token con lettura delle Actions), GITHUB_REPOSITORY (owner/repo).
#            STAGING_PROFONDITA (default 400: quanti commit recenti di staging si guardano)
#            RICHIEDI_TEST_VERDI=si (facoltativa, usata dalla promozione automatica): richiede anche che `flutter test` sia passato davvero su quel commit.
#              Su staging i test rossi non fermano la CI (TEST_OBBLIGATORI), ma fermano il rilascio: per non promuovere un commit che il rilascio rifiuterebbe,
#              si guarda il passo "Avviso test non superati" di ci.yml (eseguito solo se i test sono falliti): deve risultare "skipped" e il passo "Test" deve essere stato eseguito.
# Valvola (solo Andrea, variabile GitHub CONTROLLO_STAGING = no): salta il controllo con un avviso (da usare solo se il controllo stesso si
# rompe; i nomi dei passi sotto devono restare uguali a quelli di deploy.yml, altrimenti il controllo fallisce: e' voluto, fallisce "chiuso").
# NON PROVATO su GitHub: le chiamate all'API delle Actions non sono eseguibili in questo ambiente. La logica sull'albero e' stata provata su un repository di esempio.
set -euo pipefail
if [ "${CONTROLLO_STAGING:-}" = "no" ]; then
  echo "::warning::Controllo 'gia' provato su staging' SALTATO (CONTROLLO_STAGING=no)."; exit 0
fi
REPO="${GITHUB_REPOSITORY:?GITHUB_REPOSITORY mancante}"; N="${STAGING_PROFONDITA:-400}"
PASSI=("Deploy Hosting (progetto di test)" "Regole e indici Firestore (progetto di test)" "Deploy funzione (progetto di test)")

git fetch --quiet origin "+refs/heads/staging:refs/remotes/origin/staging" \
  || { echo "ERRORE: impossibile leggere il ramo staging"; exit 1; }
HEAD_SHA="$(git rev-parse HEAD)"; TREE="$(git rev-parse 'HEAD^{tree}')"
# Il commit PIU' RECENTE di staging con lo stesso albero. Attenzione (T-20): awk NON deve uscire al primo risultato ("exit"): con `pipefail`
# gawk chiude la pipe subito, `git log` riceve SIGPIPE e lo script termina con 141 PRIMA di fare qualsiasi controllo (rilascio del 29/10/2026).
# Cosi' awk legge tutto l'elenco (al massimo $N righe) e stampa solo la prima corrispondenza.
TROVATO="$(git log -n "$N" --format='%H %T' origin/staging | awk -v t="$TREE" '$2==t && !gia {print $1; gia=1}')"
if [ -z "$TROVATO" ]; then
  echo "ERRORE: il contenuto di $HEAD_SHA non coincide con nessuno degli ultimi $N commit di staging."
  echo "In produzione si va solo con cio' che e' gia' passato da staging, senza aggiunte. Possibili cause: commit diretto su main, conflitto risolto a mano, staging troppo avanti."
  exit 1
fi
echo "Contenuto identico al commit di staging $TROVATO (HEAD di questo rilascio: $HEAD_SHA)."

RUNS="$(gh api "repos/$REPO/actions/workflows/deploy.yml/runs?head_sha=$TROVATO&event=push&status=completed&per_page=30" \
        --jq '[.workflow_runs[] | select(.conclusion=="success") | .id] | .[]' 2>/dev/null)" \
  || { echo "ERRORE: impossibile leggere le esecuzioni di deploy.yml (permesso actions: read mancante?)"; exit 1; }
[ -n "$RUNS" ] || { echo "ERRORE: nessuna esecuzione di 'Deploy Avanza Web' conclusa con successo sul commit di staging $TROVATO (CI rossa, non finita o mai partita)."; exit 1; }

for RUN in $RUNS; do
  OK=1
  JOBS="$(gh api "repos/$REPO/actions/runs/$RUN/jobs?per_page=100" 2>/dev/null)" || continue
  for P in "${PASSI[@]}"; do
    C="$(printf '%s' "$JOBS" | jq -r --arg p "$P" '[.jobs[] | select(.name=="deploy-test") | .steps[] | select(.name==$p) | .conclusion] | first // "assente"')"
    if [ "$C" != "success" ]; then OK=0; echo "Esecuzione $RUN: passo '$P' = $C"; fi
  done
  if [ "$OK" = 1 ] && [ "${RICHIEDI_TEST_VERDI:-}" = "si" ]; then
    # job del CI richiamato da deploy.yml: il suo nome termina con "controlli" ("controlli / controlli"); fallisce "chiuso" se i nomi non tornano
    T="$(printf '%s' "$JOBS" | jq -r '[.jobs[] | select(.name|test("controlli$")) | .steps[] | select(.name=="Test") | .conclusion] | first // "assente"')"
    A="$(printf '%s' "$JOBS" | jq -r '[.jobs[] | select(.name|test("controlli$")) | .steps[] | select(.name=="Avviso test non superati") | .conclusion] | first // "assente"')"
    if { [ "$T" != "success" ] && [ "$T" != "failure" ]; } || [ "$A" != "skipped" ]; then
      OK=0; echo "Esecuzione $RUN: i test automatici non risultano passati (passo 'Test' = $T, 'Avviso test non superati' = $A; atteso: eseguito / skipped)"
    fi
  fi
  if [ "$OK" = 1 ]; then
    echo "OK: staging $TROVATO ha controlli verdi e pubblicazione di test riuscita (sito, regole e indici, funzione), esecuzione $RUN."
    exit 0
  fi
done
echo "ERRORE: il commit di staging $TROVATO non risulta pubblicato per intero sull'ambiente di test (passi saltati o falliti sopra)."
echo "Senza prova sul test non si va in produzione: controlla FIREBASE_SERVICE_ACCOUNT_TEST e il deploy di test."
exit 1
