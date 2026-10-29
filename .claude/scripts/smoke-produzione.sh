#!/usr/bin/env bash
# PROVA RAPIDA (smoke test) del sito e della funzione di produzione dopo un rilascio. SOLA LETTURA: nessun dato viene scritto o modificato.
#   - il sito risponde 200 (anche sulla pagina di accesso /login) e serve la pagina dell'app;
#   - main.dart.js e' JavaScript vero (non la pagina di ripiego), contiene la configurazione di PRODUZIONE (avanza-b62d7) e nessuna traccia del TEST (avanza-test);
#   - intestazioni di cache corrette (no-cache su index.html, main.dart.js, flutter_bootstrap.js): altrimenti gli utenti vedono versioni vecchie;
#   - nessun service worker attivo (build con --pwa-strategy=none);
#   - la funzione githubWebhook risponde: GET -> 405; POST con firma sbagliata -> 401 (legge il segreto da Secret Manager); un 500 e' solo AVVISO
#     (segreto non leggibile: prova non conclusiva, la verifica del segreto storico e' di E2E Webhook dopo il rilascio), 404/502/503/timeout = funzione rotta;
#     POST SENZA firma -> 401 (risposta data prima di leggere qualsiasi segreto: qui un 500 e' un fallimento). Nessun effetto: respinte prima di toccare Firestore (T-20);
#   - il login e' raggiungibile: una richiesta di accesso con un'email inventata deve ricevere dal servizio di accesso Firebase un rifiuto "normale"
#     (400 EMAIL_NOT_FOUND / INVALID_LOGIN_CREDENTIALS). Nessun account viene creato o modificato.
#     Limite di richieste o guasto di Google (TOO_MANY_ATTEMPTS, 403, 429, 5xx) o chiave web non trovata = solo AVVISO (prova non conclusiva), mai fallimento.
# Uso:  smoke-produzione.sh            Esito: 0 tutto ok, 1 almeno una prova fallita (le prove si ripetono SMOKE_TENTATIVI volte: la rete di Google puo' impiegare qualche secondo).
# Variabili: URL_PRODUZIONE (default https://avanza-b62d7.web.app)  FUNZIONE_URL (default la funzione githubWebhook di produzione)
#            SMOKE_TENTATIVI (default 6)  SMOKE_ATTESA secondi tra i tentativi (default 10)  FIREBASE_OPTIONS_FILE (default lib/firebase_options.dart, per la chiave web pubblica)
#            AUTH_URL (solo per le prove) cambia l'indirizzo del servizio di accesso.
#            SMOKE_FUNZIONE=no per saltare la prova della funzione, SMOKE_LOGIN=no per saltare quella del login.
# NON PROVATO contro la produzione vera (da qui non e' raggiungibile): provato su un server locale finto, che simula sia il caso sano sia i guasti.
set -uo pipefail
URL="${URL_PRODUZIONE:-https://avanza-b62d7.web.app}"; URL="${URL%/}"
FUNZ="${FUNZIONE_URL:-https://us-central1-avanza-b62d7.cloudfunctions.net/githubWebhook}"
TENT="${SMOKE_TENTATIVI:-6}"; ATT="${SMOKE_ATTESA:-10}"
OPT="${FIREBASE_OPTIONS_FILE:-lib/firebase_options.dart}"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
CB="smoke=$(date +%s)$RANDOM"      # parametro finto: evita di leggere una copia in cache
KO=0

# prova <nome> <funzione che ritorna 0 se ok>: ripete finche' passa o finiscono i tentativi
prova() {
  local nome="$1"; shift; local n
  for n in $(seq 1 "$TENT"); do
    if MSG="$("$@" 2>&1)"; then echo "OK    $nome"; return 0; fi
    [ "$n" -lt "$TENT" ] && sleep "$ATT"
  done
  echo "FALLITA $nome -> $MSG"; KO=1; return 1
}
get() { curl -sS -m 30 -o "$TMP/corpo" -D "$TMP/intest" -w '%{http_code}' "$1" 2>&1; }
intest() { tr -d '\r' < "$TMP/intest" | grep -i -m1 "^$1:" | cut -d: -f2- | sed 's/^ *//'; }

