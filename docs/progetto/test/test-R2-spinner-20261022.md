# Test R-2 — Spinner infinito al caricamento

**Data**: 2026-10-22
**Tester**: tester
**Branch**: `claude/epic-galileo-e9a406`
**Commit R-2**: `9e63c85`
**Esito finale**: SUPERATO (con osservazioni minori)

---

## Criteri di accettazione

| # | Criterio | Come verificato | Esito | Evidenza |
|---|---|---|---|---|
| 1 | `_loading` torna `false` dopo `FirebaseAuthException` | Test unitario `auth_provider_test.dart` — "loading torna false dopo una FirebaseAuthException" | OK | `flutter test --no-pub`: +1 pass |
| 2 | `_loading` torna `false` dopo eccezione generica non-Firebase (il bug R-2) | Test unitario `auth_provider_test.dart` — "loading torna false dopo un'eccezione generica non-Firebase" | OK | `flutter test --no-pub`: +2 pass |
| 3 | `_loading` torna `false` dopo un `Error` Dart | Test unitario `auth_provider_test.dart` — "loading torna false dopo un'eccezione di tipo Error" | OK | `flutter test --no-pub`: +3 pass |
| 4 | `_loading` è `false` all'avvio | Test unitario `auth_provider_test.dart` — "loading è false all'avvio" | OK | `flutter test --no-pub`: +4 pass |
| 5 | `HomePage` è `StatefulWidget` con stream creato una sola volta | Ispezione codice `lib/pages/home_page.dart` | OK | `class HomePage extends StatefulWidget`; `_stream ??= ...` in `didChangeDependencies()`; lo stream non viene ricreato su rebuild |
| 6 | Nessuna regressione sui 5 test preesistenti | Esecuzione `flutter test --no-pub` su `test/widget_test.dart` | OK | Tutti e 5 i test di `widget_test.dart` superati (+5 pass → +9 pass) |
| 7 | `flutter test --no-pub` → 9/9 test verdi | Esecuzione completa della suite | OK | Output: `+9: All tests passed!` |

---

## Test eseguiti

### `flutter test --no-pub`

```
00:02 +1: AuthProvider.signIn — R-2 loading torna false dopo una FirebaseAuthException ...
00:02 +2: AuthProvider.signIn — R-2 loading torna false dopo un'eccezione generica non-Firebase ...
00:02 +3: AuthProvider.signIn — R-2 loading torna false dopo un'eccezione di tipo Error
00:02 +4: AuthProvider.signIn — R-2 loading è false all'avvio (stato iniziale corretto)
00:02 +5: widget_test.dart: placeholder test
00:03 +6: widget_test.dart: TaskCodeBadge mostra il codice quando taskCode non è vuoto
00:03 +7: widget_test.dart: TaskCodeBadge restituisce SizedBox.shrink quando taskCode è vuoto
00:03 +8: widget_test.dart: TaskCodeBadge usa colori corretti in light mode
00:03 +9: widget_test.dart: TaskCodeBadge usa colori corretti in dark mode

+9: All tests passed!
```

**Risultato**: 9/9 PASS

### `flutter analyze --no-pub --no-fatal-infos`

Esito: 12 problemi trovati, di cui 11 errori pre-esistenti (non introdotti da R-2) e 1 nuovo warning.

**Errori pre-esistenti** (verificato con `git diff df284cc 9e63c85` — non toccati da R-2):
- 2 errori `CardThemeData` in `lib/core/theme.dart`
- 9 errori `withValues` in `lib/pages/admin/costs_page.dart`, `lib/pages/client_access_page.dart`, `lib/pages/home_page.dart` (pre-esistente), `lib/pages/login_page.dart`, `lib/pages/task_detail_page.dart`, `lib/widgets/kanban_board.dart`, `lib/widgets/task_card.dart`

**Nuovo warning introdotto da R-2**:
```
warning • The '!' will have no effect because the receiver can't be null
  • test/auth_provider_test.dart:37:53
  • unnecessary_non_null_assertion
```

Riga 37 del test: `if (_throwOnSignIn != null) throw _throwOnSignIn!;`
Il `!` è ridondante dopo il controllo `!= null`. Nessun impatto a runtime.

**Nota**: `flutter analyze` senza `--no-pub` fallisce per un conflitto di dipendenze pre-esistente (commit `5954782`): `intl ^0.20.3` richiede SDK `^3.9.0` ma l'ambiente ha SDK `3.5.4`. Non è stato introdotto da R-2.

---

## Verifica minimalità della correzione

File modificati dal commit R-2 (`git show 9e63c85 --stat`):
- `docs/progetto/diario.md` — documentazione
- `docs/progetto/ritorni.md` — documentazione
- `lib/providers/auth_provider.dart` — fix Bug 1 + iniezione `AuthServiceBase`
- `lib/services/auth_service.dart` — estratta interfaccia `AuthServiceBase`
- `lib/pages/home_page.dart` — fix Bug 2 (StatefulWidget)
- `test/auth_provider_test.dart` — 4 test unitari nuovi

Nessuna funzionalità nuova aggiunta. La modifica è strettamente limitata alla correzione dei due bug segnalati. PASS.

---

## Verifica catalogo

`AuthServiceBase` (nuova interfaccia astratta in `lib/services/auth_service.dart`) non risulta registrata in `docs/progetto/catalogo.md`. La voce esistente `AuthService` non fa menzione dell'interfaccia. Difetto di gravità bassa.

