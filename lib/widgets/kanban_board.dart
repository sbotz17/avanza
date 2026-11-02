import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../models/task.dart';
import '../core/constants.dart';
import 'progress_bar.dart';
import 'meta_line.dart';
import '../core/date_format.dart';
import 'task_code_badge.dart';

class KanbanBoard extends StatefulWidget {
  final List<Task> tasks;
  final void Function(Task) onTaskTap;

  const KanbanBoard({super.key, required this.tasks, required this.onTaskTap});

  @override
  State<KanbanBoard> createState() => _KanbanBoardState();
}

class _KanbanBoardState extends State<KanbanBoard> {
  // [R-5] Il kanban è più largo e più alto dello schermo: servono due
  // scorrimenti indipendenti (orizzontale tra le colonne, verticale tra le
  // schede), altrimenti il contenuto oltre il bordo non è raggiungibile.
  final ScrollController _horizontal = ScrollController();
  final ScrollController _vertical = ScrollController();

  @override
  void dispose() {
    _horizontal.dispose();
    _vertical.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colBg = isDark ? const Color(0xFF1E1E22) : const Color(0xFFE8E8E2);

    return ScrollConfiguration(
      // Con il mouse si può trascinare il kanban (e la rotella verticale
      // scorre la pagina), come ci si aspetta da una lavagna sul web.
      behavior: const _KanbanScrollBehavior(),
      child: Scrollbar(
        controller: _vertical,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _vertical,
          padding: const EdgeInsets.only(top: 8, bottom: 16),
          child: Scrollbar(
            controller: _horizontal,
            thumbVisibility: true,
            notificationPredicate: (n) => n.metrics.axis == Axis.horizontal,
            child: SingleChildScrollView(
              controller: _horizontal,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: kKanbanColumns.map((colId) {
                  final colTasks =
                      widget.tasks.where((t) => t.kanbanCol == colId).toList();
                  final label = kKanbanLabels[colId] ?? colId;
                  return _KanbanColumn(
                    id: colId,
                    label: label,
                    tasks: colTasks,
                    bg: colBg,
                    isDark: isDark,
                    onTaskTap: widget.onTaskTap,
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Il comportamento predefinito di Flutter non lascia trascinare i contenuti
/// con il mouse: sul web il kanban sembrerebbe bloccato. Qui il mouse vale
/// come il dito; le barre di scorrimento restano quelle esplicite del widget.
class _KanbanScrollBehavior extends MaterialScrollBehavior {
  const _KanbanScrollBehavior();

  /// Le barre di scorrimento sono già fornite esplicitamente dal widget:
  /// niente doppioni sovrapposti sulla stessa lista.
  @override
  Widget buildScrollbar(
          BuildContext context, Widget child, ScrollableDetails details) =>
      child;

  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.mouse,
        PointerDeviceKind.unknown,
      };
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
            if (task.taskCode.isNotEmpty) ...[
              TaskCodeBadge(taskCode: task.taskCode),
              const SizedBox(height: 3),
            ],
            Text(
              task.title,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            MetaLine(
              icon: Icons.event_outlined,
              iconSize: 10,
              fontSize: 9,
              text: 'Creato ${AppDate.shortDateTime(task.createdAt)}',
            ),
            const SizedBox(height: 1),
            MetaLine(
              icon: Icons.update,
              iconSize: 10,
              fontSize: 9,
              text: 'Agg. ${AppDate.shortDateTime(task.updatedAt)}',
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
