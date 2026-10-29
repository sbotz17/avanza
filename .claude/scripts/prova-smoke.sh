#!/usr/bin/env bash
# Prova in locale di smoke-produzione.sh con un `curl` FINTO (nessuna rete, nessun segreto): il sito risponde sempre bene, il codice HTTP della
# funzione githubWebhook (POST con firma sbagliata / POST senza firma) e' deciso dal caso. Esito 0 = tutti i casi si comportano come atteso.
# Casi (T-20): 401 -> ok; 500 con firma sbagliata -> ok con AVVISO (segreto non leggibile: prova non conclusiva); 404, 502, 000 -> fallito;
#              senza firma 401 -> ok; senza firma 500 o 404 -> fallito.
# Uso: bash .claude/scripts/prova-smoke.sh [percorso-di-smoke-produzione.sh]   (default: quello del repository; serve per provare una versione vecchia)
# LIMITE: il curl finto riproduce la FORMA delle risposte, non la funzione vera (che il 401 senza firma arrivi prima di Secret Manager e' letto nel codice:
# functions/src/lib/authenticate.ts, riga "Senza firma non si consulta nemmeno Secret Manager", e provato da authenticate.test.ts).
set -uo pipefail
RADICE="$(git rev-parse --show-toplevel)"
SMOKE="${1:-$RADICE/.claude/scripts/smoke-produzione.sh}"
BASE_TMP="$(mktemp -d)"; trap 'rm -rf "$BASE_TMP"' EXIT
FALLITI=0; TOTALE=0
BIN="$BASE_TMP/bin"; mkdir -p "$BIN"
cat > "$BIN/curl" <<'STUB'
#!/usr/bin/env bash
# curl finto: sito sempre in regola; la funzione risponde con i codici di $POST_FIRMA / $POST_NOFIRMA ("000" = non raggiungibile)
OUT=""; HDR=""; W=""; URL=""; FIRMA=no; METODO=GET; A=("$@")
for ((i=0; i<${#A[@]}; i++)); do
  case "${A[$i]}" in
    -o) OUT="${A[$((i+1))]}"; i=$((i+1)) ;;
    -D) HDR="${A[$((i+1))]}"; i=$((i+1)) ;;
    -w) W="${A[$((i+1))]}"; i=$((i+1)) ;;
    -X) METODO="${A[$((i+1))]}"; i=$((i+1)) ;;
    -H) case "${A[$((i+1))]}" in x-hub-signature-256:*) FIRMA=si ;; esac; i=$((i+1)) ;;
    -m|-d) i=$((i+1)) ;;
    -*) ;;
    *) URL="${A[$i]}" ;;
  esac
done
scrivi() { [ -n "$OUT" ] && [ "$OUT" != /dev/null ] && cat > "$OUT" || cat > /dev/null; }
codice() { if [ "$1" = 000 ]; then echo "curl: (7) Failed to connect (finto)" >&2; fi; [ -n "$W" ] && printf '%s' "$1"; exit 0; }
case "$URL" in
  "$FUNZIONE_URL"*)
     if [ "$METODO" != POST ]; then echo '{}' | scrivi; codice 405; fi
     if [ "$FIRMA" = si ]; then C="$POST_FIRMA"; else C="$POST_NOFIRMA"; fi
     echo '{}' | scrivi; codice "$C" ;;
  *)
     case "$URL" in
       *main.dart.js*)  { head -c 120000 /dev/zero | tr '\0' a; echo " avanza-b62d7"; } | scrivi; TIPO="application/javascript" ;;
       *flutter_bootstrap.js*) echo "// bootstrap" | scrivi; TIPO="application/javascript" ;;
       *flutter_service_worker.js*) echo "<html>flutter_bootstrap.js</html>" | scrivi; TIPO="text/html" ;;
       *) echo "<html><script src=flutter_bootstrap.js></script></html>" | scrivi; TIPO="text/html" ;;
     esac
     [ -n "$HDR" ] && printf 'HTTP/2 200\r\ncontent-type: %s\r\ncache-control: no-cache\r\n\r\n' "$TIPO" > "$HDR"
     codice 200 ;;
