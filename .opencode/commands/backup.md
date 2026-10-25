---
description: "Backup verificato del database (obbligatorio prima di OGNI variazione al database, di qualsiasi genere; si conservano gli ultimi 20)"
agent: coordinatore
---

Esegui un BACKUP VERIFICATO del database. $ARGUMENTS

1. Leggi docs/progetto/ambienti.md e produzione.md per sapere progetto Firebase, bucket dei backup (Google Cloud Storage con blocco di conservazione) e come si ottengono le credenziali. Se mancano, il backup lo esegue la CI (`backup-giornaliero.yml`, `rilascio-produzione.yml`): gli agenti non hanno le credenziali di produzione e non le chiedono. Non stampare mai credenziali.
2. Esegui `.claude/scripts/backup-firestore.sh` (export di Firestore con `gcloud firestore export` verso il bucket; calcola l'impronta prima e dopo con `.claude/scripts/impronta-firestore.mjs`: se i dati cambiano durante il backup riprova, e se non ci riesce fallisce). Gli agenti non hanno le credenziali di produzione: per la produzione il backup lo esegue la CI.
3. Controlla l'esito: backup non vuoto, verificato, registrato in INDICE-BACKUP.log. Confronta i conteggi di documenti per collezione tra database e backup (ripristinandolo in un database copia se si tratta di un'operazione importante).
4. Annota in docs/progetto/produzione.md: data, file, dimensione, checksum.
5. Ogni backup è nuovo e numerato (serie incrementale): NON sovrascrivere né cancellare a mano i precedenti. Lo script ruota da solo quelli oltre gli ultimi 20 (`BACKUP_CONSERVA`). Riferisci nel resoconto in due righe: dove si trova il backup e che è verificato.
