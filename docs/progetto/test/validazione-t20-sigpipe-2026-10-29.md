# Validazione T-20: `verifica-da-staging.sh` e SIGPIPE (seconda lettura, zona protetta `.claude/**`)

Validatore indipendente, 29/10/2026. Ramo `fix/T-20-verifica-da-staging-sigpipe`, head `d68e822`, confrontato con `origin/staging` (`e98672d`). Worktree proprio `.claude/worktrees/agent-a53c6c6d3720b6ceb`. Ambiente: gawk 5.2.1, shellcheck, git, `gh` in sola lettura (elenco esecuzioni e passi). Nessun workflow lanciato, nessun push.

## ESITO: APPROVATO (con una raccomandazione forte sullo smoke test, vedi "Rischi" punto 1)

Classificazione: nel contenuto e' una **correzione** (ripristina il comportamento documentato del rilascio), ma tocca `.claude/**` (zona protetta) quindi per regola e' trattata come **NUOVO SVILUPPO**: niente etichetta `tipo:correzione`, seconda lettura (questa) prima dell'unione, nessun tocco di Andrea. Il ramo `fix/T-20-...` senza `R-n` non e' un ramo "correzione" per `classifica-modifica.py`: coerente.

## 1. Diff riga per riga (nessun controllo indebolito)

File toccati: 5 in `.claude/scripts` (3 correzioni + 2 file di prova) e 3 in `docs/progetto` (+ report del tester). Nessun `.github/`, `lib/`, `functions/`, regole, indici, dipendenze, configurazioni. Nessun segreto (cercato nel diff: solo parole in prosa).