esac
STUB
chmod +x "$BIN/curl"
export PATH="$BIN:$PATH" URL_PRODUZIONE="https://sito.finto" FUNZIONE_URL="https://funzione.finta/githubWebhook" SMOKE_TENTATIVI=1 SMOKE_ATTESA=0 SMOKE_LOGIN=no

caso() {  # $1 descrizione, $2 codice POST con firma, $3 codice POST senza firma, $4 rc atteso, $5 testo atteso nel log ("" = nessuno), $6 testo VIETATO nel log
  TOTALE=$((TOTALE+1)); local RC
  POST_FIRMA="$2" POST_NOFIRMA="$3" bash "$SMOKE" > "$BASE_TMP/log.txt" 2>&1; RC=$?
  if [ "$RC" = "$4" ] && { [ -z "$5" ] || grep -q -- "$5" "$BASE_TMP/log.txt"; } && { [ -z "${6:-}" ] || ! grep -q -- "$6" "$BASE_TMP/log.txt"; }; then
    echo "OK    $1 (rc=$RC)"
  else FALLITI=$((FALLITI+1)); echo "FALLITO $1: atteso rc=$4 e '$5', ottenuto rc=$RC"; sed 's/^/      | /' "$BASE_TMP/log.txt" | tail -n 8; fi
  export POST_FIRMA POST_NOFIRMA
}
export POST_FIRMA=401 POST_NOFIRMA=401
caso "firma sbagliata 401, senza firma 401 -> tutte le prove superate"            401 401 0 "TUTTE LE PROVE SUPERATE" "AVVISO"
caso "firma sbagliata 500 (segreto non leggibile) -> OK con AVVISO, non fallisce"  500 401 0 "AVVISO ATTENZIONE: POST con firma sbagliata -> HTTP 500" "ALMENO UNA PROVA FALLITA"
caso "firma sbagliata 500 -> esito finale 'con avvisi'"                            500 401 0 "PROVE SUPERATE, MA CON AVVISI" ""
caso "firma sbagliata 404 -> fallito"                                              404 401 1 "ALMENO UNA PROVA FALLITA" ""
caso "firma sbagliata 502 -> fallito"                                              502 401 1 "ALMENO UNA PROVA FALLITA" ""
caso "firma sbagliata 503 -> fallito"                                              503 401 1 "ALMENO UNA PROVA FALLITA" ""
caso "firma sbagliata 000 (non raggiungibile) -> fallito"                          000 401 1 "ALMENO UNA PROVA FALLITA" ""
caso "firma sbagliata 200 (la funzione accetta una firma falsa!) -> fallito"       200 401 1 "ALMENO UNA PROVA FALLITA" ""
caso "senza firma 401 e firma 401 -> la prova senza firma passa"                   401 401 0 "OK    funzione githubWebhook: senza firma" ""
caso "senza firma 500 -> fallito (nemmeno senza segreti la funzione risponde)"     401 500 1 "senza firma -> HTTP 500" ""
caso "senza firma 404 -> fallito"                                                  401 404 1 "senza firma -> HTTP 404" ""
caso "senza firma 200 -> fallito"                                                  401 200 1 "ALMENO UNA PROVA FALLITA" ""
caso "firma 500 e senza firma 500 -> fallito (l'avviso non nasconde il guasto)"    500 500 1 "ALMENO UNA PROVA FALLITA" ""
SMOKE_FUNZIONE=no caso "SMOKE_FUNZIONE=no -> prove della funzione saltate, il resto passa" 404 404 0 "SALTATA la prova della funzione" ""

echo
echo "Casi: $TOTALE, falliti: $FALLITI"
[ "$FALLITI" = 0 ]
