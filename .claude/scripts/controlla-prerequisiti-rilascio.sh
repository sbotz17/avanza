#!/usr/bin/env bash
# Prima di toccare la produzione: i segreti e le variabili che servono ESISTONO e sono coerenti? Se manca qualcosa si ferma tutto
# PRIMA del deploy (meglio un rilascio fermato che un rilascio a meta'). Non stampa MAI i valori dei segreti.
# Variabili lette dall'ambiente del passo (il workflow le passa): FIREBASE_SERVICE_ACCOUNT (segreto), COMPLETI e BUCKET (variabili).
# Esito: 0 = tutto presente, 1 = qualcosa manca (elenco sotto). I segreti degli avvisi sono facoltativi: se mancano e' solo un avviso.
set -uo pipefail
KO=0
if [ -z "${FIREBASE_SERVICE_ACCOUNT:-}" ]; then
  echo "MANCA il segreto FIREBASE_SERVICE_ACCOUNT (chiave di pubblicazione di produzione)."; KO=1
else
  PID="$(printf '%s' "$FIREBASE_SERVICE_ACCOUNT" | jq -r 'select(.type=="service_account") | .project_id' 2>/dev/null || true)"
  if [ -z "$PID" ]; then echo "Il segreto FIREBASE_SERVICE_ACCOUNT non e' una chiave di service account valida (JSON)."; KO=1
  elif [ "$PID" != "avanza-b62d7" ]; then echo "Il segreto FIREBASE_SERVICE_ACCOUNT appartiene al progetto '$PID', non a avanza-b62d7: si rifiuta di pubblicare."; KO=1
  else echo "OK  FIREBASE_SERVICE_ACCOUNT presente e del progetto avanza-b62d7."; fi
fi
if [ "${COMPLETI:-}" = "true" ]; then
  if [ -z "${BUCKET:-}" ]; then echo "MANCA la variabile BUCKET_BACKUP_FIRESTORE (servono backup e prova su copia: PRODUZIONE_CONTROLLI_COMPLETI e' true)."; KO=1
  else echo "OK  bucket dei backup indicato."; fi
else
  echo "::warning::PRODUZIONE_CONTROLLI_COMPLETI non e' 'true': questo rilascio NON fa backup, prova su copia e confronto dei dati (il bucket dei backup non e' ancora attivo). Il rilascio non modifica i dati, ma va detto ad Andrea."
fi
if [ -z "${AVVISI_URL:-}" ] || [ -z "${AVVISI_TOKEN:-}" ] || [ -z "${AVVISI_NUMERO:-}" ]; then
  echo "::warning::Avvisi WhatsApp non configurati (AVVISI_URL / AVVISI_TOKEN / AVVISI_NUMERO): Andrea non riceverebbe l'avviso se il rilascio fallisce. Controllare l'esito su GitHub."
fi
[ "$KO" = 0 ] && echo "Prerequisiti del rilascio: OK" || echo "Prerequisiti del rilascio: NON soddisfatti, rilascio fermato prima di toccare la produzione."
exit "$KO"
