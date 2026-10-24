# CI e rilasci di Avanza — guida per Andrea

Avanza ha **un repository e due rami**: `staging` è l'ambiente di **test**, `main` è la **produzione** (progetto Firebase `avanza-b62d7`).
La squadra lavora su rami di lavoro e apre pull request verso `staging`; in `main` si arriva solo con la **promozione da staging**, che
decidi tu. Gli agenti non scrivono mai su `main`.

> **Finché non configuri nulla di quanto sotto, la produzione si comporta esattamente come oggi**: push su `main` = analisi, build,
> Hosting live e funzione `githubWebhook`. Tutto il resto è opzionale e si accende con segreti o variabili.

## Cosa fa ogni workflow (`.github/workflows/`)
| File | Quando parte | Cosa fa |
|---|---|---|
| `ci.yml` | pull request verso staging/main, push sui rami di lavoro | **Controlli**: `flutter analyze`, `flutter test`, build web, build funzioni. Il job `controlli` va reso obbligatorio. Il test oggi non blocca (vedi `TEST_OBBLIGATORI`). |
| `controlli-pr.yml` | pull request verso staging/main | Blocco di emergenza; verso `main` solo da `staging`; **zone protette**; **regole Firestore** (`controlla-regole.py`: niente regole aperte a chiunque, niente indici tolti); nessun segreto nel codice; classificazione prevista (correzione o nuovo sviluppo) scritta anche come commento sulla pull request. |
| `deploy.yml` | push su `staging`, pull request | Pubblica sul progetto di **test** (`avanza-test`) e le **anteprime** delle pull request, SOLO se il test è configurato (vedi sotto). Non pubblica mai sulla produzione. |
| `promozione.yml` | push su `staging` (con `SQUADRA_CI_ATTIVA=si`) | Apre/aggiorna la pull request **staging → main** con riepilogo e classificazione. Non unisce nulla. Se è uno sviluppo ti avvisa su WhatsApp. |
| `rilascio-produzione.yml` | push su `main` | **Rilascio in produzione**: stessi passi di sempre (Hosting live + funzione), con in più (dal 24/10/2026, sempre attivi): classificazione correzione/sviluppo (riepilogo di cosa esce nel riepilogo del job; il tocco di Andrea per gli sviluppi solo con `SVILUPPI_RICHIEDONO_APPROVAZIONE=si`), prerequisiti, "solo la testa di main", "già provato su staging", controllo della configurazione della build, **smoke test** dopo il deploy e **ritorno automatico** se fallisce. Con `PRODUZIONE_CONTROLLI_COMPLETI=true` aggiunge anche backup, prova su copia e confronto dei dati. |
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
- **`main`**: nessuno scrive direttamente; si entra solo con la pull request di promozione, con la tua approvazione (Require a pull request before merging, 1 approvazione, controlli obbligatori).
- **CODEOWNERS**: rinomina `.github/CODEOWNERS.esempio` in `.github/CODEOWNERS` (le regole della squadra, la CI e le regole di sicurezza cambiano solo con la tua approvazione).
- **Actions → General**: abilita *Allow GitHub Actions to create and approve pull requests* (serve a `promozione.yml`).

### 4. Ambiente GitHub `produzione` (Settings → Environments)
Crealo (si crea da solo al primo rilascio, ma senza protezioni) e limitalo al ramo **`main`**. **Senza revisore** (decisione del 24/10/2026: non approvi più i rilasci; un revisore qui fermerebbe anche le correzioni).

