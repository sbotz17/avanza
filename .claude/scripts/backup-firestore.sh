#!/usr/bin/env bash
# Backup verificato di Firestore (export su Google Cloud Storage). Ogni esecuzione e' un NUOVO backup numerato per data/ora (serie incrementale):
# non sovrascrive e non cancella mai il backup precedente. Per regola di Andrea (24/10/2026) si CONSERVANO GLI ULTIMI 20 backup coerenti
# (BACKUP_CONSERVA, default 20): dopo un backup riuscito, solo questa procedura ruota i piu' vecchi (mai a mano, mai il backup appena fatto).
# La squadra lo esegue PRIMA di ogni variazione al database, di qualsiasi genere (dati, struttura, indici, migrazioni, script di modifica).
# Uso:   backup-firestore.sh <cartella-locale-per-registro-e-impronte>
# Variabili: BUCKET (obbligatoria, nome del bucket SENZA gs://; meglio con blocco di conservazione)
#            FIRESTORE_PROJECT (default avanza-b62d7)  FIRESTORE_DATABASE (default "(default)")
#            BACKUP_CONSERVA (default 20, quanti backup coerenti tenere)  BACKUP_PREFISSO (default avanza)  BACKUP_TENTATIVI (default 3)  BACKUP_ATTESA secondi (default 60)
# Credenziali: quelle di Google gia' attive (nella CI: google-github-actions/auth). Mai scritte nei file.
# Il service account deve poter esportare Firestore (ruolo Cloud Datastore Import Export Admin) e scrivere nel bucket.
#
# COERENZA ("fotocopia esatta"): l'impronta del database (collezioni, documenti, hash) si calcola PRIMA e DOPO l'export.
# Se coincidono, nessuno ha modificato i dati durante il backup e l'impronta descrive esattamente il backup.
# Altrimenti si riprova (BACKUP_TENTATIVI); se non riesce il backup FALLISCE: meglio fermarsi che avere un backup non verificabile.
# Gli export non coerenti NON vengono cancellati: restano nel bucket, annotati come "non-coerente" nel registro, fuori dalle prove.
#
# Al termine scrive il segnale ".claude/backup-ok.json" nella cartella del progetto (cwd), che la guardia automatica
# richiede prima di consentire modifiche ai dati di produzione.
set -euo pipefail
DIR="${1:?cartella locale per registro e impronte}"
: "${BUCKET:?imposta BUCKET (nome del bucket Google Cloud Storage per i backup)}"
PROGETTO="${FIRESTORE_PROJECT:-avanza-b62d7}"; DB="${FIRESTORE_DATABASE:-(default)}"; PREF="${BACKUP_PREFISSO:-avanza}"
S="$(cd "$(dirname "$0")" && pwd)"
command -v gcloud >/dev/null || { echo "ERRORE: gcloud non installato"; exit 1; }
command -v node >/dev/null || { echo "ERRORE: node non installato"; exit 1; }
mkdir -p "$DIR"; chmod 700 "$DIR" 2>/dev/null || true

TENT="${BACKUP_TENTATIVI:-3}"; DEST=""; IMP=""
for n in $(seq 1 "$TENT"); do
  TS="$(date -u +%Y%m%d-%H%M%S)-$(date +%N | cut -c1-6)"
  CAND="gs://$BUCKET/$PREF/backup-$TS"
  # mai sovrascrivere nulla: se la cartella esiste gia' nel bucket si cambia nome
  while gcloud storage ls "$CAND" >/dev/null 2>&1; do CAND="${CAND}-b"; done
  PRIMA="$(mktemp)"; DOPO="$(mktemp)"
  FIRESTORE_PROJECT="$PROGETTO" FIRESTORE_DATABASE="$DB" node "$S/impronta-firestore.mjs" > "$PRIMA"
  gcloud firestore export "$CAND" --project="$PROGETTO" --database="$DB" --quiet
  FIRESTORE_PROJECT="$PROGETTO" FIRESTORE_DATABASE="$DB" node "$S/impronta-firestore.mjs" > "$DOPO"
  if cmp -s "$PRIMA" "$DOPO"; then
    DEST="$CAND"; IMP="$DIR/$(basename "$CAND").impronta"; mv "$DOPO" "$IMP"; rm -f "$PRIMA"; break
  fi
  echo "ATTENZIONE: i dati sono cambiati durante il backup (tentativo $n di $TENT). L'export $CAND resta nel bucket (non-coerente)."
  echo "$(date -Is) $CAND non-coerente" >> "$DIR/INDICE-BACKUP.log"
  rm -f "$PRIMA" "$DOPO"
  if [ "$n" -lt "$TENT" ]; then sleep "${BACKUP_ATTESA:-60}"; fi
