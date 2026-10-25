# Nodo: App Flutter web

Ultima revisione: 2026-10-25

- Solo web (https://avanza-b62d7.web.app), `--pwa-strategy=none`, `no-cache` per js/css/html/json (`firebase.json`): niente service worker.
- Router `go_router` in `lib/app.dart`: ripristina la sessione prima di decidere, ricorda la pagina richiesta (`from`), guardie per ruolo. Nuova route: aggiungerla in `lib/app.dart` e, se solo admin, in `_isAdminOnly`; poi controllare le regole Firestore.
- Ruoli: `admin` (vede tutto) e `client` (solo progetti collegati col codice). Stato auth in `lib/providers/auth_provider.dart`; accesso dati SOLO da `lib/services/firestore_service.dart`, auth da `lib/services/auth_service.dart`.
- Pagine: `login_page` (con "Ricorda email", `lib/services/remember_email.dart`), `home_page` (admin), `client_home_page`, `project_page`, `task_detail_page` (con chat admin↔squadra: `lib/widgets/task_chat.dart`, `lib/models/chat_message.dart`); admin: `costs_page`, `edit_project_page`, `edit_task_page`, `team_page`, `time_report`.
- Widget condivisi (riusare, non duplicare): `EmptyState`, `KanbanBoard`, `PhaseRow`, `ProgressBar`, `StatusPill`, `TaskCard`, `TaskCodeBadge`, `TeamMemberTile`. Colori/fasi in `lib/core/constants.dart`, tema in `lib/core/theme.dart`.
- Convenzioni UI: "Nuovo/Modifica X" = pagina intera (modello `edit_project_page`), finestre di dialogo solo per azioni secondarie; testi in italiano; tema scuro e chiaro. Prima di scegliere dove mettere una voce di menu: chiedere conferma ad Andrea.
- Modelli (`lib/models/`): `Project`, `Task`, `TaskCost`, `TeamMember`, `TimeEntry`, `ChatMessage`, stessi nomi dei campi Firestore. `Project.copyWith` ora conserva `nextTaskNumber`; `updateProject` scrive solo `editableFields()` (R-4/T-19).
- Test: `flutter analyze` (6 "info" preesistenti accettati) e `flutter test` (90 verdi al 25/10). Il Flutter installato in sessione è troppo vecchio: i test si fanno con Flutter stable recente scaricato a parte; la CI è il controllo vero.
- Catalogo oggetti: `catalogo.md`. Decisioni UI recenti: `diario.md` (T-17 Squadra, T-11/T-12 login e chat).