### 5. Interruttori e avvisi
| Nome | Tipo | A cosa serve |
|---|---|---|
| `SQUADRA_CI_ATTIVA` | variabile | `si` accende promozione e avvisi. Di default spenta. |
| `BLOCCO_SQUADRA` | variabile | `ATTIVO` ferma promozioni, rilasci e controlli (la tua leva di emergenza, anche dal telefono). |
| `TEST_OBBLIGATORI` | variabile | `true` rende bloccanti i test di `flutter test` (oggi non bloccano: prima vanno resi verdi). |
| `NOME_PROGETTO` | variabile | Nome negli avvisi (default `Avanza`). |
| `URL_PRODUZIONE` | variabile | Indirizzo per la verifica finale (default `https://avanza-b62d7.web.app`). |
| `AVVISI_URL`, `AVVISI_TOKEN`, `AVVISI_NUMERO` | segreti | Motore WhatsApp (lo stesso di Volty). Senza, gli avvisi non partono ma nulla si blocca. |
| `AVVISI_PERMETTI_HTTP` | variabile | `si` solo se il motore WhatsApp non ha HTTPS (sconsigliato). |
| `SVILUPPI_RICHIEDONO_APPROVAZIONE` | variabile | `no` (predefinito, anche se assente o vuota): i nuovi sviluppi escono da soli con tutti gli altri controlli, come le correzioni. `si` (o qualunque altro valore): il tuo tocco sull'ambiente `produzione-sviluppi` come prima. |
| `SVILUPPI_APPROVAZIONE_CONFIGURATA` | variabile | Rilevante SOLO con `SVILUPPI_RICHIEDONO_APPROVAZIONE` diverso da `no`: `si` quando hai creato l'ambiente `produzione-sviluppi` con te come revisore. Senza, in quel caso un nuovo sviluppo NON esce (rilascio fermato con avviso). Le correzioni e il modo predefinito non ne hanno bisogno. |
| `TEST_RILASCIO_NON_OBBLIGATORI` | variabile | `si` per far uscire in produzione anche con i test rossi (valvola; di norma NON impostarla: i test rossi fermano il rilascio). |
| `CONTROLLO_STAGING` | variabile | `no` salta il controllo "stesso contenuto già provato su staging" (valvola di emergenza, se il controllo stesso si rompe). |
| `CONTROLLO_CONFIG_BUILD` | variabile | `no` salta il controllo "la build non contiene la configurazione dell'altro ambiente" (solo dopo aver verificato un falso allarme). |

### 6. Etichette e tag
- Etichetta `tipo:correzione` (la crea `promozione.yml` al bisogno; la squadra la applica alle correzioni).
- Tag `ultimo-rilascio-ok`: lo crea il rilascio con i controlli completi; per il primo rilascio crealo tu su `main` (o lascia che lo crei il primo rilascio riuscito).

## Cosa NON è automatico (decisioni tue)
- Il **ripristino reale** di Firestore di produzione: la squadra prepara la prova su copia (`ripristina-firestore.sh --verifica`) ma non lo esegue.
- Creare il progetto di test, i segreti, le protezioni dei rami e l'ambiente `produzione`.
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
3. **Protezione dei rami** `main` e `staging` (sezione 3 sopra), con i controlli obbligatori `controlli`, `blocco`, `verso-produzione-solo-da-staging`, `zone-protette`, `regole`, `nessun-segreto`, e `CODEOWNERS` attivo: è ciò che impedisce a chiunque (squadra compresa) di cambiare questi flussi senza di te. Le zone protette valgono anche per le correzioni: ogni modifica a `.github/` o `.claude/` è per natura uno "sviluppo".
   **Tipo di unione della pull request di promozione `staging` -> `main`: "Create a merge commit"** (non "Squash"): con lo squash il rilascio vede un solo commit di una pull request dal ramo `staging`, non riconosce le singole correzioni e tratta TUTTO come nuovo sviluppo (con tocco richiesto ti chiederebbe il tocco anche per le correzioni: è la direzione sicura, ma inutile; nel modo predefinito cambia solo la classificazione scritta nel riepilogo).
4. **Backup**: creare il bucket con blocco di conservazione e la variabile `BUCKET_BACKUP_FIRESTORE` (sezione 2). Finché non c'è, nessuna variazione ai dati ha un backup: il rilascio lo dice a ogni esecuzione (avviso giallo) e il lunedì arriva un avviso WhatsApp.
5. **Regole di tag** (Settings > Rules > Rulesets): proteggere il tag `ultimo-rilascio-ok` dalla cancellazione (si può aggiornare solo dal rilascio).
6. **Prima volta**: lanciare a mano "Verifica sito" (ora esegue anche lo smoke test) per controllare che le prove corrispondano al sito vero; se qualcosa è un falso allarme, dillo alla squadra che aggiusta lo script (`.claude/scripts/smoke-produzione.sh`).
7. **Chi può lanciare i flussi manuali**: "Registra ore squadra" e "E2E Webhook" usano la chiave di produzione e partono da qualunque ramo. Se vuoi limitarli, sposta la chiave `FIREBASE_SERVICE_ACCOUNT` in un ambiente GitHub limitato ai rami `main` e `claude/*` (decisione tua: oggi li usa il Coordinatore da rami di lavoro).
