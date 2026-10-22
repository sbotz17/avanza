# Diario di sviluppo — Avanza

## 2026-10-22 — Badge taskCode nella UI dei task

**Cosa è stato fatto**
Aggiunto il badge visivo `taskCode` (es. "T-3") in tutti i punti della UI dove appare un task, come da istruzioni del branch `claude/epic-galileo-e9a406`.

**Componente creato**
- `lib/widgets/task_code_badge.dart` — widget `TaskCodeBadge` riusabile:
  - Badge compatto con sfondo arrotondato (#E8F0FF / #1E2A4A) e testo monospace 11px peso w600
  - Se `taskCode` è vuoto restituisce `SizedBox.shrink()` (nessun spazio occupato)
  - Supporta light mode e dark mode

**File aggiornati**
- `lib/widgets/task_card.dart` — badge accanto al titolo nella vista lista (admin e cliente)
- `lib/widgets/kanban_board.dart` — badge sopra il titolo nelle card kanban (`_KanbanCard`)
- `lib/pages/admin/edit_task_page.dart` — AppBar title mostra "Modifica task · T-3" quando il task ha un codice
- `lib/pages/task_detail_page.dart` — AppBar title mostra titolo + badge quando il task ha un codice
- `test/widget_test.dart` — test per `TaskCodeBadge` (visibilità, colori light/dark, assenza quando vuoto)

**Come provarlo**
1. Aprire un progetto con task che hanno `taskCode` non vuoto
2. Verificare che il badge appaia nella vista lista, nella vista kanban, nella pagina di dettaglio e in quella di modifica
3. Verificare che i task senza `taskCode` (campo vuoto) non mostrino badge
4. Verificare la resa in dark mode
