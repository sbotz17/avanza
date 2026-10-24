#!/usr/bin/env bash
# Applica le configurazioni di GitHub e Google descritte in docs/progetto/configurazioni-da-fare.md (T-16).
# Si lancia UNA volta dal computer di Andrea, con `gh` e `gcloud` gia' autenticati come lui:   bash scripts/applica-configurazioni.sh
# Regole: un passo alla volta, verifica dopo ogni passo, non stampa MAI segreti, e' idempotente
# (si puo' rilanciare: cio' che esiste gia' non viene duplicato ne' sovrascritto). Non cancella nulla e non tocca dati.
# Un passo che non puo' essere eseguito (es. protezione dei rami su un repository privato senza piano a pagamento)
# viene dichiarato con "ATTENZIONE" e lo script prosegue: l'elenco finale dice cosa NON e' stato fatto.
set -uo pipefail

AVANZA=sbotz17/avanza
VOLTY=sbotz17/volty-flutter
COMMERCIALI=sbotz17/commerciali
FIREBASE_PROD=avanza-b62d7
NON_FATTO=()
RULESET_BLOCCATI=""

passo() { printf '\n== %s ==\n' "$1"; }
ok()    { printf '   OK: %s\n' "$1"; }
avviso(){ printf '   ATTENZIONE: %s\n' "$1"; NON_FATTO+=("$1"); }
vecchio_valore() { # stampa il valore attuale di una variabile prima di cambiarla
  local nome="$1" repo="$2" v
  v="$(gh variable get "$nome" -R "$repo" 2>/dev/null || true)"
  printf '   %s (%s): valore precedente = %s\n' "$nome" "$repo" "${v:-<non impostata>}"
}
imposta_variabile() { # nome valore repo
  vecchio_valore "$1" "$3"
  if gh variable set "$1" --body "$2" -R "$3" >/dev/null 2>&1; then ok "$1=$2 ($3)"; else avviso "variabile $1 NON impostata su $3"; fi
}

passo "0. Controlli iniziali"
gh auth status >/dev/null 2>&1 || { echo "gh non e' autenticato: lancia 'gh auth login'"; exit 1; }
[ "$(gh api "repos/$AVANZA" --jq '.permissions.admin')" = true ] || { echo "Serve il permesso di amministratore su $AVANZA"; exit 1; }
ok "gh autenticato, amministratore su Avanza"
VOLTY_ADMIN=no
[ "$(gh api "repos/$VOLTY" --jq '.permissions.admin' 2>/dev/null || true)" = true ] && VOLTY_ADMIN=si
[ "$VOLTY_ADMIN" = si ] && ok "amministratore anche su Volty" || avviso "non risulti amministratore su $VOLTY: i passi di Volty vengono saltati"

# --- 1. Protezione dei rami (ruleset) -------------------------------------------------------------
# Due regole distinte: su STAGING controlli obbligatori; su MAIN niente controlli obbligatori, perche' la pull request di promozione
# la apre la CI con il token del flusso e le pull request aperte cosi' non fanno partire i controlli (rimarrebbe bloccata per sempre).
# main riceve solo cio' che e' gia' passato da staging (job "verso-produzione-solo-da-staging" e rilascio con prove): qui si vieta
# solo cancellazione, push forzato e push diretto (si entra solo con pull request).
crea_ruleset() { # repo nome ramo [controlli...]
  local repo="$1" nome="$2" ramo="$3"; shift 3
  local nomi
  case " $RULESET_BLOCCATI " in *" $repo "*) return 0;; esac
  if ! nomi="$(gh api "repos/$repo/rulesets" --jq '.[].name' 2>/tmp/ruleset-errore.$$)"; then
    if grep -qi 'upgrade to github pro\|make this repository public' /tmp/ruleset-errore.$$ 2>/dev/null; then
      avviso "$repo: protezione dei rami NON disponibile (repository privato senza piano a pagamento). Decisione di Andrea: passare a GitHub Pro o accettare l'assenza di protezione."
    else
      avviso "$repo: impossibile leggere le protezioni dei rami (errore GitHub)"
    fi
    RULESET_BLOCCATI="$RULESET_BLOCCATI $repo"; rm -f /tmp/ruleset-errore.$$; return 0
  fi
  rm -f /tmp/ruleset-errore.$$
  if grep -qx "$nome" <<<"$nomi"; then ok "$repo: '$nome' esiste gia' (non la tocco; controlla che contenga i controlli giusti)"; return 0; fi
  local checks="" c rule_checks=""
  for c in "$@"; do checks="$checks{\"context\":\"$c\"},"; done
  checks="${checks%,}"
  if [ -n "$checks" ]; then
    rule_checks=", { \"type\": \"required_status_checks\", \"parameters\": { \"strict_required_status_checks_policy\": false, \"required_status_checks\": [ $checks ] } }"
  fi
  if gh api -X POST "repos/$repo/rulesets" --input - >/dev/null <<JSON
{ "name": "$nome", "target": "branch", "enforcement": "active",
  "bypass_actors": [ { "actor_id": 5, "actor_type": "RepositoryRole", "bypass_mode": "always" } ],
  "conditions": { "ref_name": { "include": ["refs/heads/$ramo"], "exclude": [] } },
  "rules": [ { "type": "deletion" }, { "type": "non_fast_forward" },
    { "type": "pull_request", "parameters": { "required_approving_review_count": 0, "dismiss_stale_reviews_on_push": false, "require_code_owner_review": false, "require_last_push_approval": false, "required_review_thread_resolution": false } }
    $rule_checks ] }
