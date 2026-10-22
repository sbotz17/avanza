# Architettura: Integrazione automatica GitHub → Avanza

**Versione**: 1.0 — 2026-10-22
**Stato**: Approvata — pronta per implementazione

---

## 1. Stack tecnologico

| Livello | Tecnologia | Motivo |
|---|---|---|
| App client | Flutter (web + mobile) | Già in uso; stream Firestore aggiorna la UI in real-time senza modifiche lato client |
| Database | Firebase Firestore | Già in uso; la scrittura dalla Cloud Function è visibile in ~1-2 s nell'app aperta |
| Cloud Function | Firebase Functions Gen 2 · Node.js 20 · TypeScript | Standard Firebase; Gen 2 (onRequest) supporta la dichiarazione dei secret in modo esplicito; TypeScript evita errori di tipo sui payload GitHub |
| Secret | Firebase Secret Manager | Il secret HMAC non entra mai nel codice né nel repository; la Cloud Function lo legge a runtime |

---

## 2. Diagramma del flusso

```
GitHub Repository
    │
    │  POST HTTPS — payload JSON
    │  Header: X-Hub-Signature-256: sha256=<hmac>
    │  Header: X-GitHub-Event: push | pull_request | pull_request_review
    │  Header: X-GitHub-Delivery: <uuid>
    ▼
┌─────────────────────────────────────────────────────────────┐
│  Cloud Function: githubWebhook                              │
│  (Firebase Functions Gen 2, HTTP, Node.js 20, TypeScript)   │
│                                                             │
│  1. verificaFirma(req, GITHUB_WEBHOOK_SECRET)               │
│     → 401 se firma assente o non valida                     │
│                                                             │
│  2. leggiTipoEvento(req.headers['x-github-event'])          │
│     → 200 (no-op) se evento non gestito                     │
│                                                             │
│  3. cercaProgetto(payload.repository.html_url)              │
│     → 200 + log warning se nessun progetto corrisponde      │
│                                                             │
│  4. estraiTaskCode(branchName, prTitle)                     │
│     → 200 + log info se nessun T-N trovato                  │
│                                                             │
│  5. cercaTask(projectId, taskCode)                          │
│     → 200 + log warning se task non trovato                 │
│                                                             │
│  6. costruisciAggiornamento(evento, taskCorrente)           │
│     → no-op se idempotente (già aggiornato)                 │
│                                                             │
│  7. scriviFirestore(projectId, taskId, update)              │
│     → transazione atomica                                   │
│     → 500 se errore Firestore (GitHub riprova)              │
│                                                             │
│  8. rispondi 200 { ok: true }                               │
└─────────────────────────────────────────────────────────────┘
    │
    │  Scrittura Firestore
    ▼
Firestore: projects/{projectId}/tasks/{taskId}
    │
    │  Real-time stream (già attivo nell'app)
    ▼
App Flutter — aggiornamento visibile in ~1-2 s
```

---

## 3. Struttura cartella `functions/`

```
functions/
  src/
    index.ts                     # Entry point: esporta githubWebhook
    githubWebhook.ts             # Handler HTTP principale (orchestrazione)
    lib/
      hmac.ts                    # Verifica firma X-Hub-Signature-256
      projectResolver.ts         # Cerca progetto per githubUrl (case-insensitive)
      taskResolver.ts            # Cerca task per taskCode nella subcollection
      eventRouter.ts             # Routing per tipo evento e action
      taskUpdater.ts             # Costruisce l'aggiornamento Firestore (logica avanzamento)
      firestoreWriter.ts         # Esegue la transazione atomica su Firestore
      types.ts                   # Interfacce TypeScript: payload GitHub, TaskUpdate
  package.json
  tsconfig.json
  .eslintrc.js
  .gitignore                     # ignora node_modules/
```

**Perché questa suddivisione?** Ogni modulo ha una singola responsabilità. Il backend developer implementa un file alla volta, i test sono mirati, il tester può simulare ogni passo isolatamente.

---

## 4. Contratto API — Cloud Function `githubWebhook`

### 4.1 Signature del handler

```typescript
// functions/src/index.ts
import { onRequest } from 'firebase-functions/v2/https';
export const githubWebhook = onRequest(
  {
    region: 'us-central1',
    secrets: ['GITHUB_WEBHOOK_SECRET'],
  },
  handler   // importato da githubWebhook.ts
);
```

