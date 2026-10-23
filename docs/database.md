# Avanza — Schema dati (Firestore)

Ultimo aggiornamento: 2026-10-22

---

## Collezioni principali

### `projects/{projectId}`

Ogni documento rappresenta un progetto di sviluppo.

| Campo | Tipo | Obbligatorio | Default | Note |
|---|---|---|---|---|
| `name` | String | si | — | Nome del progetto |
| `description` | String | si | — | Descrizione libera |
| `githubUrl` | String | si | — | URL repository GitHub |
| `clientCode` | String | si | — | Codice breve casuale (6 car.) per accesso cliente |
| `ownerId` | String | si | — | UID Firebase Auth del proprietario |
| `nextTaskNumber` | int | si | `1` | Contatore progressivo per la generazione di `taskCode` nei task. Viene incrementato atomicamente ad ogni creazione di task (vedi transazione in `createTask`). Progetti pre-esistenti senza questo campo lo ricevono come `1` tramite il default nel `fromFirestore`. |
| `createdAt` | Timestamp | si | — | Data creazione |
| `updatedAt` | Timestamp | si | — | Data ultima modifica (aggiornata anche alla creazione di un task) |

**Indici**: `ownerId ASC, updatedAt DESC` (query `projectsStream`); `clientCode ASC` (query `projectByClientCode`).

---

### `projects/{projectId}/tasks/{taskId}`

Sotto-collezione. Ogni documento rappresenta un task (attivita') del progetto.

| Campo | Tipo | Obbligatorio | Default | Note |
|---|---|---|---|---|
| `title` | String | si | — | Titolo breve |
| `description` | String | si | — | Descrizione tecnica |
| `clientRequest` | String | no | `''` | Richiesta originale del cliente |
| `status` | String | si | `'backlog'` | Valori: `backlog`, `active`, `blocked`, `review`, `validated`, `released` |
| `phases` | Array | si | `[]` | Lista di `TaskPhase` (vedi sotto) |
| `notes` | Array | si | `[]` | Lista di `TaskNote` (vedi sotto) |
| `estimatedHours` | Number | si | `0` | Ore stimate |
| `actualHours` | Number | si | `0` | Ore effettive |
| `hourlyRate` | Number | si | `0` | Tariffa oraria |
| `order` | int | si | `0` | Posizione nella lista (kanban) |
| `taskCode` | String | no | `''` | Identificatore breve unico nel progetto, es. `T-1`. Assegnato alla creazione tramite transazione. I task pre-esistenti senza questo campo ricevono `''` come valore di default in `fromFirestore` (retrocompatibilita'). |
| `taskNumber` | int | no | `0` | Numero progressivo usato per generare `taskCode`. Corrisponde al valore di `nextTaskNumber` letto dal progetto al momento della creazione. I task pre-esistenti ricevono `0`. |
| `createdAt` | Timestamp | si | — | Data creazione |
| `updatedAt` | Timestamp | si | — | Data ultima modifica |

**Indici**: `order ASC` (query `tasksStream`).

#### Struttura `TaskPhase` (elemento di `phases`)

| Campo | Tipo | Note |
|---|---|---|
| `name` | String | Identificatore della fase (es. `analisi`) |
| `status` | String | `done`, `active`, `pending`, `blocked`, `skip` |
| `label` | String | Testo visualizzato |

#### Struttura `TaskNote` (elemento di `notes`)

| Campo | Tipo | Note |
|---|---|---|
| `type` | String | `ok`, `info`, `blk` |
| `text` | String | Testo della nota |

---

## Logica di assegnazione taskCode

Alla creazione di ogni task, `FirestoreService.createTask` esegue una **transazione Firestore** che:

1. Legge `nextTaskNumber` dal documento progetto (default `1` se assente — retrocompatibilita').
2. Assegna `taskNumber = nextTaskNumber` e `taskCode = "T-{taskNumber}"` al nuovo task.
3. Scrive il task e incrementa `nextTaskNumber` sul progetto in modo atomico.

In questo modo due task creati in parallelo non ricevono mai lo stesso codice.

I task creati prima dell'introduzione di questi campi hanno `taskCode = ''` e `taskNumber = 0`: sono distinguibili e non confliggono con i nuovi codici progressivi.

---

## Retrocompatibilita'

Tutti i campi aggiunti successivamente (`nextTaskNumber`, `taskCode`, `taskNumber`) sono **opzionali** lato lettura: i `fromFirestore` usano il pattern `as Type? ?? defaultValue`, quindi le versioni vecchie dell'app continuano a funzionare senza modifiche e i documenti pre-esistenti non hanno bisogno di migrazione immediata.

---

### `teamMembers/{memberId}`

Membri della squadra (agenti e persone) con tariffe. Solo il proprietario legge e scrive.

| Campo | Tipo | Note |
|---|---|---|
| `ownerId` | String | UID del proprietario |
| `name` | String | Nome del membro |
| `kind` | String | `agent` o `person` |
| `role` | String | Ruolo (analista, dba, tester...) |
| `costRate` | Number | Costo orario interno |
| `billRate` | Number | Tariffa di vendita oraria |
| `active` | Boolean | Se `false` non compare nel dialogo "Registra ore" |
| `createdAt` | Timestamp | Data creazione |

### `projects/{projectId}/timeEntries/{entryId}`

Registro ore. Solo il proprietario del progetto legge e scrive. Vedi `docs/progetto/requisiti-costi.md`.

| Campo | Tipo | Note |
|---|---|---|
| `taskId`, `taskCode` | String | Task a cui si riferiscono le ore |
| `memberId`, `memberName` | String | Membro che ha lavorato |
| `phase` | String | Fase (Analisi, Database, ...) |
| `hours` | Number | Ore lavorate |
| `costRate`, `billRate` | Number | Tariffe congelate alla registrazione |
| `date` | Timestamp | Data della registrazione |
| `note` | String | Nota facoltativa |
| `source` | String | `manual` (app) o `squad` (workflow) |
