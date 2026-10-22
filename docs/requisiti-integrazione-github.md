# Requisiti: Integrazione automatica GitHub → Avanza

**Versione**: 1.0 — 2026-10-22
**Stato**: Bozza — in attesa di revisione

---

## Obiettivo generale

Quando la squadra di sviluppo lavora su un repository GitHub collegato a un progetto Avanza, i task corrispondenti si aggiornano automaticamente senza intervento manuale. L'aggiornamento avviene via webhook GitHub → Firebase Cloud Function → Firestore.

**A chi serve**: Andrea (product owner) vede lo stato reale del lavoro in tempo reale senza dover interrogare la squadra; il cliente vede l'avanzamento aggiornato.

**Fuori ambito globale**:
- Non si crea né si cancella nessun task automaticamente (solo aggiornamenti)
- Non si sincronizzano le ore lavorate (rimangono manuali)
- Non si gestiscono commit diretti su `main`/`staging` senza PR
- Non si integrano piattaforme diverse da GitHub

---

## 1 — Mapping repo → progetto Avanza

### Obiettivo
Collegare un repository GitHub a un progetto Avanza in modo che gli eventi del repo aggiornino i task giusti.

### Come funziona oggi
Il modello `Project` ha già il campo `githubUrl` (es. `https://github.com/owner/repo`). Il campo viene salvato ma non usato per automazioni.

### Cosa cambia
La Cloud Function riceve un evento webhook da GitHub, estrae il campo `repository.html_url` dal payload e cerca in Firestore il progetto con `githubUrl` uguale a quell'URL (confronto case-insensitive, trailing slash ignorato).

Se nessun progetto corrisponde, l'evento viene ignorato silenziosamente (log di warning su Cloud Logging, nessun errore HTTP).

### Criteri di accettazione

**CA-1.1**
Dato un progetto Avanza con `githubUrl = "https://github.com/owner/volty-flutter"`,
Quando GitHub invia un evento webhook dal repository `volty-flutter`,
Allora la Cloud Function identifica correttamente quel progetto (e solo quello).

**CA-1.2**
Dato un evento webhook da un repository non collegato ad alcun progetto Avanza,
Quando la Cloud Function riceve l'evento,
Allora risponde HTTP 200 senza modificare nulla e scrive un warning nel log.

**CA-1.3**
Dato un progetto con `githubUrl` vuoto o non valido,
Quando arriva un evento,
Allora il progetto non partecipa alla ricerca e non viene modificato.

### Fuori ambito
- Collegare più repository allo stesso progetto (un progetto = un repo)
- Configurazione webhook per singolo branch o per singolo utente GitHub

---

## 2 — Mapping branch/PR → task (convenzione di naming)

### Obiettivo
Identificare automaticamente a quale task Avanza si riferisce un branch o una PR di GitHub, senza configurazione manuale per ogni task.

### Decisione: codice task breve (taskCode)

Ogni task Avanza riceve un **codice breve immutabile**: `T-<N>` dove N è un intero sequenziale per progetto (1, 2, 3…). Il codice viene assegnato alla creazione del task e non cambia mai, nemmeno se il task viene riordinato.

**Esempi**: `T-1`, `T-12`, `T-103`

Il codice è mostrato in modo prominente nell'UI del task (vicino al titolo, copyable con un tap/click).

Questo richiede l'aggiunta del campo `taskCode` (stringa, es. `"T-1"`) e `taskNumber` (intero, usato per generare il codice) al modello `Task` in Firestore. Si tratta di un'aggiunta non distruttiva.

### Convenzione di naming (per Claude Code e per la squadra)

Il codice task va incluso nel **nome del branch** OPPURE nel **titolo della PR**:

**Nel nome del branch** (preferito):
```
feature/T-1-descrizione-breve
fix/T-5-correzione-login
hotfix/T-12-blocco-checkout
```
Pattern riconosciuto: `T-\d+` ovunque nel nome del branch (case-insensitive).

**Nel titolo della PR** (alternativa se il branch non ha il codice):
```
[T-3] Aggiungi sincronizzazione GitHub
feat(T-7): redesign pagina progetto
```
Pattern riconosciuto: `T-\d+` ovunque nel titolo (case-insensitive).

