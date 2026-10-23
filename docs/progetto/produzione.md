# Produzione — Avanza

## Inventario produzione

| Componente | Dettaglio |
|---|---|
| Firebase project | `avanza-b62d7` |
| Hosting URL | https://avanza-b62d7.web.app |
| Cloud Functions | `githubWebhook` — **deployata** (gen2, `us-central1`, Node.js 22, via `gcloud` in CI) |
| Firestore | database `(default)`, regione `eur3`, creato il 2026-10-23 con il workflow "Setup Firestore". Contiene solo il progetto di prova del test E2E: nessun dato reale. Esiste anche un database vuoto `avanza`, non usato |
| Auth | Firebase Auth email/password |

## Stato attuale (2026-10-23)

**Flutter web (Hosting)**: in produzione — versione con badge taskCode (T-N) visibile.
Nota: il badge taskCode è una nuova funzionalità non ancora formalmente validata da Andrea (vedi `da-validare.md`), ma è già in produzione perché la CI deployava da `claude/epic-galileo-e9a406` a `channelId: live`. Le correzioni R-2 (spinner infinito) e R-3 (logout al refresh) sono anch'esse già in produzione.

**Cloud Functions**: deployata il 2026-10-23 (CI run #44, step "Deploy Cloud Functions" riuscito). Il deploy usa `gcloud functions deploy --gen2` e non `firebase-tools`, che avrebbe richiesto il ruolo Cloud Functions Admin. Il segreto `GITHUB_WEBHOOK_SECRET` è letto a runtime da Secret Manager.
Verificato il 2026-10-23: la funzione risponde, i webhook GitHub sono configurati e il test E2E (workflow "E2E Webhook") è verde: un branch con `T-1` nel nome aggiunge la nota al task e lo porta a "active" su Firestore.

## Requisiti IAM per deploy Cloud Functions

Service account: `firebase-adminsdk-...@avanza-b62d7.iam.gserviceaccount.com`

Ruoli necessari (da aggiungere su Google Cloud Console → IAM):
- `Cloud Functions Developer`
- `Cloud Run Admin`
- `Service Account User`
- `Artifact Registry Writer` (per Gen 2)

## Backup

Avanza usa Firebase/Firestore — i backup automatici di Firestore non sono attivati per impostazione predefinita.
**Prima di qualsiasi migrazione dati, attivare export Firestore su Cloud Storage** (da configurare).

## Registro operazioni

| Data | Operazione | Esito | Note |
|---|---|---|---|
| 2026-10-22 | Deploy Flutter web (CI automatica) | OK | Branch `claude/epic-galileo-e9a406` → live. Include badge taskCode, R-2, R-3 |
| 2026-10-22 | Deploy Cloud Functions | FALLITO (IAM mancanti) | La CI ha tentato ma mancano i ruoli IAM sul service account |
| 2026-10-23 | Deploy Cloud Functions (firebase-tools, run #37 e #40) | FALLITO | Prima API Cloud Billing, poi permesso `cloudfunctions.functions.setIamPolicy` |
| 2026-10-23 | Deploy Cloud Functions `githubWebhook` (gcloud, run #44) | OK | Gen2, Node.js 22, `--allow-unauthenticated`; la firma HMAC protegge l'endpoint |
| 2026-10-23 | Creazione database Firestore `(default)`, regole e indici (workflow Setup Firestore, run #2) | OK | Il database non esisteva: prima l'app non poteva salvare dati. Regione `eur3` (definitiva). Ruoli aggiunti al service account: Cloud Datastore Owner, Firebase Rules Admin. Il primo tentativo (run #1) era fallito per permessi mancanti |
| 2026-10-23 | Test E2E webhook -> Firestore (run #5) | OK | Utente di prova dedicato; il test crea progetto e task `T-1` di prova e cancella il branch al termine |
| 2026-10-23 | Funzione costi in produzione (PR #10) | OK | Squadra (agenti e persone), registro ore, report preventivo/costo reale/da fatturare/margine/produttività. Requisiti in `docs/progetto/requisiti-costi.md` |
| 2026-10-23 | Correzione sicurezza accessi (PR #11) | OK | Costi, tariffe e ore spostati in `taskCosts` (solo admin); accesso cliente tramite `clientAccess` (lettura solo per ID); elenco progetti solo al proprietario. Prima i costi erano leggibili da chiunque e tutti i progetti erano elencabili |
| 2026-10-23 | Pubblicazione regole Firestore (Setup Firestore run #4) | OK | Regole strette per clienti: solo stato e dettaglio dei task |
| 2026-10-23 | Migrazione costi e accessi cliente (Registra ore squadra, azione `migra`, run #13) | OK | 1 task ripulito dai costi e 1 accesso cliente creato: solo dati di prova. I valori sono copiati e verificati prima di essere tolti dal task |
| 2026-10-23 | Creazione 12 membri agenti della squadra | OK | Tariffe a zero: le inserisce Andrea dalla pagina Squadra |
| 2026-10-23 | Test E2E webhook dopo le regole strette (run #6) | OK | Il test crea anche l'accesso cliente; webhook e Firestore funzionano con le nuove regole |
| 2026-10-23 | Accesso unico con ruoli admin/cliente (PR #13) | OK | Un solo login; ruolo in `users/{uid}`; il cliente si registra e collega il codice progetto al proprio account (`users/{uid}/clientProjects`). Sessione persistente: il router ripristina la sessione e riporta alla pagina richiesta (prima si finiva sempre su `/login` aprendo dalla radice o dall'icona). Vecchio accesso anonimo con codice rimosso |
| 2026-10-23 | Regole Firestore senza accesso anonimo (Setup Firestore run #5) | OK | Progetti e task solo a proprietario e clienti collegati; `clientAccess` leggibile solo da utenti autenticati, per ID |
| 2026-10-23 | Ruolo admin assegnato ad Andrea (azione `admin`, run #14 dal branch) e ai proprietari dei progetti (`migra`, run #15) | OK | Il ruolo admin si assegna solo da script/console: i client non possono auto-promuoversi |
| 2026-10-23 | Logo di Avanza nella pagina di accesso, favicon.ico e icone web (PR #13) | OK | Prima: razzo generico e `/favicon.ico` mancante (il sito rispondeva con HTML) |
| 2026-10-23 | Test E2E webhook con i ruoli (run #7) | OK | L'utente di prova viene reso admin dal workflow prima del test |
| 2026-10-23 | Eliminato il progetto di prova del test (Registra ore squadra, azione `elimina-prova`, run #16) | OK | Cancellato solo il progetto con il nome esatto del test e i suoi dati (`recursiveDelete`), su richiesta di Andrea. Erano solo dati di prova |
| 2026-10-23 | Progetti reali collegati ai repository | OK | **Avanza** (`https://github.com/sbotz17/avanza`, creato da Andrea nell'app) e **Volty** (`https://github.com/sbotz17/volty-flutter`, creato con l'azione `crea-progetto`, run #18), entrambi intestati all'account admin di Andrea; webhook GitHub già configurati |
| 2026-10-23 | Test E2E riscritto | OK | Non usa più un utente e un progetto di prova (si sarebbero sovrapposti al progetto reale con lo stesso indirizzo GitHub): crea un task temporaneo `T-9xxx` nel progetto reale, verifica la nota sul task e cancella task e branch |
| 2026-10-23 | Versione web senza service worker (`--pwa-strategy=none`) e cache `no-cache` per js/css/html/json | OK | Un utente vedeva ancora la vecchia versione: il browser conservava una copia (cache di un anno sui file JavaScript con nome fisso e service worker). In incognito vedeva la versione nuova, quindi il server era corretto |

## Piano di rollback

**Flutter web**: Firebase Hosting mantiene versioni precedenti → `firebase hosting:rollback --project avanza-b62d7` (da fare con il CLI di Andrea).

**Cloud Functions**: versioni precedenti visibili su Google Cloud Console → Cloud Functions → seleziona funzione → "Revisioni".

**Dati Firestore**: nessuna migrazione eseguita finora. Le scritture della Cloud Function sono solo additive (aggiunge note e aggiorna campi nullable).
