# Architettura — Avanza

Sintesi dell'architettura attuale. Per l'integrazione con GitHub vedi `docs/architettura-integrazione-github.md`.

## Componenti
- **App Flutter web** (`lib/`): `go_router` con ripristino della sessione e guardie di ruolo (`lib/app.dart`); stato di autenticazione e ruolo in `lib/providers/auth_provider.dart`;
  accesso ai dati solo da `lib/services/firestore_service.dart`; modelli in `lib/models/`; pagine in `lib/pages/` e `lib/pages/admin/`; widget condivisi in `lib/widgets/`;
  colori, fasi e colonne in `lib/core/constants.dart`, tema in `lib/core/theme.dart`.
- **Cloud Functions** (`functions/`, TypeScript, Node.js 22, gen2, `us-central1`): `githubWebhook` riceve gli eventi di GitHub, verifica la firma HMAC (segreto in Secret Manager),
  trova progetto e task e li aggiorna con le regole "solo avanzare" e note idempotenti (`functions/src/lib/`).
- **Firestore** (`firestore.rules`, `firestore.indexes.json`): database `(default)` in `eur3`. Le regole sono l'unica difesa vera. Schema in `docs/database.md`.
- **Hosting Firebase**: Flutter web (`build/web`), senza service worker, `no-cache` per js/css/html/json (`firebase.json`).
- **Script di amministrazione** (`scripts/`): `registra-ore.mjs` (azioni `membro`, `ore`, `migra`, `admin`, `crea-progetto`, `elimina-prova`) ed `e2e-webhook.mjs`, usati dai workflow con il service account della CI.
- **CI/CD** (`.github/workflows/`): pubblicazione di app e funzione, "Setup Firestore" (regole e indici), "Registra ore squadra", "E2E Webhook", "Verifica sito".
  I workflow del flusso controllato (controlli, promozione, rilascio, backup, avvisi) sono in preparazione: nomi definitivi in `.github/workflows/`.

## Flusso dei dati principale
Un push o una pull request su GitHub → webhook → `githubWebhook` → legge `projects` (per indirizzo GitHub) e `tasks` (per codice `T-N`) → aggiorna il task (stato, fasi, note) → l'app lo mostra.
Le ore registrate vanno in `timeEntries` e incrementano `taskCosts.actualHours`; i report della pagina Costi leggono `taskCosts`, `timeEntries` e `teamMembers` (solo admin).

## Collegamento automatico ai repository GitHub (T-20, fase 1)
Requisiti e decisioni di Andrea: `requisiti-collegamento.md`. La stessa funzione `githubWebhook` riceve ora gli eventi da DUE canali: i webhook dei singoli repository (segreto storico `GITHUB_WEBHOOK_SECRET`) e una **GitHub App personale** installata su tutti i repository (segreto `GITHUB_APP_WEBHOOK_SECRET`, facoltativo finche' non esiste). Entrambi i segreti stanno in Secret Manager.
- **Autenticazione** (`lib/authenticate.ts`, `lib/secrets.ts`, `lib/hmac.ts`): firma HMAC-SHA256 con confronto a tempo costante; si prova prima il segreto storico (percorso di oggi invariato), poi quello dell'App solo se esiste; un segreto assente o vuoto non viene mai accettato; senza firma si risponde 401 senza leggere Secret Manager. Nessun segreto nei log.
- **Elaborazione** (`lib/eventProcessor.ts`): ogni evento autenticato lascia un log strutturato (`lib/eventLog.ts`: esito `aggiornato | creato | non_agganciato | scartato | escluso | ignorato` + motivo, senza dati personali). Il progetto del repository si trova per identificativo numerico (`githubRepoId`) e poi per indirizzo (`lib/projectResolver.ts`); se esiste si aggancia (solo aggiunte, `lib/projectLink.ts`) e il task si aggiorna come sempre (`routeEvent`, `buildUpdate`, `writeUpdate`: solo avanzare, note idempotenti).
- **Progetto nuovo** (`lib/projectCreator.ts`): solo per eventi di "lavoro vero" (ramo non cancellato, pull request, recensione), interruttore acceso in `githubCollegamento/config`, proprietario ammesso, repository non fork / non archiviato / senza il topic `avanza-ignora`, tetto giornaliero non raggiunto. Una transazione con ID deterministico `gh_<id>` (idempotente, nessun duplicato), intestato all'admin configurato; stessi campi di `crea-progetto` grazie al modulo condiviso `lib/projectFactory.ts` (usato anche da `scripts/registra-ore.mjs`). Un progetto eliminato dall'app non risorge (registro `githubRepos`). **I task non si creano mai da soli.**
- **Approvazioni**: una recensione "approved" promuove a Validato solo se `review.author_association` e' OWNER, MEMBER o COLLABORATOR; le altre lasciano solo una nota.
- **Configurazione**: `githubCollegamento/config`, scritta dallo script (azione `collegamento`), letta dalla funzione con copia in memoria di 60 s; nessun valore (uid, account) nel codice. Schema in `docs/database.md`.
- **Segreto dell'App**: segreto GitHub `GH_APP_WEBHOOK_SECRET` (+ `_TEST`) -> workflow `imposta-segreto-app.yml` -> Secret Manager; passi in `configurazioni-da-fare.md` sezione 9.

## Sicurezza
- Login con Firebase Auth; ruolo in `users/{uid}.role` (`admin` solo da script/console).
- Il cliente accede a un progetto solo dopo averlo collegato col codice progetto (`users/{uid}/clientProjects`, verificato dalle regole).
- Nessuna chiave di servizio nell'app o nel repository; segreti nei segreti della CI e in Secret Manager.

## Ambienti
Un repository, due rami: `staging` (test, progetto Firebase `avanza-test` da creare) e `main` (produzione, `avanza-b62d7`). Dettagli in `ambienti.md`.

## Decisioni architetturali
Registrate in `registro-decisioni.md` (data, decisione, alternative, motivo).
