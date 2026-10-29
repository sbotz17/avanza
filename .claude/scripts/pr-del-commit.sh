#!/usr/bin/env bash
# Raccoglie le pull request che compongono i commit di un intervallo (cio' che e' entrato in staging e non e' ancora in produzione)
# e scrive l'elenco nel formato letto da classifica-modifica.py:  {"commit_senza_pr": 0|1, "pr": [{numero, ramo, etichette, titolo, corpo}]}
# Script UNICO usato da promozione.yml e da classifica-rilascio.sh (prima la logica era copiata in due posti).
#
# Uso:  pr-del-commit.sh <intervallo-git> <file-di-uscita.json>        es.  pr-del-commit.sh origin/main..HEAD /tmp/richieste.json
# Variabili: GH_TOKEN, GITHUB_REPOSITORY (oppure REPO).
# Regole (nel dubbio la strada prudente = "sviluppo"):
#   - la pull request di PROMOZIONE (ramo di partenza staging, oppure destinata a main) NON conta: e' il "contenitore" dei commit, non una modifica,
#     e per classifica-modifica.py sarebbe sempre "ramo non da correzione". I commit che restano senza altre PR risultano "senza pull request";
#   - se GitHub non risponde per un commit, quel commit e' trattato come senza pull request (commit_senza_pr = 1);
#   - nessuna scrittura su GitHub: solo letture. Esito 0 se il file e' stato scritto, 1 se non si riesce a produrlo.
# NON PROVATO contro l'API vera di GitHub: provato con un `gh` finto (.claude/scripts/ non ha ancora un test automatico per questo).
set -uo pipefail
RANGE="${1:-}"; OUT="${2:-}"
[ -n "$RANGE" ] && [ -n "$OUT" ] || { echo "Uso: pr-del-commit.sh <intervallo-git> <file-di-uscita.json>" >&2; exit 2; }
REPO="${GITHUB_REPOSITORY:-${REPO:-}}"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
: > "$TMP/lista.jsonl"; SENZA=0
COMMITS="$(git rev-list --no-merges "$RANGE" 2>/dev/null)" || { echo "Intervallo non valido: $RANGE" >&2; exit 1; }
for c in $COMMITS; do
  if [ -z "$REPO" ] || ! gh api "repos/$REPO/commits/$c/pulls" > "$TMP/p.json" 2>/dev/null; then
    echo "AVVISO: pull request del commit $c non leggibili: trattato come modifica senza pull request" >&2
    SENZA=1; continue
  fi
  # si tolgono le PR di promozione PRIMA di contare: un commit con la sola PR di promozione e' "senza pull request"
  if ! jq -c '[.[] | select(.head.ref != "staging" and .base.ref != "main")] | .[] | {numero:.number, ramo:.head.ref, etichette:[.labels[].name], titolo:.title, corpo:(.body // "")}' "$TMP/p.json" > "$TMP/c.jsonl" 2>/dev/null; then
    echo "AVVISO: risposta non leggibile per il commit $c: trattato come modifica senza pull request" >&2
    SENZA=1; continue
  fi
  [ -s "$TMP/c.jsonl" ] || SENZA=1
  cat "$TMP/c.jsonl" >> "$TMP/lista.jsonl"
done
jq -s --argjson s "$SENZA" '{commit_senza_pr:$s, pr:(unique_by(.numero))}' "$TMP/lista.jsonl" > "$OUT" 2>/dev/null || { echo "Impossibile scrivere $OUT" >&2; exit 1; }
