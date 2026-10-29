# CI e rilasci di Avanza — guida per Andrea

Avanza ha **un repository e due rami**: `staging` è l'ambiente di **test**, `main` è la **produzione** (progetto Firebase `avanza-b62d7`).
La squadra lavora su rami di lavoro e apre pull request verso `staging`; in `main` si arriva solo con la **promozione da staging**, che dal 24/10/2026
(T-18) è **automatica ma condizionata**: la CI la unisce da sola quando tutti i controlli sono verdi (non serve il tuo tocco). Gli agenti non scrivono mai su `main`.

> **Finché non configuri nulla di quanto sotto, la produzione si comporta esattamente come oggi**: push su `main` = analisi, build,
> Hosting live e funzione `githubWebhook`. Tutto il resto è opzionale e si accende con segreti o variabili.

## Cosa fa ogni workflow (`.github/workflows/`)
| File | Quando parte | Cosa fa |
|---|---|---|
| `ci.yml` | pull request verso staging/main, push sui rami di lavoro | **Controlli**: `flutter analyze`, `flutter test`, build web, build funzioni. Il job `controlli` va reso obbligatorio. Il test oggi non blocca (vedi `TEST_OBBLIGATORI`). |
| `controlli-pr.yml` | pull request verso staging/main | Blocco di emergenza; verso `main` solo da `staging`; **zone protette**; **regole Firestore** (`controlla-regole.py`: niente regole aperte a chiunque, niente indici tolti); nessun segreto nel codice; classificazione prevista (correzione o nuovo sviluppo) scritta anche come commento sulla pull request. |
| `deploy.yml` | push su `staging`, pull request | Pubblica sul progetto di **test** (`avanza-test`) e le **anteprime** delle pull request, SOLO se il test è configurato (vedi sotto). Non pubblica mai sulla produzione. |
| `promozione.yml` | push su `staging` (job `pr`); a fine di "Deploy Avanza Web", `ci` e `controlli-pr` su `staging` o a mano (job `unione`); con `SQUADRA_CI_ATTIVA=si` | `pr`: apre/aggiorna la pull request **staging → main** con riepilogo e classificazione (se è uno sviluppo ti avvisa su WhatsApp). `unione` (**T-18**): se la TESTA di `staging` ha tutti i controlli verdi (CI con test passati, deploy di test completo, controlli della pull request, nessun conflitto, nessun blocco) **unisce la pull request con un merge commit e avvia `rilascio-produzione.yml`** (`gh workflow run`, perché un'unione fatta dal bot non fa partire da sola il push su `main`). Se manca anche un solo controllo, o è in corso, non unisce e non va in rosso: riprova al prossimo evento. Logica in `.claude/scripts/promuovi-staging.sh`. |
| `rilascio-produzione.yml` | push su `main` oppure avvio esplicito (`workflow_dispatch`, ramo `main`) dalla promozione automatica | **Rilascio in produzione**: stessi passi di sempre (Hosting live + funzione), con in più (dal 24/10/2026, sempre attivi): classificazione correzione/sviluppo (riepilogo di cosa esce nel riepilogo del job; il tocco di Andrea per gli sviluppi solo con `SVILUPPI_RICHIEDONO_APPROVAZIONE=si`), prerequisiti, "solo la testa di main", "già provato su staging", controllo della configurazione della build, **smoke test** dopo il deploy e **ritorno automatico** se fallisce. Con `PRODUZIONE_CONTROLLI_COMPLETI=true` aggiunge anche backup, prova su copia e confronto dei dati. |
| `backup-giornaliero.yml` | ogni notte (con `BUCKET_BACKUP_FIRESTORE`) | Export di Firestore su bucket, impronta dei dati e prova di ripristino su copia (deve dare IDENTICO). |
| `avvisi.yml` | push/pull request su staging che toccano `da-validare.md`, `registro-decisioni.md`, `BLOCCO-SQUADRA.md` (con `SQUADRA_CI_ATTIVA=si`) | Avvisi WhatsApp con testi fissi. Se il motore WhatsApp non è configurato lo scrive nel log ("AVVISO NON PARTITO") e va avanti. |
| `setup-firestore.yml`, `registra-ore.yml`, `e2e-webhook.yml`, `verifica-sito.yml` | a mano | Strumenti già in uso: creare/pubblicare Firestore, gestire membri/ore/progetti, provare il webhook, controllare il sito. Non cambiati. |

## Cosa devi configurare tu (una volta)
Segreti: **Settings → Secrets and variables → Actions**. Variabili: stessa pagina, scheda *Variables*.

### 1. Ambiente di test (progetto Firebase `avanza-test`)
1. Crea un nuovo progetto Firebase `avanza-test` (Auth email/password, Firestore `(default)` regione `eur3`, Hosting). Per la funzione serve il piano con fatturazione.
2. Crea un account di servizio per il deploy e salva la sua chiave JSON nel segreto **`FIREBASE_SERVICE_ACCOUNT_TEST`**. (Facoltativo: variabile `PROGETTO_FIREBASE_TEST` se il progetto non si chiama `avanza-test`.)
3. Serve ancora una modifica dell'app (la fa la squadra, lavoro di sviluppo): `lib/firebase_options_test.dart` con la configurazione web del progetto di test e il suo uso con `--dart-define=APP_ENV=test`.
   **Finché quel file non esiste il deploy di test e le anteprime NON partono**, per non far usare al sito di test i dati di produzione.

### 2. Backup e controlli completi di produzione
1. Crea un bucket Google Cloud Storage **con blocco di conservazione (retention)** per i backup e dai al service account di produzione (`FIREBASE_SERVICE_ACCOUNT`) i ruoli *Cloud Datastore Import Export Admin* e scrittura/lettura sul bucket (e il permesso di creare/eliminare database Firestore per la prova su copia: ha già *Cloud Datastore Owner*).
2. Variabile **`BUCKET_BACKUP_FIRESTORE`** = nome del bucket (senza `gs://`): accende il backup notturno.
3. Variabile **`PRODUZIONE_CONTROLLI_COMPLETI`** = `true`: ogni rilascio fa prima backup e prova su copia, poi verifica e, se serve, ritorno automatico. **Prima di accenderla provala con il backup notturno** (`backup-giornaliero.yml` → *Run workflow*): questi passaggi sono nuovi e non ancora provati su GitHub.

### 3. Protezione dei rami (Settings → Branches)
- **`staging`**: pull request obbligatoria; controlli obbligatori: `controlli` (da `ci.yml`), `blocco`, `verso-produzione-solo-da-staging`, `zone-protette`, `regole`, `nessun-segreto`; solo merge "squash"; "Require review from Code Owners" (dopo aver attivato il CODEOWNERS).
- **`main`**: nessuno scrive direttamente; si entra solo con la pull request di promozione, che la CI unisce da sola con i controlli verdi (Require a pull request before merging, **0 approvazioni**, niente push forzati né cancellazione).
  **Attenzione ai controlli obbligatori su `main` (T-18):** una pull request aperta dal bot (`GITHUB_TOKEN`) non fa partire i workflow `pull_request`, quindi `controlli`, `zone-protette`, ecc. possono non comparire mai su di essa e, se resi *obbligatori* su `main`, la pull request resterebbe `BLOCKED` per sempre (la promozione lo dice nel riepilogo e non unisce). Per questo su `main` NON si rendono obbligatori i controlli di `controlli-pr.yml`/`ci.yml`: le stesse verifiche sono già obbligatorie su `staging` e la promozione controlla da sola i controlli verdi della testa di `staging`, mentre il rilascio rifà CI, test, build e confronto con `staging`. Dettagli e comandi: `docs/progetto/configurazioni-da-fare.md`, sezione 1.
- **CODEOWNERS**: rinomina `.github/CODEOWNERS.esempio` in `.github/CODEOWNERS` (le regole della squadra, la CI e le regole di sicurezza cambiano solo con la tua approvazione).
- **Actions → General**: abilita *Allow GitHub Actions to create and approve pull requests* (serve a `promozione.yml`). *Allow auto-merge* **non** serve: la promozione unisce direttamente.
- Impostazioni del repository: devono restare permessi i *merge commit* (oggi lo sono): la promozione NON usa lo squash.

### 4. Ambiente GitHub `produzione` (Settings → Environments)
Crealo (si crea da solo al primo rilascio, ma senza protezioni) e limitalo al ramo **`main`**. **Senza revisore** (decisione del 24/10/2026: non approvi più i rilasci; un revisore qui fermerebbe anche le correzioni).

### 5. Interruttori e avvisi
| Nome | Tipo | A cosa serve |
|---|---|---|
| `SQUADRA_CI_ATTIVA` | variabile | `si` accende la promozione (compresa l'unione automatica in produzione) e gli avvisi. Di default spenta: **mettere `no` è il modo più semplice per fermare la promozione automatica**. |
| `BLOCCO_SQUADRA` | variabile | `ATTIVO` ferma promozioni (unione automatica compresa), rilasci e controlli (la tua leva di emergenza, anche dal telefono). |
| `TEST_OBBLIGATORI` | variabile | `true` rende bloccanti i test di `flutter test` (oggi non bloccano: prima vanno resi verdi). |
| `NOME_PROGETTO` | variabile | Nome negli avvisi (default `Avanza`). |
| `URL_PRODUZIONE` | variabile | Indirizzo per la verifica finale (default `https://avanza-b62d7.web.app`). |
| `AVVISI_URL`, `AVVISI_TOKEN`, `AVVISI_NUMERO` | segreti | Motore WhatsApp (lo stesso di Volty). Senza, gli avvisi non partono ma nulla si blocca. |
| `AVVISI_PERMETTI_HTTP` | variabile | `si` solo se il motore WhatsApp non ha HTTPS (sconsigliato). |
| `SVILUPPI_RICHIEDONO_APPROVAZIONE` | variabile | `no` (predefinito, anche se assente o vuota): i nuovi sviluppi escono da soli con tutti gli altri controlli, come le correzioni. `si` (o qualunque altro valore): il tuo tocco sull'ambiente `produzione-sviluppi` come prima. |
| `SVILUPPI_APPROVAZIONE_CONFIGURATA` | variabile | Rilevante SOLO con `SVILUPPI_RICHIEDONO_APPROVAZIONE` diverso da `no`: `si` quando hai creato l'ambiente `produzione-sviluppi` con te come revisore. Senza, in quel caso un nuovo sviluppo NON esce (rilascio fermato con avviso). Le correzioni e il modo predefinito non ne hanno bisogno. |
| `TEST_RILASCIO_NON_OBBLIGATORI` | variabile | `si` per far uscire in produzione anche con i test rossi (valvola; di norma NON impostarla: i test rossi fermano il rilascio). La promozione automatica la rispetta: senza la valvola non unisce un commit di `staging` con test rossi. |
| `CONTROLLO_STAGING` | variabile | `no` salta il controllo "stesso contenuto già provato su staging" (valvola di emergenza, se il controllo stesso si rompe). |
| `CONTROLLO_CONFIG_BUILD` | variabile | `no` salta il controllo "la build non contiene la configurazione dell'altro ambiente" (solo dopo aver verificato un falso allarme). |

### 6. Etichette e tag
- Etichetta `tipo:correzione` (la crea `promozione.yml` al bisogno; la squadra la applica alle correzioni).
- Tag `ultimo-rilascio-ok`: lo crea il rilascio con i controlli completi; per il primo rilascio crealo tu su `main` (o lascia che lo crei il primo rilascio riuscito).

## Promozione automatica (T-18, 24/10/2026) — come funziona e come fermarla
Decisione di Andrea: "la squadra è autonoma se i test sono verdi". Dopo ogni modifica entrata in `staging`, `promozione.yml` (job `unione`) controlla la TESTA di `staging`:
1. nessun blocco (`BLOCCO_SQUADRA`, `BLOCCO-SQUADRA.md` su `staging` o su `main`) e `SQUADRA_CI_ATTIVA=si`;
2. l'unione darebbe esattamente il contenuto di `staging` (nessun conflitto, nessuna modifica estranea su `main`); altrimenti **anomalia**: rosso + avviso, nessuna unione;
3. `verifica-da-staging.sh`: "Deploy Avanza Web" su quel commit concluso con successo, con sito, regole/indici e funzione di test pubblicati davvero, e con i test automatici passati;
4. la pull request di promozione (solo dello stesso repository: quelle dei fork con un ramo `staging` si ignorano) esiste, ha la stessa testa di `staging`, nessun controllo suo rosso né in corso (una risposta di forma imprevista vale come "non si unisce"), nessun conflitto, stato noto e buono;
4b. `firestore.rules` e `firestore.indexes.json` sono uguali tra `staging` e `main`: se differiscono la promozione si ferma ("serve una persona", avviso WhatsApp): pubblicare con Setup Firestore e unire a mano;
5. solo allora: unione con **merge commit** (mai squash) vincolata alla testa verificata (`--match-head-commit`), verifica che il commit di unione abbia il contenuto di `staging`, avvio esplicito di `rilascio-produzione.yml` sul ramo `main` (salvo che ce ne sia già uno in coda per lo stesso commit).
Se un controllo manca o è in corso: **niente unione e niente rosso**, riprova al prossimo evento (ogni workflow di controllo che finisce su `staging` ne è uno). Una sola promozione alla volta (gruppo `promozione-unione`); i rilasci restano uno alla volta (gruppo `produzione`).
Il rilascio resta l'ultima barriera e rifà i suoi controlli. Se `SVILUPPI_RICHIEDONO_APPROVAZIONE` non è vuota/`no`, un nuovo sviluppo unito in `main` **aspetta comunque il tuo tocco** sull'ambiente `produzione-sviluppi`.
**Prova a mano (a secco):** Actions > promozione > *Run workflow* con `solo_verifica` = true (predefinito): fa tutti i controlli ma non unisce.
**Per fermarla subito:** `SQUADRA_CI_ATTIVA` = `no`, oppure `BLOCCO_SQUADRA` = `ATTIVO`. **Per tornare al vecchio modo (PR aperta ma unita a mano):** togliere il job `unione` (revert del commit T-18).
**Rischio accettato:** il job `unione` esegue gli script presenti su `staging` con permessi di scrittura e `CODEOWNERS` NON è attivo (c'è solo l'esempio): oggi nessun blocco tecnico impedisce di cambiarli senza Andrea; vedi `registro-decisioni.md` (T-18, rischio d). **Prima promozione dopo T-18:** vedi `docs/progetto/configurazioni-da-fare.md`, sezione 7 (backup, tag, revisore temporaneo, unione manuale, Setup Firestore). In breve: `workflow_run` e `workflow_dispatch` usano il file di `promozione.yml` presente su `main`, che ancora non ha il job `unione`: la prima pull request di promozione che contiene T-18 va unita a mano (da un amministratore); da lì in poi è automatico. Lo stesso vale per ogni modifica futura a `promozione.yml` (vale dopo la promozione successiva).

## Cosa NON è automatico (decisioni tue)
- Il **ripristino reale** di Firestore di produzione: la squadra prepara la prova su copia (`ripristina-firestore.sh --verifica`) ma non lo esegue.
- Creare il progetto di test, i segreti, le protezioni dei rami e l'ambiente `produzione`.
- Il tocco sugli sviluppi, solo se riaccendi `SVILUPPI_RICHIEDONO_APPROVAZIONE`. Per il resto la promozione e il rilascio sono automatici con i controlli verdi.
- Il ritorno automatico riporta indietro sito e funzione, **non i dati**.

## Revisione di sicurezza del 24/10/2026 (cosa è cambiato e cosa devi fare tu)
Dettagli e rischi: `docs/progetto/test/2026-10-24-audit-rilascio-produzione.md`. In sintesi, prima di toccare la produzione il rilascio ora controlla (e si ferma al primo problema):
1. **correzione o sviluppo?** ricalcolato al momento del rilascio (`classifica-rilascio.sh`, stessa regola della promozione); il riepilogo di cosa esce finisce nel riepilogo del job (utile per `docs/progetto/rilasci.md`). Il tuo tocco sull'ambiente `produzione-sviluppi` serve solo se `SVILUPPI_RICHIEDONO_APPROVAZIONE` non è `no` (predefinito: nessun tocco);
2. **prerequisiti**: il segreto `FIREBASE_SERVICE_ACCOUNT` esiste ed è la chiave di `avanza-b62d7` (mai quella di test);
3. **solo la testa di main** (un "Re-run" di un rilascio vecchio non riporta indietro la produzione);
4. **stesso contenuto già provato su staging**: esiste un commit di staging con file identici, con controlli verdi e con sito, regole/indici e funzione pubblicati davvero sul progetto di test;
5. **la build di produzione non contiene `avanza-test`** (e quella di test non contiene `avanza-b62d7`);
6. test automatici rossi = rilascio fermato (prima non fermavano nulla);
Dopo il deploy: **smoke test** (sito 200 anche su `/login`, `main.dart.js` con `avanza-b62d7`, cache `no-cache`, funzione `githubWebhook` che risponde 405/401, servizio di accesso Firebase raggiungibile) e, se fallisce, **ritorno automatico** del sito e della funzione al tag `ultimo-rilascio-ok` (nello stesso job: non chiede un secondo tuo tocco). Il tag si aggiorna a ogni rilascio verificato, anche senza `PRODUZIONE_CONTROLLI_COMPLETI`. Il primo rilascio con questa procedura non ha un punto di ritorno (il tag non esiste ancora): se vuoi, crealo tu sul commit di `main` che oggi è in produzione.

### Cosa deve fare Andrea (la squadra non ha questi permessi)
1. **Niente più tocco sugli sviluppi (decisione del 24/10/2026).** Non serve creare `produzione-sviluppi` né impostare `SVILUPPI_APPROVAZIONE_CONFIGURATA`. Facoltativo: variabile `SVILUPPI_RICHIEDONO_APPROVAZIONE` = `no` (è già il predefinito). **Solo se vuoi tornare all'approvazione manuale**: crea l'ambiente `produzione-sviluppi` (*Required reviewers* = te; *Deployment branches* = solo `main`), imposta `SVILUPPI_APPROVAZIONE_CONFIGURATA` = `si` e poi `SVILUPPI_RICHIEDONO_APPROVAZIONE` = `si`.
2. **Ambiente `produzione`**: *Deployment branches* = solo `main`, **senza revisore obbligatorio** (fermerebbe ogni rilascio, correzioni comprese).
3. **Protezione dei rami** `main` e `staging` (sezione 3 sopra): su `staging` i controlli obbligatori `controlli`, `blocco`, `verso-produzione-solo-da-staging`, `zone-protette`, `regole`, `nessun-segreto`; su `main` solo pull request obbligatoria, 0 approvazioni, niente push forzato né cancellazione (i controlli obbligatori su `main` bloccherebbero la promozione automatica: vedi sezione 3 e T-18); e `CODEOWNERS` attivo: è ciò che impedisce a chiunque (squadra compresa) di cambiare questi flussi senza di te. Le zone protette valgono anche per le correzioni: ogni modifica a `.github/` o `.claude/` è per natura uno "sviluppo".
   **Tipo di unione della pull request di promozione `staging` -> `main`: "Create a merge commit"** (non "Squash"): con lo squash il rilascio vede un solo commit di una pull request dal ramo `staging`, non riconosce le singole correzioni e tratta TUTTO come nuovo sviluppo (con tocco richiesto ti chiederebbe il tocco anche per le correzioni: è la direzione sicura, ma inutile; nel modo predefinito cambia solo la classificazione scritta nel riepilogo).
4. **Backup**: creare il bucket con blocco di conservazione e la variabile `BUCKET_BACKUP_FIRESTORE` (sezione 2). Finché non c'è, nessuna variazione ai dati ha un backup: il rilascio lo dice a ogni esecuzione (avviso giallo) e il lunedì arriva un avviso WhatsApp.
5. **Regole di tag** (Settings > Rules > Rulesets): proteggere il tag `ultimo-rilascio-ok` dalla cancellazione (si può aggiornare solo dal rilascio).
6. **Prima volta**: lanciare a mano "Verifica sito" (ora esegue anche lo smoke test) per controllare che le prove corrispondano al sito vero; se qualcosa è un falso allarme, dillo alla squadra che aggiusta lo script (`.claude/scripts/smoke-produzione.sh`).
7. **Chi può lanciare i flussi manuali**: "Registra ore squadra" e "E2E Webhook" usano la chiave di produzione e partono da qualunque ramo. Se vuoi limitarli, sposta la chiave `FIREBASE_SERVICE_ACCOUNT` in un ambiente GitHub limitato ai rami `main` e `claude/*` (decisione tua: oggi li usa il Coordinatore da rami di lavoro).