**Priorità**: se entrambi contengono un codice task, prevale il branch name.

Se non si trova nessun codice task nel branch né nel titolo, l'evento viene ignorato (log di info).

### Criteri di accettazione

**CA-2.1**
Dato un branch chiamato `feature/T-3-autosync-github`,
Quando la Cloud Function riceve un evento da quel branch,
Allora identifica correttamente il task con `taskCode = "T-3"` nel progetto collegato.

**CA-2.2**
Dato un branch senza codice task (es. `fix/typo-readme`) ma una PR con titolo `[T-7] Fix typo`,
Quando arriva l'evento PR,
Allora la Cloud Function usa `T-7` dal titolo della PR.

**CA-2.3**
Dato un task appena creato,
Quando viene salvato in Firestore,
Allora il campo `taskCode` è `"T-<N>"` dove N è il prossimo intero disponibile per quel progetto (sequenziale, senza buchi dalla creazione; buchi da eventuali cancellazioni sono accettabili).

**CA-2.4**
Dato un task esistente con `taskCode = "T-2"` che viene riordinato nell'UI (campo `order` cambia),
Quando il task viene salvato,
Allora `taskCode` rimane invariato (`"T-2"`).

**CA-2.5**
Dato un evento con un codice task non presente nel progetto (es. `T-99` e il progetto ha solo `T-1..T-5`),
Quando la Cloud Function riceve l'evento,
Allora risponde HTTP 200 senza modificare nulla e scrive un warning nel log.

### Fuori ambito
- Riconoscimento di issue number GitHub (es. `#123`)
- Riconoscimento basato sul titolo del branch in linguaggio naturale
- Collegamento di un branch a più task contemporaneamente

---

## 3 — Trigger eventi: quali eventi GitHub aggiornano cosa

### Tabella degli eventi rilevanti

| Evento GitHub | Condizione | Azione in Avanza |
|---|---|---|
| `push` | Branch nuovo (non esisteva) | Task → `active`; fase Analisi → `active` se era `pending` |
| `push` | Branch esistente, commit aggiuntivi | Aggiunge nota automatica con hash commit e messaggio (solo se la nota non esiste già per quel commit) |
| `pull_request` / `opened` | PR aperta verso qualsiasi base | Aggiunge nota automatica "PR aperta: #N — `<titolo>`"; fase in corso (vedi §4) → nessun cambio di status automatico |
| `pull_request` / `merged` | PR mergeata | Task → `review`; fase Frontend → `done` se era `active`; aggiunge nota "PR #N mergeata in `<base>`" |
| `pull_request` / `closed` (non merged) | PR chiusa senza merge | Aggiunge nota "PR #N chiusa senza merge"; nessun cambio di status |
| `pull_request` / `review_requested` | — | Ignorato |
| `pull_request_review` / `submitted` con state `approved` | — | Task → `validated`; fase Validazione → `done` |

### Criteri di accettazione

**CA-3.1**
Dato un task `T-4` in status `backlog`,
Quando viene fatto push di un branch `feature/T-4-nuova-feature` (branch nuovo),
Allora il task passa a status `active` e la fase Analisi diventa `active`.

**CA-3.2**
Dato un task `T-4` in status `active`,
Quando viene aperta una PR con titolo `[T-4] Implementazione feature`,
Allora viene aggiunta una nota di tipo `info` con testo "PR aperta: #N — Implementazione feature"; lo status del task NON cambia.

**CA-3.3**
Dato un task `T-4` in status `active`,
Quando la PR viene mergeata nel branch `staging` o `main`,
Allora il task passa a status `review` e viene aggiunta una nota di tipo `ok` con testo "PR #N mergeata in staging".

**CA-3.4**
Dato un task `T-4` in status `review`,
Quando un reviewer approva la PR su GitHub,
Allora il task passa a status `validated` e la fase Validazione diventa `done`.

**CA-3.5**
Dato un task già in status `released`,
Quando arriva qualsiasi evento GitHub,
Allora il task NON viene modificato (status `released` è terminale).

