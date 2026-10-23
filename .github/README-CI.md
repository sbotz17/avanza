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
| `rilascio-produzione.yml` | push su `main` | **Rilascio in produzione**: stessi passi di sempre. Con `PRODUZIONE_CONTROLLI_COMPLETI=true` aggiunge backup, prova su copia, verifica, tag `ultimo-rilascio-ok` e **ritorno automatico** se qualcosa va storto dopo l'avvio. |
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
Crealo (si crea da solo al primo rilascio, ma senza protezioni), limitalo al ramo **`main`** e aggiungi **te** come **revisore obbligatorio**: ogni rilascio in produzione aspetterà il tuo tocco (anche dal telefono).

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

### 6. Etichette e tag
- Etichetta `tipo:correzione` (la crea `promozione.yml` al bisogno; la squadra la applica alle correzioni).
- Tag `ultimo-rilascio-ok`: lo crea il rilascio con i controlli completi; per il primo rilascio crealo tu su `main` (o lascia che lo crei il primo rilascio riuscito).

## Cosa NON è automatico (decisioni tue)
- Il **ripristino reale** di Firestore di produzione: la squadra prepara la prova su copia (`ripristina-firestore.sh --verifica`) ma non lo esegue.
- Creare il progetto di test, i segreti, le protezioni dei rami e l'ambiente `produzione`.
- Il ritorno automatico riporta indietro sito e funzione, **non i dati**.