### 4.2 Input atteso

**Metodo**: solo `POST`. Risponde `405` per qualsiasi altro metodo.

**Headers obbligatori**:

| Header | Valore | Uso |
|---|---|---|
| `X-Hub-Signature-256` | `sha256=<hex>` | Verifica firma HMAC-SHA256 del body con il secret |
| `X-GitHub-Event` | `push` / `pull_request` / `pull_request_review` / altri | Routing evento |
| `X-GitHub-Delivery` | UUID (es. `abc-123-...`) | Logging; non usato per idempotenza |
| `Content-Type` | `application/json` | Richiesto da Firebase onRequest |

**Body** (JSON): payload standard GitHub per il tipo evento. Campi usati:

| Campo payload | Usato in | Note |
|---|---|---|
| `repository.html_url` | Tutti | Cerca il progetto Avanza; confronto case-insensitive, trailing slash ignorato |
| `ref` | `push` | Es. `refs/heads/feature/T-4-login`; si estrae la parte dopo `refs/heads/` |
| `created` | `push` | `true` = branch nuovo; `false` = commit aggiuntivi |
| `commits[0].id` | `push` | Hash commit (breve: primi 7 char) |
| `commits[0].message` | `push` | Messaggio commit, troncato a 100 char, non interpretato |
| `pull_request.number` | `pull_request` | Numero PR |
| `pull_request.title` | `pull_request` | Titolo PR; usato per estrarre `T-N` se branch non ce l'ha |
| `pull_request.merged` | `pull_request` | `true` = merged; `false` = chiusa senza merge |
| `pull_request.base.ref` | `pull_request` | Branch di destinazione (es. `staging`, `main`) |
| `pull_request.head.ref` | `pull_request` | Branch sorgente; preferito per estrarre `T-N` |
| `review.state` | `pull_request_review` | Solo `"approved"` è gestito |
| `review.user.login` | `pull_request_review` | Nome reviewer per la nota |

### 4.3 Routing eventi

```
X-GitHub-Event: push
  payload.created = true   → BRANCH_CREATED  (task → active, fase Analisi → active)
  payload.created = false  → COMMIT_PUSHED   (aggiunge nota commit)

X-GitHub-Event: pull_request
  action = "opened"                               → PR_OPENED   (aggiunge nota)
  action = "closed" && pull_request.merged = true → PR_MERGED   (task → review, fase Frontend → done)
  action = "closed" && pull_request.merged = false→ PR_CLOSED   (aggiunge nota)
  altri action                                    → IGNORATO    (200, no-op)

X-GitHub-Event: pull_request_review
  action = "submitted" && review.state = "approved" → PR_APPROVED (task → validated, fase Validazione → done)
  altri                                             → IGNORATO

altri eventi (issues, star, fork, ecc.)            → IGNORATO (200, no-op)
```

### 4.4 Output HTTP

| Codice | Corpo | Quando |
|---|---|---|
| `200` | `{ "ok": true }` | Evento elaborato correttamente oppure ignorato legittimamente (no match, evento non gestito, idempotente) |
| `401` | `{ "error": "invalid signature" }` | Firma HMAC assente o non valida |
| `405` | `{ "error": "method not allowed" }` | Richiesta non POST |
| `500` | `{ "error": "internal error" }` | Errore Firestore (GitHub riproverà automaticamente) |

### 4.5 Interfacce TypeScript (`lib/types.ts`)

```typescript
// Aggiornamento calcolato da eventRouter/taskUpdater prima della scrittura
interface TaskUpdate {
  newStatus?: TaskStatus;           // solo se avanza (mai retrocede)
  phaseUpdates?: PhaseUpdate[];     // solo le fasi che avanzano
  note: TaskNote;                   // la nota da aggiungere
}

interface PhaseUpdate {
  phaseName: string;                // es. "Analisi", "Frontend", "Validazione"
  newStatus: PhaseStatus;           // "active" o "done"
}

interface TaskNote {
  type: 'info' | 'ok' | 'blk';
  text: string;                     // sempre con prefisso "[gh] "
}

type TaskStatus = 'backlog' | 'active' | 'blocked' | 'review' | 'validated' | 'released';
type PhaseStatus = 'pending' | 'active' | 'done' | 'blocked' | 'skip';
```

---

## 5. Aggiornamento Firestore

