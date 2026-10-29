# Validazione indipendente dell'audit-completa del 28/10/2026 (PR #36, solo documentazione)

- **Validatore**: agente `validatore`, 28/10/2026. Ramo `docs/audit-completa-2026-10-28` (PR #36 verso `staging`).
- **Classificazione**: la PR #36 e **documentazione** (nessun codice, nessuna regola, nessun workflow). Non e una correzione e non porta nulla in produzione da sola. La promozione vera e la PR #27, che questa validazione NON approva.

## ESITO PER LA PR #36: APPROVATO (documentazione)

### 1. Numeri riprodotti di persona
| Dichiarato | Mio risultato |
|---|---|
| 137/137 prove delle regole (`rules_audit.py`) | **Riprodotto**: emulatore Firestore, regole del ramo, `TOTALE prove: 137, difformi dall'atteso: 0` |
| 10/10 mutazioni individuate (`mutate.py`) | **Riprodotto**: M1..M10 tutte "INDIVIDUATA" (1-4 prove rosse ciascuna) |
| Funzioni 326/326 test | **Riprodotto** (`npm test` in `functions/`, 12 suite) in memoria. Sull'emulatore Firestore: non rifatto |
| `controlla-regole.py` | **REGOLE OK** |
| Regole diverse da `main`: una sola aggiunta (chat, 20 righe) | **Confermato**: `git diff origin/main origin/staging -- firestore.rules` = 20 righe aggiunte (blocco chat), nessuna rimossa; `firestore.indexes.json`: nessuna modifica |
| `main` senza tag `ultimo-rilascio-ok` | `git tag` locale vuoto e `gh api .../tags` senza risultati: **coerente**. Il passo di ritorno del workflow conferma che senza tag il ritorno non e disponibile |

Nota: `mutate.py` e `common.mjs` hanno percorsi della sessione di prova scritti nel file (dichiarato nel README); per riprodurli ho adattato i percorsi in copie fuori dal repository.

### 2. Aree 1-4 contro i criteri di accettazione
- Requisiti 1, 3, 4 (progetti/T-N, ruoli e accessi, costi solo admin), 5 (sessione, F5), 10 (ricorda email) e 11 (chat T-12): i criteri sono coperti dalle prove del report (A1-A8, C1-C8, N1-N4, R1, P1-P14, S1-S6, X1) e dalle 137 regole. Per il requisito 10 i criteri "togli la casella", "accesso fallito non salva" sono nei test Flutter (`test/remember_email_test.dart`), non nella prova browser: coperti, anche se per altra via. "Spazio locale non disponibile": non l'ho trovato nominato nel report, **non verificato da me**.
- Requisito 6 (nessuna versione vecchia dopo un rilascio): coperto solo dalla build locale (service worker vuoto); le intestazioni reali dell'hosting non sono state provate dall'audit (dichiarato) ma lo smoke test del rilascio le controlla.
- Area 4 (GitHub): **"SUPERATA" va letta come "superata a livello di codice, test ed emulatore"**, come il report scrive. I criteri di accettazione di `requisiti-collegamento.md` si verificano per definizione sulla versione di test con un repository di prova e GitHub reale, e quel documento dice ancora "nessun criterio verificato" (sez. Accettazione). L'audit non li ha chiusi, e lo dichiara onestamente. Non e un motivo di rifiuto della PR di documentazione, ma l'accettazione di T-20 resta aperta e non va data per fatta.

### 3. Area 5 "BLOCCATA"
Dichiarata onestamente. Verificato per lettura di `rilascio-produzione.yml` e `configurazioni-da-fare.md` sez. 7:
1. Backup/IDENTICO: **vero** che con `PRODUZIONE_CONTROLLI_COMPLETI` diverso da `true` i passi di backup e confronto sono saltati (righe 255, 266, 318) e il rilascio parte solo con avviso.
2. Tag assente: **vero**; il passo di ritorno stampa "ritorno automatico non disponibile", e il tag viene scritto solo dopo uno smoke test riuscito (riga 329-334).
3. Ambiente `produzione`/variabili non leggibili: non ricontrollato (il proxy blocca; non verificato).
4. `SQUADRA_CI_ATTIVA` gia `si`: **plausibile** (il job `pr` di `promozione.yml` gira solo con `si`, riga 38), ma e dedotto, non letto; **contrasta** con il piano sez. 7 punto 4 ("resta no"). Non verificato.
5. Regole da pubblicare dopo: **vero** (le regole non fanno parte del rilascio).
I cinque punti sono veri o plausibili e non sono difetti del codice. Il gate della promozione resta CHIUSO, come il report afferma.

### 4. Contenuto del diff PR #36
19 file, **tutti sotto `docs/`**: nessun codice dell'app, nessuna regola, nessun workflow, nessun file di configurazione. Scansione delle righe aggiunte per chiavi private, token (ghp_, github_pat_, xox, AKIA, sk-), JSON di service account: nessun segreto. Gli unici "AIza" sono menzioni nel testo del report (non valori). Gli script di prova usano token finti non firmati dell'emulatore e `demo-avanza`; nessuna credenziale. Una nota di forma: `audit-2026-10-28.md` e `audit-completa.md` sono identici (copia datata dichiarata). I percorsi assoluti della sessione dentro gli script sono dichiarati nel README.

### 5. Rischio "permesso negato" sul secondo segreto: ANALISI
Letti `functions/src/lib/authenticate.ts`, `secrets.ts`, `githubWebhook.ts` e `.claude/scripts/smoke-produzione.sh`.
- Lo smoke test invia una POST con firma **presente ma sbagliata**: la funzione legge prima il segreto storico (esiste in produzione), poi `getApp()`.
- `createSecretReader` trasforma in "assente" (null) solo i codici gRPC 5 (NOT_FOUND) e 9 (FAILED_PRECONDITION). Qualsiasi altro errore, **compreso 7 PERMISSION_DENIED**, viene rilanciato; `authenticateWebhook` lo converte in **HTTP 500** (`segreto_app_non_disponibile`); lo smoke test si aspetta 401 e **fallisce** (8 tentativi da 15 s, poi il job fallisce).
- **Segreto assente e service account CON ruolo `secretAccessor` a livello di progetto**: Secret Manager risponde NOT_FOUND, quindi 401: smoke OK.
- **Segreto assente e service account SENZA accesso a livello di progetto (solo permesso su singoli segreti, p.es. solo su `GITHUB_WEBHOOK_SECRET`)**: Secret Manager, per non rivelare l'esistenza dei segreti, tende a rispondere PERMISSION_DENIED (non NOT_FOUND) per un segreto inesistente. In quel caso la risposta sarebbe **500** anche con segreto "assente". Questo e il caso reale piu probabile da guardare, e **non e provato da nessuno** (non ho accesso a Google). Lo escludo solo come non verificato: e un comportamento della piattaforma che ricordo ma non ho potuto confermare qui.
- Conseguenza al primo rilascio: lo smoke test fallisce, **non c'e tag quindi nessun ritorno automatico**: il nuovo sito e la nuova funzione restano pubblicati (le richieste GitHub vere con firma storica continuano a funzionare; solo le richieste con firma errata danno 500 invece di 401).
- Il codice non va cambiato in questa PR (e documentazione). Se la verifica IAM mostra il rischio, la scelta e del Coordinatore con lo sviluppatore-backend (tradurre il codice 7 del solo segreto della App in "assente" sarebbe una modifica di sicurezza: richiede seconda lettura) oppure dare/verificare l'accesso prima del rilascio.

## Rischi per la PRIMA promozione che il Coordinatore deve chiudere (nell'ordine)
1. **Secondo segreto / IAM (smoke test)**: prima del rilascio verificare con `gcloud projects get-iam-policy avanza-b62d7` che `firebase-adminsdk-fbsvc@avanza-b62d7.iam.gserviceaccount.com` abbia `roles/secretmanager.secretAccessor` a livello di progetto (allora assente = 401), oppure creare `GITHUB_APP_WEBHOOK_SECRET` con accesso per quel service account PRIMA del rilascio (Parte A di `configurazioni-da-fare.md` sez. 9). Se non si riesce a verificare: trattarlo come rischio aperto e annotarlo nel registro.
2. **Nessun ritorno automatico**: creare il tag `ultimo-rilascio-ok` su `4e66a0e` (decisione/azione di Andrea, il proxy della sessione lo blocca) oppure accettare in modo esplicito, nel registro, il ritorno a mano.
3. **Backup**: finche `BUCKET_BACKUP_FIRESTORE` non e verificato e `PRODUZIONE_CONTROLLI_COMPLETI=true`, il rilascio parte senza backup ne prova di ripristino e il Setup Firestore pubblica le regole senza backup. Va chiuso prima (regola d'oro dei dati).
4. **Promozione automatica gia accesa**: se `SQUADRA_CI_ATTIVA=si` (dedotto), dopo l'unione ogni push su `staging` puo accodare un secondo rilascio. Allineare lo stato al piano (spenta fino al primo rilascio riuscito) e leggerlo davvero.
5. **Ordine regole/codice**: tra l'unione e il Setup Firestore la chat dell'admin non funziona (degrada in modo pulito, provato dal tester). Eseguire il Setup subito dopo, in fascia a basso traffico.
6. **Ambiente `produzione`** limitato al ramo `main` con revisore solo per il primo salto: non verificato da nessuno.
7. **Contatori `nextTaskNumber` in produzione (O-2)**: se sono stati azzerati in passato nascono T-N duplicati. Controllo in sola lettura prima del rilascio; qualsiasi correzione dei dati e di Andrea.
8. **Dopo il rilascio**: `e2e-webhook.yml` e `verifica-sito.yml`; accettazione indipendente dell'`analista` sul sito di TEST reale (login con Auth reale, indici reali, intestazioni di cache, funzione di test) che l'audit non ha potuto fare: senza, i criteri di accettazione restano "non verificato per la parte con servizi reali" e vanno motivati nel registro prima di rilasciare.
9. Difetti B-1 (`pubspec.lock` non allineato: build non riproducibili), B-2 (`.claude/worktrees` non in `.gitignore`), B-3, B-4 e decisioni O-1, O-3: non bloccanti, da aprire nel flusso ritorni.

## Cosa NON ho verificato
- Qualsiasi servizio reale: GitHub (variabili, ambienti, segreti), Google Cloud/IAM/Secret Manager, sito di test e produzione. Il comportamento reale di Secret Manager (NOT_FOUND o PERMISSION_DENIED per un segreto inesistente senza accesso di progetto) e la mia memoria della piattaforma, non una prova.
- Le prove nel browser (46) con Playwright: non rieseguite (richiedono build dell'app con collegamento agli emulatori e Chromium); mi baso sul report e sugli script letti. Rieseguite solo regole, mutazioni, test delle funzioni e controllo regole.
- I 326 test delle funzioni sull'emulatore Firestore, i 90 test Flutter, `flutter analyze`, la build web, `actionlint`, `prova-promozione.sh` (57 casi): non rieseguiti.
- Contenuto di PR #27 (208 file): non riesaminato file per file; solo le regole Firestore e i punti sopra.
