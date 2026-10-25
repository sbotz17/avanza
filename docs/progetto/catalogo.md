# Catalogo oggetti — Avanza

Ogni oggetto del progetto è registrato qui: nome, categoria, percorso, scopo e dove è usato.
Aggiornare a ogni nuovo oggetto o modifica significativa.

---

## Flutter — Modelli (`lib/models/`)

| Nome | Percorso | Scopo | Usato in |
|------|----------|-------|----------|
| `Task` | `lib/models/task.dart` | Modello dati del task (con campi `taskCode`, `taskNumber`, `githubBranch?`, `githubPrNumber?`) | Ovunque nel frontend |
| `Project` | `lib/models/project.dart` | Modello dati del progetto (con `nextTaskNumber`) | Home, project page, firestore_service |
| `ChatMessage`, `canShowTaskChat` | `lib/models/chat_message.dart` | [T-12] Messaggio della chat admin-squadra (`fromMap`/`toMap`, `cleanText`) e regola "chi vede la chat" (admin e task non `validated`/`released`) | `firestore_service.dart`, `task_chat.dart`, `task_detail_page.dart`, `test/chat_message_test.dart` |

---

## Flutter — Widget (`lib/widgets/`)

| Nome | Percorso | Scopo | Usato in |
|------|----------|-------|----------|
| `TaskCodeBadge` | `lib/widgets/task_code_badge.dart` | Badge compatto che mostra il codice univoco di un task (es. "T-3"); si nasconde se vuoto | `task_card.dart`, `kanban_board.dart`, `edit_task_page.dart`, `task_detail_page.dart` |
| `KanbanBoard` | `lib/widgets/kanban_board.dart` | Board kanban con colonne per status | `project_page.dart` |
| `TaskCard` | `lib/widgets/task_card.dart` | Card compatta per un task nella lista/kanban | `kanban_board.dart` |
| `PhaseRow` | `lib/widgets/phase_row.dart` | Riga singola fase di un task | `task_detail_page.dart`, `edit_task_page.dart` |
| `ProgressBar` | `lib/widgets/progress_bar.dart` | Barra di avanzamento percentuale | `task_card.dart`, `task_detail_page.dart` |
| `StatusPill` | `lib/widgets/status_pill.dart` | Pillola colorata per lo status del task | `task_card.dart`, `task_detail_page.dart` |
| `EmptyState` | `lib/widgets/empty_state.dart` | Schermata vuota con messaggio e icona | `project_page.dart`, `home_page.dart`, `task_chat.dart` |
| `TaskChat`, `taskStatusSummary` | `lib/widgets/task_chat.dart` | [T-12] Chat in tempo reale dell'admin con la squadra su un task non completato; riquadro "Stato attuale" calcolato dai dati del task | `task_detail_page.dart` (solo admin) |
| `TeamMemberTile`, `memberRoleLabel`, `memberCostNotSet` | `lib/widgets/team_member_tile.dart` | [T-19] Riga di un membro della squadra: tipo e ruolo ben visibili, costo e vendita orari sulla stessa riga, "Costo non impostato" quando il costo è 0; helper per il testo del ruolo e per il costo a 0 | `team_page.dart`, `test/team_page_test.dart` |

---

## Flutter — Pagine (`lib/pages/`)

| Nome | Percorso | Scopo | Usato in |
|------|----------|-------|----------|
| `HomePage` | `lib/pages/home_page.dart` | Lista dei progetti | `app.dart` |
| `ProjectPage` | `lib/pages/project_page.dart` | Dettaglio progetto con kanban | `app.dart` |
| `TaskDetailPage` | `lib/pages/task_detail_page.dart` | Dettaglio task (sola lettura cliente) | `app.dart` |
| `EditTaskPage` | `lib/pages/admin/edit_task_page.dart` | Form creazione/modifica task | `project_page.dart` |
| `EditProjectPage` | `lib/pages/admin/edit_project_page.dart` | Form creazione/modifica progetto | `home_page.dart` |
| `CostsPage` | `lib/pages/admin/costs_page.dart` | Riepilogo costi e ore per progetto | `app.dart` |
| `TeamPage`, `TeamMembersView`, `MissingCostNotice`, `MemberDialog` | `lib/pages/admin/team_page.dart` | [T-19] Squadra: lista dei membri (aiuto se vuota, avviso se ci sono costi a 0) e dialogo Nuovo/Modifica membro con menu a tendina Ruolo (ruoli standard + "Altro…" con testo libero) | `app.dart`, `test/team_page_test.dart` |
| `LoginPage` | `lib/pages/login_page.dart` | Login con email/password | `app.dart` |
| `ClientAccessPage` | `lib/pages/client_access_page.dart` | Accesso cliente via token | `app.dart` |