**CA-3.6**
Dato un evento GitHub di tipo non previsto in tabella (es. `issues`, `star`, `fork`),
Quando la Cloud Function lo riceve,
Allora risponde HTTP 200 senza modificare nulla.

### Fuori ambito
- Aggiornamento automatico delle ore effettive (`actualHours`)
- Aggiornamento automatico delle fasi Analisi, Database, Backend, Design, Test in base al contenuto dei commit
- Gestione di eventi da GitHub Actions (job completato, test superato, ecc.) — da valutare in futuro

---

## 4 — Aggiornamenti automatici al task

### Campi che possono cambiare automaticamente

| Campo | Tipo di modifica | Regola |
|---|---|---|
| `status` | Solo avanzamento | Si può solo avanzare lungo la sequenza: `backlog → active → review → validated → released`. Mai retrocedere automaticamente. |
| `phases[N].status` | Solo avanzamento | Si può solo avanzare: `pending → active → done`. Mai tornare indietro automaticamente. |
| `notes` | Aggiunta in coda | Le note automatiche si aggiungono in fondo; le note manuali non vengono mai toccate. |
| `updatedAt` | Aggiornamento timestamp | Ogni volta che la Cloud Function modifica il task. |

### Campi che non cambiano mai automaticamente

`title`, `description`, `clientRequest`, `estimatedHours`, `actualHours`, `hourlyRate`, `order`, `taskCode`, `taskNumber`

### Formato delle note automatiche

Le note aggiunte dalla Cloud Function hanno il prefisso `[gh]` per distinguerle da quelle manuali:

```
tipo: "info" | "ok" | "blk"
testo: "[gh] <messaggio>"
```

Esempi:
- `[gh] Branch feature/T-4-autosync creato`
- `[gh] PR #42 aperta: "Integrazione GitHub"`
- `[gh] PR #42 mergeata in staging`
- `[gh] PR #42 chiusa senza merge`
- `[gh] PR #42 approvata da reviewer`

### Idempotenza

Ogni operazione è idempotente: se la Cloud Function riceve lo stesso evento due volte (GitHub fa retry), il secondo invio non duplica note né cambia lo status già aggiornato.

**Strategia**: la nota automatica include un identificatore univoco dell'evento GitHub (es. hash del commit o ID della PR + tipo evento) come campo nascosto, oppure si verifica l'assenza di una nota con lo stesso testo prima di aggiungerla.

### Criteri di accettazione

**CA-4.1**
Dato un task con status `active`,
Quando la Cloud Function elabora un evento che mapperebbe a `active` (es. secondo push),
Allora il task rimane `active` (nessun cambio, nessun errore).

**CA-4.2**
Dato un task con status `review`,
Quando arriva un evento push (che normalmente porta a `active`),
Allora il task NON retrocede a `active` e rimane `review`.

**CA-4.3**
Dato un evento GitHub ricevuto due volte (retry),
Quando la Cloud Function elabora il secondo invio,
Allora il task non viene modificato la seconda volta (nessuna nota duplicata, nessun cambio di status).

**CA-4.4**
Dato un task con note manuali esistenti,
Quando la Cloud Function aggiunge una nota automatica,
Allora le note manuali rimangono intatte e la nuova nota è aggiunta in coda.

---

## 5 — Architettura proposta

### Componenti

```
GitHub Repository
    │
    │  webhook HTTPS POST
    ▼
Firebase Cloud Function: "githubWebhook"
    │  (HTTP trigger, URL pubblico)
    │  1. Verifica firma HMAC-SHA256 (secret condiviso)
    │  2. Estrae tipo evento e payload
    │  3. Cerca progetto per githubUrl
    │  4. Estrae taskCode da branch/PR
    │  5. Cerca task per taskCode
    │  6. Applica la logica di aggiornamento
    │  7. Scrive in Firestore (transazione atomica)
    ▼
Firestore
    /projects/{projectId}/tasks/{taskId}
```

### Cloud Function: dettaglio

