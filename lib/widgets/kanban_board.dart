import 'package:flutter/material.dart';
import '../models/task.dart';
import '../core/constants.dart';
import 'status_pill.dart';
import 'progress_bar.dart';

class KanbanBoard extends StatelessWidget {
  final List<Task> tasks;
  final void Function(Task) onTaskTap;

  const KanbanBoard({super.key, required this.tasks, required this.onTaskTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colBg = isDark ? const Color(0xFF1E1E22) : const Color(0xFFE8E8E2);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: kKanbanColumns.map((colId) {
          final colTasks = tasks.where((t) => t.kanbanCol == colId).toList();
          final label = kKanbanLabels[colId] ?? colId;
          return _KanbanColumn(
            id: colId,
            label: label,
            tasks: colTasks,
            bg: colBg,
            isDark: isDark,
            onTaskTap: onTaskTap,
          );
        }).toList(),
      ),
    );
  }
}

class _KanbanColumn extends StatelessWidget {
  final String id;
  final String label;
  final List<Task> tasks;
  final Color bg;
  final bool isDark;
  final void Function(Task) onTaskTap;

  const _KanbanColumn({
    required this.id,
    required this.label,
    required this.tasks,
    required this.bg,
    required this.isDark,
    required this.onTaskTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg2 = isDark ? kFg2Dark : kFg2Light;
    final borderColor = isDark ? kBorderDark : kBorderLight;
    final dotColor = _dotColor(id, isDark);

    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Column header
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: fg2,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (tasks.isNotEmpty)
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: borderColor,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${tasks.length}',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: fg2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (tasks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Center(
                child: Text(
                  '—',
                  style: TextStyle(fontSize: 11, color: fg2.withValues(alpha: 0.4)),
                ),
              ),
            )
          else
            ...tasks.map((task) => _KanbanCard(
                  task: task,
                  isDark: isDark,
                  onTap: () => onTaskTap(task),
                )),
        ],
      ),
    );
  }

  Color _dotColor(String colId, bool isDark) {
    switch (colId) {
      case 'released':
      case 'validated':
        return isDark ? kDoneColorDark : kDoneColor;
      case 'active':
      case 'review':
        return isDark ? kActiveColorDark : kActiveColor;
      case 'blocked':
        return isDark ? kBlockedColorDark : kBlockedColor;
      default:
        return isDark ? kPendingColorDark : kPendingColor;
    }
  }
}

class _KanbanCard extends StatelessWidget {
  final Task task;
  final bool isDark;
  final VoidCallback onTap;

  const _KanbanCard({required this.task, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cardColor = isDark ? kCardDark : kCardLight;
    final borderColor = isDark ? kBorderDark : kBorderLight;
    final fg2 = isDark ? kFg2Dark : kFg2Light;
    final pct = task.pct.round();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
              blurRadius: 4,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              task.title,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: SegmentedProgressBar(phases: task.phases, height: 3),
                ),
                const SizedBox(width: 6),
                Text(
                  '$pct%',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: fg2,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
