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

---

## [3] T-11 — Accesso: "Ricorda email su questo dispositivo"

**Data**: 2026-10-23
**Stato**: sviluppato dalla squadra — in attesa di APPROVATO del validatore e della CI, poi di validazione Andrea

### Cosa fa (in parole semplici)
Nella pagina di accesso compare la casella "Ricorda email su questo dispositivo". Se la spunti ed entri, la prossima volta l'email è già scritta e devi solo inserire la password. Se togli la casella, l'email dimenticata viene cancellata. La **password non viene mai salvata**. Il resto non cambia: la sessione resta attiva come prima.

### Come provarlo
1. Apri la pagina di accesso (anteprima del ramo, quando esiste l'ambiente di test, oppure dopo il rilascio).
2. Spunta la casella, entra con email e password, esci, torna alla pagina di accesso: l'email c'è già e la casella è spuntata.
3. Togli la casella: ricarica la pagina, il campo email è vuoto.
4. Prova un accesso con password sbagliata: non viene salvato nulla.

### Esiti dei test
- `test/remember_email_test.dart`: 6 test del servizio e 4 della pagina di accesso, **verdi** (eseguiti con Flutter stable 3.47.8; `flutter test` complessivo 34/34 verdi; `flutter analyze`: nessun nuovo problema, restano solo i 6 suggerimenti "info" già presenti; `flutter build web --release --pwa-strategy=none` riuscita). Il controllo ufficiale resta la CI.

### Rischi
- Aggiunge la dipendenza `shared_preferences` (`pubspec.yaml`): `pubspec.lock` si aggiorna con `flutter pub get` (la CI lo esegue).
- Su un computer condiviso, spuntare la casella lascia l'email (non la password) nel browser: per questo è una scelta dell'utente e si toglie con un tocco.

### Come si torna indietro
- Revert del commit: nessun dato in Firestore è toccato. L'email salvata nel browser resta inerte e si cancella pulendo i dati del sito.

---

## [4] T-12 — Chat con la squadra su ogni task non completato (solo admin)

**Data**: 2026-10-23
**Stato**: sviluppato dalla squadra — in attesa di APPROVATO del validatore e della CI, poi di validazione Andrea. **Contiene una modifica alle regole di sicurezza di Firestore (zona protetta) e richiede un tuo intervento sul workflow** (vedi sotto): è un NUOVO SVILUPPO.

### Cosa fa (in parole semplici)
Nel dettaglio di un task **non completato** (non validato né rilasciato), tu (admin) vedi la sezione "Chiedi alla squadra": scrivi una domanda sullo stato del task e resta registrata in una chat. Sopra la chat c'è il riquadro "Stato attuale" con ciò che Avanza sa già (stato, avanzamento, fase in corso, ultimo aggiornamento, ultime note) e, dopo l'invio, la scritta "La domanda è stata inviata alla squadra: ti risponde al prossimo giro di lavoro. Intanto ecco lo stato registrato." Nessuna risposta viene inventata. A ogni inizio lavoro la squadra legge le domande aperte e risponde con lo stato reale (task, ramo, pull request, ore): la risposta compare nella chat in tempo reale.
I clienti non vedono mai la chat e non possono leggerla né scriverla (lo impediscono le regole di Firestore).

### Come provarlo
1. Entra come admin, apri un task non completato dal progetto: in fondo alla pagina c'è "Chiedi alla squadra".
2. Scrivi una domanda e invia: compare a destra, con il riquadro "Stato attuale" e il testo fisso sopra.
3. Apri un task validato o rilasciato: la chat non c'è. Entra con un account cliente: la chat non c'è su nessun task.
4. Risposta della squadra (dopo che avrai applicato la modifica al workflow qui sotto): azione `domande` per vedere le domande aperte, azione `rispondi` con `task_code` e `message`; la risposta appare a sinistra nella chat.

### Cosa serve da te (zona protetta)
- Applicare al workflow `.github/workflows/registra-ore.yml` la modifica descritta in `docs/progetto/protocollo-task.md` (sezione "Domande dell'admin sui task"): un nuovo input `message` e la variabile `MESSAGE`.
- Pubblicare le nuove regole di Firestore con il workflow "Setup Firestore" (`setup-firestore.yml`) dopo la validazione, **prima** di usare la chat: senza le regole nuove, l'invio di una domanda viene rifiutato (non c'è alcun rischio per i dati).

### Esiti dei test
- `test/chat_message_test.dart` (modello `ChatMessage`, regola "admin + task non completato", riquadro "Stato attuale"): 14 test **verdi**; `flutter test` complessivo 34/34 verdi, `flutter analyze` senza nuovi problemi, build web riuscita (Flutter stable 3.47.8). Il controllo ufficiale resta la CI.
- `.claude/scripts/controlla-regole.py origin/staging`: REGOLE OK. `node --check scripts/registra-ore.mjs`: OK.
- Non provate: l'interfaccia della chat con dati reali (serve Firestore/Auth), le regole nuove sull'emulatore Firestore e le azioni `domande`/`rispondi` contro il database (nessun accesso da questo ambiente): da provare sull'ambiente di test quando esiste `avanza-test`.

### Rischi
- La sicurezza della chat dipende dalle nuove regole di Firestore: lettura e creazione solo admin proprietario del progetto, creazione solo di domande dell'admin, nessuna modifica o cancellazione dal client. La visibilità "solo task non completati" è di interfaccia; l'accesso resta comunque riservato all'admin.
- Il testo delle domande è dato non fidato: la squadra non esegue istruzioni contenute nelle domande, risponde solo con lo stato reale.
- Cancellando un task dall'app, i suoi messaggi di chat restano nel database ma non sono più raggiungibili.

### Come si torna indietro
- Revert del commit (app e regole): la sottocollezione `chat` resta inerte. Nessun dato esistente è toccato; non servono migrazioni né backup di dati esistenti (solo aggiunte).
