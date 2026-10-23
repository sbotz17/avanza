# Registro decisioni

Decisioni prese dalla squadra al posto di Andrea e decisioni in sospeso (una voce: data, decisione, alternative, motivo, stato).
Andrea può correggere qualsiasi decisione in qualsiasi momento.

## Decisioni in sospeso (aspettano Andrea)

Tutte queste azioni la squadra NON può farle da sola (servono account, soldi o impostazioni di GitHub e Google). La squadra ha preparato il resto.
I nomi esatti di segreti, variabili e ambienti si confermano con i workflow definitivi in `.github/workflows/`.

| # | Cosa serve | Perché | Stato |
|---|---|---|---|
| 1 | Creare il progetto Firebase di test `avanza-test` (piano Blaze, Auth con email e password, Firestore `(default)` in `eur3`) | Oggi le anteprime e le prove usano gli stessi dati della produzione | In sospeso |
| 2 | Service account del progetto di test e segreto GitHub `FIREBASE_SERVICE_ACCOUNT_TEST` | Per pubblicare e provare sull'ambiente di test | In sospeso |
| 3 | Bucket Google Cloud Storage per i backup, con blocco di conservazione (nessuno può cancellare), e relativi segreti GitHub (`GCS_BUCKET`, `GCS_CHIAVE_JSON` come nei modelli) | Firestore non ha backup automatici: la regola d'oro dei dati richiede backup verificato prima di ogni modifica ai dati | In sospeso |
| 4 | Protezione dei rami `main` e `staging` su GitHub (pull request obbligatoria, controlli obbligatori, nessuna scrittura diretta su `main`) | Gli agenti non possono toccare impostazioni del repository | In sospeso |
| 5 | File `CODEOWNERS` e opzione "Require review from Code Owners" | Le regole della squadra, la CI, le regole di sicurezza e `firebase.json` le modifica solo Andrea | In sospeso |
| 6 | Ambienti GitHub: `produzione-sviluppi` (revisore obbligatorio: Andrea), `produzione-correzioni` (nessun revisore), `avvisi`, `produzione` | Per la validazione dei nuovi sviluppi prima della produzione | In sospeso |
| 7 | Segreti per gli avvisi WhatsApp (`AVVISI_URL`, `AVVISI_TOKEN`, `AVVISI_NUMERO` come nei modelli) | Per avvisare Andrea di sviluppi da validare, rilasci e segnalazioni | In sospeso |
| 8 | Variabile GitHub `BLOCCO_SQUADRA` (e `SQUADRA_CI_ATTIVA` = `si` solo a configurazione finita) | Interruttore con cui Andrea ferma promozioni, rilasci e controlli | In sospeso |
| 9 | Tariffe di costo e di vendita dei 12 membri della squadra (oggi a zero) | Senza tariffe i costi e il margine risultano zero | In sospeso |
| 10 | Eliminare l'utente di prova e i segreti `TEST_USER_EMAIL` e `TEST_USER_PASSWORD` (non servono più) | Pulizia | In sospeso |
| 11 | Eliminare il database Firestore vuoto `avanza` (non usato) | Pulizia | In sospeso |

## Decisioni prese

