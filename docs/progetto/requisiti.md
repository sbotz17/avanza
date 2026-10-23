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

## Non ancora realizzato (idee e limiti noti)
- Modulo Assistente (manuale, bot, segnalazioni di malfunzionamenti): previsto dalle regole della squadra, non ancora richiesto né progettato per Avanza.
- L'admin non può scollegare un cliente da un progetto (lo può fare solo il cliente).
- Codice progetto di 6 caratteri: un utente registrato potrebbe provare a indovinarlo (rischio basso).
- Produttività per fase (oggi solo per task: non ci sono stime per fase).
- Nascondere `githubUrl` e `ownerId` ai clienti (oggi il documento progetto li contiene ed è leggibile ai clienti collegati).
