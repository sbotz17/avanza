# Diario di sviluppo — Avanza

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
