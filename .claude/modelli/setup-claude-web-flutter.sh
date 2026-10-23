#!/bin/bash
# Script di setup per l'ambiente cloud di Claude Code (claude.ai/code > pulsante con la nuvola > Cloud >
# ingranaggio dell'ambiente > "Script di configurazione"): installa Flutter stable.
# Gira come root su Ubuntu 24.04 prima che parta la sessione; il risultato viene memorizzato per le sessioni successive.
# Nessuna chiave: le sessioni non hanno accesso alla produzione.
set -u
DEST=/opt/flutter
if [ ! -x "$DEST/bin/flutter" ]; then
  JSON=$(curl -fsSL https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json || true)
  URL=$(printf '%s' "$JSON" | python3 -c "import json,sys;d=json.load(sys.stdin);h=d['current_release']['stable'];r=[x for x in d['releases'] if x['hash']==h][0];print(d['base_url']+'/'+r['archive'])" 2>/dev/null || true)
  if [ -n "$URL" ]; then
    curl -fsSL "$URL" | tar -xJ -C /opt || echo "ATTENZIONE: download dell'archivio Flutter non riuscito"
  fi
  [ -x "$DEST/bin/flutter" ] || git clone --depth 1 -b stable https://github.com/flutter/flutter.git "$DEST" || echo "ATTENZIONE: Flutter non installato"
fi
git config --global --add safe.directory '*'
ln -sf "$DEST/bin/flutter" /usr/local/bin/flutter
ln -sf "$DEST/bin/dart" /usr/local/bin/dart
flutter config --no-analytics >/dev/null 2>&1 || true
flutter --version || echo "ATTENZIONE: Flutter non pronto"
exit 0
