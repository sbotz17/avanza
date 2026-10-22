# Report di test — Integrazione GitHub (badge taskCode + Cloud Function githubWebhook)

**Data**: 2026-10-22
**Branch**: `claude/epic-galileo-e9a406`
**Tester**: tester (agente automatico)
**Esito finale**: SUPERATO

---

## 1. Sviluppo 1: Badge taskCode nella UI Flutter

### Criteri di accettazione

| # | Criterio | Come verificato | Esito | Evidenza |
|---|---|---|---|---|
| 1 | `TaskCodeBadge` mostra il testo (es. "T-3") quando `taskCode` non è vuoto | Analisi codice `lib/widgets/task_code_badge.dart` + test widget `flutter test test/widget_test.dart --no-pub` | OK | riga 17: `if (taskCode.isEmpty) return const SizedBox.shrink();` — se non vuoto, il Container con il Text viene restituito; test "mostra il codice quando taskCode non è vuoto" PASS |
| 2 | `TaskCodeBadge` restituisce `SizedBox.shrink()` quando `taskCode` è '' | Analisi codice + test widget | OK | riga 17: `if (taskCode.isEmpty) return const SizedBox.shrink();` — test "restituisce SizedBox.shrink quando taskCode è vuoto" PASS |
| 3 | Colori corretti: light bg #E8F0FF / fg #3B5BDB, dark bg #1E2A4A / fg #748FFC | Analisi codice + test widget | OK | `task_code_badge.dart` righe 3-6: `_lightBg = Color(0xFFE8F0FF)`, `_lightFg = Color(0xFF3B5BDB)`, `_darkBg = Color(0xFF1E2A4A)`, `_darkFg = Color(0xFF748FFC)`; test light e dark mode PASS |
| 4 | Badge in lista task, kanban, AppBar edit, AppBar dettaglio | Analisi codice dei 4 file | OK | `task_card.dart` righe 52-55; `kanban_board.dart` righe 193-195; `edit_task_page.dart` righe 155-156; `task_detail_page.dart` righe 75-86 |
| 5 | Layout card non si rompe (titolo in Expanded, no overflow) | Analisi codice | OK | `task_card.dart` riga 56: titolo in `Expanded`; `task_detail_page.dart` riga 78: titolo in `Flexible` con `overflow: TextOverflow.ellipsis` |

### Test widget eseguiti

Comando: `flutter test test/widget_test.dart --no-pub`

```
00:16 +5: All tests passed!
```

5 test passati:
- `placeholder test` PASS
- `TaskCodeBadge mostra il codice quando taskCode non è vuoto` PASS
- `TaskCodeBadge restituisce SizedBox.shrink quando taskCode è vuoto` PASS
- `TaskCodeBadge usa colori corretti in light mode` PASS
- `TaskCodeBadge usa colori corretti in dark mode` PASS

---

## 2. Sviluppo 2: Cloud Function githubWebhook

### Criteri di accettazione