---

## Flutter — Servizi e provider (`lib/services/`, `lib/providers/`)

| Nome | Percorso | Scopo | Usato in |
|------|----------|-------|----------|
| `FirestoreService` | `lib/services/firestore_service.dart` | Accesso CRUD a Firestore (progetti, task, fasi, note; [T-12] `chatStream`, `sendChatQuestion`) | Pagine e provider |
| `AuthServiceBase` | `lib/services/auth_service.dart` | Interfaccia astratta per l'autenticazione; consente l'iniezione di stub nei test senza Firebase | `auth_provider.dart`, `test/auth_provider_test.dart` |
| `AuthService` | `lib/services/auth_service.dart` | Implementazione concreta di `AuthServiceBase` tramite Firebase Auth | `auth_provider.dart` |
| `AuthProvider` | `lib/providers/auth_provider.dart` | Provider ChangeNotifier per lo stato di autenticazione | `app.dart` |
| `RememberEmailService` | `lib/services/remember_email.dart` | [T-11] Salva/legge/cancella l'email ricordata nello spazio locale (`shared_preferences`); mai la password | `login_page.dart`, `test/remember_email_test.dart` |

---

## Flutter — Core (`lib/core/`)

| Nome | Percorso | Scopo | Usato in |
|------|----------|-------|----------|
| `AppTheme` | `lib/core/theme.dart` | Tema Material3 (light/dark, colori, tipografia) | `main.dart` |
| `AppConstants` | `lib/core/constants.dart` | Costanti applicative (statusOrder, colori status, ecc.; [T-12] `kCompletedStatuses`, `kChatMaxLength`) | Widget, pagine |
| `kMemberRoles` | `lib/core/constants.dart` | [T-19] Elenco dei 13 ruoli standard della squadra (valori minuscoli salvati in `teamMembers.role`) per il menu Ruolo | `team_page.dart`, `test/team_page_test.dart` |

---

## Cloud Functions Firebase (`functions/src/`)

