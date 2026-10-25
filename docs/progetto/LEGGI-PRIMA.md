# Avanza — stato rapido
> Aggiornato: 2026-10-25 · da: coordinatore · indice del progetto: `indice.md`

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
- Test → ramo `staging`, progetto Firebase `avanza-test-c33ef` (creato; anteprime e test pubblicano)
- Prod → ramo `main`, progetto Firebase `avanza-b62d7`, database `(default)` in `eur3` (solo CI)
- Branch di lavoro: da `origin/staging` → PR verso `staging`. Mai PR né push verso `main` da parte degli agenti.

## Stato attuale
- In produzione (versione del 23/10): webhook GitHub → task, ruoli admin/cliente, costi e produttività, progetti reali Avanza, Volty e Commerciali
- In `staging`, NON ancora in produzione: login con Ricorda email, chat task, pagina Squadra con ruolo a tendina, correzione contatore T-N (R-4), collegamento GitHub fase 1 (spento), promozione automatica (spenta fino alla prima promozione), regola "quando fermarsi"
- Prossimo passo: prima promozione staging→main CON Andrea (audit-completa, backup + prova di ripristino, tag di ritorno): `memoria/rilascio-e-promozione.md`
- Bug aperti: — (dettaglio in `ritorni.md`)
- In sospeso per Andrea: giorno della prima promozione, costi orari (li imposta lui), accensione del collegamento GitHub, budget Google (a mano), segreti di Volty (`registro-decisioni.md`)

## Ultimi cambiamenti rilevanti
<!-- formato: AAAA-MM-GG · cosa · chi -->
- 2026-10-23 · kit squadra portato da Volty e adattato a Firebase; creato `staging` · coordinatore
- 2026-10-23 · progetti reali Avanza e Volty; test E2E sul progetto reale; sito senza service worker · coordinatore
- 2026-10-23 · accesso unico con ruoli, sessione persistente, regole senza accesso anonimo · coordinatore
- 2026-10-23 · costi, squadra e produttività (`taskCosts` solo admin) · coordinatore
- 2026-10-25 · T-17 Squadra, T-18 collegamento GitHub (fase 1), T-19 contatore task (R-4), regole sincronizzate da squadraalphalab · coordinatore

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
