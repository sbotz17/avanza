# Avanza — stato rapido
> Aggiornato: 2026-10-23 · da: coordinatore

<!-- ISTRUZIONI PER IL COORDINATORE
     Mantieni questo file ≤ 60 righe. Aggiornalo dopo ogni task completato.
     È il PRIMO file che ogni agente legge: deve essere sempre preciso e conciso.
-->

## Progetto in sintesi
- Scopo: monitorare lo stato di avanzamento lavori dei progetti (task a fasi, kanban, costi e produttività della squadra)
- Stack: Flutter web · Firebase (Firestore, Auth, Cloud Functions gen2, Hosting) · GitHub
- Piattaforme: solo web (https://avanza-b62d7.web.app)
- Ruoli: `admin` vede tutto; `client` solo i progetti collegati col codice progetto e il dettaglio dei task

## Ambienti
- Test → ramo `staging`, progetto Firebase `avanza-test` (DA CREARE da Andrea: finché non c'è, anteprime e test non pubblicano nulla)
- Prod → ramo `main`, progetto Firebase `avanza-b62d7`, database `(default)` in `eur3` (solo CI)
- Branch di lavoro: da `origin/staging` → PR verso `staging`. Mai PR né push verso `main` da parte degli agenti.

## Stato attuale
- In produzione: webhook GitHub → task, ruoli admin/cliente, costi e produttività, progetti reali Avanza e Volty
- In lavorazione: allineamento alla squadra (regole, agenti, CI, ambienti)
- Da validare con Andrea: allineamento ambienti e regole di protezione (vedi `da-validare.md`)
- Bug aperti: — (dettaglio in `ritorni.md`)
- Decisioni in sospeso: 11 azioni di Andrea su Google e GitHub (dettaglio in `registro-decisioni.md`)

## Ultimi cambiamenti rilevanti
<!-- formato: AAAA-MM-GG · cosa · chi -->
- 2026-10-23 · kit squadra portato da Volty e adattato a Firebase; creato `staging` · coordinatore
- 2026-10-23 · progetti reali Avanza e Volty; test E2E sul progetto reale; sito senza service worker · coordinatore
- 2026-10-23 · accesso unico con ruoli, sessione persistente, regole senza accesso anonimo · coordinatore
- 2026-10-23 · costi, squadra e produttività (`taskCosts` solo admin) · coordinatore

## Mappa rapida — cosa leggere per ogni task

| Task | File da leggere |
|---|---|
| Nuova funzione | `requisiti.md` · `architettura.md` · `catalogo.md` |
| Bug / ritorno | `ritorni.md` · `requisiti.md` (sezione pertinente) |
| Dati, regole, indici | `database.md` · `docs/database.md` · `ambienti.md` |
| UI nuova o modificata | `catalogo.md` · `architettura.md` (e le pagine in `lib/pages/`) |
| Rilascio | `produzione.md` · `ambienti.md` |
| Stato progetto | solo questo file + `registro-decisioni.md` + `da-validare.md` |
| Costi e ruoli | `requisiti-costi.md` |
| Integrazione GitHub | `docs/requisiti-integrazione-github.md` · `docs/architettura-integrazione-github.md` |
| Log attività | `log-attivita.md` |

## Note veloci
- Dati: regole in `firestore.rules`, indici in `firestore.indexes.json`, pubblicazione col workflow "Setup Firestore"; modifiche solo additive
- Ogni nuova route: aggiungerla in `lib/app.dart` e, se solo admin, in `_isAdminOnly`; poi controllare le regole di Firestore
- Il sito resta senza service worker (`--pwa-strategy=none`) e con `no-cache` per js/css/html/json
- Il codice Dart può non compilare in locale: la CI (`flutter analyze`, build) è il controllo vero