| Nome | Percorso | Scopo | Usato in |
|------|----------|-------|----------|
| `githubWebhook` | `functions/src/githubWebhook.ts` | Handler HTTP Gen 2 — orchestra la verifica HMAC e il routing degli eventi GitHub | `functions/src/index.ts` |
| `index` (entry point) | `functions/src/index.ts` | Esporta `githubWebhook` come Firebase Cloud Function | Deploy Firebase |
| `verifySignature` | `functions/src/lib/hmac.ts` | Verifica la firma X-Hub-Signature-256 con `timingSafeEqual` (anti timing-attack) | `githubWebhook.ts` |
| `resolveProject` | `functions/src/lib/projectResolver.ts` | Trova il progetto Firestore che corrisponde all'URL GitHub del repository | `githubWebhook.ts` |
| `resolveTask` | `functions/src/lib/taskResolver.ts` | Trova il task in una subcollection Firestore dato il `taskCode` | `githubWebhook.ts` |
| `routeEvent` | `functions/src/lib/eventRouter.ts` | Trasforma l'evento GitHub (push / pull_request / pull_request_review) in un `DesiredUpdate` | `githubWebhook.ts` |
| `buildUpdate` | `functions/src/lib/taskUpdater.ts` | Costruisce l'aggiornamento Firestore applicando la logica di avanzamento (no retrocessione, idempotenza note) | `githubWebhook.ts` |
| `writeUpdate` | `functions/src/lib/firestoreWriter.ts` | Esegue la transazione atomica su Firestore (status + fasi + nota) | `githubWebhook.ts` |
| Interfacce condivise | `functions/src/lib/types.ts` | Tipi TypeScript condivisi tra i moduli Cloud Function (`GithubEvent`, `DesiredUpdate`, ecc.) | Tutti i moduli `lib/` |
| `authenticateWebhook` | `functions/src/lib/authenticate.ts` | [T-20] Autentica la richiesta con due segreti (storico e GitHub App), restituisce l'origine (`webhook` / `github-app`); 401/500 senza mai esporre segreti | `githubWebhook.ts` |
| `createWebhookSecrets`, `createSecretReader` | `functions/src/lib/secrets.ts` | [T-20] Lettura dei segreti da Secret Manager con copia a tempo; il segreto dell'App e' facoltativo (assente = si usa solo lo storico) | `githubWebhook.ts` |
| `processEvent` | `functions/src/lib/eventProcessor.ts` | [T-20] Elabora un evento autenticato: progetto noto -> aggancio + aggiornamento task; progetto sconosciuto -> creazione con tutti i controlli; log strutturato per ogni esito | `githubWebhook.ts` |
| `logEvent`, `cleanDelivery` | `functions/src/lib/eventLog.ts` | [T-20] Registro strutturato degli eventi (esito + motivo, senza dati personali) | `eventProcessor.ts` |
| `createProjectForRepo` | `functions/src/lib/projectCreator.ts` | [T-20] Crea il progetto di un repository sconosciuto in una transazione (ID deterministico, tetto giornaliero, lapide dei progetti eliminati, intestatario admin verificato) | `eventProcessor.ts` |
| `syncProjectLink`, `applyRepositoryAction` | `functions/src/lib/projectLink.ts` | [T-20] Aggancia un progetto esistente al repository (aggiunge `githubRepoId`, aggiorna l'indirizzo se rinominato) e segna archiviazione/cancellazione del repository | `eventProcessor.ts` |
| `resolveProjectForRepo` | `functions/src/lib/projectResolver.ts` | [T-20] Estende `resolveProject`: cerca per identificativo numerico del repository e poi per indirizzo | `eventProcessor.ts`, `projectLink.ts` |
| `generateClientCode`, `buildProjectData`, `buildClientAccessData`, `normalizeGithubUrl` | `functions/src/lib/projectFactory.ts` | [T-20] UNICA implementazione di codice cliente, forma dei documenti progetto/accesso cliente e confronto indirizzi (prima era scritta nello script e nell'app) | `projectCreator.ts`, `projectResolver.ts`, `scripts/registra-ore.mjs` |
| `extractRepoInfo`, `isIgnoredRepo`, `creationBlockReason`, `cleanText`, `isGithubRepoUrl`, `IGNORE_TOPIC` | `functions/src/lib/repoInfo.ts` | [T-20] Legge e valida i dati del repository dal payload (testo non fidato ripulito); esclusioni: topic `avanza-ignora`, fork, archiviato | `eventProcessor.ts` |
| `loadLinkConfig`, `parseLinkConfig` | `functions/src/lib/linkConfig.ts` | [T-20] Legge/valida `githubCollegamento/config` (interruttore spento se incompleto), copia 60 s | `eventProcessor.ts` |
| `repoRef`, `autoProjectId`, `dayRef`, `dayKey` | `functions/src/lib/linkStore.ts` | [T-20] Riferimenti ai documenti di supporto (registro repository, contatore giornaliero) e ID deterministico del progetto | `projectCreator.ts`, `projectLink.ts` |
| `isProjectCreatingEvent`, `TRUSTED_REVIEW_ASSOCIATIONS` | `functions/src/lib/eventRouter.ts` | [T-20] Quali eventi possono far nascere un progetto; chi puo' far avanzare un task con un'approvazione | `eventProcessor.ts` |

---

## Script di amministrazione (`scripts/`)

| Nome | Percorso | Scopo | Usato in |
|------|----------|-------|----------|
| `registra-ore.mjs` | `scripts/registra-ore.mjs` | Azioni della squadra su Firestore (Admin SDK): `membro`, `ore`, `importa-task`, `stato`, `admin`, `crea-progetto`, `elimina-prova`, `migra`; [T-12] `domande` (sola lettura) e `rispondi` (chat admin-squadra) | Workflow "Registra ore squadra" |
| `registra-ore.mjs` azioni `collegamento`, `collegamento-stato` | `scripts/registra-ore.mjs` | [T-20] Accende/spegne la creazione automatica dei progetti, riammette un repository escluso, mostra lo stato (scrive solo `githubCollegamento/config` e lo stato del registro `githubRepos`) | Workflow "Registra ore squadra" |
| `imposta-segreto-app.yml` | `.github/workflows/imposta-segreto-app.yml` | [T-20] Porta il segreto della GitHub App dal segreto GitHub `GH_APP_WEBHOOK_SECRET` a Secret Manager (`GITHUB_APP_WEBHOOK_SECRET`), senza terminale; produzione solo da `main` | A mano (workflow_dispatch) |

---

## Script di controllo del rilascio (`.claude/scripts/`)

| Nome | Percorso | Scopo | Usato in |
|------|----------|-------|----------|
| `classifica-rilascio.sh` | `.claude/scripts/classifica-rilascio.sh` | Ricalcola al momento del rilascio se ciò che esce è correzione o sviluppo (riusa `classifica-modifica.py`) e se regole/indici Firestore cambiano | `rilascio-produzione.yml` (job `classifica`) |
| `controlla-prerequisiti-rilascio.sh` | `.claude/scripts/controlla-prerequisiti-rilascio.sh` | Segreti e variabili necessari presenti; la chiave è del progetto `avanza-b62d7` (mai i valori in chiaro) | `rilascio-produzione.yml` |
| `verifica-da-staging.sh` | `.claude/scripts/verifica-da-staging.sh` | Il contenuto è identico a un commit di `staging` con controlli verdi e pubblicazione di test riuscita; con `RICHIEDI_TEST_VERDI=si` richiede anche i test automatici passati (T-18) | `rilascio-produzione.yml`, `setup-firestore.yml`, `promuovi-staging.sh` |
| `promozione-pr.sh` | `.claude/scripts/promozione-pr.sh` | Apre o aggiorna la pull request `staging -> main` (riepilogo, classificazione correzione/sviluppo, etichette). Estratto dal workflow per essere usato dai due job | `promozione.yml` (job `pr` e `unione`) |
| `promuovi-staging.sh` | `.claude/scripts/promuovi-staging.sh` | Promozione automatica: controlla interruttori e blocco, regole/indici Firestore uguali (altrimenti "serve una persona"), contenuto dell'unione, controlli verdi della testa di `staging` e della PR; se tutto è verde unisce (merge commit) e avvia `rilascio-produzione.yml`; altrimenti non fa nulla (T-18) | `promozione.yml` (job `unione`) |
| `prova-promozione.sh` | `.claude/scripts/prova-promozione.sh` | Prova locale di `promuovi-staging.sh` e `promozione-pr.sh` (57 casi) con repository git vero e `gh` finto | a mano / `validatore` |
| `controlla-build-ambiente.sh` | `.claude/scripts/controlla-build-ambiente.sh` | La build web contiene la configurazione del progetto giusto (prod/test) e nessuna traccia dell'altro | `ci.yml`, `deploy.yml`, `rilascio-produzione.yml` |
| `smoke-produzione.sh` | `.claude/scripts/smoke-produzione.sh` | Prova rapida in sola lettura di sito, cache, funzione e login dopo il rilascio | `rilascio-produzione.yml`, `verifica-sito.yml` |
| `pr-del-commit.sh` | `.claude/scripts/pr-del-commit.sh` | Raccoglie le pull request dei commit di un intervallo (formato per `classifica-modifica.py`), escludendo la PR di promozione staging -> main. Script unico: prima la logica era copiata in due posti | `promozione.yml`, `classifica-rilascio.sh` |
| `salvavita-test.sh` | `.claude/scripts/salvavita-test.sh` | Rifiuta il flusso di test se progetto o chiave di servizio di test sono quelli della produzione (`avanza-b62d7`) | `deploy.yml` (deploy di test e anteprima) |
