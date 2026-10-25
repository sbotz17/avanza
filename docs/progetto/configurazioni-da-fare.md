# Configurazioni di GitHub e Google da applicare (per una sessione con accesso di amministratore)

> **Strada consigliata (T-16):** invece di eseguire a mano i punti 1, 2, 3, 5 e 6, si lancia `bash scripts/applica-configurazioni.sh` dal computer di Andrea (`gh` e `gcloud` autenticati). Lo script e' idempotente, non stampa segreti e alla fine elenca cio' che NON ha potuto fare. Differenze volute rispetto ai comandi qui sotto (esito della seconda lettura del validatore):
> - **Due regole di protezione**: `staging` con i controlli obbligatori; `main` senza controlli obbligatori (solo niente cancellazione, niente push forzato, solo pull request), perche' la pull request di promozione la apre la CI con il token del flusso e le pull request aperte cosi' non fanno partire i controlli: con controlli obbligatori su `main` resterebbe bloccata per sempre.
> - **Volty e' un repository privato**: senza GitHub Pro (o repository pubblico) GitHub rifiuta ogni protezione dei rami. Lo script lo dichiara e prosegue. **Decisione in sospeso per Andrea** (vedi registro decisioni). Se si attiva, la promozione di Volty (push diretto su `main` con `PROD_DEPLOY_KEY`) va riesaminata.
> - Su Volty `SQUADRA_CI_ATTIVA` si imposta solo se i segreti di produzione esistono (altrimenti il rilascio potrebbe partire senza backup).
> - L'ambiente `produzione` esistente non viene riscritto.

**Perché esiste:** la sessione cloud della squadra NON può cambiare le impostazioni di GitHub (protezione dei rami, ambienti, variabili, webhook): il suo ambiente le blocca.
Una sessione di Claude Code sul computer di Andrea, con `gh` e `gcloud` autenticati come lui, può applicarle da sola. Autorizzazione: Andrea, 24/10/2026 ("fate tutto in autonomia").
Regole per chi esegue: un passo alla volta; **verifica dopo ogni passo** (comando di controllo indicato); **non stampare mai segreti** (né in terminale, né in log, né in chat); se un passo fallisce, fermati e riferisci l'errore a Andrea; annota ogni modifica in `docs/progetto/registro-decisioni.md`.
Prima di iniziare: `gh auth status` (account sbotz17, permessi `repo`, `workflow`, `admin:repo_hook`) e `gcloud auth list`.

