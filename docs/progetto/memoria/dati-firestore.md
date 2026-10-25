# Nodo: Dati e Firestore

Ultima revisione: 2026-10-25

- Database `(default)` in `eur3` (regione definitiva). Le regole (`firestore.rules`) sono l'unica difesa vera; nessuna collezione senza regole esplicite.
- Schema completo: `docs/database.md` (da aggiornare a ogni modifica) e riepilogo `database.md`. Collezioni: `users`, `clientAccess`, `projects` (+ `tasks`, `taskCosts`, `timeEntries`, chat dei task), `teamMembers`, e per T-20 `githubRepos` e `githubCollegamento` (nessuna regola per i client: solo Admin SDK).
- Modifiche SOLO additive e idempotenti; regole e indici si pubblicano con il workflow "Setup Firestore" (da `main`), NON dal rilascio (che avvisa soltanto se cambiano).
- Contatore dei task: `projects/{id}.nextTaskNumber`, incrementato solo dalla creazione di un task (transazione); corretto il bug che lo azzerava (R-4/T-19). Letture reali del 25/10: Commerciali 14 (max T-13), Volty 27 (max T-26), Avanza 20 (max T-19).
- Backup: bucket `avanza-backup-b62d7` (variabile `BUCKET_BACKUP_FIRESTORE`), script `.claude/scripts/backup-firestore.sh` con impronta prima/dopo, ultimi 20 conservati (rotazione solo dello script); backup giornaliero in `backup-giornaliero.yml` (partirà dopo la promozione). **Prova di ripristino IDENTICO non ancora fatta** (impegno: prima del prossimo rilascio).
- Ripristino della produzione: sempre decisione di Andrea. Cancellare o sovrascrivere dati reali: solo insieme ad Andrea.
- Azioni sui dati dal workflow "Registra ore squadra": `membro`, `ore`, `migra`, `admin`, `crea-progetto`, `importa-task`, `stato` (sola lettura, ora con contatori e membri), `copia-squadra`, `collegamento`, `collegamento-stato`, `domande`, `rispondi`, `backup`. Il backup precede ogni azione che scrive.
- Controlli: `.claude/scripts/controlla-regole.py` (in CI); emulatore Firestore per i test delle funzioni.
