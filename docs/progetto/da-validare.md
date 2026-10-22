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