### 5.1 Percorso documenti

```
projects/{projectId}/tasks/{taskId}
```

- `projectId`: trovato cercando `githubUrl` nella collection `projects`
- `taskId`: trovato cercando `taskCode` nella subcollection `tasks` del progetto

Query usate:
```
// Cerca progetto
db.collection('projects')
  .where('githubUrl_lower', '==', repoUrl.toLowerCase().replace(/\/$/, ''))
  .limit(1)

// Oppure (senza campo denormalizzato): scan filtrato in memoria
// — da decidere nel dettaglio implementativo (ADR-03)

// Cerca task
db.collection('projects').doc(projectId)
  .collection('tasks')
  .where('taskCode', '==', 'T-N')
  .limit(1)
```

### 5.2 Campi aggiornati per tipo evento

**BRANCH_CREATED** (`push.created = true`):
```
status:          "active"   ← solo se taskStatusOrder[current] < taskStatusOrder["active"]
phases[Analisi]: { status: "active" }  ← solo se era "pending"
notes:           arrayUnion({ type: "info", text: "[gh] Branch <branch> creato" })
githubBranch:    "<branch>"
updatedAt:       serverTimestamp()
```

**COMMIT_PUSHED** (`push.created = false`):
```
notes:    arrayUnion({ type: "info", text: "[gh] Commit <7char>: <msg troncato>" })
updatedAt: serverTimestamp()
```
Idempotenza: non aggiunge nota se il testo `[gh] Commit <hash>:` è già presente.

**PR_OPENED**:
```
notes:          arrayUnion({ type: "info", text: "[gh] PR #<N> aperta: \"<titolo>\"" })
githubPrNumber: <N>
updatedAt:      serverTimestamp()
```
Idempotenza: non aggiunge nota se `[gh] PR #<N> aperta` è già presente.

**PR_MERGED**:
```
status:           "review"   ← solo se statusOrder[current] < statusOrder["review"]
phases[Frontend]: { status: "done" }  ← solo se era "active"
notes:            arrayUnion({ type: "ok", text: "[gh] PR #<N> mergeata in <base>" })
updatedAt:        serverTimestamp()
```
Idempotenza: non aggiunge nota se `[gh] PR #<N> mergeata` è già presente.

**PR_CLOSED** (no merge):
```
notes:    arrayUnion({ type: "blk", text: "[gh] PR #<N> chiusa senza merge" })
updatedAt: serverTimestamp()
```

**PR_APPROVED**:
```
status:              "validated"  ← solo se statusOrder[current] < statusOrder["validated"]
phases[Validazione]: { status: "done" }
notes:               arrayUnion({ type: "ok", text: "[gh] PR #<N> approvata da <reviewer>" })
updatedAt:           serverTimestamp()
```
Idempotenza: non aggiunge nota se `[gh] PR #<N> approvata` è già presente.

### 5.3 Regola "solo avanzamento"

Sequenza ordinata degli stati:
```typescript
const STATUS_ORDER = ['backlog', 'active', 'blocked', 'review', 'validated', 'released'];
// "released" è terminale: nessun aggiornamento automatico
// "blocked" non fa parte della progressione automatica (viene impostato manualmente)
```

Prima di aggiornare `status`:
```typescript
if (task.status === 'released') return; // terminale
if (STATUS_ORDER.indexOf(newStatus) <= STATUS_ORDER.indexOf(task.status)) return; // no retrocessione
```

Stessa logica per le fasi: si avanza solo se `phaseStatusOrder[new] > phaseStatusOrder[current]`.

### 5.4 Scrittura atomica

Ogni modifica al task usa una **transazione Firestore** (non `update` diretto):
```typescript
await db.runTransaction(async (tx) => {
  const taskDoc = await tx.get(taskRef);
  // ... calcola update ...
  tx.update(taskRef, computedUpdate);
});
```
Questo evita race condition se due eventi arrivano quasi contemporaneamente.

### 5.5 Indici Firestore necessari

| Collection | Campo | Tipo indice | Note |
|---|---|---|---|
| `tasks` (subcollection) | `taskCode` | Singolo (ASC) | Firestore crea automaticamente indici su campi singoli; nessun indice composto necessario |
| `projects` | `githubUrl` | Singolo (ASC) | Già creato se `githubUrl` era usato in query; da verificare nelle regole |

---

