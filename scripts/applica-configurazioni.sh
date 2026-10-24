#!/usr/bin/env bash
# Applica le configurazioni di GitHub e Google descritte in docs/progetto/configurazioni-da-fare.md (T-16).
# Si lancia UNA volta dal computer di Andrea, con `gh` e `gcloud` gia' autenticati come lui:   bash scripts/applica-configurazioni.sh
# Regole: un passo alla volta, verifica dopo ogni passo, si ferma al primo errore, non stampa MAI segreti,
# e' idempotente (si puo' rilanciare: cio' che esiste gia' non viene duplicato ne' sovrascritto).
# Non cancella nulla e non tocca dati: solo protezioni dei rami, ambiente, variabili e un webhook.
set -euo pipefail

AVANZA=sbotz17/avanza
VOLTY=sbotz17/volty-flutter
COMMERCIALI=sbotz17/commerciali
FIREBASE_PROD=avanza-b62d7

passo() { printf '\n== %s ==\n' "$1"; }
ok()    { printf '   OK: %s\n' "$1"; }
avviso(){ printf '   ATTENZIONE: %s\n' "$1"; }

passo "0. Controlli iniziali"
gh auth status >/dev/null 2>&1 || { echo "gh non e' autenticato: lancia 'gh auth login'"; exit 1; }
[ "$(gh api "repos/$AVANZA" --jq '.permissions.admin')" = true ] || { echo "Serve il permesso di amministratore su $AVANZA"; exit 1; }
[ "$(gh api "repos/$VOLTY" --jq '.permissions.admin')" = true ] || { echo "Serve il permesso di amministratore su $VOLTY"; exit 1; }
ok "gh autenticato, amministratore su Avanza e Volty"

# --- 1. Protezione dei rami (ruleset) -------------------------------------------------------------
ruleset() {
  local repo="$1"; shift
  local checks=""; local c
  for c in "$@"; do checks="$checks{\"context\":\"$c\"},"; done
  checks="${checks%,}"
  local nomi; nomi="$(gh api "repos/$repo/rulesets" --jq '.[].name')"
  if grep -qx 'Protezione main e staging' <<<"$nomi"; then
    ok "$repo: la protezione dei rami esiste gia' (non la tocco)"; return
  fi
  gh api -X POST "repos/$repo/rulesets" --input - >/dev/null <<JSON
{ "name": "Protezione main e staging", "target": "branch", "enforcement": "active",
  "bypass_actors": [ { "actor_id": 5, "actor_type": "RepositoryRole", "bypass_mode": "always" } ],
  "conditions": { "ref_name": { "include": ["refs/heads/main", "refs/heads/staging"], "exclude": [] } },
  "rules": [ { "type": "deletion" }, { "type": "non_fast_forward" },
    { "type": "pull_request", "parameters": { "required_approving_review_count": 0, "dismiss_stale_reviews_on_push": false, "require_code_owner_review": false, "require_last_push_approval": false, "required_review_thread_resolution": false } },
    { "type": "required_status_checks", "parameters": { "strict_required_status_checks_policy": false, "required_status_checks": [ $checks ] } } ] }
JSON
  nomi="$(gh api "repos/$repo/rulesets" --jq '.[].name')"
  grep -qx 'Protezione main e staging' <<<"$nomi" || { echo "$repo: ruleset non trovato dopo la creazione"; exit 1; }
  ok "$repo: protezione dei rami creata"
}
passo "1. Protezione dei rami main e staging"
ruleset "$AVANZA" controlli zone-protette regole nessun-segreto blocco
ruleset "$VOLTY"  test nessun-segreto migrazioni zone-protette blocco
avviso "Dopo questo passo aprire una pull request di prova verso staging e controllare che tutti i controlli richiesti compaiano e passino."

# --- 2. Ambiente produzione (senza revisore) e variabile degli sviluppi ----------------------------
passo "2. Ambiente 'produzione' senza revisore (Avanza) e variabile degli sviluppi"
gh api -X PUT "repos/$AVANZA/environments/produzione" --input - >/dev/null <<'JSON'
{ "deployment_branch_policy": {"protected_branches": false, "custom_branch_policies": true} }
JSON
POLITICHE="$(gh api "repos/$AVANZA/environments/produzione/deployment-branch-policies" --jq '.branch_policies[].name')"
if ! grep -qx main <<<"$POLITICHE"; then
  gh api -X POST "repos/$AVANZA/environments/produzione/deployment-branch-policies" -f name=main >/dev/null