## 1. Protezione dei rami (ruleset) — Avanza, Volty (e Commerciali se ha `main`)
Regole: nessuna cancellazione, nessun push forzato, solo pull request (0 approvazioni richieste: nessun tocco umano), controlli obbligatori **dove la pull request può produrli**. L'amministratore del repository può scavalcare (emergenze).
Controlli obbligatori (nomi esatti dei job):
- Avanza, solo su `staging`: `controlli`, `zone-protette`, `regole`, `nessun-segreto`, `blocco`.
- Volty: `test`, `nessun-segreto`, `migrazioni`, `zone-protette`, `blocco`.
**Avanza — `main` senza controlli obbligatori (T-18, promozione automatica):** la pull request `staging -> main` la apre e la unisce il bot (`GITHUB_TOKEN`), e le pull request aperte dal bot NON fanno partire i workflow `pull_request`: i controlli obbligatori non comparirebbero mai e la pull request resterebbe `BLOCKED` (la promozione lo scrive nel riepilogo e non unisce). Le stesse verifiche sono già obbligatorie su `staging` (prima di entrarvi) e `promuovi-staging.sh` controlla i controlli verdi della testa di `staging`; il rilascio rifà CI, test, build e confronto con `staging`. Alternativa se si vogliono comunque i controlli su `main`: aprire la pull request con un token che faccia partire i workflow (token personale o app GitHub, che la squadra non ha): decisione di Andrea, da rivalutare.
```bash
REPO=sbotz17/avanza   # per Volty vedi sotto
cat > /tmp/ruleset-staging.json <<'JSON'
{ "name": "Protezione staging", "target": "branch", "enforcement": "active",
  "bypass_actors": [ { "actor_id": 5, "actor_type": "RepositoryRole", "bypass_mode": "always" } ],
  "conditions": { "ref_name": { "include": ["refs/heads/staging"], "exclude": [] } },
  "rules": [ { "type": "deletion" }, { "type": "non_fast_forward" },
    { "type": "pull_request", "parameters": { "required_approving_review_count": 0, "dismiss_stale_reviews_on_push": false, "require_code_owner_review": false, "require_last_push_approval": false, "required_review_thread_resolution": false } },
    { "type": "required_status_checks", "parameters": { "strict_required_status_checks_policy": false,
      "required_status_checks": [ {"context":"controlli"}, {"context":"zone-protette"}, {"context":"regole"}, {"context":"nessun-segreto"}, {"context":"blocco"} ] } } ] }
JSON
cat > /tmp/ruleset-main.json <<'JSON'
{ "name": "Protezione main", "target": "branch", "enforcement": "active",
  "bypass_actors": [ { "actor_id": 5, "actor_type": "RepositoryRole", "bypass_mode": "always" } ],
  "conditions": { "ref_name": { "include": ["refs/heads/main"], "exclude": [] } },
  "rules": [ { "type": "deletion" }, { "type": "non_fast_forward" },
    { "type": "pull_request", "parameters": { "required_approving_review_count": 0, "dismiss_stale_reviews_on_push": false, "require_code_owner_review": false, "require_last_push_approval": false, "required_review_thread_resolution": false } } ] }
JSON
gh api -X POST repos/$REPO/rulesets --input /tmp/ruleset-staging.json
gh api -X POST repos/$REPO/rulesets --input /tmp/ruleset-main.json
gh api repos/$REPO/rulesets --jq '.[].name'     # verifica
```
Volty (un solo ruleset per `main` e `staging`, come prima, con i controlli di Volty): usare il file dell'esempio precedente cambiando `REPO` e l'elenco `required_status_checks`; la promozione di Volty è un altro flusso.
**Prova obbligatoria dopo l'attivazione:** aprire una pull request di prova verso `staging` e controllare che tutti i controlli richiesti compaiano e passino. Se uno non compare mai (nome diverso), la PR resta bloccata: correggere il nome nel ruleset (`gh api -X PUT repos/$REPO/rulesets/<id>`), non togliere la protezione.
**Prova della promozione automatica (T-18):** Actions > promozione > *Run workflow* con `solo_verifica` = true: deve dire se la testa di `staging` sarebbe unita, senza unire. Poi osservare la prima promozione vera.
Nota: l'unione di `staging` → `main` deve essere "Create a merge commit" (con lo squash tutto viene trattato come sviluppo e il rilascio non ritrova il contenuto): la promozione usa `--merge`. L'impostazione *Allow auto-merge* NON serve (la promozione unisce direttamente); servono invece i *merge commit* consentiti e *Allow GitHub Actions to create and approve pull requests* (sezione 3). Il bot unisce con il proprio token: nessuna delle regole sopra lo ostacola (0 approvazioni, nessun controllo obbligatorio su `main`).

## 2. Ambiente `produzione` (senza revisore) e variabile degli sviluppi (Avanza; analogo per Volty se presente nei suoi workflow)
> **Eccezione temporanea:** per la PRIMA promozione (sezione 7) il revisore sull'ambiente `produzione` si TIENE (o si rimette) e si toglie solo dopo il primo rilascio riuscito.
Decisione di Andrea (24/10/2026): niente più tocco umano per i nuovi sviluppi. L'ambiente `produzione` è limitato al ramo `main` e **non ha revisore** (con un revisore fermerebbe ogni rilascio); la variabile `SVILUPPI_RICHIEDONO_APPROVAZIONE` vale `no`.
```bash
# ambiente produzione: solo main, NESSUN revisore
gh api -X PUT repos/sbotz17/avanza/environments/produzione --input - <<'JSON'
{ "deployment_branch_policy": {"protected_branches": false, "custom_branch_policies": true} }
JSON
gh api repos/sbotz17/avanza/environments/produzione/deployment-branch-policies --jq '.branch_policies[].name'   # se non c'e' main:
# gh api -X POST repos/sbotz17/avanza/environments/produzione/deployment-branch-policies -f name=main
gh api repos/sbotz17/avanza/environments/produzione --jq '[.protection_rules[]?.type]'   # verifica: NON deve contenere "required_reviewers"
gh variable set SVILUPPI_RICHIEDONO_APPROVAZIONE --body no -R sbotz17/avanza              # (anche se non impostata vale 'no')
gh variable list -R sbotz17/avanza | grep SVILUPPI
```
Se un ambiente `produzione` con revisore esiste gia', toglilo (Settings > Environments > produzione > Required reviewers) altrimenti ogni rilascio aspetta un tocco.
**Facoltativo, solo se Andrea vuole tornare all'approvazione manuale degli sviluppi:**
```bash
ID=$(gh api users/sbotz17 --jq .id)
gh api -X PUT repos/sbotz17/avanza/environments/produzione-sviluppi --input - <<JSON
{ "reviewers": [ {"type":"User","id":$ID} ], "deployment_branch_policy": {"protected_branches": false, "custom_branch_policies": true} }
JSON
gh api -X POST repos/sbotz17/avanza/environments/produzione-sviluppi/deployment-branch-policies -f name=main
gh api repos/sbotz17/avanza/environments/produzione-sviluppi --jq '.protection_rules'      # verifica: deve elencare il revisore
gh variable set SVILUPPI_APPROVAZIONE_CONFIGURATA --body si -R sbotz17/avanza              # SOLO dopo la verifica sopra
gh variable set SVILUPPI_RICHIEDONO_APPROVAZIONE --body si -R sbotz17/avanza               # riaccende il tocco
```
Regole di lettura della variabile: assente, vuota o `no` = nessun tocco; **qualunque altro valore** (anche un errore di battitura) = tocco richiesto, e se l'ambiente non e' configurato il rilascio degli sviluppi si ferma (meglio fermi che senza controllo).

