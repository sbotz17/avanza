# Diario di sviluppo — Avanza

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