- `verifica-da-staging.sh` (1 riga): `awk '$2==t{print $1; exit}'` -> `awk '$2==t && !gia {print $1; gia=1}'`. Stesso risultato (prima corrispondenza = commit piu' recente di staging con lo stesso albero), awk legge tutto (al massimo `N` righe). Albero identico, deploy di test completo (3 passi `success`), `RICHIEDI_TEST_VERDI`, valvola, fallire chiuso: **invariati**, righe non toccate.
- `backup-firestore.sh` (1 riga): `echo "$ELENCO" | grep -q` -> `grep -q ... <<< "$ELENCO"`. Export senza `overall_export_metadata` -> ancora errore e uscita 1.
- `ripristina-firestore.sh` (2 righe): elenco letto in variabile con `|| exit 1` (messaggio nuovo "non e' leggibile"), poi `grep -q <<<`. Backup senza metadati -> ancora errore e uscita 1. Cambia solo il messaggio se gcloud fallisce (comunque uscita 1).
- Here-string: con bash >= 5.1 usa una pipe solo se il dato entra nel buffer, altrimenti un file temporaneo: nessun SIGPIPE possibile. Il tester l'ha provata con 60 MB; io non ho riletto il sorgente di bash (non verificato oltre alla prova pratica).
- I file di prova non rientrano nel rilascio (non chiamati da nessun workflow): `prova-script-gcloud.sh` nuovo, `prova-promozione.sh` +43 righe. Registrati in `catalogo.md`; modi file 755 conservati; nessun duplicato evitabile (stub di gcloud unico).
- Ambito: la correzione di backup e ripristino e' della stessa classe di difetto (pipeline con lettore che chiude in anticipo) sul percorso del rilascio: giustificata, non e' ampliamento di funzioni.

## 2. Prove rieseguite di persona

- `bash .claude/scripts/prova-promozione.sh`: **61 casi, 0 falliti** (15 s, gawk).
- `bash .claude/scripts/prova-script-gcloud.sh`: **6 casi, 0 falliti**.
- `bash -n` su tutti gli script: nessun errore. `shellcheck -S warning` sui 5 script toccati: pulito.
- Con `verifica-da-staging.sh` di `origin/staging` rimesso nel ramo: **2 casi FALLITI** (uscita 141; promozione "non-ora"): le prove falliscono prima e passano dopo.
- Mutazioni mie: (a) albero non confrontato -> 1 caso fallito (il caso aggiunto dal tester); (b) tutti gli `exit 1` dello script resi no-op -> 6 casi falliti. Individuate.
- Riproduzione indipendente del guasto: storia di 400 commit con lo stesso albero, vecchia pipeline con gawk e `pipefail`: **30 volte su 30 uscita 141** (il registro dice 29/30: differenza trascurabile, ordine di grandezza confermato).

## 3. Report del tester

Onesto: dichiara cosa non ha verificato (runner reale, `gh`/`gcloud` reali, frequenza 29/30, seconda lettura) e il file di log fuori repository. Le mutazioni che aveva trovato scoperte (albero qualsiasi / non trovato non fallisce) sono ora coperte dal caso aggiunto: confermato da me. Le evidenze sono concrete. Non ho riscontrato omissioni sui criteri.

## 4. Registro decisioni del 29/10

Veritiero. Verificato: il run 40792206718 su `main` ha `classifica` e `controlli` verdi, `approvazione-sviluppo` saltato, `rilascio` fallito **solo** al passo "Gia' provato su staging" e tutti i passi seguenti saltati (nessun backup, nessun deploy); `b59bbd8` e il commit dichiarato hanno lo stesso albero (`651f09b...`, che e' un albero, non un commit: la frase lo dice "albero"). Il log del run e' davvero illeggibile da qui (403). L'errore dell'audit del 28/10 ("passato per caso", mawk) e' dichiarato in chiaro; il limite "awk del runner non verificato" e' scritto. Non verificato da me: che sito e funzione di produzione siano ancora a `4e66a0e` (il sito risponde 403 al proxy della sessione).
Nota minore: nelle vecchie voci "T-20" indica il collegamento GitHub App (codice finto, vedi voce del 28/10 sulla mappa dei T-N); ora T-20 e' anche questo task. Rischio di confusione documentale, nessun effetto sui dati (il webhook agisce solo su task esistenti del progetto).

## 5. Rischi latenti dei passi dopo "Gia' provato su staging" (per gravita')

Letti: `rilascio-produzione.yml` per intero, `verifica-da-staging.sh`, `controlla-prerequisiti-rilascio.sh`, `controlla-build-ambiente.sh`, `backup-firestore.sh`, `ripristina-firestore.sh`, `impronta-firestore.mjs`, `smoke-produzione.sh`, `setup-firestore.yml`, `secrets.ts`, `authenticate.ts`.

1. **ALTO (probabilita' media): smoke test della funzione, POST con firma sbagliata.** Il codice nuovo (non ancora in produzione: li' c'e' `4e66a0e`) dopo il segreto storico legge `GITHUB_APP_WEBHOOK_SECRET`, che in produzione risulta "da creare". `secrets.ts` trasforma in "assente" solo NOT_FOUND (5) e FAILED_PRECONDITION (9); PERMISSION_DENIED (7) -> 500 (`authenticate.ts`, test `authenticate.test.ts:92` lo vuole di proposito). Se `firebase-adminsdk-fbsvc` ha `secretAccessor` a livello di progetto: segreto inesistente = NOT_FOUND = 401 = smoke OK. Se ha il permesso solo sul singolo segreto storico: Secret Manager risponde (ricordo della piattaforma, non provato da qui) PERMISSION_DENIED -> 500 -> smoke FALLITO dopo il deploy. Conseguenze: sito e funzione restano gia' sul nuovo codice, **il tag `ultimo-rilascio-ok` non esiste quindi nessun ritorno automatico** ("ritorno NON riuscito, serve intervento subito" a Andrea), il tag non viene scritto, "Controlli completi 3" (impronta dopo il rilascio) viene saltato. La produzione non perde dati e i webhook firmati col segreto storico funzionano comunque, ma il rilascio risulta fallito con un falso allarme. Gia' segnalato nella validazione del 28/10 (punto 1) e non risolto.
   **Parere netto: si', rendere lo smoke tollerante PRIMA di rilasciare; NON toccare il codice della funzione.** Motivi: il 500 per segreto illeggibile e' una decisione gia' validata e testata (visibilita' sulle consegne GitHub fallite); cambiarla riapre un giro completo di funzioni, tester, revisione sicurezza; lo smoke invece e' uno script di 3 righe e lo stesso fix passa dalla stessa pipeline di questo ramo. Modifica minima proposta (NON applicata) in `smoke-produzione.sh`, `p_funz_post`: accettare 401; se la risposta e' 500 non fallire ma scrivere in `$TMP/avvisi` ("POST con firma sbagliata -> 500: segreto del webhook o della GitHub App non leggibile (IAM?), prova non conclusiva; verificare con un ping firmato") e tornare 0; qualsiasi altro codice (404, 000, 502, 503...) resta un fallimento. In piu', per non perdere la prova "la funzione risponde senza leggere Secret Manager": un `p_funz_post_nofirma` (POST senza intestazione di firma -> deve dare 401 `firma_assente`, nessuna lettura segreti). Compenso alla minore sensibilita': dopo il rilascio lanciare E2E Webhook (`e2e-webhook.yml`), che passa dal percorso del segreto storico firmato. Alternativa/aggiunta a costo zero di codice: prima del rilascio verificare `gcloud projects get-iam-policy avanza-b62d7` (ruolo `secretmanager.secretAccessor` a livello di progetto per quel service account) oppure creare il segreto con "Imposta segreto GitHub App" (serve il valore di Andrea e il ruolo Secret Manager Admin alla CI). Se almeno una delle due e' fatta, lo smoke rigido passa.
2. **MEDIO (probabilita' media): `ripristina-firestore.sh --verifica` non e' mai stato eseguito contro Google reale.** `backup-giornaliero.yml` non ha ancora nessuna esecuzione (`gh run list`: vuota); il backup vero e' stato provato solo il 24/10 (T-19, via registra-ore), la prova di ripristino IDENTICO e' ancora un "passaggio saltato" dichiarato nel registro (voce T-19). Punti non provati: creazione del database copia (`datastore.databases.create` e `delete` per il service account; la creazione e' gia' riuscita una volta con Setup Firestore), `gcloud firestore import gs://.../backup-TS` (la documentazione mostra spesso il percorso del file `*.overall_export_metadata`: se serve, l'import fallisce), permessi/posizione del bucket `avanza-backup-b62d7` per eur3, tempi. Se fallisce: il rilascio si ferma al passo "Controlli completi 2" **prima** di toccare la produzione (fallisce chiuso, sicuro), ma resta un database `copia-ripristino-*` da togliere a mano e un altro rilascio perso. Mitigazione: far girare prima `backup-giornaliero.yml` a mano (stesso script, nessun effetto sulla produzione) e leggere l'esito.
3. **MEDIO-BASSO: backup coerente.** `backup-firestore.sh` confronta l'impronta prima/dopo l'export: se qualcuno scrive durante il backup (3 tentativi, 60 s) fallisce. Fail chiuso; rischio basso per un'app con pochi utenti.
4. **BASSO: regole Firestore.** Il rilascio non pubblica regole e indici (le pubblica Setup Firestore da `main`, con backup): il sito nuovo girera' con le regole vecchie finche' non lo si lancia (sottocollezione chat). Gia' noto e scritto nel registro; da fare subito dopo il rilascio.
5. **BASSO: build.** `controlla-build-ambiente.sh prod` e' gia' passato su una build reale nel job `controlli` del run fallito (verde): non e' piu' un rischio teorico. `smoke-produzione.sh` e' passato su produzione vera il 28/10 (Verifica sito) per sito, cache, funzione vecchia e login: solo il comportamento della funzione NUOVA e' non provato.
6. **BASSO: `verifica-da-staging.sh` dopo la correzione.** Non provato con `gh api` reale (stesso limite dichiarato). Il commit scelto e' il piu' recente con quell'albero: se quello avesse una esecuzione di deploy cancellata (concorrenza) il controllo fallisce chiuso, non apre.
7. Documentale: voci vecchie con "T-20" per il collegamento GitHub App (vedi sopra).

## Non verificato da me

Esecuzione sul runner GitHub reale (versione di awk, tempi); `gh api` e `gcloud` reali nelle prove; IAM reale del service account e esistenza di `GITHUB_APP_WEBHOOK_SECRET` (nessun accesso a Google, variabili GitHub illeggibili: 403); comportamento reale di Secret Manager (NOT_FOUND o PERMISSION_DENIED per segreto inesistente) e di `gcloud firestore import` con il percorso usato; stato attuale di sito e funzione di produzione; sorgente interno di bash per le here-string.

## Cosa fare ora (consigli al Coordinatore)

- Questa correzione si puo' unire in `staging`: nessun controllo di sicurezza indebolito.
- Prima della prossima promozione: (a) decidere il punto 1 (consigliato: ritocco allo smoke come sopra, oppure verifica/creazione IAM-segreto), (b) lanciare a mano `backup-giornaliero.yml` per provare backup e ripristino reali (punto 2), (c) non c'e' il tag `ultimo-rilascio-ok`: il primo rilascio e' senza ritorno automatico (gia' accettato nel registro, ritorno manuale a `4e66a0e`).