p_pagina() {      # $1 = percorso
  local c; c="$(get "$URL$1?$CB")"
  [ "$c" = 200 ] || { echo "HTTP $c (atteso 200)"; return 1; }
  grep -q 'flutter_bootstrap.js' "$TMP/corpo" || { echo "la pagina non e' quella dell'app (manca flutter_bootstrap.js)"; return 1; }
}
p_cache_index() {
  local c; c="$(get "$URL/index.html?$CB")"; [ "$c" = 200 ] || { echo "HTTP $c"; return 1; }
  intest cache-control | grep -qi 'no-cache\|no-store' || { echo "Cache-Control di index.html = '$(intest cache-control)' (atteso no-cache)"; return 1; }
}
p_mainjs() {
  local c ct; c="$(get "$URL/main.dart.js?$CB")"; [ "$c" = 200 ] || { echo "HTTP $c"; return 1; }
  ct="$(intest content-type)"; echo "$ct" | grep -qi 'javascript' || { echo "Content-Type '$ct' (atteso JavaScript: forse risponde la pagina di ripiego)"; return 1; }
  [ "$(wc -c < "$TMP/corpo")" -gt 100000 ] || { echo "main.dart.js troppo piccolo"; return 1; }
  grep -q -F 'avanza-b62d7' "$TMP/corpo" || { echo "main.dart.js NON contiene la configurazione di produzione avanza-b62d7"; return 1; }
  if grep -q -F 'avanza-test' "$TMP/corpo"; then echo "main.dart.js CONTIENE avanza-test: sito di produzione con configurazione di TEST"; return 1; fi
  intest cache-control | grep -qi 'no-cache\|no-store' || { echo "Cache-Control di main.dart.js = '$(intest cache-control)' (atteso no-cache)"; return 1; }
}
p_bootstrap() {
  local c; c="$(get "$URL/flutter_bootstrap.js?$CB")"; [ "$c" = 200 ] || { echo "HTTP $c"; return 1; }
  intest content-type | grep -qi 'javascript' || { echo "flutter_bootstrap.js non e' JavaScript"; return 1; }
  intest cache-control | grep -qi 'no-cache\|no-store' || { echo "Cache-Control di flutter_bootstrap.js = '$(intest cache-control)'"; return 1; }
}
p_sw() {   # nessun service worker vero (con --pwa-strategy=none il file non c'e': Firebase risponde con la pagina di ripiego)
  get "$URL/flutter_service_worker.js?$CB" >/dev/null
  if grep -q 'RESOURCES\|CACHE_NAME' "$TMP/corpo" 2>/dev/null; then echo "flutter_service_worker.js contiene un service worker attivo"; return 1; fi
}
p_funz_get() { local c; c="$(curl -sS -m 30 -o /dev/null -w '%{http_code}' "$FUNZ" 2>&1)"; [ "$c" = 405 ] || { echo "GET -> HTTP $c (atteso 405)"; return 1; }; }
p_funz_post() {
  local c; c="$(curl -sS -m 30 -o /dev/null -w '%{http_code}' -X POST -H 'content-type: application/json' -H 'x-github-event: ping' \
      -H 'x-hub-signature-256: sha256=0000000000000000000000000000000000000000000000000000000000000000' -d '{}' "$FUNZ" 2>&1)"
  case "$c" in
    401) ;;
    # 500 = la funzione risponde ma non riesce a leggere un segreto (es. quello della GitHub App, ancora da creare, o un permesso IAM mancante):
    # prova NON conclusiva, non un guasto del rilascio (altrimenti si fermerebbe e annullerebbe un rilascio buono). Il percorso del segreto
    # storico lo prova E2E Webhook dopo il rilascio; che la funzione risponda senza leggere segreti lo prova p_funz_post_nofirma. (T-20)
    500) echo "ATTENZIONE: POST con firma sbagliata -> HTTP 500: segreto del webhook o della GitHub App non leggibile (IAM? segreto da creare?): prova NON conclusiva. Verificare il percorso del segreto storico con E2E Webhook dopo il rilascio." >> "$TMP/avvisi"
        echo "HTTP 500 con firma sbagliata: segreto non leggibile, prova non conclusiva (avviso)" ;;
    *)  echo "POST con firma sbagliata -> HTTP $c (atteso 401; 404/502/503/000 = funzione rotta o non raggiungibile)"; return 1 ;;
  esac
}
p_funz_post_nofirma() {   # senza intestazione di firma la funzione risponde 401 PRIMA di leggere Secret Manager (authenticate.ts: "firma_assente")
  local c; c="$(curl -sS -m 30 -o /dev/null -w '%{http_code}' -X POST -H 'content-type: application/json' -H 'x-github-event: ping' -d '{}' "$FUNZ" 2>&1)"
  [ "$c" = 401 ] || { echo "POST senza firma -> HTTP $c (atteso 401 senza leggere segreti; 500 = la funzione non risponde nemmeno senza segreti, 404/5xx = rotta)"; return 1; }
}
p_login() {
  local chiave c corpo
  chiave="$(sed -n '/static const FirebaseOptions web/,/);/p' "$OPT" 2>/dev/null | sed -n "s/.*apiKey: *'\([^']*\)'.*/\1/p" | head -1)"
  # Senza la chiave la prova NON si puo' fare: non si segna OK in silenzio. Scelta prudente ma non bloccante: AVVISO esplicito
  # (un file cambiato di posto non deve annullare un rilascio buono, ma chi legge deve sapere che il login NON e' stato provato).
  if [ -z "$chiave" ]; then
    echo "ATTENZIONE: chiave web non trovata in $OPT: la prova del servizio di accesso NON e' stata fatta (NON verificata)." >> "$TMP/avvisi"
    echo "chiave web non trovata in $OPT: prova del login non eseguita (avviso)"; return 0
  fi
  c="$(curl -sS -m 30 -o "$TMP/auth" -w '%{http_code}' -X POST -H 'content-type: application/json' -H "Referer: $URL/" \
      -d "{\"email\":\"smoke-$RANDOM$RANDOM@example.invalid\",\"password\":\"non-valida-$RANDOM\",\"returnSecureToken\":true}" \
      "${AUTH_URL:-https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword}?key=$chiave" 2>&1)"
  corpo="$(tr -d '\n' < "$TMP/auth" 2>/dev/null)"
  # Un limite di richieste o un guasto passeggero di Google (TOO_MANY_ATTEMPTS, 429, 5xx) NON dice nulla sul nostro sito: solo avviso,
  # altrimenti il ritorno automatico annullerebbe un rilascio buono. Si fallisce solo se l'accesso risponde in modo davvero inatteso.
  case "$c" in
    400) if echo "$corpo" | grep -q 'EMAIL_NOT_FOUND\|INVALID_LOGIN_CREDENTIALS\|INVALID_PASSWORD'; then :
         elif echo "$corpo" | grep -q 'TOO_MANY_ATTEMPTS'; then
           echo "Auth ha risposto TOO_MANY_ATTEMPTS_TRY_LATER (limite di richieste di Google sull'indirizzo della CI): prova del login non conclusiva, non blocca." >> "$TMP/avvisi"
         else echo "Auth risponde 400 ma con un errore inatteso: $(echo "$corpo" | head -c 200)"; return 1; fi ;;
    403) echo "Auth ha risposto 403 alla prova di accesso (chiave con restrizioni?): prova non conclusiva, non blocca." >> "$TMP/avvisi" ;;
    429) echo "Auth ha risposto 429 (troppe richieste): prova del login non conclusiva, non blocca." >> "$TMP/avvisi" ;;
    5??) echo "Auth ha risposto HTTP $c (guasto passeggero del servizio Google?): prova del login non conclusiva, non blocca." >> "$TMP/avvisi" ;;
    *)   echo "Auth -> HTTP $c (atteso 400 con EMAIL_NOT_FOUND/INVALID_LOGIN_CREDENTIALS)"; return 1 ;;
  esac
}

