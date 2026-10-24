#!/usr/bin/env bash
# Classifica CIO' CHE STA PER ANDARE IN PRODUZIONE (correzione oppure nuovo sviluppo) rifacendo i conti sul serio al momento del rilascio,
# con lo stesso criterio della promozione (classifica-modifica.py): non ci si fida dell'etichetta messa sulla pull request di promozione.
# I nuovi sviluppi hanno bisogno della validazione di Andrea (ambiente GitHub produzione-sviluppi): lo applica rilascio-produzione.yml.
# Nel dubbio (base non trovata, elenco non leggibile, nessuna modifica) il risultato e' "sviluppo".
#
# Confronto: dall'ultima versione buona (tag ultimo-rilascio-ok, se e' antenato di HEAD), altrimenti dal commit precedente di main
# (variabile PRIMA = github.event.before), altrimenti dal primo genitore di HEAD, ma SOLO se HEAD e' un commit di unione (due genitori); in ogni altro caso "sviluppo".
# Variabili: GH_TOKEN, GITHUB_REPOSITORY, PRIMA (facoltativa), GITHUB_OUTPUT.
# Scrive: tipo=correzione|sviluppo, motivo=..., regole_cambiate=si|no, base=<riferimento usato>.
# Le pull request di promozione (staging -> main) non contano: vedi pr-del-commit.sh.
# NON PROVATO su GitHub (le chiamate gh api non sono eseguibili qui); la parte git e la classificazione sono state provate su un repository di esempio.
set -uo pipefail
OUT="${GITHUB_OUTPUT:-/dev/null}"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
fine() { # $1 tipo, $2 motivo, $3 regole, $4 base
  { echo "tipo=$1"; echo "motivo=$2"; echo "regole_cambiate=${3:-no}"; echo "base=${4:-}"; } >> "$OUT"
  echo "CLASSIFICAZIONE: $1 ($2)"; exit 0
}
git fetch --tags --force --quiet 2>/dev/null || true
BASE=""
if git rev-parse -q --verify refs/tags/ultimo-rilascio-ok >/dev/null 2>&1 && git merge-base --is-ancestor refs/tags/ultimo-rilascio-ok HEAD 2>/dev/null; then
  BASE="refs/tags/ultimo-rilascio-ok"
elif [ -n "${PRIMA:-}" ] && ! echo "$PRIMA" | grep -qE '^0+$' && git cat-file -e "${PRIMA}^{commit}" 2>/dev/null; then
  BASE="$PRIMA"
elif git rev-parse -q --verify 'HEAD^2' >/dev/null 2>&1; then
  # ripiego (avvio manuale, nessun tag): solo se HEAD e' un commit di unione (promozione), altrimenti si esaminerebbe soltanto l'ultimo commit
  BASE="$(git rev-parse -q --verify 'HEAD^1' 2>/dev/null || true)"
fi
[ -n "$BASE" ] || fine sviluppo "versione in produzione non individuabile" no ""

REGOLE=no
if ! git diff --quiet "$BASE" HEAD -- firestore.rules firestore.indexes.json 2>/dev/null; then REGOLE=si; fi

# raccolta delle pull request dei commit: script condiviso con promozione.yml (esclude la PR di promozione staging -> main)
bash .claude/scripts/pr-del-commit.sh "$BASE..HEAD" "$TMP/richieste.json" \
  || fine sviluppo "elenco delle pull request non leggibile" "$REGOLE" "$BASE"

# script e regole di classificazione: quelli di HEAD (che e' main, gia' protetto)
GITHUB_OUTPUT="$TMP/cls.out" python3 .claude/scripts/classifica-modifica.py "$BASE" "$TMP/richieste.json" .claude/zone-protette.json | tail -n 12
TIPO="$(grep '^tipo=' "$TMP/cls.out" 2>/dev/null | tail -1 | cut -d= -f2)"
MOT="$(grep '^motivo=' "$TMP/cls.out" 2>/dev/null | tail -1 | cut -d= -f2-)"
[ "$TIPO" = "correzione" ] || TIPO=sviluppo
fine "$TIPO" "${MOT:-classificazione non disponibile}" "$REGOLE" "$BASE"
