#!/usr/bin/env bash
# Salvavita dei flussi di TEST (deploy.yml: deploy di test e anteprime): il flusso di test non deve mai poter pubblicare sulla produzione.
# Fallisce (exit 1) se il progetto Firebase indicato e' quello di produzione, oppure se la chiave di servizio di test e' in realta' quella della produzione.
# Variabili: PROGETTO (progetto di test), SA_TEST (contenuto JSON della chiave di test, facoltativo: non viene mai stampato).
# Usato da deploy.yml (passi "Il progetto di test e' configurato?" di deploy-test e anteprima): prima la stessa logica era scritta due volte.
set -uo pipefail
PROD="avanza-b62d7"
if [ "${PROGETTO:-}" = "$PROD" ]; then
  echo "::error::PROGETTO_FIREBASE_TEST punta alla PRODUZIONE ($PROD): flusso di test fermato."; exit 1
fi
if [ -n "${SA_TEST:-}" ] && [ "$(printf '%s' "$SA_TEST" | jq -r '.project_id // empty' 2>/dev/null)" = "$PROD" ]; then
  echo "::error::FIREBASE_SERVICE_ACCOUNT_TEST e' la chiave della PRODUZIONE: flusso di test fermato."; exit 1
fi
exit 0
