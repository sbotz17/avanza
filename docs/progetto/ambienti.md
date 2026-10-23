# Ambienti — Avanza

## Piattaforma
- **Frontend**: Flutter web (unica piattaforma: nessuna app mobile, nessuno store, nessun installer)
- **Backend**: Firebase (Firestore, Auth con email e password, Cloud Functions gen2 su Node.js 22, Secret Manager, Hosting)
- **Repository**: `sbotz17/avanza` — UN repository, DUE rami

## Modello a due ambienti (un repository, due rami)
| | Test (sviluppo) | Produzione |
|---|---|---|
| Ramo | `staging` | `main` |
| Progetto Firebase | `avanza-test` — **DA CREARE da Andrea** | `avanza-b62d7` |
| Sito | da definire (Hosting del progetto di test) | https://avanza-b62d7.web.app |
| Database | Firestore `(default)` del progetto di test (da creare) | Firestore `(default)` in `eur3` |
| Chi pubblica | la CI, a ogni modifica di `staging` (finché il progetto di test non esiste non pubblica nulla) | la CI, solo con la promozione controllata da `staging` a `main` |
| Dati | solo dati di prova, mai dati reali | dati reali |

**Regole di lavoro**
1. Si lavora su rami `fix/`, `hotfix/`, `feature/` (e sul ramo `claude/...` assegnato dalla sessione) e si apre una pull request verso `staging`.
2. Gli agenti non aprono pull request e non scrivono su `main`. In `main` si arriva solo con la promozione controllata della CI.
3. Le correzioni di malfunzionamenti vanno in produzione da sole con tutti i controlli; i nuovi sviluppi aspettano la validazione di Andrea e la sua approvazione sull'ambiente GitHub `produzione-sviluppi`.
4. Prima di ogni modifica ai dati di produzione: backup verificato (vedi `CLAUDE.md`, "Regola d'oro dei dati").
5. Le anteprime e i test non devono mai usare il progetto di produzione.

> Oggi (2026-10-23) l'ambiente di test non esiste ancora. Fino alla sua creazione le anteprime dei rami di sviluppo non pubblicano nulla e i test sono la CI (`flutter analyze`, build, `flutter test`).

## Firestore (produzione)
- Progetto `avanza-b62d7`, database `(default)` in `eur3` (regione definitiva), creato il 2026-10-23 con il workflow "Setup Firestore".
- Esiste anche un database vuoto `avanza`, non usato dal codice (da eliminare quando Andrea vuole).
- Collezioni: vedi `docs/database.md` e `database.md`. Regole in `firestore.rules`, indici in `firestore.indexes.json`.
- Backup: export su bucket Google Cloud Storage con blocco di conservazione — **da configurare** (Firestore non ha backup automatici attivi per impostazione predefinita).

## Cloud Functions
- `githubWebhook`, gen2, Node.js 22, regione `us-central1`, pubblicata con `gcloud functions deploy` dalla CI.
- URL: https://us-central1-avanza-b62d7.cloudfunctions.net/githubWebhook (pubblica; la firma HMAC dei messaggi la protegge).
- Webhook GitHub configurati sui repository `sbotz17/avanza` e `sbotz17/volty-flutter`.

## Hosting Firebase
- Cartella pubblicata: `build/web`; build con `flutter build web --release --base-href / --pwa-strategy=none`.
- `firebase.json`: `Cache-Control: no-cache` per js, css, html, json (da verificare con "Verifica sito").

