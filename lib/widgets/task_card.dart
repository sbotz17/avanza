import 'package:flutter/material.dart';
import '../models/task.dart';
import '../core/constants.dart';
import '../core/date_format.dart';
import 'status_pill.dart';
import 'progress_bar.dart';
import 'task_code_badge.dart';
import 'meta_line.dart';

class TaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback onTap;

  const TaskCard({super.key, required this.task, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? kCardDark : kCardLight;
    final borderColor = isDark ? kBorderDark : kBorderLight;
    final fg2 = isDark ? kFg2Dark : kFg2Light;
    final pct = task.pct.round();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
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
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (task.taskCode.isNotEmpty) ...[
                            TaskCodeBadge(taskCode: task.taskCode),
                            const SizedBox(width: 6),
                          ],
                          Expanded(
                            child: Text(
                              task.title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (task.description.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          task.description,
                          style: TextStyle(fontSize: 12, color: fg2),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 6),
                      // Data e ora: senza di esse non si capisce quando il task
                      // è nato né quando è stato aggiornato l'ultima volta.
                      Wrap(
                        spacing: 10,
                        runSpacing: 2,
                        children: [
                          MetaLine(
                            icon: Icons.event_outlined,
                            text: 'Creato il ${AppDate.dateTime(task.createdAt)}',
                          ),
                          MetaLine(
                            icon: Icons.update,
                            text:
                                'Aggiornato il ${AppDate.dateTime(task.updatedAt)}',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                StatusPill(status: task.status),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Avanzamento',
                            style: TextStyle(fontSize: 11, color: fg2),
                          ),
                          Text(
                            '$pct%',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: fg2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      SegmentedProgressBar(phases: task.phases),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(Icons.chevron_right, color: fg2, size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