done
[ -n "$DEST" ] || { echo "ERRORE: impossibile ottenere un backup coerente (database in attivita'). Riprova in un orario a basso traffico. NESSUNA modifica ai dati deve procedere."; exit 1; }
[ -s "$IMP" ] || { echo "ERRORE: impronta vuota (database senza collezioni o non leggibile)"; exit 1; }

# verifica che l'export esista e abbia il file dei metadati
ELENCO="$(gcloud storage ls -r -l "$DEST" 2>/dev/null)" || { echo "ERRORE: export non leggibile dal bucket"; exit 1; }
# here-string e non `echo | grep -q`: con pipefail, se l'elenco supera il buffer di una pipe (64 KB) echo prende SIGPIPE quando grep -q esce (T-20)
grep -q 'overall_export_metadata' <<< "$ELENCO" || { echo "ERRORE: export incompleto (manca overall_export_metadata)"; exit 1; }
SIZE="$(echo "$ELENCO" | awk '/^ *[0-9]+ /{s+=$1} END{print s+0}')"
SHA="$(echo "$ELENCO" | awk '/gs:\/\//{print $NF" "$1}' | sort | sha256sum | cut -d' ' -f1)"   # impronta dell'elenco file e dimensioni
[ "$SIZE" -gt 0 ] || { echo "ERRORE: export vuoto"; exit 1; }
# l'impronta dei dati viaggia con il backup (nello stesso bucket, solo aggiunta)
gcloud storage cp "$IMP" "$DEST.impronta" --no-clobber >/dev/null
chmod 400 "$IMP" 2>/dev/null || true
echo "$(date -Is) $DEST $SIZE $SHA" >> "$DIR/INDICE-BACKUP.log"           # registro solo in aggiunta
mkdir -p .claude
printf '{"epoch": %s, "file": "%s", "sha256": "%s", "size": %s, "backup": "%s"}\n' "$(date +%s)" "$IMP" "$SHA" "$SIZE" "$DEST" > .claude/backup-ok.json
# ---- ROTAZIONE: si tengono gli ultimi BACKUP_CONSERVA backup coerenti (default 20); i piu' vecchi li rimuove QUESTA procedura e solo lei ----
# Si guarda il bucket (non il registro locale, che nella CI non resta tra un'esecuzione e l'altra): un backup e' COERENTE se ha accanto il file .impronta.
KEEP="${BACKUP_CONSERVA:-20}"
if [[ "$KEEP" =~ ^[0-9]+$ ]] && [ "$KEEP" -ge 1 ]; then
  ELENCO_IMP="$(gcloud storage ls "gs://$BUCKET/$PREF/" 2>/dev/null | grep -E 'backup-[0-9-]+(-b)*\.impronta$' | sort || true)"
  TOT="$(printf '%s\n' "$ELENCO_IMP" | grep -c . || true)"
  if [ "${TOT:-0}" -gt "$KEEP" ]; then
    printf '%s\n' "$ELENCO_IMP" | head -n "$((TOT - KEEP))" | while read -r IMPV; do
      [ -n "$IMPV" ] || continue
      V="${IMPV%.impronta}"
      [ "$V" = "$DEST" ] && continue                         # mai il backup appena fatto
      if gcloud storage rm -r "$V" >/dev/null 2>&1; then
        gcloud storage rm "$IMPV" >/dev/null 2>&1 || true
        echo "$(date -Is) ruotato $V" >> "$DIR/INDICE-BACKUP.log"
        echo "Rotazione: rimosso il backup piu' vecchio $V (si conservano gli ultimi $KEEP)."
      else
        echo "ATTENZIONE: impossibile rimuovere $V (probabile blocco di conservazione del bucket): resta dov'e', la rotazione ci riprova al prossimo backup."
      fi
    done
  fi
fi
echo "BACKUP OK: $DEST ($SIZE byte, sha256 elenco $SHA)"
echo "Impronta dei dati: $IMP"
echo "Ricorda: verifica anche il ripristino su una copia (ripristina-firestore.sh --verifica) prima di operare in produzione."
