# Test R-5 — Kanban: scorrimento verticale e orizzontale (v2)

- Data: 2026-11-02
- Tester: sessione indipendente (tester della squadra)
- Ramo in prova: `fix/kanban-scorrimento`
- Commit fissato: `9c14d30` (HEAD) — correzione del widget in `29d8508`, codice prima della correzione in `d12df7e`
- PR: #54 verso `staging`
- Segnalazione: R-5 (`docs/progetto/ritorni.md` §R-5)

## Criteri di accettazione e verifica

| # | Criterio | Come verificato | Esito | Evidenza |
|---|---|---|---|---|
| 1 | Il kanban scorre in verticale (schede oltre l'altezza raggiungibili) | Test widget: `SingleChildScrollView` verticale presente e `maxScrollExtent > 0` con 25 schede su schermo 400×300 | OK | `test/task_progress_kanban_test.dart` → «ha uno scorrimento verticale e uno orizzontale» verde; test temporaneo 320×600 idem |
| 2 | Il kanban scorre in orizzontale (colonne oltre la larghezza raggiungibili) | Test widget: `SingleChildScrollView` orizzontale presente e `maxScrollExtent > 0` | OK | stesso test, verde |
| 3 | Trascinamento verticale e orizzontale indipendenti | Test widget: drag verticale cambia solo l'offset verticale (orizzontale resta 0), poi drag orizzontale cambia solo l'orizzontale | OK | test «si trascina in verticale e in orizzontale» verde |
| 4 | Trascinamento possibile anche con il mouse (web) | Test temporaneo del tester con `tester.dragFrom(..., kind: PointerDeviceKind.mouse)`: offset verticale e orizzontale > 0 | OK | test temporaneo (poi rimosso) verde; vedi prova rossa del mouse sotto |
| 5 | Barre di scorrimento visibili | Lettura codice: due `Scrollbar(thumbVisibility: true)`, una per asse, con `notificationPredicate` orizzontale; `buildScrollbar` disattivato per non duplicare | OK (per lettura codice) | `lib/widgets/kanban_board.dart` righe 39–60, 84–95 |
| 6 | Tap su una scheda continua a funzionare dentro gli scorrimenti | Test temporaneo: `tester.tap` su una scheda chiama `onTaskTap` con il task giusto | OK | test temporaneo verde |
| 7 | Nessuna regressione sulle altre schermate | `KanbanBoard` è usato solo in `lib/pages/project_page.dart` come `body` dello `Scaffold`; `ScrollConfiguration` è locale al widget; nessun'altra schermata tocca le regole globali | OK (per ricerca codice) | grep `KanbanBoard` → solo `project_page.dart` e test |
| 8 | Caso vuoto / contenuto che sta nello schermo: nessuna eccezione, nessuna barra verticale necessaria | Test temporaneo: 0 task e 1 scheda su 400×1200 → `maxScrollExtent` verticale = 0, nessuna eccezione | OK | test temporaneo verde |
| 9 | Compatibilità: le versioni precedenti dell'app continuano a funzionare | La correzione è solo UI locale: nessun cambio di dati, Firestore, regole, API o percorsi. Nessuna migrazione richiesta | OK (non applicabile lato dati) | diff `29d8508` limitato a widget + test + docs |

## Comandi eseguiti

| Comando | Esito |
|---|---|
| `git status` / `git log -3` | ramo `fix/kanban-scorrimento`, HEAD `9c14d30`, albero pulito |
| `flutter analyze` | **6 issue** (`info`), tutte preesistenti e fuori dal file toccato: `edit_task_page.dart` (3 `deprecated_member_use`), `test/auth_provider_test.dart` (1 `use_super_parameters`, 2 `prefer_const_constructors`) — 0 errori, 0 warning, 0 nel file toccato |
| `flutter test` | **117/117 verdi** (`All tests passed!`) |
| `flutter test test/task_progress_kanban_test.dart` (codice nuovo) | 8/8 verdi |

## Prova di regressione (rossa): i test falliscono sul codice precedente

1. Salvato `lib/widgets/kanban_board.dart` corrente.
2. Sostituito con la versione prima della correzione:
   `git show HEAD~2:lib/widgets/kanban_board.dart > lib/widgets/kanban_board.dart`
3. `flutter test test/task_progress_kanban_test.dart`
   Esito: **`00:00 +6 -2: Some tests failed.`** — falliscono
   - «KanbanBoard scorrimento ha uno scorrimento verticale e uno orizzontale»
     `Bad state: No element` su `scrollViewFor` (nessun `SingleChildScrollView` verticale).
   - «KanbanBoard scorrimento si trascina in verticale e in orizzontale»
     `Bad state: No element` (`test/task_progress_kanban_test.dart:117`).
4. Ripristinato il file: hash riallineato a `0c6e6e3` (= `HEAD:lib/widgets/kanban_board.dart`), `git status` pulito.

**Seconda prova rossa (solo scope mouse).** Rimosso temporaneamente l'override `dragDevices` dal `_KanbanScrollBehavior` (comportamento predefinito di Flutter):
- test temporaneo `tester.dragFrom(..., kind: PointerDeviceKind.mouse)` → **FALLITO** (`Actual: <0.0>`), quindi l'override `dragDevices` è ciò che rende possibile il trascinamento col mouse;
- i test committati restano verdi → **i test committati usano il touch e non coprono il caso mouse** (vedi difetto D-1).
File ripristinato, `git status` pulito.

## Difetti trovati

### D-1 (gravità bassa) — manca un test automatico per il trascinamento col mouse
- Dove: `test/task_progress_kanban_test.dart`, gruppo «KanbanBoard scorrimento».
- Cosa: i due test usano `tester.dragFrom` senza `kind`, quindi simulano il **touch**. Il pezzo nuovo che serve al web (abilitare `PointerDeviceKind.mouse` in `dragDevices`) non è protetto da nessun test committato: togliendo l'override i test restano verdi. La funzione **funziona** (verificata dal tester con un test dedicato), ma una regressione futura non verrebbe fermata.
- Proposta: aggiungere al gruppo un test con `tester.dragFrom(..., kind: PointerDeviceKind.mouse)` che verifichi offset > 0 in verticale e orizzontale. Inviare allo sviluppatore frontend (che ha toccato il file).
- Nota: non blocca il rilascio; il comportamento è verificato manualmente dal tester.

Nessun duplicato evitabile introdotto: `_KanbanScrollBehavior` è privato e locale; `KanbanBoard` e la sua voce in `catalogo.md` restano unici.

## Aree

| Area | Stato | Motivo |
|---|---|---|
| Scorrimento kanban (widget) | **PROVATA** | Criteri 1–4, 6, 8 verificati con test automatici (compreso il caso mouse); criterio 5 per lettura codice; test rossa allegata |
| Kanban nel browser reale (web desktop e smartphone) | **BLOCCATA** | Non eseguibile da questa sessione: serve un account reale (email/password) e un progetto con molti task. Nessuna credenziale di test disponibile. Da fare con la build di anteprima quando esiste l'utente di test. |
| Altre schermate / dati | **PROVATA** (per analisi) | `KanbanBoard` usato solo in `project_page.dart`; nessun cambiamento a dati, regole o API |

## Residui e cosa NON è stato provato
- **Prova UI nel browser reale: NON eseguita** (mancano credenziali). Restano da provare in anteprima: rotella del mouse, barre visibili anche in tema chiaro, trascinamento con trackpad, comportamento in formato smartphone.
- La resa grafica delle due barre (posizione, sovrapposizione) non è stata vista a schermo: solo lettura codice + test widget.
- `flutter build web` non eseguito (non richiesto per il fix; `flutter analyze` è pulito).

## Verdetto
**SUPERATO**, con area UI browser `BLOCCATA` (mancano credenziali) e difetto D-1 di gravità bassa (test mouse mancante) da rimandare allo sviluppatore frontend. Nessun difetto bloccante o alto.

## Addendum (2/11, dopo il report) — D-1 corretto
- Aggiunto il test committato «si trascina con il mouse in entrambi i sensi» (`tester.dragFrom(..., kind: PointerDeviceKind.mouse)`, prima verticale poi orizzontale) in `test/task_progress_kanban_test.dart`.
- Prova rossa eseguita: togliendo `PointerDeviceKind.mouse` da `dragDevices` il test **fallisce**; rimettendolo **passa**. Quindi ora la protezione del mouse è coperta.
- `flutter test` dopo l'aggiunta: **118/118 verdi**.
- D-1 è chiuso. Resta `BLOCCATA` solo la prova nel browser reale (mancano credenziali).