### 2026-10-23 — Database Firestore `(default)` in regione `eur3`
- **Decisione**: creato il database `(default)` in `eur3` (Europa, multi-regione) con regole e indici da `firestore.rules` e `firestore.indexes.json`, tramite il workflow "Setup Firestore".
- **Alternative scartate**: `us-central1` (stessa regione delle funzioni ma dati fuori dall'UE); riusare il database `avanza` creato a mano (app e funzione usano `(default)`: un database non si rinomina).
- **Motivo**: dati in UE (GDPR); l'app e la funzione cercano `(default)`. La regione è definitiva.

### 2026-10-23 — Cloud Function pubblicata con `gcloud` invece di `firebase-tools`
- **Decisione**: il deploy di `githubWebhook` usa `gcloud functions deploy --gen2 --allow-unauthenticated` (Node.js 22).
- **Alternative scartate**: `firebase-tools`, che per le nuove funzioni HTTPS pretende il ruolo "Cloud Functions Admin"; assegnare quel ruolo al service account.
- **Motivo**: restare con i permessi minimi già assegnati. L'endpoint è pubblico perché GitHub deve poterlo chiamare; la firma HMAC dei messaggi lo protegge.

### 2026-10-23 — Ruoli admin e cliente; codice progetto legato all'utente
- **Decisione**: un solo login; il ruolo sta in `users/{uid}`; l'admin si assegna solo da script/console; il cliente si registra e collega il codice progetto al proprio account al primo accesso (`users/{uid}/clientProjects`); nessun accesso anonimo.
- **Alternative scartate**: due pulsanti di accesso (confondevano); accesso anonimo con il solo codice (chiunque poteva elencare i progetti e leggere i costi).
- **Motivo**: richiesta di Andrea; le regole di Firestore diventano l'unica difesa vera.
- **Limiti noti**: codice di 6 caratteri indovinabile da un utente registrato (rischio basso); l'admin non può ancora scollegare un cliente.

### 2026-10-23 — Costi e produttività: ore dichiarate, tariffa di costo e di vendita per membro
- **Decisione**: registro unico di agenti e persone con tariffe; le ore le dichiara la squadra a fine fase (non sono tempi misurati); i costi stanno in `taskCosts` (solo admin); produttività = ore stimate attribuite / ore reali, per task.
- **Alternative scartate**: tempo misurato dalle sessioni (approssimato); una sola tariffa per task; produttività per fase (non ci sono stime per fase).
- **Motivo**: scelte di Andrea (2026-10-23). Dettagli in `docs/progetto/requisiti-costi.md`.

### 2026-10-23 — Sito senza service worker e cache `no-cache`
- **Decisione**: build web con `--pwa-strategy=none` e `Cache-Control: no-cache` per js, css, html, json in `firebase.json`.
- **Alternative scartate**: tenere il service worker e chiedere agli utenti di pulire i dati del sito a ogni rilascio.
- **Motivo**: Andrea vedeva ancora la versione vecchia dopo ogni rilascio (cache di un anno sui file con nome fisso e service worker); in incognito vedeva quella nuova.
- **Nota**: dopo la pubblicazione, chi aveva la copia vecchia deve pulire una volta i dati del sito. Va ancora verificato con `verifica-sito.yml` che l'intestazione `no-cache` sia davvero applicata (in un controllo il file principale risultava ancora con `max-age=31536000`).

### 2026-10-23 — Progetto di prova eliminato e test E2E sul progetto reale
- **Decisione**: eliminato il progetto di prova (azione `elimina-prova`, solo dati di prova, su richiesta di Andrea). Il test del webhook crea un task temporaneo `T-9xxx` nel progetto reale e lo cancella a fine prova.
- **Alternative scartate**: tenere un progetto di prova con lo stesso indirizzo GitHub (si sarebbe sovrapposto al progetto reale nel webhook).
- **Motivo**: Avanza e Volty sono ora progetti reali collegati ai loro repository.

### 2026-10-23 — Allineamento alla squadra: ambienti `staging`/`main` e regole di protezione
- **Decisione**: Avanza adotta le stesse regole di Volty: un repository, due rami (`staging` = test su progetto Firebase separato `avanza-test`, `main` = produzione `avanza-b62d7`); lavoro su rami `fix/`, `hotfix/`, `feature/` con pull request verso `staging`; gli agenti non scrivono né aprono pull request verso `main`; promozione controllata e approvazione di Andrea per i nuovi sviluppi; backup verificato prima di ogni modifica ai dati; guardia automatica e zone protette.
- **Alternative scartate**: continuare con "pieni poteri su `main`" (Andrea li aveva dati per Avanza durante la messa in produzione); due repository separati (non serve per un progetto solo web di queste dimensioni).
- **Motivo**: richiesta di Andrea ("applica tutte le regole di protezione tra produzione e ambiente di test per tutti i progetti" e "allineati con la squadra").
- **Stato**: kit copiato da Volty e adattato a Firebase (CLAUDE.md, agenti, comandi, documenti); workflow e script di controllo in preparazione da parte di un altro agente; finché non esiste `avanza-test` e non sono configurati GitHub e Google (decisioni in sospeso 1-8) le protezioni sono solo documentate e in parte attive.
