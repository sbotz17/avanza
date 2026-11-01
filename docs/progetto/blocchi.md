# Blocchi funzionali — Avanza

Ultima revisione: 2026-11-01

Un blocco funzionale per volta: due sessioni non lavorano mai sullo stesso blocco. La mappa qui sotto
serve al comando `scripts/blocco-squadra.py` (copia globale `~/.claude/scripts/blocco-squadra.py`).

| Blocco | Cosa comprende | File tipici |
|---|---|---|
| `app-task` | Elenco e dettaglio dei task: schede, date, richiesta originale, note, chat | `lib/pages/project_page.dart`, `lib/pages/task_detail_page.dart`, `lib/widgets/task_card.dart`, `lib/models/task.dart` |
| `collegamento-github` | Webhook, GitHub App, creazione automatica dei progetti, aggiornamento task da GitHub | `functions/src/`, `scripts/registra-ore.mjs`, `.github/workflows/registra-ore.yml` |
| `costi-squadra` | Pagina Squadra, registro ore, report costi e produttività | `lib/pages/admin/team_page.dart`, `lib/pages/admin/time_report.dart`, `lib/pages/admin/costs_page.dart`, `lib/models/time_entry.dart` |
| `accessi-ruoli` | Login, ruoli, collegamento cliente-progetto, regole Firestore | `lib/providers/`, `lib/services/auth_service.dart`, `firestore.rules` |
| `rilascio` | CI, promozione, backup, ambienti | `.github/workflows/`, `.claude/scripts/` |