## 6. Gestione del secret HMAC

**Firebase Secret Manager** (non Firebase environment config, che è deprecato in Gen 2).

Flusso:
1. Andrea genera un secret casuale (es. `openssl rand -hex 32`)
2. Lo salva in Firebase Secret Manager con nome `GITHUB_WEBHOOK_SECRET` nel progetto `avanza-b62d7`
3. La Cloud Function lo dichiara: `secrets: ['GITHUB_WEBHOOK_SECRET']` — accessibile a runtime come `process.env.GITHUB_WEBHOOK_SECRET`
4. Lo stesso secret viene incollato nel campo "Secret" della configurazione webhook su GitHub (una volta per repository)
5. Il secret non entra mai in Git, nei log né nell'app Flutter

**Verifica firma** (`lib/hmac.ts`):
```typescript
import { createHmac, timingSafeEqual } from 'crypto';

function verifySignature(body: Buffer, signature: string, secret: string): boolean {
  const expected = 'sha256=' + createHmac('sha256', secret).update(body).digest('hex');
  const a = Buffer.from(expected, 'utf8');
  const b = Buffer.from(signature, 'utf8');
  if (a.length !== b.length) return false;
  return timingSafeEqual(a, b);
}
```
`timingSafeEqual` previene timing attack. Il body deve essere letto come Buffer grezzo prima del parsing JSON.

---

## 7. Nuovi campi al modello Task (Firestore)

Tutti additivi. I task esistenti senza questi campi vengono letti normalmente; la Cloud Function li ignora se `taskCode` è assente.

| Campo | Tipo Firestore | Default | Immutabile | Note |
|---|---|---|---|---|
| `taskNumber` | `number` | sequenziale per progetto | Sì (dopo creazione) | Generato da `FirestoreService.createTask` con transazione per garantire unicità |
| `taskCode` | `string` | `"T-<taskNumber>"` | Sì | Es. `"T-1"`, `"T-12"`; mostrato nell'UI vicino al titolo |
| `githubBranch` | `string \| null` | `null` | No (aggiornato dalla CF) | Ultimo branch associato |
| `githubPrNumber` | `number \| null` | `null` | No (aggiornato dalla CF) | Numero ultima PR associata |

**Generazione `taskNumber` (transazione su `FirestoreService.createTask`):**
La variabile `taskNumber` viene determinata con una transazione che legge il documento contatore `projects/{projectId}` → campo `lastTaskNumber`, lo incrementa e salva il nuovo task con `taskNumber = lastTaskNumber + 1`. Questo garantisce unicità anche in caso di creazioni parallele.

---

## 8. Blocchi di lavoro indipendenti

| Blocco | Agente | Dipendenze | Output atteso |
|---|---|---|---|
| **A — Modello dati** | `dba` | Nessuna | Aggiunta campi `taskCode`, `taskNumber`, `githubBranch`, `githubPrNumber` al modello Firestore e a `Task.dart`; aggiornamento `FirestoreService.createTask` con transazione; aggiornamento `firestore.rules`; documentazione in `docs/database.md` |
| **B — Cloud Function** | `sviluppatore-backend` | Contratto in §4, §5, §6 (questo doc) | Implementazione `functions/src/` completa; `package.json` e `tsconfig.json`; test con payload simulati |
| **C — UI taskCode** | `sviluppatore-frontend` | Blocco A (campo `taskCode` nel modello Flutter) | `taskCode` visibile nell'UI del task (vicino al titolo, copiabile con tap) |

I blocchi B e C possono partire in parallelo non appena il Blocco A è completato e il contratto dati è stabile. Il blocco B non richiede modifiche all'app Flutter.

---

## 9. Ambienti e avvio

### Locale (sviluppo)

```bash
# 1. Emulatori Firebase (Firestore + Functions)
cd avanza/
firebase emulators:start --only functions,firestore

# URL locale della Cloud Function:
# http://localhost:5001/avanza-b62d7/us-central1/githubWebhook

# 2. App Flutter
flutter run -d chrome
# (con FIREBASE_EMULATOR=true nelle env vars, oppure via firebase_options)

# 3. Compilazione TypeScript (watch mode)
cd functions/
npm run build:watch
```