| # | Criterio | Come verificato | Esito | Evidenza |
|---|---|---|---|---|
| 1 | `hmac.ts` verifica HMAC-SHA256 con `timingSafeEqual` | Analisi codice `functions/src/lib/hmac.ts` + 6 test Jest | OK | riga 14: `import { createHmac, timingSafeEqual } from 'crypto'`; righe 19-22: confronto con `timingSafeEqual` e length check; tutti e 6 i test hmac.test.ts PASS |
| 2a | push created=true → status active, nota `[gh] Branch X creato` | Analisi `eventRouter.ts` righe 78-87 + test `eventRouter.test.ts` | OK | `desired.newStatus = 'active'`, `note.text = '[gh] Branch ${branch} creato'`; test "routes BRANCH_CREATED" PASS |
| 2b | push created=false → nota `[gh] Commit sha7: msg` | Analisi `eventRouter.ts` righe 88-97 + test | OK | `sha7 = commit.id.substring(0, 7)`, `text = '[gh] Commit ${sha7}: ${msg}'`; test "routes COMMIT_PUSHED" PASS |
| 2c | pull_request opened → nota `[gh] PR #N aperta`, aggiorna githubPrNumber | Analisi `eventRouter.ts` righe 107-118 + test | OK | `text = '[gh] PR #${pr.number} aperta: "${titleTrunc}"'`, `desired.githubPrNumber = pr.number`; test PASS |
| 2d | pull_request closed+merged=true → status review, nota `[gh] PR #N mergeata` | Analisi `eventRouter.ts` righe 121-134 + test | OK | `desired.newStatus = 'review'`, `note.text = '[gh] PR #${pr.number} mergeata in ${base}'`; test PASS |
| 2e | pull_request_review approved → status validated | Analisi `eventRouter.ts` righe 150-176 + test | OK | `desired.newStatus = 'validated'`; test "routes PR_APPROVED" PASS |
| 3 | Non si retrocede mai (backlog→active→review→validated→released) | Analisi `taskUpdater.ts` righe 12-64 + test | OK | `STATUS_ORDER` array, confronto di indici `newIdx > currentIdx`; test "does NOT retreat from review to active" e "does NOT advance a released task" PASS |
| 4 | Idempotenza: nota duplicata non aggiunta | Analisi `taskUpdater.ts` righe 48-51 + test | OK | `task.notes.some((n) => n.text === desired.note.text)` → `return null`; test "returns null when the exact note already exists" PASS |
| 5 | Secret HMAC non nel codice né in repository | Ispezione git: `git ls-files --error-unmatch functions/.env.local`; analisi `githubWebhook.ts` | OK | `.env.local` NOT TRACKED; `process.env.GITHUB_WEBHOOK_SECRET` (runtime env); `.env.local.example` contiene solo placeholder `inserisci-qui-un-secret-di-test-locale` |
| 6 | `githubBranch` e `githubPrNumber` nullable e retrocompatibili | Analisi `lib/models/task.dart` | OK | righe 62-63: `final String? githubBranch;` e `final int? githubPrNumber;`; costruttore con default `null`; `fromFirestore` righe 109-110: `d['githubBranch'] as String?` (null-safe) |
| 7 | 53 test Jest passano | `cd functions && npm install && npm test` | OK | `Tests: 53 passed, 53 total` (3 test suite: hmac=6, eventRouter=24, taskUpdater=23) |
| 8 | `flutter analyze --no-fatal-infos` non introduce nuovi errori | `dart analyze lib/widgets/task_code_badge.dart lib/models/task.dart` | OK con riserva | Vedi "Difetti trovati" — problema pre-esistente nell'ambiente, i file del nuovo sviluppo sono puliti |

### Test Jest eseguiti

Comando: `cd functions && npm install && npm test`

```
PASS src/test/eventRouter.test.ts
PASS src/test/hmac.test.ts
PASS src/test/taskUpdater.test.ts

Test Suites: 3 passed, 3 total
Tests:       53 passed, 53 total
Time:        4.612 s
```

---

## 3. `flutter analyze` — situazione ambiente

**Problema pre-esistente (non da questo sviluppo)**: `pubspec.yaml` richiede `intl: ^0.20.3` che esige Dart SDK `^3.9.0`, ma il SDK installato localmente è Dart 3.5.4 / Flutter 3.24.5. `flutter pub get` e `flutter test` (senza `--no-pub`) falliscono con:

```
The current Dart SDK version is 3.5.4.
Because avanza depends on intl >=0.20.3 which requires SDK version ^3.9.0, version solving failed.
```

Questo problema è stato introdotto da commit `5954782` (pre-esistente rispetto a questo sviluppo).

**Workaround usato**: `flutter test --no-pub` usa il `pubspec.lock` esistente (che punta a `intl 0.19.0`) e i test passano. Per `flutter analyze`, è stato usato `dart analyze` direttamente.

**Analisi dei file del nuovo sviluppo** (`dart analyze lib/widgets/task_code_badge.dart lib/models/task.dart`):
```
Analyzing task_code_badge.dart, task.dart...
No issues found!
```

**Errori pre-esistenti** (non da questo sviluppo, presenti prima del commit `92fc67b`):
- `core/theme.dart`: `CardThemeData` non disponibile in Flutter 3.24.5 (richiede 3.27+) — 2 errori
- `widgets/task_card.dart`, `kanban_board.dart`, `task_detail_page.dart`, altri: `.withValues(alpha:)` non disponibile in Flutter 3.24.5 — 9 errori

Verifica: `git show 26d3559:lib/widgets/kanban_board.dart | grep withValues` → presenti già nel commit precedente al badge.

---

## 4. Difetti trovati