JSON
  then
    nomi="$(gh api "repos/$repo/rulesets" --jq '.[].name' 2>/dev/null || true)"
    if grep -qx "$nome" <<<"$nomi"; then ok "$repo: '$nome' creata"; else avviso "$repo: '$nome' non trovata dopo la creazione"; fi
  else
    avviso "$repo: creazione di '$nome' FALLITA"
  fi
}
passo "1. Protezione dei rami (Avanza)"
crea_ruleset "$AVANZA" "Protezione staging" staging controlli zone-protette regole nessun-segreto blocco
crea_ruleset "$AVANZA" "Protezione main" main
passo "1b. Protezione dei rami (Volty)"
if [ "$VOLTY_ADMIN" = si ]; then
  # Se Volty e' privato e senza piano a pagamento, GitHub rifiuta: lo si dichiara e si prosegue.
  # Se si attiva (GitHub Pro), la promozione di Volty che fa push diretto su main con la chiave PROD_DEPLOY_KEY va riesaminata
  # (la chiave non e' tra gli attori che possono scavalcare la protezione): vedi docs/progetto/configurazioni-da-fare.md.
  crea_ruleset "$VOLTY" "Protezione staging" staging test nessun-segreto migrazioni zone-protette blocco
  crea_ruleset "$VOLTY" "Protezione main" main
fi
echo "   Dopo questo passo: aprire una pull request di prova verso staging e controllare che tutti i controlli richiesti compaiano e passino."

# --- 2. Ambiente produzione (senza revisore) e variabile degli sviluppi ----------------------------
passo "2. Ambiente 'produzione' senza revisore (Avanza) e variabile degli sviluppi"
if gh api "repos/$AVANZA/environments/produzione" >/dev/null 2>&1; then
  ok "ambiente produzione gia' presente (non lo riscrivo)"
else
  if gh api -X PUT "repos/$AVANZA/environments/produzione" --input - >/dev/null 2>&1 <<'JSON'
{ "deployment_branch_policy": {"protected_branches": false, "custom_branch_policies": true} }
JSON
  then ok "ambiente produzione creato"; else avviso "ambiente produzione NON creato"; fi
fi
POLITICHE="$(gh api "repos/$AVANZA/environments/produzione/deployment-branch-policies" --jq '.branch_policies[].name' 2>/dev/null || true)"
if ! grep -qx main <<<"$POLITICHE"; then
  gh api -X POST "repos/$AVANZA/environments/produzione/deployment-branch-policies" -f name=main >/dev/null 2>&1 \
    && ok "ambiente produzione limitato al ramo main" || avviso "limite al ramo main sull'ambiente produzione NON impostato"
fi
REVISORE="$(gh api "repos/$AVANZA/environments/produzione" --jq '[.protection_rules[]?.type] | index("required_reviewers")' 2>/dev/null || echo null)"
if [ "$REVISORE" != "null" ]; then
  avviso "l'ambiente 'produzione' ha un revisore: ogni rilascio aspetterebbe un tocco. Toglilo in Settings > Environments > produzione > Required reviewers."
else
  ok "ambiente produzione: nessun revisore"
fi
imposta_variabile SVILUPPI_RICHIEDONO_APPROVAZIONE no "$AVANZA"

# --- 3. Variabili e permessi di Actions ----------------------------------------------------------
passo "3. Variabili e permessi di Actions (Avanza)"
imposta_variabile PRODUZIONE_CONTROLLI_COMPLETI true "$AVANZA"
imposta_variabile SQUADRA_CI_ATTIVA si "$AVANZA"
echo "   Nota: PRODUZIONE_CONTROLLI_COMPLETI=true attiva i controlli completi di rilascio, mai provati su GitHub: il primo rilascio potrebbe fermarsi (e' il comportamento voluto, meglio fermi che senza controllo)."
gh api -X PUT "repos/$AVANZA/actions/permissions/workflow" -f default_workflow_permissions=read -F can_approve_pull_request_reviews=true >/dev/null 2>&1 \
  && ok "Actions di Avanza puo' aprire pull request (permessi di lettura per default)" || avviso "permessi di Actions di Avanza NON impostati"
gh variable list -R "$AVANZA"

