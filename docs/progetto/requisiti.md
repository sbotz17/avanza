# Requisiti — Avanza

Sintesi dei requisiti già realizzati e in vigore. I dettagli stanno nei documenti collegati.

## Cosa è Avanza
App web per monitorare lo stato di avanzamento dei lavori: progetti, task con fasi (Analisi, Database, Backend, Design, Frontend, Test, Validazione),
vista a lista e kanban (Da fare, In corso, Bloccato, In test / QA, Validato, Rilasciato), codice breve per ogni task (es. `T-3`).

## Requisiti in vigore
1. **Progetti e task**: l'admin crea e modifica progetti e task; ogni task ha un codice progressivo `T-N` unico nel progetto.
2. **Integrazione con GitHub**: gli eventi del repository (branch, commit, pull request, review) aggiornano da soli i task il cui codice compare nel nome del branch o nel titolo della PR.
   Dettagli in `docs/requisiti-integrazione-github.md` e `docs/architettura-integrazione-github.md`. Il webhook è la Cloud Function `githubWebhook`.
3. **Ruoli e accessi**: un solo login (email e password).
   - `admin`: vede e modifica tutto (progetti, task, costi, squadra).
   - `client` (cliente): si registra, collega il codice progetto al proprio account al primo accesso e vede solo i propri progetti e, per ognuno, stato e dettaglio dei task.
   - Nessun accesso anonimo. Costi, tariffe, ore, squadra e produttività sono solo admin, garantito dalle regole di sicurezza di Firestore.
4. **Costi e produttività**: squadra di agenti e persone con tariffe, registro ore per task e fase, preventivo, costo reale, da fatturare, margine e produttività per membro.
   Dettagli in `docs/progetto/requisiti-costi.md`.
5. **Sessione**: la sessione sopravvive a refresh, chiusura del browser e standby; riaprendo il sito si torna alla pagina in cui si era.
6. **Aggiornamenti visibili**: il sito non deve mai mostrare una versione vecchia dopo un rilascio (niente service worker, `no-cache` per js/css/html/json).
7. **Piattaforme**: solo web. Nessuna app mobile né store.
8. **Ambienti**: un repository, due rami. `staging` = test (progetto Firebase `avanza-test`, da creare), `main` = produzione (`avanza-b62d7`). Vedi `ambienti.md`.
9. **Protezione di produzione e dei dati**: regole della squadra in `CLAUDE.md` (backup verificato prima di ogni modifica ai dati, nessuna cancellazione di dati reali, GO/NO-GO del guardiano,
   validazione di Andrea per i nuovi sviluppi).

10. **Accesso: ricorda email (T-11)**: nella pagina di accesso la casella "Ricorda email su questo dispositivo" salva in locale solo l'email (mai la password) dopo un accesso riuscito e la precompila alla visita successiva. Criteri di accettazione:
    - con la casella spuntata e un accesso riuscito, riaprendo la pagina l'email è già scritta e la casella è spuntata;
    - togliendo la casella, il valore salvato si cancella e la visita successiva trova il campo vuoto;
    - un accesso non riuscito non salva nulla; la password non viene mai salvata dall'app;
    - la sessione resta persistente come prima; se lo spazio locale non è disponibile l'accesso funziona comunque.
11. **Chat con la squadra sui task non completati (T-12, solo admin)**: nel dettaglio di un task non `validated`/`released` l'admin può scrivere alla squadra una domanda sullo stato. Criteri di accettazione:
    - la chat si vede solo all'admin e solo se il task non è completato; i clienti non la vedono né possono leggerla o scriverla (regole Firestore: `projects/{p}/tasks/{t}/chat`);
    - l'admin invia domande (1-2000 caratteri); i messaggi si aggiornano in tempo reale, con bolle diverse per admin e squadra, in tema chiaro e scuro, con stato vuoto;
    - sopra la chat c'è il riquadro "Stato attuale" calcolato dai dati del task (nessun testo inventato) e, dopo l'invio, il testo fisso "La domanda è stata inviata alla squadra: ti risponde al prossimo giro di lavoro. Intanto ecco lo stato registrato.";
    - la squadra risponde con l'azione `rispondi` di `scripts/registra-ore.mjs` (sola Admin SDK) e legge le domande aperte con `domande`; non si può modificare né cancellare un messaggio dal client.

## Non ancora realizzato (idee e limiti noti)
- Modulo Assistente (manuale, bot, segnalazioni di malfunzionamenti): previsto dalle regole della squadra, non ancora richiesto né progettato per Avanza.
- L'admin non può scollegare un cliente da un progetto (lo può fare solo il cliente).
- Codice progetto di 6 caratteri: un utente registrato potrebbe provare a indovinarlo (rischio basso).
- Produttività per fase (oggi solo per task: non ci sono stime per fase).
- Nascondere `githubUrl` e `ownerId` ai clienti (oggi il documento progetto li contiene ed è leggibile ai clienti collegati).