**Runtime**: Node.js 20 (standard Firebase)
**Trigger**: HTTP (onRequest)
**URL**: generato da Firebase al deploy (es. `https://us-central1-avanza-app.cloudfunctions.net/githubWebhook`)
**Metodo accettato**: solo POST
**Autenticazione**: firma HMAC-SHA256 sull'header `X-Hub-Signature-256` (secret salvato in Firebase environment config, mai nel codice)

**Flusso interno**:
1. Verifica firma → se non valida, risponde 401
2. Legge `X-GitHub-Event` header
3. Se evento non in lista (§3), risponde 200 senza fare nulla
4. Estrae `repository.html_url` dal payload → cerca progetto in Firestore
5. Estrae `taskCode` da branch name o PR title → cerca task nel progetto
6. Costruisce l'aggiornamento (status, fasi, note) in base all'evento
7. Esegue un update in transazione Firestore (atomic)
8. Risponde 200

**Errori**:
- Firma non valida → 401
- Progetto non trovato → 200 (log warning)
- Task non trovato → 200 (log warning)
- Errore Firestore → 500 (GitHub riproverà)

### Configurazione webhook su GitHub

Per ogni repository da collegare, l'admin configura su GitHub:
- **Payload URL**: URL della Cloud Function
- **Content type**: `application/json`
- **Secret**: il secret condiviso (lo stesso usato dalla Cloud Function per verificare la firma)
- **Events**: `push`, `pull_request`, `pull_request_review`

Questa configurazione si fa una volta per repository, non per ogni task.

### Aggiornamento Avanza UI

L'app Flutter già usa `Stream<List<Task>>` da Firestore: l'aggiornamento è visibile in tempo reale senza modifiche all'app client, grazie alla natura real-time di Firestore.

### Dove vive il codice della Cloud Function

`functions/src/githubWebhook.ts` (o `.js`)
Si aggiunge `"functions"` alla configurazione in `firebase.json`.

### Criteri di accettazione

**CA-5.1**
Dato un evento GitHub con firma HMAC non valida (o assente),
Quando la Cloud Function lo riceve,
Allora risponde HTTP 401 e non modifica nulla in Firestore.

**CA-5.2**
Dato un evento GitHub valido e firmato,
Quando la Cloud Function lo elabora correttamente,
Allora risponde HTTP 200 entro 5 secondi.

**CA-5.3**
Dato un aggiornamento scritto in Firestore dalla Cloud Function,
Quando l'app Avanza è aperta su quel progetto,
Allora il task aggiornato appare entro 2 secondi (real-time stream).

**CA-5.4**
Dato il secret webhook mai nel codice sorgente,
Quando si ispeziona il repository Git,
Allora il secret non è presente in nessun file versionato.

---

## 6 — Modifiche al modello dati esistente

Tutte le modifiche sono additive (nessun campo eliminato o rinominato).

### Nuovi campi su Task

| Campo | Tipo | Valore default | Note |
|---|---|---|---|
| `taskNumber` | `int` | sequenziale per progetto | Immutabile dopo creazione; usato per generare `taskCode` |
| `taskCode` | `String` | `"T-<taskNumber>"` | Es. `"T-1"`, `"T-12"`; mostrato nell'UI |
| `githubBranch` | `String` (nullable) | `null` | Ultimo branch GitHub associato al task |
| `githubPrNumber` | `int` (nullable) | `null` | Numero dell'ultima PR associata |

### Compatibilità con task esistenti

I task creati prima di questa integrazione non hanno `taskCode`. La Cloud Function li ignora (non può associarli a branch/PR). L'admin può assegnare manualmente `taskCode` ai task esistenti dall'UI Avanza. Per i nuovi task il codice è assegnato automaticamente.

### Indice Firestore necessario

Query: `collection('projects/{id}/tasks').where('taskCode', '==', 'T-N').limit(1)`

Indice singolo su `taskCode` all'interno della subcollection `tasks` (Firestore crea gli indici su campi singoli automaticamente; nessun indice composto necessario).

---

## 7 — Sicurezza