---

## Difetti trovati

### D-1 — Warning `unnecessary_non_null_assertion` in `test/auth_provider_test.dart:37`

- **File**: `test/auth_provider_test.dart`, riga 37
- **Descrizione**: Il `!` su `_throwOnSignIn!` è ridondante perché il ramo è già protetto da `if (_throwOnSignIn != null)`. Genera un warning di analisi statica.
- **Passi per riprodurre**: `flutter analyze --no-pub --no-fatal-infos` → riga `warning • unnecessary_non_null_assertion • test/auth_provider_test.dart:37:53`
- **Gravità**: bassa (solo warning, nessun impatto a runtime, solo nel codice di test)
- **Sviluppatore competente**: risolutore-bug / sviluppatore-frontend

### D-2 — `AuthServiceBase` non registrata in `catalogo.md`

- **File**: `docs/progetto/catalogo.md`
- **Descrizione**: La nuova interfaccia `AuthServiceBase` introdotta da R-2 per la testabilità non è registrata nel catalogo. Solo `AuthService` (la classe concreta) figura nella lista dei servizi.
- **Gravità**: bassa (catalogo incompleto, nessun impatto funzionale)
- **Sviluppatore competente**: risolutore-bug

---

## Conclusione

Tutti i 7 criteri di accettazione sono verificati e superati. 9/9 test verdi. La correzione è minimale e limitata ai soli file previsti. I due difetti trovati (D-1 e D-2) sono di gravità bassa e non bloccante.

**ESITO: SUPERATO**

---

## Validazione

**Data**: 2026-10-22
**Validatore**: validatore
**Commit HEAD al momento della validazione**: `ba9cc38`

### Classificazione

CORREZIONE — il fix ripristina il comportamento documentato (spinner si ferma dopo login, lista progetti non resetta a ogni rebuild). Non aggiunge funzioni, non tocca permessi, RLS, autenticazione, configurazioni o dipendenze.

### Controllo indipendente eseguito

1. **Codice verificato direttamente** — `lib/providers/auth_provider.dart` e `lib/pages/home_page.dart` riletti. Il pattern `catch (_)` + `finally` per garantire `_loading = false` è corretto e minimale. La conversione a `StatefulWidget` con `_stream` creato in `didChangeDependencies()` è la soluzione canonica Flutter per questo problema. Nessuna funzionalità aggiunta.

2. **D-1 verificata come risolta** — la riga 37 di `test/auth_provider_test.dart` nel commit HEAD (`ba9cc38`) recita `throw _throwOnSignIn;` senza `!`. `flutter analyze` non segnala più il warning. Soluzione: campo `final Object?` promosso da Dart 3.5.4 dopo il guard `!= null`.

3. **D-2 verificata come risolta** — `docs/progetto/catalogo.md` nel commit HEAD contiene la riga di `AuthServiceBase` (interfaccia astratta) e la riga aggiornata di `AuthService` (implementazione concreta). Entrambe indicano percorso, scopo e dove sono usate.

4. **Test rilanciate in prima persona** — `flutter test --no-pub` sul ramo `claude/epic-galileo-e9a406`: **9/9 PASS** (4 test R-2 + 5 widget test; nessun fallimento).

5. **Minimalità confermata** — i 6 file del commit R-2 sono esattamente quelli attesi. Nessuna modifica a permessi, RLS, dipendenze, CI o zone protette.

6. **`ritorni.md`** — R-2 è registrato con esito `confermato`, causa, correzione e file toccati. Stato `IN TEST`, da aggiornare a `CHIUSO` dopo il rilascio.

### Segnalazione: commit R-3 presente sullo stesso ramo — validazione obbligatoria prima del rilascio

Durante la validazione di R-2, il risolutore-bug ha committato su questo stesso ramo un commit R-3 (`ba9cc38 fix: R-3 mantieni sessione Firebase al refresh della pagina`). Questo commit:

- aggiunge `_initializing` / `isInitializing` ad `AuthProvider` e adatta `HomePage` di conseguenza;
- **corregge D-1 e D-2** (quindi i difetti del report del tester sono già chiusi nel codice attuale);
- dichiara nel messaggio di commit "12 test totali verdi" ma il file di test effettivo ha **solo 9 test** (i 3 test per `isInitializing` erano stati scritti nella working tree ma non sono stati committati nel ramo).

**R-3 non ha ancora un report del tester né una validazione**. Poiché è sullo stesso ramo di R-2, qualsiasi tentativo di rilasciare R-2 porterebbe in produzione anche R-3. Prima del rilascio è obbligatorio:

1. il tester esegua il ciclo completo su R-3 (inclusa la correzione della discrepanza sul conteggio dei test);
2. il validatore approvi R-3;
3. oppure, se si vuole rilasciare R-2 da sola, si crei un ramo `fix/R-2` con il solo commit `9e63c85` (più D-1/D-2 su un commit separato) e si apra una PR dedicata.

Questo segnale non blocca l'APPROVATO di R-2 come correzione di codice, ma blocca il rilascio del ramo corrente fino a risoluzione.

### Esito

**APPROVATO** per la correzione R-2 (commit `9e63c85` + le correzioni minori D-1/D-2 già in HEAD).

Il ramo `claude/epic-galileo-e9a406` non può essere rilasciato in produzione finché R-3 non ha superato il suo ciclo tester + validatore (o finché R-2 non viene isolata su un proprio ramo).
