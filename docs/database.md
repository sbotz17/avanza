# Avanza — Schema dati (Firestore)

Ultimo aggiornamento: 2026-10-25 (T-20: collegamento automatico ai repository GitHub)

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

**Campi aggiunti dal collegamento automatico ai repository (T-20, solo aggiunte, tutti facoltativi; l'app e le versioni vecchie li ignorano e `updateProject` usa `update`, quindi non li perde):**

| Campo | Tipo | Scritto da | Note |
|---|---|---|---|
| `githubRepoId` | int | `githubWebhook` | Identificativo numerico stabile del repository su GitHub. Aggiunto al primo evento ricevuto (anche ai progetti registrati a mano); permette di riconoscere il repository anche dopo una rinomina o un trasferimento. Non viene mai sovrascritto se diverso. |
| `autoCreated` | bool | `githubWebhook` | `true` solo per i progetti creati in automatico dal collegamento. |
| `autoCreatedSource` | String | `githubWebhook` | `github-app` (GitHub App personale) o `webhook` (webhook del singolo repository): da quale canale e' arrivato l'evento che ha creato il progetto. |
| `githubUrlPrecedente` | String | `githubWebhook` | Vecchio indirizzo, conservato quando il repository viene rinominato/trasferito e `githubUrl` si aggiorna. |
| `githubArchived` | bool | `githubWebhook` | Repository archiviato (`true`) o riattivato (`false`). Il progetto resta con tutta la sua storia. |
| `githubDeleted` | bool | `githubWebhook` | Repository cancellato su GitHub: il progetto resta (ore, costi e task sono dati reali). |

I progetti creati in automatico hanno ID deterministico `gh_<id repository>` (due eventi insieme non possono crearne due) e gli stessi campi base di `crea-progetto` (nome = nome del repository, descrizione, `githubUrl`, `clientCode` di 6 caratteri, `ownerId` = admin configurato, `nextTaskNumber` = 1, date) piu' la voce `clientAccess`. Non hanno task: i task li crea solo la squadra.
Il webhook non modifica mai `updatedAt` dei progetti (la lista e' ordinata per quel campo).

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
| `copiedFrom` | String (facoltativo) | Solo per i membri creati dall'azione `copia-squadra` (T-19): id del membro originale da cui sono copiati. Non usato dall'app; serve a non copiare due volte e a riconoscere le copie per un eventuale annullamento (da decidere con Andrea). |

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

### `projects/{projectId}/taskCosts/{taskId}`

Stime, ore reali e tariffa del task. **Solo il proprietario** legge e scrive: i clienti non devono vedere i costi.
Sostituisce i campi `estimatedHours`, `actualHours`, `hourlyRate` che prima stavano nel documento `tasks` (leggibile da tutti).

| Campo | Tipo | Note |
|---|---|---|
| `estimatedHours` | Number | Ore stimate (preventivo) |
| `actualHours` | Number | Ore reali, incrementate dal registro ore |
| `hourlyRate` | Number | Tariffa oraria del task (preventivo) |

### `clientAccess/{codiceCliente}`

Codice progetto: l'ID del documento è il codice (6 caratteri). Lettura solo per ID (`get`) e solo da utenti autenticati, mai elenco.

| Campo | Tipo | Note |
|---|---|---|
| `projectId` | String | Progetto che il cliente può aprire |
| `ownerId` | String | UID del proprietario |
| `createdAt` | Timestamp | Data creazione |

### `users/{uid}`

Profilo e ruolo. Ognuno legge solo il proprio. Un nuovo utente nasce sempre `client`; il ruolo non è modificabile dai client (solo script/console).

| Campo | Tipo | Note |
|---|---|---|
| `email` | String | Email dell'utente |
| `role` | String | `admin` o `client` |
| `createdAt` | Timestamp | Data creazione |

### `users/{uid}/clientProjects/{projectId}`

Progetti collegati a un cliente tramite codice progetto. Creazione consentita solo se `code` è il codice di quel progetto (`clientAccess/{code}.projectId == projectId`).

| Campo | Tipo | Note |
|---|---|---|
| `code` | String | Codice progetto usato per il collegamento |
| `projectId` | String | Progetto collegato |
| `linkedAt` | Timestamp | Data del collegamento |

### `projects/{projectId}/tasks/{taskId}/chat/{messageId}`  (T-12)

Chat dell'admin con la squadra sul task. **Solo admin proprietario del progetto**: i clienti non leggono né scrivono (le regole del task NON si estendono alla sottocollezione).

| Campo | Tipo | Note |
|---|---|---|
| `from` | String | `admin` (scritto dall'app) oppure `squadra` (scritto solo dallo script) |
| `text` | String | 1-2000 caratteri |
| `authorUid` | String | UID di chi scrive (per `squadra`: `squadra`) |
| `authorName` | String | Nome mostrato (per l'admin: nome o email; per la squadra: membro indicato o `Squadra`), max 200 caratteri |
| `createdAt` | Timestamp | Orario del server (`serverTimestamp`) |
| `kind` | String | `domanda` (admin), `risposta` (squadra) o `stato-automatico` (squadra, riservato) |

**Accessi** (regole in `firestore.rules`):
- lettura: `isAdmin() && isProjectOwner(projectId)`;
- creazione dal client: solo `from == 'admin'`, `kind == 'domanda'`, `authorUid == request.auth.uid`, `authorName` stringa (max 200), `text` stringa di 1-2000 caratteri, `createdAt == request.time`, nessun campo oltre quelli elencati;
- nessun `update` né `delete` dal client;
- le risposte `squadra` le scrive solo l'Admin SDK (`scripts/registra-ore.mjs`, azione `rispondi`), che non passa dalle regole.

**Indici**: nessun indice composto (query con solo `orderBy('createdAt')`, indice automatico). L'app mostra la chat solo se il task non è `validated`/`released`; la regola Firestore non controlla lo stato del task (la limitazione è di interfaccia, l'accesso resta comunque riservato all'admin).
Il documento è aggiuntivo: i task esistenti e le versioni vecchie dell'app non sono toccati. Cancellando un task dall'app i messaggi restano (il client non può cancellarli).

---

### `githubCollegamento/config`  (T-20)

Configurazione del collegamento automatico. **Solo Admin SDK**: nessuna regola `match` in `firestore.rules`, quindi qualsiasi client (anche admin) e' respinto per impostazione predefinita (provato sull'emulatore con le regole attuali: 403 per non autenticato, cliente e admin, in lettura, scrittura ed elenco). La scrive solo lo script di amministrazione (workflow "Registra ore squadra", azione `collegamento`); la funzione la legge (copia in memoria di 60 secondi, quindi "spegni" ha effetto entro un minuto, senza ridistribuire).

| Campo | Tipo | Note |
|---|---|---|
| `autoCreateProjects` | bool | Interruttore. Solo il valore `true` accende la creazione automatica dei progetti. Se il documento manca o e' incompleto la creazione e' SPENTA (comportamento di prima). |
| `ownerUid` | String | uid dell'admin a cui si intestano i progetti nuovi. Mai ricavato dall'evento. All'uso la funzione verifica che `users/{uid}.role` sia `admin`. |
| `allowedOwners` | Array di String | Account GitHub (login, minuscolo) i cui repository possono dare origine a un progetto. |
| `maxNewProjectsPerDay` | int | Tetto di progetti nuovi al giorno (ora italiana), 1-50, predefinito 5. |
| `updatedAt` | Timestamp | Ultima modifica. |

### `githubCollegamento/giorno-AAAA-MM-GG`  (T-20)

Contatore dei progetti creati in automatico nel giorno (ora italiana): `progettiCreati` (int) e `updatedAt`. Serve al tetto anti-abuso; aggiornato nella stessa transazione che crea il progetto. Solo Admin SDK. Nessuna cancellazione automatica (cancellare dati si decide con Andrea).

### `githubRepos/{idRepositoryGitHub}`  (T-20)

Registro dei repository noti. **Solo Admin SDK** (come sopra). Serve a non far "risorgere" un progetto eliminato dall'app e a gestire le esclusioni.

| Campo | Tipo | Note |
|---|---|---|
| `repoId` | int | Identificativo numerico del repository (e' anche l'ID del documento). |
| `fullName` | String | `proprietario/nome` al momento della registrazione. |
| `githubUrl` | String | Indirizzo al momento della registrazione. |
| `projectId` | String | Progetto collegato. |
| `state` | String | `tracked` (ha un progetto), `excluded` (non si crea piu' da solo: progetto eliminato dall'app oppure escluso a mano), `readmitted` (esclusione tolta: al prossimo evento il progetto si ricrea e torna `tracked`). |
| `reason` | String (facoltativo) | `progetto_eliminato`, `riammesso-da-amministratore`, ... |
| `source` | String | `auto` (creato dal collegamento) o `attach` (progetto esistente agganciato). |
| `createdAt`, `updatedAt` | Timestamp | |

**Come si riconosce un progetto eliminato**: se per un repository `tracked` arriva un evento e non esiste piu' nessun progetto (ne' per identificativo ne' per indirizzo), il repository passa a `excluded` con motivo `progetto_eliminato` e NON viene ricreato. Limite noto: un progetto di cui nessun evento e' mai arrivato dopo l'attivazione non e' ancora nel registro; se viene eliminato prima del suo primo evento, al primo evento successivo ricompare. Per chiuderlo del tutto servirebbe scrivere la "lapide" dall'app al momento dell'eliminazione (richiede una regola Firestore nuova: proposta per la fase successiva).
Per riavere un progetto eliminato: azione `collegamento` con `note=riammetti` e `github_url` del repository (non cancella nulla), oppure ricrearlo a mano.

**Indici**: nessun indice nuovo (ricerche per ID, uguaglianza su un solo campo, scansione di `projects` come prima).

