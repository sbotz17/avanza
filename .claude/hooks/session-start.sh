#!/bin/bash
# SessionStart hook — carica il contesto minimo del progetto
# Output va al modello come contesto iniziale (risparmia token sulle Read successive)
set -euo pipefail

PROJECT="${CLAUDE_PROJECT_DIR:-.}"
DOCS="$PROJECT/docs/progetto"

echo "=== CONTESTO PROGETTO: $(basename "$PROJECT") ==="
echo "Data: $(date '+%Y-%m-%d')"
echo ""

# 1. Indice (mappa delle aree — nodo di navigazione principale)
if [ -f "$DOCS/indice.md" ]; then
  cat "$DOCS/indice.md"
  echo ""
fi

# 2. Blocchi attivi (chi sta lavorando su cosa — evita conflitti)
if [ -f "$DOCS/blocchi.md" ]; then
  echo "--- BLOCCHI ATTIVI ---"
  grep -E "(OCCUPATO|IN_CODA|occupa|coda)" "$DOCS/blocchi.md" 2>/dev/null | head -10 || true
  echo ""
fi

# 3. Task corrente (se esiste)
if [ -f "$DOCS/task.md" ]; then
  echo "--- TASK CORRENTE ---"
  head -20 "$DOCS/task.md"
  echo ""
fi
