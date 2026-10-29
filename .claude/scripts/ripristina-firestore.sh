#!/usr/bin/env bash
# PROVA di ripristino di un backup Firestore su un database COPIA, con confronto dell'impronta (IDENTICO oppure DIFFERENTE).
# Non tocca MAI il database (default) di produzione. Il ripristino reale in produzione e' una DECISIONE DI ANDREA:
# la squadra prepara analisi, backup scelto e prova su copia, ma non lo esegue.
#
# Uso:  ripristina-firestore.sh --verifica <gs://bucket/.../backup-...> [--impronta <file-impronta>] [--elimina-copia]
#   --impronta       file con l'impronta del backup (default: <backup>.impronta scaricata dal bucket)
#   --elimina-copia  alla fine elimina il database copia creato da questo script (solo nomi copia-ripristino-*; lo usa la CI,
#                    la guardia automatica impedisce agli agenti di cancellare database)
# Variabili: FIRESTORE_PROJECT (default avanza-b62d7)  FIRESTORE_LOCATION (default eur3: la stessa del database)
set -euo pipefail
S="$(cd "$(dirname "$0")" && pwd)"
[ "${1:-}" = "--verifica" ] || { echo "Uso: $0 --verifica <gs://backup> [--impronta file] [--elimina-copia]"; echo "Il ripristino reale in produzione non e' automatizzato: e' una decisione di Andrea."; exit 2; }
BK="${2:?indirizzo del backup (gs://...)}"; shift 2
IMPR=""; ELIMINA=0
while [ $# -gt 0 ]; do case "$1" in --impronta) IMPR="${2:?file}"; shift 2;; --elimina-copia) ELIMINA=1; shift;; *) echo "opzione sconosciuta: $1"; exit 2;; esac; done
PROGETTO="${FIRESTORE_PROJECT:-avanza-b62d7}"; LOC="${FIRESTORE_LOCATION:-eur3}"
case "$BK" in gs://*) ;; *) echo "ERRORE: il backup deve essere un indirizzo gs://"; exit 1;; esac
COPIA="copia-ripristino-$(date -u +%Y%m%d%H%M%S)"     # nome sempre nuovo: non si riusa e non si sovrascrive nulla
case "$COPIA" in copia-ripristino-*) ;; *) echo "ERRORE: nome copia non valido"; exit 1;; esac

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
if [ -z "$IMPR" ]; then
  gcloud storage cp "$BK.impronta" "$TMP/backup.impronta" >/dev/null || { echo "ERRORE: impronta del backup non trovata ($BK.impronta)"; exit 1; }
  IMPR="$TMP/backup.impronta"
fi
[ -s "$IMPR" ] || { echo "ERRORE: impronta del backup vuota"; exit 1; }
gcloud storage ls -r "$BK" | grep -q 'overall_export_metadata' || { echo "ERRORE: il backup non ha i metadati dell'export"; exit 1; }

echo "Creo il database copia $COPIA ($PROGETTO, $LOC)..."
gcloud firestore databases create --database="$COPIA" --location="$LOC" --type=firestore-native --project="$PROGETTO" --quiet
echo "Importo il backup nella copia..."
gcloud firestore import "$BK" --database="$COPIA" --project="$PROGETTO" --quiet
FIRESTORE_PROJECT="$PROGETTO" FIRESTORE_DATABASE="$COPIA" node "$S/impronta-firestore.mjs" > "$TMP/copia.impronta"

if diff <(sort "$IMPR") <(sort "$TMP/copia.impronta") >/dev/null; then
  echo "RISULTATO: IDENTICO al backup (collezioni, documenti e contenuto)."; ESITO=0
else
  echo "RISULTATO: DIFFERENTE dal backup! Dettaglio:"; diff <(sort "$IMPR") <(sort "$TMP/copia.impronta") || true; ESITO=1
fi
if [ "$ELIMINA" = 1 ]; then
  echo "Elimino la copia $COPIA (creata da questo script)."
  gcloud firestore databases delete --database="$COPIA" --project="$PROGETTO" --quiet || echo "ATTENZIONE: copia $COPIA non eliminata, va tolta a mano."
else
  echo "La copia $COPIA resta nel progetto per le verifiche: si elimina dalla console quando non serve piu'."
fi
exit "$ESITO"