## Segreti e variabili
| Nome | Dove | Usato per | Stato |
|---|---|---|---|
| `FIREBASE_SERVICE_ACCOUNT` | segreto GitHub | pubblicazione e script sul progetto di produzione | presente |
| `FIREBASE_SERVICE_ACCOUNT_TEST` | segreto GitHub | pubblicazione e prove sul progetto di test | da creare |
| `GITHUB_TOKEN` | automatico di GitHub | anteprime Hosting, test E2E (crea e cancella un branch) | automatico |
| `GITHUB_WEBHOOK_SECRET` | Firebase Secret Manager (`avanza-b62d7`) | verifica della firma dei webhook | presente |
| `TEST_USER_EMAIL`, `TEST_USER_PASSWORD` | segreti GitHub | usati dal vecchio test E2E: non servono più | da eliminare |
| `GCS_BUCKET`, `GCS_CHIAVE_JSON` | segreti GitHub | backup su bucket con blocco di conservazione (nomi dai modelli CI) | da creare |
| `AVVISI_URL`, `AVVISI_TOKEN`, `AVVISI_NUMERO` | segreti GitHub (ambiente `avvisi`) | avvisi WhatsApp ad Andrea (nomi dai modelli CI) | da creare |
| `BLOCCO_SQUADRA` | variabile GitHub | interruttore di Andrea per fermare promozioni, rilasci e controlli | da creare |

I nomi definitivi di segreti, variabili e ambienti dipendono dai workflow in `.github/workflows/`: si confermano quando sono pronti.

## Ruoli IAM del service account di produzione
Service account `firebase-adminsdk-fbsvc@avanza-b62d7.iam.gserviceaccount.com` (già assegnati): Cloud Functions Developer, Cloud Run Admin, Service Account User, Artifact Registry Writer,
Secret Manager (lettura e accesso al segreto del webhook), Cloud Datastore Owner, Firebase Rules Admin. API abilitate: Cloud Functions, Cloud Build, Artifact Registry, Cloud Run, Eventarc, Pub/Sub,
Storage, Secret Manager, Cloud Billing, Firestore. Lo stesso insieme servirà sul progetto di test.

## Cosa deve configurare Andrea (una volta sola)
| Dove | Cosa | A cosa serve |
|---|---|---|
| Google / Firebase | Creare il progetto `avanza-test` (piano Blaze), attivare Auth con email e password, creare Firestore `(default)`, assegnare al service account gli stessi ruoli della produzione | Ambiente di test separato |
| GitHub | Creare il segreto `FIREBASE_SERVICE_ACCOUNT_TEST` con la chiave del service account di test | Pubblicare e provare sul test |
| Google Cloud | Creare il bucket dei backup con blocco di conservazione e il relativo segreto GitHub | Backup che nessuno può cancellare |
| GitHub | Proteggere i rami `main` (nessuna scrittura diretta, pull request e controlli obbligatori) e `staging` (pull request e controlli obbligatori) | Gli agenti non possono toccare produzione |
| GitHub | `CODEOWNERS` con Andrea come proprietario di `.github/`, `.claude/`, `CLAUDE.md`, `firestore.rules`, `firebase.json` e opzione "Require review from Code Owners" | Le regole della squadra e della sicurezza le cambia solo Andrea |
| GitHub | Ambienti `produzione-sviluppi` (revisore: Andrea), `produzione-correzioni`, `avvisi`, `produzione` | Approvazione dei nuovi sviluppi |
| GitHub | Segreti degli avvisi WhatsApp e variabile `BLOCCO_SQUADRA` | Avvisi e interruttore di sicurezza |

Dettaglio e stato di ogni punto: `registro-decisioni.md` (decisioni in sospeso).

## Note
- Nessun ambiente Supabase né Vercel: il progetto usa esclusivamente Firebase e GitHub.
- Il progetto Firebase di test non esiste ancora: tutto ciò che lo riguarda è "da creare" o "da definire".


## Ambiente di test creato (2026-10-23)
- Progetto Firebase di test: `avanza-test-c33ef` (Blaze, Auth email/password, Firestore `(default)` in eur3), creato da Andrea.
- Segreto GitHub `FIREBASE_SERVICE_ACCOUNT_TEST` e variabile `PROGETTO_FIREBASE_TEST=avanza-test-c33ef` impostati da Andrea.
- L'app usa la configurazione di test con `--dart-define=APP_ENV=test` (`lib/firebase_options_test.dart`, scelta in `lib/main.dart`); senza il define usa la produzione. `.firebaserc` alias `test` allineato.
- Ancora da verificare: primo deploy di test dal ramo `staging` e regole Firestore sul progetto di test.
