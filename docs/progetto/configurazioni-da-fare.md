# Configurazioni di GitHub e Google da applicare (per una sessione con accesso di amministratore)

**Perché esiste:** la sessione cloud della squadra NON può cambiare le impostazioni di GitHub (protezione dei rami, ambienti, variabili, webhook): il suo ambiente le blocca.
Una sessione di Claude Code sul computer di Andrea, con `gh` e `gcloud` autenticati come lui, può applicarle da sola. Autorizzazione: Andrea, 24/10/2026 ("fate tutto in autonomia").
Regole per chi esegue: un passo alla volta; **verifica dopo ogni passo** (comando di controllo indicato); **non stampare mai segreti** (né in terminale, né in log, né in chat); se un passo fallisce, fermati e riferisci l'errore a Andrea; annota ogni modifica in `docs/progetto/registro-decisioni.md`.
Prima di iniziare: `gh auth status` (account sbotz17, permessi `repo`, `workflow`, `admin:repo_hook`) e `gcloud auth list`.

## 1. Protezione dei rami (ruleset) — Avanza, Volty (e Commerciali se ha `main`)
Regole: nessuna cancellazione, nessun push forzato, solo pull request (0 approvazioni richieste: l'approvazione di Andrea vale sugli ambienti), controlli obbligatori. L'amministratore del repository può scavalcare (emergenze).
Controlli obbligatori (nomi esatti dei job):
- Avanza: `controlli`, `zone-protette`, `regole`, `nessun-segreto`, `blocco`.
- Volty: `test`, `nessun-segreto`, `migrazioni`, `zone-protette`, `blocco`.
```bash
REPO=sbotz17/avanza   # poi sbotz17/volty-flutter, con i controlli di Volty
cat > /tmp/ruleset.json <<'JSON'
{ "name": "Protezione main e staging", "target": "branch", "enforcement": "active",
  "bypass_actors": [ { "actor_id": 5, "actor_type": "RepositoryRole", "bypass_mode": "always" } ],
  "conditions": { "ref_name": { "include": ["refs/heads/main", "refs/heads/staging"], "exclude": [] } },
  "rules": [ { "type": "deletion" }, { "type": "non_fast_forward" },
    { "type": "pull_request", "parameters": { "required_approving_review_count": 0, "dismiss_stale_reviews_on_push": false, "require_code_owner_review": false, "require_last_push_approval": false, "required_review_thread_resolution": false } },
    { "type": "required_status_checks", "parameters": { "strict_required_status_checks_policy": false,
      "required_status_checks": [ {"context":"controlli"}, {"context":"zone-protette"}, {"context":"regole"}, {"context":"nessun-segreto"}, {"context":"blocco"} ] } } ] }
JSON
gh api -X POST repos/$REPO/rulesets --input /tmp/ruleset.json
gh api repos/$REPO/rulesets --jq '.[].name'     # verifica
```
**Prova obbligatoria dopo l'attivazione:** aprire una pull request di prova verso `staging` e controllare che tutti i controlli richiesti compaiano e passino. Se uno non compare mai (nome diverso), la PR resta bloccata: correggere il nome nel ruleset (`gh api -X PUT repos/$REPO/rulesets/<id>`), non togliere la protezione.
Nota: l'unione di `staging` → `main` deve essere "Create a merge commit" (con lo squash tutto viene trattato come sviluppo).

## 2. Ambiente `produzione` (senza revisore) e variabile degli sviluppi (Avanza; analogo per Volty se presente nei suoi workflow)
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

## 7. Chiusura
Annotare in `docs/progetto/registro-decisioni.md` cosa è stato applicato e verificato, aggiornare `docs/progetto/ambienti.md` (rami protetti, ambienti), e riferire ad Andrea in italiano: cosa è fatto, cosa è stato verificato davvero e cosa no.
