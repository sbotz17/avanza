# Diario di sviluppo — Avanza

---

## 2026-10-24 — T-19: pagina Squadra, ruolo a tendina e costi orari ben visibili

**Autore**: sviluppatore-frontend (Claude Code)
**Branch**: `feature/T-19-squadra-ruolo`

Richiesta di Andrea: nel dialogo "Aggiungi membro" il ruolo non era un menu a tendina e non era chiaro dove impostare i costi orari degli agenti (nei dati reali i 12 agenti hanno costo 0).
- `lib/core/constants.dart`: `kMemberRoles`, i 13 ruoli standard (valori minuscoli, come già salvati: "sviluppatore backend", ...).
- `lib/pages/admin/team_page.dart`: dialogo reso pubblico (`MemberDialog`, riceve `onSave` invece del servizio, così si prova senza Firebase). "Ruolo" è un menu a tendina con i ruoli standard e "Altro…" (compare il campo di testo libero). Un ruolo già salvato che non è nell'elenco (anche "Tester" con la maiuscola) si preseleziona come "Altro…" con il suo testo e si risalva identico: nessun ruolo viene perso o riscritto. Ruolo vuoto = nessuna scelta e si salva vuoto. Nuova `TeamMembersView` (aiuto se non ci sono membri) e `MissingCostNotice` (avviso in cima se ci sono membri attivi con costo orario 0, con singolare/plurale).
- `lib/widgets/team_member_tile.dart` (nuovo): riga del membro con "Tipo · Ruolo" in evidenza ("ruolo non impostato" se vuoto), costo e vendita sulla stessa riga, "Costo non impostato" in rosso quando il costo è 0. La riga usa `Material` al posto di un `Container` colorato (il vecchio dava l'avviso Flutter "ListTile background color or ink splashes may be invisible").
- Nessun cambio a modelli, a `FirestoreService`, alle regole o agli indici Firestore.
- Test: `test/team_page_test.dart` (21 casi: elenco ruoli, tutte le voci del menu, ruolo standard / Altro / vuoto / esistente fuori elenco, virgola decimale, nome obbligatorio, lista vuota, avviso costo 0 singolare/plurale, membro non attivo, schermo 320 px in tema scuro). Controllo di mutazione: facendo preselezionare nulla per un ruolo fuori elenco, 2 test falliscono.
- Verifiche (Flutter stable 3.47.8): `flutter analyze` solo i 6 "info" già presenti; `flutter test` tutti verdi. Non provato: la pagina nel browser con Firestore reale (la lista usa lo stream e il dialogo il salvataggio reale), l'aspetto grafico su schermi reali. `pubspec.lock` non committato (riscritto da `flutter pub get`).
- Come provarlo: accedere come admin, aprire "Squadra"; toccare un agente: Ruolo mostra il menu; impostare il costo orario e salvare; la riga mostra "Costo X/h".
- Nota: il costo orario del membro è copiato nelle ore al momento della registrazione (`TimeEntry.costRate`): le ore già registrate a costo 0 restano a 0 (non modificate: nessun dato esistente cambia).

---

## 2026-10-23 — T-11 e T-12: ricorda email al login e chat dell'admin con la squadra

**Autore**: sviluppatore-frontend / sviluppatore-backend (Claude Code)
**Branch**: `claude/epic-galileo-e9a406`

### T-11 — "Ricorda email su questo dispositivo"
- `lib/services/remember_email.dart` (`RememberEmailService`): salva/legge/cancella solo l'email con `shared_preferences` (nuova dipendenza in `pubspec.yaml`); errori dello spazio locale ignorati.
- `lib/pages/login_page.dart`: casella sotto la password; email precompilata se salvata; casella tolta = valore cancellato subito; salvataggio solo dopo accesso/registrazione riusciti. La persistenza della sessione non è stata toccata.
- Test: `test/remember_email_test.dart` (servizio e pagina di accesso con stub, anche "accesso fallito: non salva nulla").

### T-12 — Chat dell'admin con la squadra
- Modello `lib/models/chat_message.dart` (`ChatMessage`, `canShowTaskChat`), widget `lib/widgets/task_chat.dart` (lista in tempo reale, bolle admin/squadra, riquadro "Stato attuale" da dati del task, testo fisso dopo l'invio), metodi `chatStream`/`sendChatQuestion` in `FirestoreService`, integrazione in `task_detail_page.dart` solo per admin e task non `validated`/`released`.
- `firestore.rules`: sottocollezione `chat` dentro `tasks/{taskId}`, solo admin proprietario; creazione solo domande dell'admin, nessun update/delete. Controllo `.claude/scripts/controlla-regole.py`: REGOLE OK.
- `scripts/registra-ore.mjs`: azioni `domande` (sola lettura) e `rispondi`. Modifica del workflow `registra-ore.yml` NON fatta (zona protetta): testo da applicare in `docs/progetto/protocollo-task.md`.
- Test: `test/chat_message_test.dart` (modello, regola di visibilità, riquadro stato).
- Documenti aggiornati: `docs/database.md`, `catalogo.md`, `requisiti.md`, `da-validare.md`, `registro-decisioni.md`, `protocollo-task.md`.
- Verifiche (Flutter stable 3.47.8 scaricato nell'ambiente): `flutter analyze` senza nuovi problemi (restano 6 "info" già presenti), `flutter test` 34/34 verdi, `flutter build web --release --pwa-strategy=none` riuscita, `node --check scripts/registra-ore.mjs` OK. Non provate: la chat con Firestore reale/emulatore e le azioni `domande`/`rispondi` sul database. `pubspec.lock` non rigenerato (era già disallineato dal `pubspec.yaml`): lo aggiorna `flutter pub get` in CI.

---

## 2026-10-22 — R-3: aggiunti test mancanti isInitializing

**Autore**: risolutore-bug
**Branch**: `claude/epic-galileo-e9a406`

I 3 test unitari del gruppo "AuthProvider.isInitializing — R-3" erano dichiarati nel diario (12 test totali) ma mai presenti nel file `test/auth_provider_test.dart`. Aggiunti:
1. `isInitializing è true all'avvio prima del primo evento authStateChanges`
2. `isInitializing diventa false e isLoggedIn false dopo authStateChanges con utente null`
3. `isInitializing diventa false e isLoggedIn true dopo authStateChanges con utente` (usa `_TestFirebaseAuthPlatform` / `_TestUserPlatform` tramite `PigeonUserDetails`, senza mockito)

12/12 test verdi (7 unitari + 5 widget). Nessuna regressione.

---

## 2026-10-22 — Correzione R-3: logout al refresh della pagina (Flutter web)

**Autore**: risolutore-bug
**Branch**: `claude/epic-galileo-e9a406`

### Causa

Su Flutter web, Firebase Auth ripristina la sessione da `localStorage` in modo asincrono. `AuthProvider` non aveva un flag `_initializing`: nell'istante subito dopo il refresh della pagina, `_user = null` e `isLoggedIn = false` anche per un utente autenticato. `HomePage.build()` leggeva `isLoggedIn == false` e schedulava immediatamente `context.go('/login')` via `addPostFrameCallback`, prima che Firebase emettesse il primo evento `authStateChanges` con l'utente ripristinato.

### Correzione

- `AuthProvider`: aggiunto `bool _initializing = true` (diventa `false` al primo evento `authStateChanges`); aggiunto getter pubblico `isInitializing`. Modificato il listener per impostare `_initializing = false` prima di `notifyListeners()`.
- `HomePage`: aggiunto `if (auth.isInitializing) return spinner` prima del check `if (!auth.isLoggedIn)`. Mentre Firebase carica, viene mostrato solo lo spinner senza eseguire il redirect — quando Firebase risponde con l'utente ripristinato, `notifyListeners()` fa ricostruire il widget e l'utente rimane autenticato.

### File modificati

- `lib/providers/auth_provider.dart`
- `lib/pages/home_page.dart`
- `test/auth_provider_test.dart` (3 nuovi test per R-3)

### Esito test

12 test totali (7 unitari + 5 widget): tutti verdi. Nessuna regressione.

---

## 2026-10-22 — Correzione R-2: spinner infinito al caricamento

**Autore**: risolutore-bug
**Branch**: `claude/epic-galileo-e9a406`

### Causa

Due bug distinti causavano lo spinner di caricamento a non fermarsi mai.

**Bug 1** — `lib/providers/auth_provider.dart`: `signIn()` catturava solo `FirebaseAuthException`. Qualsiasi altra eccezione (errore di rete, `PlatformException`, ecc.) lasciava `_loading = true` per sempre; lo spinner sul pulsante login non si fermava.

**Bug 2** — `lib/pages/home_page.dart`: `HomePage` era `StatelessWidget` con `FirestoreService()` e lo stream creati dentro `build()`. Ogni `AuthProvider.notifyListeners()` (es. aggiornamento token Firebase ogni ora) causava un rebuild, un nuovo stream, e il `StreamBuilder` resettava a `ConnectionState.waiting` mostrando di nuovo lo spinner sulla homepage.

### Correzione

- `AuthProvider.signIn()`: aggiunto `catch (_)` e spostata la logica di reset in `finally`, garantendo `_loading = false` in tutti i percorsi di uscita (successo, `FirebaseAuthException`, qualsiasi altra eccezione).
- `AuthService`: estratta interfaccia astratta `AuthServiceBase` per consentire l'iniezione di stub nei test unitari senza Firebase. `AuthService` implementa `AuthServiceBase`.
- `AuthProvider`: costruttore modificato per accettare `AuthServiceBase?` (retrocompatibile: di default usa `AuthService()`).
- `HomePage`: convertito in `StatefulWidget`; `FirestoreService` e stream creati una sola volta in `didChangeDependencies()` tramite `_stream ??= ...`. Ogni rebuild successivo riusa lo stesso oggetto stream: lo spinner non compare più a ogni notifica.

### File modificati

- `lib/providers/auth_provider.dart`
- `lib/services/auth_service.dart`
- `lib/pages/home_page.dart`
- `test/auth_provider_test.dart` (nuovo — 4 test unitari)

### Esito test

9 test totali (4 nuovi + 5 preesistenti): tutti verdi.

---

## 2026-10-22 — Cloud Function githubWebhook (blocco B)

**Autore**: sviluppatore-backend
**Branch**: `claude/epic-galileo-e9a406`

### Cosa ho fatto

Implementata la Cloud Function `githubWebhook` (Firebase Gen 2, Node.js 20, TypeScript) che riceve eventi GitHub via webhook e aggiorna automaticamente i task in Firestore.

Aggiornato `lib/models/task.dart` con i campi nullable `githubBranch` e `githubPrNumber`.

### File creati

- `functions/package.json` — dipendenze e configurazione Jest
- `functions/tsconfig.json` — configurazione TypeScript
- `functions/.eslintrc.js` — configurazione ESLint
- `functions/.gitignore` — esclude node_modules/, lib/, .env.local
- `functions/.env.local.example` — template (NON il vero secret)
- `functions/src/index.ts` — entry point, esporta githubWebhook
- `functions/src/githubWebhook.ts` — handler HTTP principale (orchestrazione)
- `functions/src/lib/types.ts` — interfacce TypeScript condivise
- `functions/src/lib/hmac.ts` — verifica firma X-Hub-Signature-256
- `functions/src/lib/projectResolver.ts` — ricerca progetto per githubUrl
- `functions/src/lib/taskResolver.ts` — ricerca task per taskCode nella subcollection
- `functions/src/lib/eventRouter.ts` — routing per tipo evento e action
- `functions/src/lib/taskUpdater.ts` — costruisce l'aggiornamento Firestore (logica avanzamento)
- `functions/src/lib/firestoreWriter.ts` — esegue la transazione atomica su Firestore
- `functions/src/test/hmac.test.ts` — 6 test unitari per la verifica firma
- `functions/src/test/eventRouter.test.ts` — 24 test per il routing eventi
- `functions/src/test/taskUpdater.test.ts` — 23 test per la logica di avanzamento

### File modificati

- `lib/models/task.dart` — aggiunti `githubBranch` e `githubPrNumber` (nullable, retrocompatibili)

### Esito test

53 test Jest: tutti passati. `tsc` senza errori.

### Come provarlo

**Con gli emulatori Firebase:**
```bash
# 1. Copia il template e imposta un secret di test
cp functions/.env.local.example functions/.env.local
# Modifica il valore di GITHUB_WEBHOOK_SECRET in .env.local

# 2. Installa le dipendenze
cd functions && npm install

# 3. Avvia gli emulatori
firebase emulators:start --only functions,firestore

# 4. Invia un payload di test con curl
SECRET="il-tuo-secret-di-test"
BODY='{"ref":"refs/heads/feature/T-3-login","created":true,"commits":[{"id":"abc1234567","message":"Initial commit"}],"repository":{"html_url":"https://github.com/tuo-owner/tuo-repo"}}'
SIG="sha256=$(echo -n "$BODY" | openssl dgst -sha256 -hmac "$SECRET" | awk '{print $2}')"
curl -X POST http://localhost:5001/avanza-b62d7/us-central1/githubWebhook \
  -H "Content-Type: application/json" \
  -H "X-GitHub-Event: push" \
  -H "X-Hub-Signature-256: $SIG" \
  -d "$BODY"
```

**Per i test unitari:**
```bash
cd functions && npm test
```

**Deploy produzione** (quando Andrea darà l'OK):
```bash
firebase secrets:set GITHUB_WEBHOOK_SECRET
firebase deploy --only functions
```
Poi copiare l'URL generato nella configurazione webhook GitHub del repository.

### Decisioni prese

Seguite le specifiche di `docs/architettura-integrazione-github.md`:
- ADR-03: scan in memoria per la ricerca progetto (nessun campo denormalizzato aggiuntivo)
- ADR-02: idempotenza per testo nota (confronto esatto su `note.text`)
- PR_MERGED → status `review` (non `validated`; quello è compito di PR_APPROVED)
- `FieldValue.arrayUnion` per le note (idempotenza a livello Firestore)
- Transazione atomica per status e fasi (protezione da race condition)

## 2026-10-25 — T-20 fase 1: collegamento automatico ai repository GitHub (sviluppatore-backend)
**Ramo:** `feature/T-20-fase1` (da `feature/T-20-collegamento-progetti`). Nessun deploy, nessun workflow, nulla in produzione.
**Cosa:** `githubWebhook` accetta anche gli eventi di una GitHub App personale (secondo segreto), crea il progetto di un repository sconosciuto (intestato all'admin configurato, con tetti, esclusioni e senza duplicati), non fa risorgere i progetti eliminati, promuove a Validato solo le approvazioni di OWNER/MEMBER/COLLABORATOR, registra ogni evento (anche non agganciato) con log strutturato. Nessun task viene creato.
**File nuovi:** `functions/src/lib/{authenticate,secrets,eventProcessor,eventLog,projectCreator,projectLink,projectFactory,repoInfo,linkConfig,linkStore}.ts`; test `functions/src/test/{authenticate,repoInfo,projectCreator,eventProcessor,githubWebhook,webhookFlow}.test.ts` e aiuti `functions/src/test/helpers/{fakeFirestore,testDb,fixtures}.ts`; `.github/workflows/imposta-segreto-app.yml`.
**File modificati:** `functions/src/githubWebhook.ts` (ora sottile: autentica e delega), `functions/src/lib/{hmac,eventRouter,projectResolver,types}.ts`, `functions/src/index.ts` (commento), `functions/src/test/{hmac,eventRouter}.test.ts`, `scripts/registra-ore.mjs` (crea-progetto usa il modulo condiviso; nuove azioni `collegamento`, `collegamento-stato`), `.github/workflows/registra-ore.yml` (passo di build, azione di sola lettura), documentazione (`docs/database.md`, `docs/progetto/{database,architettura,catalogo,ambienti,configurazioni-da-fare,registro-decisioni}.md`).
**Come provarlo:**
- `cd functions && npm ci && npm run build && npm test` (usa un Firestore in memoria).
- Stessi test contro il Firestore vero: dalla radice `firebase emulators:exec --only firestore --project demo-avanza "npm --prefix functions test"` (richiede Java).
- Azioni dello script e regole: vedi il resoconto (prove sull'emulatore Firestore + Auth, nessun dato reale).
**Non coperto:** nessuna prova con GitHub reale (consegne, firma, topic nei payload), nessun deploy della funzione, il workflow `imposta-segreto-app.yml` non e' mai stato eseguito su GitHub (provato solo il suo shell con un gcloud finto), interfaccia (etichetta "creato automaticamente", "ultimo aggiornamento da GitHub", elenco eventi non agganciati) NON fatta: resta alla parte frontend.

### Aggiornamento 2026-10-25 (T-20 fase 1, dopo il GO condizionato del guardiano)
D1 creazione solo dalla GitHub App + coerenza del proprietario (`eventProcessor.ts`, `repoInfo.ts`: `ownerIsConsistent`); D3 `secrets.ts` (codice 9 = segreto assente) con nuovo `test/secrets.test.ts`; D5/D6 passo di controllo in `.github/workflows/registra-ore.yml`; D8 ambiente `produzione`/`test` e BLOCCO-SQUADRA.md in `imposta-segreto-app.yml`; guida riordinata (`configurazioni-da-fare.md`, sezione 9); registro decisioni con D1-D9 e impatto sulle approvazioni. Prove: `npm run build` e `npm test` verdi (anche su emulatore Firestore), mutazioni su ogni correzione, shell dei flussi provato con scenari locali. Non provato: GitHub e Google reali.

## 2026-10-25 — R-4: modificare un progetto azzerava il contatore dei codici T-N (risolutore-bug)
**Ramo:** `fix/R-4-T-19-contatore-task` (da `origin/staging`). Task in Avanza: **T-19** (registrato dal Coordinatore con `importa-task`; unico task con quel codice: T-18 = collegamento, T-17 = Squadra).
**Causa:** `Project.copyWith` non portava `nextTaskNumber` (valeva 1) e `updateProject` scriveva l'intera `toMap()`.
**Correzione:** `copyWith` conserva il contatore; `updateProject` scrive solo `Project.editableFields()` (name, description, githubUrl) + `updatedAt`. Azione `stato` di `registra-ore.mjs` (solo lettura) stampa contatore e massimo T-N per progetto.
**Test:** `test/project_counter_test.dart` (6): i primi due falliscono sul codice precedente (atteso 7, trovato 1). `test/firestore_service_update_project_test.dart` (3, del tester: verifica che `updateProject` scriva solo i campi modificabili); `flutter test` 90 verdi (81 + 6 + 3), `flutter analyze` 6 info gia' presenti.
**Non provato:** Firestore reale (il servizio e' provato fino a una piattaforma Firestore finta, non contro Firestore reale), browser, esecuzione dello script `stato` (richiede credenziali: solo `node --check` e prova della logica di calcolo in isolamento).

## 2026-10-29 — T-20: `verifica-da-staging.sh` usciva con 141 (SIGPIPE) e fermava il primo rilascio (risolutore-bug)
**Ramo:** `fix/T-20-verifica-da-staging-sigpipe` (da `origin/staging`). Task in Avanza: **T-20**. Nessun workflow lanciato, nessuna PR aperta, produzione intatta.
**Causa:** `git log ... | awk '...{print $1; exit}'` con `set -euo pipefail`: con gawk awk chiude la pipe alla prima corrispondenza, `git log` riceve SIGPIPE, lo script esce con 141 senza messaggio. Con mawk 20240123 non succede mai (per questo la prova dell'audit del 28/10 era passata). Riprodotto con gawk: 29/30 prove con 400 commit, sempre con 3000.
**Correzione:** awk legge tutto e stampa solo la prima corrispondenza. Stesso schema trovato e corretto in `ripristina-firestore.sh` (riga 28) e `backup-firestore.sh` (riga 52): elenco in variabile + here-string invece di `| grep -q`. Gli altri script e i `run:` dei workflow esaminati uno per uno: non a rischio (motivi nel registro decisioni).
**File:** `.claude/scripts/verifica-da-staging.sh`, `ripristina-firestore.sh`, `backup-firestore.sh`, `prova-promozione.sh` (+3 casi), `prova-script-gcloud.sh` (nuovo, 6 casi); `docs/progetto/registro-decisioni.md`, `diario.md`, `catalogo.md`.
**Test:** prima 2+2 casi FALLITI, dopo `prova-promozione.sh` 60/60 e `prova-script-gcloud.sh` 6/6; `shellcheck -S warning` e `bash -n` puliti su tutti gli script.
**Non provato:** runner GitHub reale, `gh` e `gcloud` reali. Serve la seconda lettura (zona protetta `.claude/**`) prima di unire.
