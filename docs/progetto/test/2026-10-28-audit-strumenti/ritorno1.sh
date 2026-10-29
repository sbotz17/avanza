#!/usr/bin/env bash
# Copia ESATTA del passo "RITORNO 1" di rilascio-produzione.yml (senza la parte "git fetch" dal remoto GitHub)
GITHUB_OUTPUT=/tmp/claude-0/-home-user/a4a389bf-77be-5d81-ac7f-0c1bb199291a/scratchpad/ritorno.out
: > "$GITHUB_OUTPUT"
if git rev-parse -q --verify refs/tags/ultimo-rilascio-ok >/dev/null; then
  PREC="$(git rev-parse 'refs/tags/ultimo-rilascio-ok^{commit}')"
  if [ "$PREC" = "$(git rev-parse HEAD)" ]; then
    echo "ok=no" >> "$GITHUB_OUTPUT"; echo "L'ultima versione buona coincide con questa: non c'e' nulla a cui tornare."
  else
    echo "ok=si" >> "$GITHUB_OUTPUT"; echo "Si torna a $PREC"
  fi
else
  echo "ok=no" >> "$GITHUB_OUTPUT"; echo "Il tag ultimo-rilascio-ok non esiste (primo rilascio con questa procedura): ritorno automatico non disponibile."
fi
cat "$GITHUB_OUTPUT"
