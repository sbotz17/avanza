# Sviluppi in attesa di validazione

## [1] Integrazione automatica GitHub → Avanza

**Data**: 2026-10-22
**Stato**: APPROVATO dal validatore — in attesa di validazione Andrea

### Cosa fa (in parole semplici)

Quando la squadra di sviluppo lavora su un progetto GitHub collegato ad Avanza, i task si aggiornano **automaticamente** senza che nessuno debba farlo a mano:

- Aprire un branch `feature/T-3-login` → il task T-3 passa in "Attivo"
- Fare un commit → appare una nota nel task con il messaggio del commit
- Aprire una Pull Request → appare la nota con il numero PR
- Fare il merge della PR → il task passa in "In revisione"
- Ricevere una review approvata → il task passa in "Validato"

Inoltre ogni task mostra ora un **codice breve** (es. "T-3") come badge colorato nella lista, nel kanban e nella schermata di dettaglio.

### Come provarlo

1. **Badge taskCode**: su https://avanza-b62d7.web.app, entra in un progetto con almeno un task — dovresti vedere il badge "T-N" accanto al titolo di ogni task. I task vecchi (senza codice) non mostrano nulla.

2. **Cloud Function** (richiede configurazione): per ora non ancora deployata in produzione — serve prima la tua validazione. I 53 test automatici sono verdi.

### Esiti dei test
- 5 test Flutter: **PASS**
- 53 test Jest (Cloud Function): **PASS**
- `flutter analyze --no-fatal-infos`: nessun nuovo errore introdotto
- Rischio dati: **nullo** (la funzione aggiunge solo note e aggiorna campi nullable; nessun dato esistente viene alterato)

### Passi dopo la tua validazione

1. Impostare `GITHUB_WEBHOOK_SECRET` in Firebase Secret Manager
2. Deploy Cloud Function (`firebase deploy --only functions`)
3. Configurare il webhook su ogni repo GitHub da collegare

### Come si torna indietro

- Badge UI: revert del commit, nessun effetto sui dati
- Cloud Function: semplicemente non viene deployata; i task in Firestore non vengono toccati

### Rischi
Nessuno identificato. La funzione è read-only su GitHub e write-only su Firestore con campi aggiuntivi nullable.

---

## [2] Allineamento alla squadra: ambienti test/produzione e regole di protezione

**Data**: 2026-10-23
**Stato**: preparato dalla squadra — in attesa di validazione Andrea (e di alcune configurazioni tue, vedi sotto)

### Cosa fa (in parole semplici)
Porta in Avanza le stesse regole di sicurezza che usiamo su Volty:
- **Due ambienti**: un ramo `staging` per provare (con un progetto Firebase di test separato, `avanza-test`) e il ramo `main` per la produzione.
  Le prove non toccano più i dati veri.
- **Gli agenti non scrivono più in produzione**: lavorano su rami di sviluppo con pull request verso `staging`. In `main` si arriva solo con la promozione controllata e, per i nuovi sviluppi, con la tua approvazione.
- **Squadra con regole scritte** (`CLAUDE.md`, agenti, comandi in `.claude/`): analisi, sviluppo, test, validazione, guardiano della produzione con GO o NO-GO, backup verificato prima di ogni modifica ai dati.
- **Documenti di progetto** aggiornati: stato rapido, requisiti, architettura, ambienti, registro delle decisioni.

### Come provarlo
1. Leggi `docs/progetto/registro-decisioni.md`: la tabella "Decisioni in sospeso" elenca le 11 cose che solo tu puoi fare (progetto di test, bucket dei backup, protezione dei rami, ambienti GitHub, avvisi).
2. Il ramo `staging` esiste già su GitHub (creato da `main`).
3. Dopo che avrai creato il progetto `avanza-test` e i segreti, una modifica a `staging` pubblicherà sul sito di test e potrai provarla senza rischi.

### Esiti dei test
- Solo documentazione e regole di lavoro: nessun codice dell'app è cambiato in questo passo.
- I workflow e gli script di controllo (CI, backup, ripristino, guardia automatica) sono preparati da un altro passo del lavoro e vanno ancora provati: finora non c'è stata alcuna prova sul progetto di test, che non esiste.

### Rischi
- Finché non configuri GitHub e Google, le protezioni sono scritte ma non tutte attive: per esempio nulla impedisce ancora tecnicamente una scrittura diretta su `main`.
- Senza il progetto di test le anteprime non pubblicano nulla e le prove restano la CI.
- Le nuove regole fermano la squadra dal fare da sola cose che prima faceva (merge in produzione): i tempi di rilascio dei nuovi sviluppi dipendono dalla tua approvazione.

### Come si torna indietro
- Sono file di documentazione e regole di lavoro: basta ripristinare i file precedenti con Git. Nessun dato e nessuna impostazione del sito vengono toccati da questa parte.