## 3. Variabili e permessi di Actions (Avanza)
```bash
gh variable set PRODUZIONE_CONTROLLI_COMPLETI --body true -R sbotz17/avanza        # il bucket dei backup esiste (BUCKET_BACKUP_FIRESTORE gia' impostata)
gh variable set SQUADRA_CI_ATTIVA --body si -R sbotz17/avanza
gh api -X PUT repos/sbotz17/avanza/actions/permissions/workflow -f default_workflow_permissions=read -F can_approve_pull_request_reviews=true
gh variable list -R sbotz17/avanza
```
Per Volty: variabili `SQUADRA_CI_ATTIVA=si`, `NOME_PROGETTO=Volty` e quelle elencate in testa a `rilascio-produzione.yml`; i segreti Supabase/Vercel/WhatsApp li fornisce Andrea (mai in chat): `gh secret set NOME -R sbotz17/volty-flutter` (il valore si digita nel terminale). `GCS_BUCKET` e `GCS_CHIAVE_JSON` di Volty sono già impostati da Andrea.

## 4. CODEOWNERS (Avanza)
**Stato (T-18): NON attivo** (esiste solo `.github/CODEOWNERS.esempio`; nessun ruleset richiede la revisione dei Code Owners). Finché non lo è, gli script di promozione e rilascio (`.claude/scripts/`, `.github/`) possono essere cambiati da chi riesce a far entrare una modifica in `staging`, e il job `unione` li esegue con permessi di scrittura: rischio accettato (decisione di Andrea sull'autonomia, 24/10/2026), registrato in `registro-decisioni.md`.
`git mv .github/CODEOWNERS.esempio .github/CODEOWNERS` su un ramo `feature/`, pull request verso `staging`. Controllare il contenuto prima: deve nominare solo `@sbotz17`.

## 5. Webhook di Commerciali (aggiorna i task in Avanza)
Il segreto è lo stesso degli altri repository (Secret Manager, progetto `avanza-b62d7`, segreto `GITHUB_WEBHOOK_SECRET`). **Non stamparlo**: passarlo da variabile d'ambiente.
```bash
export WH_SECRET="$(gcloud secrets versions access latest --secret=GITHUB_WEBHOOK_SECRET --project=avanza-b62d7)"
gh api -X POST repos/sbotz17/commerciali/hooks --input - <<JSON
{ "name":"web", "active":true, "events":["push","pull_request","pull_request_review"],
  "config": { "url":"https://us-central1-avanza-b62d7.cloudfunctions.net/githubWebhook", "content_type":"json", "secret":"$WH_SECRET", "insecure_ssl":"0" } }
JSON
unset WH_SECRET
gh api repos/sbotz17/commerciali/hooks --jq '.[] | {id,events,url:.config.url}'     # verifica (il segreto non viene mostrato)
```
Prova: creare un ramo `test/T-N-prova` con un codice di task esistente in Avanza (progetto Commerciali) e controllare la nota sul task; poi cancellare il ramo di prova.

## 6. Avviso di budget Google Cloud (Avanza produzione, Avanza test, Volty backup)
```bash
BILLING=$(gcloud billing accounts list --format='value(name)' --filter=open=true | head -1)
for P in avanza-b62d7 avanza-test-c33ef volty-backup; do
  gcloud billing budgets create --billing-account="$BILLING" --display-name="Budget $P" \
    --filter-projects="projects/$P" --budget-amount=5EUR \
    --threshold-rule=percent=0.5 --threshold-rule=percent=0.9 --threshold-rule=percent=1.0
done
gcloud billing budgets list --billing-account="$BILLING"
```
Le notifiche vanno per email agli amministratori della fatturazione (comportamento predefinito).

## 7. PRIMA promozione `staging -> main` (non automatica) e accensione della promozione automatica (T-18)
`main` (`4e66a0e`) è molto indietro rispetto a `staging` (decine di file, regole Firestore della sottocollezione chat comprese). Il primo salto lo fa il `guardiano-produzione` con un amministratore, un passo alla volta, fermandosi al primo imprevisto:
1. **Backup verificato** prima di tutto: variabile `BUCKET_BACKUP_FIRESTORE` (bucket con blocco di conservazione) e `PRODUZIONE_CONTROLLI_COMPLETI=true`; provare il backup (azione `backup` di "Registra ore squadra" o `backup-giornaliero.yml`) fino a "IDENTICO". Senza backup verificato non si procede.
2. **Tag `ultimo-rilascio-ok`** su `main` `4e66a0e`, ma solo dopo aver verificato che coincida con ciò che è in produzione (sito e funzione).
3. **Revisore sull'ambiente `produzione`** per questo primo salto (eccezione temporanea): si toglie subito dopo.
4. **Unione manuale** della prima PR `staging -> main` con **merge commit**, in fascia a basso traffico. `SQUADRA_CI_ATTIVA` resta `no`, quindi **la PR non si apre da sola e va aperta a mano** (da `staging` verso `main`); il suo corpo non riporta la dimensione del salto: guardarla con `git diff --stat origin/main origin/staging` e controllare con `git diff origin/main origin/staging -- firestore.rules firestore.indexes.json` se le regole Firestore differiscono. Tra l'unione e il passo 5 il nuovo codice gira con le vecchie regole: la chat dei task può non funzionare in quella finestra (nessuna perdita di dati), quindi fascia a basso traffico e passo 5 subito dopo.
5. **Subito dopo**: pubblicare le regole con "Setup Firestore" da `main` (con backup) e controllare a mano login e chat nel browser; scrivere cosa non è provato.
6. **Solo dopo**: togliere il revisore, `SQUADRA_CI_ATTIVA=si`, poi Actions > promozione > *Run workflow* con `solo_verifica=true` (prova a secco), poi osservare la prima promozione vera.
Da quel momento la promozione è automatica con i controlli verdi, **tranne** quando `firestore.rules` o `firestore.indexes.json` differiscono tra `staging` e `main`: in quel caso si ferma ("serve una persona"): pubblicare le regole con Setup Firestore e unire a mano la PR.

## 8. Chiusura
Annotare in `docs/progetto/registro-decisioni.md` cosa è stato applicato e verificato, aggiornare `docs/progetto/ambienti.md` (rami protetti, ambienti), e riferire ad Andrea in italiano: cosa è fatto, cosa è stato verificato davvero e cosa no.

## 9. Collegamento di Avanza a TUTTI i progetti: segreto, GitHub App, accensione (T-20, fase 1)
**A cosa serve:** con una "GitHub App" tua, installata una volta su tutti i tuoi repository (anche quelli futuri), GitHub avvisa Avanza di ogni ramo, pull request e approvazione. Avanza crea da sola il progetto di un repository nuovo e aggiorna i task che hanno già il codice `T-N`. I task non si creano da soli. L'App ha permessi di **sola lettura** e si disinstalla con un clic.
**Quando farlo:** dopo che questa modifica è arrivata in produzione (promozione da `staging` a `main`) e con la seconda lettura fatta. Prima la funzione nuova non c'è.
**Cosa cambia di visibile:** (1) i progetti nuovi nascono da soli solo dopo l'accensione della Parte D e solo per eventi che arrivano dall'App (non dai vecchi webhook per-repository); (2) **le approvazioni di chi non è proprietario, membro o collaboratore di un repository non portano più un task a "Validato"**: resta solo una nota (prima qualunque approvazione bastava).
**Non verificato dalla squadra:** nomi esatti dei menu e dei campi di GitHub e di Google (i passi non sono stati provati su GitHub/Google reali); che il service account della CI possa creare segreti in Secret Manager (vedi A4); che GitHub inserisca sempre l'elenco degli argomenti (topic) nelle consegne; come si chiama il servizio nei log di Google (vedi C2). Se un nome non corrisponde, scrivi alla squadra: aggiorna questa pagina.

### Parte A — PRIMA il segreto (senza terminale)
Si fa prima dell'App, così l'App nasce già con un segreto che Avanza conosce e si può verificare tutto prima di installarla.
1. **Genera** una stringa casuale lunga (almeno 32 caratteri) con il tuo gestore di password. **Non scriverla in chat e non salvarla in un file del progetto.**
2. **Salvala su GitHub** come segreto: preferibile come *segreto dell'ambiente* `produzione` (repository `sbotz17/avanza` > **Settings** > **Environments** > **produzione** > **Add environment secret**), perché lì lo leggono solo i job che girano su `main`. In alternativa **Settings** > **Secrets and variables** > **Actions** > **New repository secret**. Nome esatto: `GH_APP_WEBHOOK_SECRET` (GitHub non accetta nomi che iniziano per `GITHUB_`).
3. **Scheda Actions** > a sinistra **Imposta segreto GitHub App** > **Run workflow** > `produzione`. Parte solo da `main` (e usa l'ambiente `produzione`). Aspetta il **segno verde**: vuol dire che il segreto è in Google Secret Manager con il nome `GITHUB_APP_WEBHOOK_SECRET` e che la funzione riesce a leggerlo.
4. **Se è rosso**, il messaggio dice cosa manca (di solito: il service account della CI non può creare segreti). Strada consigliata (**strada 2**, minimo privilegio): Google Cloud Console > **Secret Manager** > **Crea segreto**, nome `GITHUB_APP_WEBHOOK_SECRET`, incolla lo stesso valore; nella scheda **Autorizzazioni** del solo quel segreto, dai **Secret Manager Secret Accessor** al service account della funzione (`firebase-adminsdk-fbsvc@avanza-b62d7.iam.gserviceaccount.com`) se non lo ha già a livello di progetto. Motivo: l'*Accessor* permette solo di **leggere** quel segreto. In alternativa, se preferisci che sia il flusso a crearlo, dai al service account il ruolo **Secret Manager Admin**, rilancia il flusso e **toglilo subito dopo**: l'Admin permette di creare, modificare e cancellare *qualsiasi* segreto del progetto (comprese le chiavi di produzione), un potere che non deve restare a una chiave usata dalla CI.
5. Entro 2-10 minuti la funzione legge il segreto (copia in memoria a tempo). Se non c'è ancora, la funzione continua a funzionare solo con il segreto di oggi: nessun danno.

### Parte B — Creare l'App su GitHub e installarla (circa 10-15 minuti)
1. **Prima di installare, decidi quali repository NON vuoi in Avanza** (prove, copie, archivi): aggiungi l'argomento (topic) `avanza-ignora` a ciascuno (pagina del repository > ingranaggio accanto a "About" > Topics). Fork e repository archiviati sono già esclusi da soli.
2. Accedi a GitHub come `sbotz17`. Foto del profilo > **Settings** > in fondo a sinistra **Developer settings** > **GitHub Apps** > **New GitHub App**.
3. **GitHub App name:** `Avanza collegamento` (se occupato, aggiungi un suffisso). **Homepage URL:** `https://avanza-b62d7.web.app`.
4. **Webhook:** **Active** acceso. **Webhook URL:** `https://us-central1-avanza-b62d7.cloudfunctions.net/githubWebhook`. **Webhook secret:** incolla **lo stesso valore** della Parte A.
5. **Repository permissions**, tutti **Read-only**: **Metadata** (obbligatorio), **Contents**, **Pull requests**. Nessun altro permesso e **nessuno in scrittura**.
6. **Subscribe to events:** **Push**, **Pull request**, **Pull request review**, **Repository**. (Se un evento non compare, manca il permesso corrispondente.)
7. **Where can this GitHub App be installed?** **Only on this account**. Poi **Create GitHub App**.
8. Nella pagina dell'App, menu a sinistra **Install App** > **Install** accanto al tuo account > **All repositories** > **Install**.
9. **Non generare** la "Private key" né il "Client secret": non servono.

### Parte C — Controlli prima di accendere
1. Nella pagina dell'App > **Advanced** > **Recent deliveries**: deve comparire un `ping` con risposta **200** (se vedi 401 il segreto dell'App non coincide con quello della Parte A).
2. **Guarda nei log quali repository comparirebbero come progetti.** Google Cloud Console > **Logging** > **Logs Explorer**, progetto `avanza-b62d7`, cerca il testo `creazione_spenta` (la funzione `githubWebhook` è un servizio Cloud Run chiamato `githubwebhook`). Ogni riga riporta il nome del repository (`repo`). Per ogni repository che **non** vuoi come progetto, aggiungi il topic `avanza-ignora` (Parte B1) **prima** di accendere. Finché l'interruttore è spento non nasce nessun progetto: i log servono proprio a prepararsi.
3. Actions > **Registra ore squadra** > Run workflow: `action = collegamento-stato` (sola lettura). Dopo qualche evento sui due repository (un push o una pull request), **Avanza e Volty devono risultare `tracked`** nell'elenco "Repository noti". Se non lo sono, non accendere: i loro vecchi webhook non stanno arrivando.

### Parte D — Accendere la creazione automatica (la fa la squadra, con te al corrente)
Finché non è acceso, la funzione **non crea nulla** (si comporta come prima; aggancia solo l'identificativo del repository ai progetti già esistenti). I progetti nascono solo da eventi dell'App, non dai vecchi webhook per-repository.
1. Actions > **Registra ore squadra** > Run workflow, **dal ramo `main`**: `action = collegamento`, `note = attiva`, `email = bottiandrea83@gmail.com`, `github_url = https://github.com/sbotz17/avanza`. L'esito deve riportare l'uid `ffbUiSphhBW1qQi3lUzzvTfKXY32` e l'account ammesso `sbotz17`: **se l'uid è diverso, fermarsi**.
2. Il flusso **si ferma da solo** (con messaggio) se non gira da `main`, se il blocco di Andrea è attivo (`BLOCCO_SQUADRA` o `BLOCCO-SQUADRA.md`) o se manca il bucket dei backup (`BUCKET_BACKUP_FIRESTORE`) per `attiva` e `riammetti`. Prima di scrivere fa il backup verificato.
3. **Spegnere** (freno): `action = collegamento`, `note = spegni` (effetto entro un minuto; i progetti già creati restano; funziona anche senza bucket dei backup, ma solo da `main` e con il blocco non attivo). **Riammettere** un progetto eliminato: `note = riammetti`, `github_url` = indirizzo del repository. **Escludere** un repository: topic `avanza-ignora`.
4. Tetti: 5 progetti nuovi al giorno (predefinito). Fork e archiviati non creano mai progetti.

### Prova su ambiente di test (consigliata prima della Parte D in produzione)
Una GitHub App ha un solo indirizzo, quindi per provare sul test serve una **seconda App** (es. `Avanza collegamento (prova)`) con webhook URL `https://us-central1-avanza-test-c33ef.cloudfunctions.net/githubWebhook`, un segreto diverso, installata **solo su un repository di prova**. Il segreto GitHub si chiama `GH_APP_WEBHOOK_SECRET_TEST` e il flusso si lancia con `ambiente = test` (GitHub crea da solo l'ambiente `test` al primo uso).

### Tornare indietro
- Fermare la creazione: `collegamento` con `note = spegni`; oppure disinstalla l'App (GitHub > Settings > Applications > Installed GitHub Apps > Configure > Uninstall). I progetti già creati restano (sono dati: toglierli sarebbe una cancellazione reale, da decidere con te). I webhook dei singoli repository non vengono toccati.
- Togliere il segreto dell'App dal funzionamento: Google Cloud Console > **Secret Manager** > `GITHUB_APP_WEBHOOK_SECRET` > scheda **Versioni** > i tre puntini sulla versione > **Disabilita** (**non** "Distruggi": la distruzione è definitiva). La funzione tratta la versione disabilitata come "segreto assente" e continua a funzionare col solo segreto di oggi (comportamento coperto da test automatici; non provato su Google reale). Per riattivarla: **Abilita**.