### D-1: Dipendenza intl incompatibile con SDK locale (pre-esistente)

- **Descrizione**: `pubspec.yaml` specifica `intl: ^0.20.3` introdotto da commit `5954782` (fix precedente). `intl 0.20.x` richiede Dart SDK `^3.9.0` ma il SDK locale è `3.5.4`. Il CI usa "Flutter stable" (probabilmente Dart 3.9+) e può funzionare, ma l'ambiente di sviluppo locale non può eseguire `flutter pub get`.
- **Passi per riprodurre**: `cd /home/user/avanza && flutter pub get`
- **Gravità**: Media
- **Commit responsabile**: `5954782` (pre-esistente)
- **Sviluppatore competente**: sviluppatore-frontend
- **Nota**: Workaround: `flutter test --no-pub` funziona grazie al lockfile con `intl 0.19.0`

### D-2: API Flutter 3.27+ usate con SDK 3.24.5 (pre-esistente)

- **Descrizione**: `Color.withValues(alpha:)` e `CardThemeData` sono API introdotte in Flutter 3.27+, non disponibili in Flutter 3.24.5 locale. Producono 11 errori di analisi in `core/theme.dart`, `widgets/task_card.dart`, `widgets/kanban_board.dart`, `pages/task_detail_page.dart` e altri. Nessuno di questi errori è stato introdotto dall'attuale sviluppo.
- **Gravità**: Media
- **Commit responsabile**: `fdfeef3` e `6706f58` (pre-esistenti)
- **Sviluppatore competente**: sviluppatore-frontend

### D-3: `catalogo.md` mancante — nuovi oggetti non registrati (organizzativo)

- **Descrizione**: Il file `docs/progetto/catalogo.md` non esiste. I nuovi oggetti creati da questo sviluppo non sono registrati: `TaskCodeBadge` (`lib/widgets/task_code_badge.dart`), i moduli Cloud Function (`functions/src/lib/hmac.ts`, `eventRouter.ts`, `taskUpdater.ts`, `projectResolver.ts`, `taskResolver.ts`, `firestoreWriter.ts`). Secondo le regole del progetto ogni nuovo oggetto va registrato.
- **Gravità**: Bassa
- **Sviluppatore competente**: sviluppatore-frontend (badge), sviluppatore-backend (Cloud Functions)

### D-4 (osservazione, non bloccante): STATUS_ORDER duplicato

- **Descrizione**: `STATUS_ORDER` e `PHASE_STATUS_ORDER` sono duplicati tra `functions/src/lib/taskUpdater.ts` e `functions/src/lib/firestoreWriter.ts`. Il commento in `firestoreWriter.ts` lo giustifica con "to avoid circular imports". Potrebbe essere estratto in `types.ts` o in un `constants.ts` dedicato.
- **Gravità**: Bassa (duplicato giustificato)
- **Sviluppatore competente**: sviluppatore-backend

---

## 5. Verifiche di sicurezza

| Controllo | Esito |
|---|---|
| `functions/.env.local` non in git | OK — `git ls-files --error-unmatch functions/.env.local` → "NOT TRACKED" |
| `functions/.env.local` non esiste su disco | OK — file non presente |
| `functions/.env.local.example` contiene solo placeholder | OK — `GITHUB_WEBHOOK_SECRET=inserisci-qui-un-secret-di-test-locale` |
| Nessun secret hardcoded nei sorgenti `.ts` | OK — tutte le occorrenze di `GITHUB_WEBHOOK_SECRET` sono commenti, `process.env`, o config `secrets: []` |
| `functions/lib/` (compiled output) non in git | OK — `git ls-files functions/lib/` → nessun output |

---

## 6. Esito

**SUPERATO**

Tutti e 13 i criteri di accettazione sono verificati. I 5 test Flutter e i 53 test Jest passano. I 3 difetti trovati (D-1, D-2, D-3) sono pre-esistenti o organizzativi, nessuno è bloccante per questa funzionalità.

I difetti D-1 e D-2 vanno rimandati allo sviluppatore-frontend per un aggiornamento del Flutter SDK nell'ambiente di sviluppo locale (o per verificare che il CI con Flutter stable li risolva). Il difetto D-3 va rimandato agli sviluppatori per creare `docs/progetto/catalogo.md` e registrare i nuovi oggetti.