- Il secret del webhook è salvato in Firebase environment config (o Secret Manager), mai in Git
- La Cloud Function non ha accesso a Firestore Authentication: opera con le credenziali del service account Firebase Admin SDK (accesso completo a Firestore, solo lato server)
- Le Firestore Security Rules per il client (app Flutter) non cambiano: l'accesso dalla Cloud Function bypassa le rules (Admin SDK)
- Nessun dato dell'utente GitHub (email, token) viene salvato in Firestore
- Il contenuto dei commit (messaggi, diff) è considerato dato non fidato: non viene salvato né interpretato come istruzione; si salva solo l'hash breve del commit e il messaggio (max 100 caratteri, troncato)

---

## 8 — Domande aperte

1. **Webhook secret**: chi lo genera e dove viene salvato fuori dal codice? (Proposta: Firebase Secret Manager, gestito da Andrea)
2. **Task per i vecchi task senza taskCode**: si vuole un'utilità di migrazione che assegni taskCode a tutti i task esistenti in ordine di `createdAt`? (Decisione presa: opzionale, l'admin lo fa dall'UI se serve; i vecchi task vengono semplicemente ignorati dalla Cloud Function)
3. **Notifica all'admin**: quando la Cloud Function aggiorna un task, si vuole una notifica push/email ad Andrea o al cliente? (Non incluso in questa iterazione — da valutare)
4. **Fase "rilasciato"**: quando un task passa a `released`? Oggi non c'è un evento GitHub che mappa naturalmente su `released`. Proposta: rimane manuale, oppure si aggiunge un tag/release GitHub come trigger. (Decisione presa: rimane manuale per ora)
5. **Multi-branch per task**: se si aprono più PR per lo stesso task (es. fix e feature separati), i dati si sovrascrivono. Accettabile nella prima versione? (Decisione presa: sì, si tiene solo l'ultimo evento; la nota viene aggiunta comunque)

---

## 9 — Decisioni prese (alternative scartate)

| Decisione | Alternativa scartata | Motivo |
|---|---|---|
| `taskCode` come campo dedicato (`T-N`) | Usare il doc ID Firestore (stringa casuale 20 char) | I doc ID non sono leggibili né usabili in un nome branch; Claude Code avrebbe bisogno di copiare stringhe lunghe |
| `taskCode` come campo dedicato | Usare il campo `order` esistente come riferimento | `order` è un ordinamento UI, può cambiare; non è stabile come identificatore |
| Aggiornamento solo in avanzamento (mai retrocesso automaticamente) | Permettere retrocessione automatica (es. PR chiusa → task torna a active) | Troppo rischioso: una PR chiusa per errore non deve cancellare il lavoro segnalato; le retrocessioni restano manuali |
| Note con prefisso `[gh]` | Note automatiche in un campo separato (`githubEvents[]`) | Aggiunge complessità al modello; le note esistenti sono già visualizzate bene nell'UI; il prefisso distingue visivamente |
| Idempotenza per contenuto nota | Usare un ID evento GitHub come campo nascosto | Il contenuto è più semplice da verificare senza aggiungere struttura; l'ID evento GitHub potrebbe cambiare tra retry |
| Cloud Function HTTP (Firebase) | GitHub Action che scrive direttamente su Firestore | Una GitHub Action richiederebbe credenziali Firebase nel repository GitHub; più rischiosa e più difficile da mantenere |
| Aggiornamento `actualHours` manuale | Calcolare ore da timestamp commit | I commit non riflettono il tempo di lavoro reale; meglio non introdurre dati imprecisi |

---

## 10 — Agenti da coinvolgere

| Agente | Motivo |
|---|---|
| **architetto** | Struttura della Cloud Function, configurazione Firebase Functions, indici Firestore |
| **dba** | Aggiunta campi `taskCode`, `taskNumber`, `githubBranch`, `githubPrNumber`; verifica regole Firestore |
| **sviluppatore-backend** | Implementazione Cloud Function (`githubWebhook`), logica di mapping, scrittura Firestore |
| **sviluppatore-frontend** | Aggiornamento UI per mostrare `taskCode` in modo prominente; eventuale indicatore "ultima attività GitHub" nel task |
| **tester** | Verifica criteri di accettazione con payload GitHub simulati |
| **validatore** | Approvazione finale prima del deploy |
| **redattore-manuale** | Documentazione della convenzione di naming per Claude Code e per la squadra |