passo "3b. Variabili di Volty (solo se i segreti di produzione ci sono)"
if [ "$VOLTY_ADMIN" = si ]; then
  SEGRETI_VOLTY="$(gh secret list -R "$VOLTY" --json name --jq '.[].name' 2>/dev/null || true)"
  imposta_variabile NOME_PROGETTO Volty "$VOLTY"
  if grep -qx SUPABASE_DB_URL <<<"$SEGRETI_VOLTY" && grep -qx GCS_BUCKET <<<"$SEGRETI_VOLTY" && grep -qx GCS_CHIAVE_JSON <<<"$SEGRETI_VOLTY"; then
    imposta_variabile SQUADRA_CI_ATTIVA si "$VOLTY"
  else
    avviso "Volty: SQUADRA_CI_ATTIVA NON impostata perche' mancano segreti di produzione (SUPABASE_DB_URL, GCS_BUCKET, GCS_CHIAVE_JSON): senza backup il rilascio non deve partire. Reimpostala dopo aver salvato i segreti."
  fi
  gh variable list -R "$VOLTY"
fi

# --- 5. Webhook di Commerciali ---------------------------------------------------------------------
passo "5. Webhook di Commerciali (aggiorna i task in Avanza)"
if gh api "repos/$COMMERCIALI" >/dev/null 2>&1; then
  if HOOKS="$(gh api "repos/$COMMERCIALI/hooks" --jq '.[].config.url' 2>/dev/null)"; then
    if grep -q 'githubWebhook' <<<"$HOOKS"; then
      ok "il webhook di Commerciali esiste gia'"
    else
      if WH_SECRET="$(gcloud secrets versions access latest --secret=GITHUB_WEBHOOK_SECRET --project="$FIREBASE_PROD" 2>/dev/null)" && [ -n "$WH_SECRET" ]; then
        # il corpo JSON e' costruito con jq (nessun problema con caratteri speciali) e passato da stdin: il segreto non appare in argomenti ne' in output
        if jq -n --arg url "https://us-central1-$FIREBASE_PROD.cloudfunctions.net/githubWebhook" --arg secret "$WH_SECRET" \
             '{name:"web", active:true, events:["push","pull_request","pull_request_review"], config:{url:$url, content_type:"json", secret:$secret, insecure_ssl:"0"}}' \
           | gh api -X POST "repos/$COMMERCIALI/hooks" --input - >/dev/null 2>&1; then
          ok "webhook di Commerciali creato (il segreto non viene mostrato)"
        else
          avviso "webhook di Commerciali NON creato (errore GitHub)"
        fi
      else
        avviso "webhook di Commerciali NON creato: non riesco a leggere il segreto GITHUB_WEBHOOK_SECRET con gcloud (login o permessi)"
      fi
      unset WH_SECRET
    fi
  else
    avviso "Commerciali: impossibile leggere i webhook (permessi): webhook NON verificato"
  fi
else
  avviso "repository $COMMERCIALI non raggiungibile con il tuo account: webhook NON creato"
fi

# --- 6. Avvisi di budget Google Cloud --------------------------------------------------------------
passo "6. Avvisi di budget Google Cloud (5 EUR: avvisi al 50%, 90%, 100%)"
BILLING="$(gcloud billing accounts list --format='value(name)' --filter=open=true --limit=1 2>/dev/null || true)"
if [ -z "$BILLING" ]; then
  avviso "nessun account di fatturazione aperto trovato (o gcloud non autenticato): budget NON creati"
else
  ESISTENTI="$(gcloud billing budgets list --billing-account="$BILLING" --format='value(displayName)' 2>/dev/null || true)"
  for P in avanza-b62d7 avanza-test-c33ef volty-backup; do
    if grep -qx "Budget $P" <<<"$ESISTENTI"; then
      ok "budget gia' presente per $P"
    elif gcloud billing budgets create --billing-account="$BILLING" --display-name="Budget $P" \
           --filter-projects="projects/$P" --budget-amount=5EUR \
           --threshold-rule=percent=0.5 --threshold-rule=percent=0.9 --threshold-rule=percent=1.0 >/dev/null 2>&1; then
      ok "budget creato per $P"
    else
      avviso "budget per $P NON creato (progetto non collegato alla fatturazione o permessi mancanti)"
    fi
  done
  gcloud billing budgets list --billing-account="$BILLING" --format='table(displayName,amount.specifiedAmount.units)' 2>/dev/null || true
fi

passo "Riepilogo"
if [ "${#NON_FATTO[@]}" -eq 0 ]; then
  echo "Tutti i passi dello script sono andati a buon fine."
else
  echo "Passi NON eseguiti o da controllare:"
  for m in "${NON_FATTO[@]}"; do echo " - $m"; done
fi
echo "Riporta a Claude l'intero output di questo script (non contiene segreti)."
echo "Non fatto da questo script: CODEOWNERS (pull request), segreti di Volty, prova della protezione con una pull request verso staging."
