#!/usr/bin/env bash
# Controlla che una build web di Flutter sia collegata al progetto Firebase GIUSTO, PRIMA di pubblicarla.
#   produzione (prod): deve contenere avanza-b62d7 e NON deve contenere nulla del progetto di test (avanza-test / avanza-test-c33ef);
#   test:              deve contenere avanza-test-c33ef e NON deve contenere avanza-b62d7.
# Serve a evitare i due errori peggiori: un sito di produzione che parla col database di test, e un sito di test che scrive nei dati reali.
#
# Uso:  controlla-build-ambiente.sh prod|test <cartella-build-web>      (es. build/web)
# Esito: 0 = coerente, 1 = NON coerente (la pubblicazione NON deve procedere), 2 = uso sbagliato.
# Valvola (solo Andrea, variabile GitHub CONTROLLO_CONFIG_BUILD = no): salta il controllo con un avviso. Serve solo se il compilatore
# lasciasse nel JavaScript di produzione il testo della configurazione di test pur senza usarla (falso allarme): prima si verifica, poi si decide.
# Il controllo cerca testo nei file della build (non esegue nulla). NON PROVATO su una build reale in questo ambiente (Flutter non installato):
# e' stato provato su cartelle di esempio; il primo giro vero e' quello della CI.
set -euo pipefail
AMB="${1:-}"; DIR="${2:-}"
[ -n "$DIR" ] && { [ "$AMB" = prod ] || [ "$AMB" = test ]; } || { echo "Uso: $0 prod|test <cartella-build-web>"; exit 2; }
[ -d "$DIR" ] || { echo "ERRORE: cartella $DIR inesistente"; exit 1; }
if [ "${CONTROLLO_CONFIG_BUILD:-}" = "no" ]; then
  echo "::warning::Controllo della configurazione della build SALTATO (CONTROLLO_CONFIG_BUILD=no)."; exit 0
fi
PROD="avanza-b62d7"; TEST_ID="avanza-test-c33ef"
JS="$DIR/main.dart.js"
[ -s "$JS" ] || { echo "ERRORE: $JS mancante o vuoto: la build non e' completa"; exit 1; }
DIM="$(wc -c < "$JS")"
[ "$DIM" -gt 100000 ] || { echo "ERRORE: $JS troppo piccolo ($DIM byte): build sospetta"; exit 1; }

conta() { grep -rIl -F -- "$1" "$DIR" 2>/dev/null | head -5 || true; }
ERR=0
if [ "$AMB" = prod ]; then
  grep -q -F -- "$PROD" "$JS" || { echo "ERRORE: la build di PRODUZIONE non contiene la configurazione $PROD"; ERR=1; }
  for t in "$TEST_ID" "avanza-test"; do
    TROVATI="$(conta "$t")"
    if [ -n "$TROVATI" ]; then echo "ERRORE: la build di PRODUZIONE contiene '$t' (configurazione di TEST) in:"; echo "$TROVATI"; ERR=1; fi
  done
else
  grep -q -F -- "$TEST_ID" "$JS" || { echo "ERRORE: la build di TEST non contiene la configurazione $TEST_ID"; ERR=1; }
  TROVATI="$(conta "$PROD")"
  if [ -n "$TROVATI" ]; then echo "ERRORE: la build di TEST contiene '$PROD' (configurazione di PRODUZIONE) in:"; echo "$TROVATI"; ERR=1; fi
fi
if [ "$ERR" = 0 ]; then echo "Build $AMB coerente: configurazione del progetto giusto, nessuna traccia dell'altro ambiente ($DIM byte in main.dart.js)."; fi
exit "$ERR"
