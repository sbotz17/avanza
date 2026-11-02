import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/firestore_service.dart';
import '../models/project.dart';
import '../models/task.dart';
import '../core/constants.dart';
import '../core/routes.dart';
import '../widgets/task_card.dart';
import '../widgets/kanban_board.dart';
import '../widgets/empty_state.dart';

class ProjectPage extends StatefulWidget {
  final String projectId;

  /// [T-25] Vista scelta nel percorso (`?view=kanban`): così, tornando dal
  /// dettaglio di un task, si ritrova il kanban invece della lista.
  final bool initialKanban;

  const ProjectPage({
    super.key,
    required this.projectId,
    this.initialKanban = false,
  });

  @override
  State<ProjectPage> createState() => _ProjectPageState();
}

class _ProjectPageState extends State<ProjectPage> {
  late bool _kanbanView;
  final _service = FirestoreService();

  @override
  void initState() {
    super.initState();
    _kanbanView = widget.initialKanban;
  }

  @override
  void didUpdateWidget(covariant ProjectPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Cambio di `?view=` (es. avanti/indietro del browser o link diretto):
    // la schermata segue l'indirizzo.
    if (oldWidget.initialKanban != widget.initialKanban) {
      _kanbanView = widget.initialKanban;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isAdmin = auth.isAdmin;

    return StreamBuilder<Project?>(
      stream: _service.projectStream(widget.projectId),
      builder: (context, projectSnap) {
        final project = projectSnap.data;

        return StreamBuilder<List<Task>>(
          stream: _service.tasksStream(widget.projectId),
          builder: (context, taskSnap) {
            final tasks = taskSnap.data ?? [];
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final fg2 = isDark ? kFg2Dark : kFg2Light;

            return Scaffold(
              appBar: AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () =>
                      isAdmin ? context.go('/home') : context.go('/client-home'),
                ),
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project?.name ?? 'Progetto',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    if (project != null && project.githubUrl.isNotEmpty)
                      Text(
                        _shortUrl(project.githubUrl),
                        style: TextStyle(fontSize: 11, color: fg2),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
                actions: [
                  IconButton(
                    icon: Icon(_kanbanView
                        ? Icons.view_list_rounded
                        : Icons.view_column_rounded),
                    onPressed: () {
                      final next = !_kanbanView;
                      setState(() => _kanbanView = next);
                      // Tiene l'indirizzo allineato alla vista: ricaricando la
                      // pagina si ritrova il kanban e il link è condivisibile.
                      context.go(
                        projectPath(widget.projectId, kanban: next),
                      );
                    },
                    tooltip: _kanbanView ? 'Vista lista' : 'Vista kanban',
                  ),
                  if (isAdmin) ...[
                    IconButton(
                      icon: const Icon(Icons.euro_rounded),
                      onPressed: () =>
                          context.go('/project/${widget.projectId}/costs'),
                      tooltip: 'Costi',
                    ),
                    PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'edit') {
                          context.go('/project/${widget.projectId}/edit');
                        }
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(children: [
                            Icon(Icons.edit_outlined, size: 18),
                            SizedBox(width: 8),
                            Text('Modifica progetto'),
                          ]),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              body: taskSnap.connectionState == ConnectionState.waiting
                  ? const Center(child: CircularProgressIndicator())
                  : tasks.isEmpty
                      ? EmptyState(
                          icon: Icons.assignment_outlined,
                          title: 'Nessun task',
                          subtitle: isAdmin
                              ? 'Aggiungi il primo task con il pulsante +.'
                              : 'Nessun task disponibile al momento.',
                        )
                      : _kanbanView
                          ? KanbanBoard(
                              tasks: tasks,
                              onTaskTap: (t) =>
                                  context.go(_taskPath(t.id)),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: tasks.length,
                              itemBuilder: (context, i) => TaskCard(
                                task: tasks[i],
                                onTap: () =>
                                    context.go(_taskPath(tasks[i].id)),
                              ),
                            ),
              floatingActionButton: isAdmin
                  ? FloatingActionButton(
                      onPressed: () => context.go(_editTaskPath('new')),
                      child: const Icon(Icons.add),
                    )
                  : null,
            );
          },
        );
      },
    );
  }

  /// Porta la vista scelta nel percorso, così il dettaglio task può tornarci.
  String _taskPath(String taskId) =>
      taskPath(widget.projectId, taskId, kanban: _kanbanView);

  String _editTaskPath(String taskId) =>
      editTaskPath(widget.projectId, taskId, kanban: _kanbanView);

  String _shortUrl(String url) => url
      .replaceFirst('https://github.com/', '')
      .replaceFirst('http://github.com/', '');
}