**Test webhook locale**: usare [smee.io](https://smee.io) o [ngrok](https://ngrok.com) per esporre l'emulatore su un URL pubblico e configurarlo come webhook su GitHub, oppure usare `curl` con payload GitHub di test.

In ambiente emulatore il secret HMAC viene letto da `.env.local` nella cartella `functions/` (file escluso da Git):
```
GITHUB_WEBHOOK_SECRET=<secret-di-test-locale>
```

### Staging / Produzione

Unico progetto Firebase: `avanza-b62d7` (da `.firebaserc`).

Non esiste ancora un secondo progetto Firebase per lo staging. Decisione in sospeso: vedi ADR-04 in §10.

**Deploy Cloud Function**:
```bash
firebase deploy --only functions
```

**URL produzione** (generato da Firebase al primo deploy):
```
https://us-central1-avanza-b62d7.cloudfunctions.net/githubWebhook
```
Questo URL va incollato nella configurazione webhook su GitHub.

---

## 10. Registro decisioni (ADR)

### ADR-01 · Firebase Functions Gen 2 invece di Gen 1
**Data**: 2026-10-22
**Decisione**: Cloud Function scritta in Gen 2 (`onRequest` da `firebase-functions/v2/https`).
**Motivazione**: Gen 2 supporta la dichiarazione esplicita dei secret (`secrets: [...]`), che è il modo ufficiale e sicuro per accedere a Firebase Secret Manager a runtime. Gen 1 usava `functions.config()` (deprecato).
**Alternativa scartata**: Gen 1 (`functions.https.onRequest`) — deprecata per i nuovi deploy, non supporta `secrets:`.

### ADR-02 · Idempotenza per testo nota, non per X-GitHub-Delivery
**Data**: 2026-10-22
**Decisione**: Prima di aggiungere una nota automatica, la Cloud Function verifica che non esista già una nota con lo stesso testo identificante (es. `[gh] Commit <hash>:` oppure `[gh] PR #<N> mergeata`).
**Motivazione**: Semplice da implementare senza aggiungere struttura al documento Firestore. `X-GitHub-Delivery` potrebbe essere diverso tra retry (non documentato come stabile).
**Alternativa scartata**: Salvare `X-GitHub-Delivery` in un array `processedDeliveries` — aggiunge un campo e cresce senza bound nel tempo.

### ADR-03 · Ricerca progetto per githubUrl: scan in memoria vs campo denormalizzato
**Data**: 2026-10-22
**Decisione**: La Cloud Function carica tutti i documenti `projects` (solo campo `githubUrl` e `id`, con `select`) e fa il match in memoria. Accettabile perché il numero di progetti è piccolo (< 100 per ora).
**Motivazione**: Non richiede un campo denormalizzato `githubUrl_lower` aggiuntivo; evita una migrazione; più semplice da mantenere.
**Alternativa scartata**: Aggiungere `githubUrl_lower` (versione lowercase senza trailing slash) per una query `where` diretta. Da adottare se i progetti diventano molti (> 500).
**Revisione**: Rivalutare se il progetto supera i 500 progetti.

### ADR-04 · Staging: unico progetto Firebase (decisione in sospeso)
**Data**: 2026-10-22
**Decisione in sospeso**: Non esiste un secondo progetto Firebase per lo staging. Attualmente non c'è un `docs/ambienti.md` che lo descriva.
**Opzioni**: (a) usare emulatori locali per i test; (b) creare un secondo progetto Firebase `avanza-staging`; (c) accettare che staging = produzione (rischio).
**Raccomandazione dell'architetto**: opzione (a) per ora — i test della Cloud Function si fanno con gli emulatori; il deploy diretto su produzione si fa solo con tutti i controlli passati. Appena il progetto cresce, si valuta (b).
**Azione richiesta ad Andrea**: confermare l'approccio prima del deploy in produzione della Cloud Function.

### ADR-05 · Transazione per taskNumber (unicità sequenziale)
**Data**: 2026-10-22
**Decisione**: `taskNumber` viene generato con una transazione Firestore che legge e incrementa il contatore `lastTaskNumber` nel documento del progetto.
**Motivazione**: Senza transazione, due task creati quasi contemporaneamente potrebbero ottenere lo stesso numero. La transazione garantisce unicità senza gap (tranne cancellazioni, accettabili per i requisiti).
**Alternativa scartata**: Query `orderBy('taskNumber', 'desc').limit(1)` + incremento — race condition possibile.

---

*Fine documento architettura.*
