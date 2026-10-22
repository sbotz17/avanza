import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/firestore_service.dart';
import '../models/task.dart';
import '../core/constants.dart';
import '../widgets/status_pill.dart';
import '../widgets/progress_bar.dart';
import '../widgets/phase_row.dart';
import '../widgets/empty_state.dart';

class TaskDetailPage extends StatelessWidget {
  final String projectId;
  final String taskId;
  final bool clientMode;

  const TaskDetailPage({
    super.key,
    required this.projectId,
    required this.taskId,
    this.clientMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isAdmin = !clientMode && auth.isLoggedIn;
    final service = FirestoreService();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg2 = isDark ? kFg2Dark : kFg2Light;

    return StreamBuilder<List<Task>>(
      stream: service.tasksStream(projectId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final tasks = snap.data ?? [];
        final task = tasks.cast<Task?>().firstWhere(
              (t) => t?.id == taskId,
              orElse: () => null,
            );

        if (task == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState(
              icon: Icons.search_off,
              title: 'Task non trovato',
            ),
          );
        }

        final pct = task.pct.round();
        final sectionTitle = TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: fg2,
        );

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.go('/project/$projectId'),
            ),
            title: Text(task.title),
            actions: [
              if (isAdmin)
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () =>
                      context.go('/project/$projectId/task/$taskId/edit'),
                  tooltip: 'Modifica',
                ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? kCardDark : kCardLight,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: isDark ? kBorderDark : kBorderLight),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black
                            .withOpacity(isDark ? 0.25 : 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  task.title,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (task.description.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    task.description,
                                    style: TextStyle(
                                        fontSize: 13, color: fg2),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          StatusPill(status: task.status),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Avanzamento', style: sectionTitle),
                          Text(
                            '$pct%',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: fg2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      SegmentedProgressBar(phases: task.phases, height: 10),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Client request
                if (task.clientRequest.isNotEmpty) ...[
                  Text('Richiesta', style: sectionTitle),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? kCardDark : kCardLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border(
                        left: BorderSide(
                          color: isDark ? kActiveColorDark : kActiveColor,
                          width: 3,
                        ),
                      ),
                    ),
                    child: Text(
                      task.clientRequest,
                      style: const TextStyle(fontSize: 13, height: 1.6),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Phases
                Text('Fasi di sviluppo', style: sectionTitle),
                const SizedBox(height: 8),
                ...task.phases.map((p) => PhaseRow(phase: p)),

                const SizedBox(height: 16),

                // Notes
                if (task.notes.isNotEmpty) ...[
                  Text('Note e stato corrente', style: sectionTitle),
                  const SizedBox(height: 8),
                  ...task.notes.map((n) => _NoteCard(note: n, isDark: isDark)),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _NoteCard extends StatelessWidget {
  final TaskNote note;
  final bool isDark;

  const _NoteCard({required this.note, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final (bg, border, icon) = _style(note.type, isDark);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: border, width: 3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              note.text,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  (Color, Color, String) _style(String type, bool isDark) {
    switch (type) {
      case 'ok':
        return (
          isDark ? kDoneBgDark : kDoneBg,
          isDark ? kDoneColorDark : kDoneColor,
          '✓',
        );
      case 'blk':
        return (
          isDark ? kBlockedBgDark : kBlockedBg,
          isDark ? kBlockedColorDark : kBlockedColor,
          '⚠',
        );
      default:
        return (
          isDark ? kActiveBgDark : kActiveBg,
          isDark ? kActiveColorDark : kActiveColor,
          '→',
        );
    }
  }
}
