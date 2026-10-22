import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/firestore_service.dart';
import '../models/project.dart';
import '../models/task.dart';
import '../core/constants.dart';
import '../widgets/task_card.dart';
import '../widgets/kanban_board.dart';
import '../widgets/empty_state.dart';

class ProjectPage extends StatefulWidget {
  final String projectId;
  final bool clientMode;

  const ProjectPage({
    super.key,
    required this.projectId,
    this.clientMode = false,
  });

  @override
  State<ProjectPage> createState() => _ProjectPageState();
}

class _ProjectPageState extends State<ProjectPage> {
  bool _kanbanView = false;
  final _service = FirestoreService();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isAdmin = !widget.clientMode && auth.isLoggedIn;

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
                      isAdmin ? context.go('/home') : context.go('/client'),
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
                    onPressed: () => setState(() => _kanbanView = !_kanbanView),
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
                              onTaskTap: (t) => context.go(
                                '/project/${widget.projectId}/task/${t.id}',
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: tasks.length,
                              itemBuilder: (context, i) => TaskCard(
                                task: tasks[i],
                                onTap: () => context.go(
                                  '/project/${widget.projectId}/task/${tasks[i].id}',
                                ),
                              ),
                            ),
              floatingActionButton: isAdmin
                  ? FloatingActionButton(
                      onPressed: () => context.go(
                        '/project/${widget.projectId}/task/new/edit',
                      ),
                      child: const Icon(Icons.add),
                    )
                  : null,
            );
          },
        );
      },
    );
  }

  String _shortUrl(String url) => url
      .replaceFirst('https://github.com/', '')
      .replaceFirst('http://github.com/', '');
}