echo "== Smoke test di produzione: $URL"
prova "pagina principale /" p_pagina /
prova "pagina di accesso /login raggiungibile" p_pagina /login
prova "intestazioni di cache di index.html" p_cache_index
prova "main.dart.js: JavaScript vero, configurazione di produzione, cache corretta" p_mainjs
prova "flutter_bootstrap.js: JavaScript e cache corretta" p_bootstrap
prova "nessun service worker attivo" p_sw
if [ "${SMOKE_FUNZIONE:-}" != no ]; then
  prova "funzione githubWebhook: GET -> 405" p_funz_get
  prova "funzione githubWebhook: firma sbagliata -> 401 (legge il segreto, nessun effetto; 500 = avviso)" p_funz_post
  prova "funzione githubWebhook: senza firma -> 401 (non legge segreti)" p_funz_post_nofirma
else echo "SALTATA la prova della funzione (SMOKE_FUNZIONE=no)"; fi
if [ "${SMOKE_LOGIN:-}" != no ]; then
  prova "servizio di accesso Firebase raggiungibile (rifiuto normale di credenziali inventate)" p_login
else echo "SALTATA la prova del login (SMOKE_LOGIN=no)"; fi
[ -s "$TMP/avvisi" ] && sort -u "$TMP/avvisi" | sed 's/^/AVVISO /'
echo "== NON verificato da questo test: accesso reale con un utente, caricamento dei dati, funzioni dentro l'app (serve un browser)."
if [ "$KO" = 0 ] && [ -s "$TMP/avvisi" ]; then echo "SMOKE TEST: PROVE SUPERATE, MA CON AVVISI (almeno una prova non conclusiva: leggi gli AVVISO qui sopra)"
elif [ "$KO" = 0 ]; then echo "SMOKE TEST: TUTTE LE PROVE SUPERATE"; else echo "SMOKE TEST: ALMENO UNA PROVA FALLITA"; fi
exit "$KO"