fi
REVISORE="$(gh api "repos/$AVANZA/environments/produzione" --jq '[.protection_rules[]?.type] | index("required_reviewers")')"
if [ "$REVISORE" != "null" ]; then
  avviso "l'ambiente 'produzione' ha un revisore: ogni rilascio aspetterebbe un tocco. Toglilo in Settings > Environments > produzione > Required reviewers."
else
  ok "ambiente produzione: solo main, nessun revisore"
fi
gh variable set SVILUPPI_RICHIEDONO_APPROVAZIONE --body no -R "$AVANZA"
ok "SVILUPPI_RICHIEDONO_APPROVAZIONE=no (Avanza)"

# --- 3. Variabili e permessi di Actions ----------------------------------------------------------
passo "3. Variabili e permessi di Actions"
gh variable set PRODUZIONE_CONTROLLI_COMPLETI --body true -R "$AVANZA"
gh variable set SQUADRA_CI_ATTIVA --body si -R "$AVANZA"
gh variable set SQUADRA_CI_ATTIVA --body si -R "$VOLTY"
gh variable set NOME_PROGETTO --body Volty -R "$VOLTY"
for R in "$AVANZA" "$VOLTY"; do
  gh api -X PUT "repos/$R/actions/permissions/workflow" -f default_workflow_permissions=read -F can_approve_pull_request_reviews=true >/dev/null
done
ok "variabili impostate; Actions puo' aprire pull request (Avanza e Volty)"
gh variable list -R "$AVANZA"
gh variable list -R "$VOLTY"

# --- 5. Webhook di Commerciali ---------------------------------------------------------------------
passo "5. Webhook di Commerciali (aggiorna i task in Avanza)"
if gh api "repos/$COMMERCIALI" >/dev/null 2>&1; then
  HOOKS="$(gh api "repos/$COMMERCIALI/hooks" --jq '.[].config.url')"
  if grep -q 'githubWebhook' <<<"$HOOKS"; then
    ok "il webhook di Commerciali esiste gia'"
  else
    WH_SECRET="$(gcloud secrets versions access latest --secret=GITHUB_WEBHOOK_SECRET --project="$FIREBASE_PROD")"
    gh api -X POST "repos/$COMMERCIALI/hooks" --input - >/dev/null <<JSON
{ "name":"web", "active":true, "events":["push","pull_request","pull_request_review"],
  "config": { "url":"https://us-central1-$FIREBASE_PROD.cloudfunctions.net/githubWebhook", "content_type":"json", "secret":"$WH_SECRET", "insecure_ssl":"0" } }
JSON
    unset WH_SECRET
    gh api "repos/$COMMERCIALI/hooks" --jq '.[] | {id,events,url:.config.url}'
    ok "webhook di Commerciali creato (il segreto non viene mostrato)"
  fi
else
  avviso "repository $COMMERCIALI non raggiungibile con il tuo account: webhook NON creato"
fi

# --- 6. Avvisi di budget Google Cloud --------------------------------------------------------------
passo "6. Avvisi di budget Google Cloud (5 EUR: avvisi al 50%, 90%, 100%)"
BILLING="$(gcloud billing accounts list --format='value(name)' --filter=open=true | head -1)"
if [ -z "$BILLING" ]; then
  avviso "nessun account di fatturazione aperto trovato: budget NON creati"
else
  ESISTENTI="$(gcloud billing budgets list --billing-account="$BILLING" --format='value(displayName)' 2>/dev/null || true)"
  for P in avanza-b62d7 avanza-test-c33ef volty-backup; do
    if grep -qx "Budget $P" <<<"$ESISTENTI"; then
      ok "budget gia' presente per $P"
    else
      gcloud billing budgets create --billing-account="$BILLING" --display-name="Budget $P" \
        --filter-projects="projects/$P" --budget-amount=5EUR \
        --threshold-rule=percent=0.5 --threshold-rule=percent=0.9 --threshold-rule=percent=1.0 >/dev/null
      ok "budget creato per $P"
    fi
  done
  gcloud billing budgets list --billing-account="$BILLING" --format='table(displayName,amount.specifiedAmount.units)'
fi

passo "Fatto"
echo "Riporta a Claude l'intero output di questo script (non contiene segreti)."
echo "Non fatto da questo script: CODEOWNERS (pull request), segreti di Volty, prova della protezione con una pull request."
