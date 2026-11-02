/// Percorsi dell'app con la vista scelta.
///
/// [T-25] La vista kanban viaggia nel percorso (`?view=kanban`) così, entrando
/// in un task e tornando indietro, si ritrova la vista selezionata.
library;

const String kViewQuery = 'view';
const String kKanbanValue = 'kanban';

bool isKanbanQuery(Map<String, String> query) => query[kViewQuery] == kKanbanValue;

String viewQuery(bool kanban) => kanban ? '?$kViewQuery=$kKanbanValue' : '';

String projectPath(String projectId, {bool kanban = false}) =>
    '/project/$projectId${viewQuery(kanban)}';

String taskPath(String projectId, String taskId, {bool kanban = false}) =>
    '/project/$projectId/task/$taskId${viewQuery(kanban)}';

String editTaskPath(String projectId, String taskId, {bool kanban = false}) =>
    '/project/$projectId/task/$taskId/edit${viewQuery(kanban)}';
