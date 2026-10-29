#!/usr/bin/env bash
# Prova in locale di backup-firestore.sh e ripristina-firestore.sh con un `gcloud` e un `node` FINTI (nessun accesso a Google, nessun segreto).
# Caso (T-20): l'elenco dei file del backup e' LUNGO (migliaia di righe, oltre i 64 KB del buffer di una pipe) e il file dei metadati compare per primo.
# Con `set -o pipefail` una pipeline `produttore | grep -q ...` termina con 141 (SIGPIPE) appena grep trova la riga e chiude: il controllo
# "il backup ha i metadati dell'export" risultava FALSO anche con un backup buono (e il backup / la prova di ripristino si fermavano).
# La parte analoga per `verifica-da-staging.sh` (git log | awk ...exit) e' in prova-promozione.sh.
# Uso: bash .claude/scripts/prova-script-gcloud.sh        (dalla radice del repository). Esito 0 = tutti i casi superati.
set -uo pipefail
RADICE="$(git rev-parse --show-toplevel)"
BASE_TMP="$(mktemp -d)"; trap 'rm -rf "$BASE_TMP"' EXIT
FALLITI=0; TOTALE=0
BIN="$BASE_TMP/bin"; mkdir -p "$BIN"
ELENCO_FILE="$BASE_TMP/elenco.txt"; export ELENCO_FILE
# elenco finto dell'export: i metadati PER PRIMI, poi 5000 file (circa 500 KB)
{ echo "      512  2026-10-29T00:00:00Z  gs://bucket-prova/avanza/backup-x/backup-x.overall_export_metadata"
  for i in $(seq 1 5000); do echo "     1000  2026-10-29T00:00:00Z  gs://bucket-prova/avanza/backup-x/all_namespaces/kind_cartella/output-$i"; done; } > "$ELENCO_FILE"
cat > "$BIN/gcloud" <<'STUB'
#!/usr/bin/env bash
# gcloud finto: risponde solo ai comandi usati dai due script
case "$1 $2" in
  "storage ls")
     case "$*" in
       *" -r -l "*|*" -r gs://"*) exec cat "$ELENCO_FILE" ;;             # elenco dei file dell'export (lungo)
       *"/avanza/backup-"*) exit 1 ;;                                      # il candidato non esiste ancora nel bucket
       *) exit 0 ;;                                                        # elenco dei backup con impronta: vuoto (niente rotazione)
     esac ;;
  "storage cp") for a in "$@"; do U="$a"; done; echo "collezione 1 abc" > "$U" 2>/dev/null || true; exit 0 ;;
  "firestore export"|"firestore databases"|"firestore import") exit 0 ;;
  *) echo "gcloud finto: comando non previsto: $*" >&2; exit 2 ;;
esac
STUB
cat > "$BIN/node" <<'STUB'
#!/usr/bin/env bash
echo "collezione 1 abc"
STUB
chmod +x "$BIN/gcloud" "$BIN/node"
export PATH="$BIN:$PATH" BUCKET=bucket-prova BACKUP_TENTATIVI=1 BACKUP_ATTESA=0

esito() {  # $1 descrizione, $2 rc atteso, $3 testo atteso nel log, $4 rc ottenuto, $5 file di log
  TOTALE=$((TOTALE+1))
  if [ "$4" = "$2" ] && grep -q -- "$3" "$5"; then echo "OK    $1"
  else FALLITI=$((FALLITI+1)); echo "FALLITO $1: atteso rc=$2 e '$3', ottenuto rc=$4"; sed 's/^/      | /' "$5" | tail -n 6; fi
}

# premessa: la vecchia forma del controllo fallisce davvero con un elenco di queste dimensioni
TOTALE=$((TOTALE+1))
( set -o pipefail; E="$(cat "$ELENCO_FILE")"; echo "$E" | grep -q 'overall_export_metadata' ); RC=$?
if [ "$RC" = 141 ]; then echo "OK    premessa: 'echo \"\$ELENCO\" | grep -q' con pipefail esce con 141 su un elenco lungo"
else FALLITI=$((FALLITI+1)); echo "FALLITO premessa: la vecchia forma doveva uscire con 141, uscita $RC (la prova non dimostrerebbe nulla)"; fi
TOTALE=$((TOTALE+1))
( set -o pipefail; cat "$ELENCO_FILE" | grep -q 'overall_export_metadata' ); RC=$?
if [ "$RC" = 141 ]; then echo "OK    premessa: 'produttore | grep -q' con pipefail esce con 141 su un elenco lungo"
else FALLITI=$((FALLITI+1)); echo "FALLITO premessa: 'produttore | grep -q' doveva uscire con 141, uscita $RC"; fi

# backup-firestore.sh: elenco lungo -> deve riuscire
LAV="$BASE_TMP/lavoro"; mkdir -p "$LAV"
( cd "$LAV" && bash "$RADICE/.claude/scripts/backup-firestore.sh" "$LAV/registro" > "$BASE_TMP/backup.log" 2>&1 ); RC=$?
esito "backup-firestore.sh con elenco dell'export lungo (5001 righe) -> BACKUP OK" 0 "BACKUP OK" "$RC" "$BASE_TMP/backup.log"
# ... e deve fallire quando i metadati mancano davvero (il controllo non e' stato indebolito)
grep -v overall_export_metadata "$ELENCO_FILE" > "$BASE_TMP/senza.txt"; ELENCO_FILE="$BASE_TMP/senza.txt"
( cd "$LAV" && bash "$RADICE/.claude/scripts/backup-firestore.sh" "$LAV/registro2" > "$BASE_TMP/backup2.log" 2>&1 ); RC=$?
esito "backup-firestore.sh senza metadati nell'elenco -> ERRORE (controllo ancora attivo)" 1 "export incompleto" "$RC" "$BASE_TMP/backup2.log"
ELENCO_FILE="$BASE_TMP/elenco.txt"

# ripristina-firestore.sh: elenco lungo -> IDENTICO; senza metadati -> errore
( bash "$RADICE/.claude/scripts/ripristina-firestore.sh" --verifica gs://bucket-prova/avanza/backup-x > "$BASE_TMP/ripr.log" 2>&1 ); RC=$?
esito "ripristina-firestore.sh con elenco del backup lungo -> IDENTICO" 0 "IDENTICO" "$RC" "$BASE_TMP/ripr.log"
ELENCO_FILE="$BASE_TMP/senza.txt"
( bash "$RADICE/.claude/scripts/ripristina-firestore.sh" --verifica gs://bucket-prova/avanza/backup-x > "$BASE_TMP/ripr2.log" 2>&1 ); RC=$?
esito "ripristina-firestore.sh senza metadati nel backup -> ERRORE (controllo ancora attivo)" 1 "non ha i metadati" "$RC" "$BASE_TMP/ripr2.log"

echo
echo "Casi: $TOTALE, falliti: $FALLITI"
[ "$FALLITI" = 0 ]
