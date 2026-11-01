import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/date_format.dart';
import '../models/task.dart';

/// Riquadro della richiesta originale di un task: mostra sempre il testo (o
/// "Nessuna richiesta registrata") e la data in cui la richiesta è arrivata,
/// così nel dettaglio si capisce a cosa si riferisce il lavoro.
class TaskRequestCard extends StatelessWidget {
  final Task task;

  const TaskRequestCard({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg2 = isDark ? kFg2Dark : kFg2Light;

    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (task.clientRequest.isEmpty)
            Text(
              'Nessuna richiesta registrata per questo task.',
              style: TextStyle(
                fontSize: 13,
                height: 1.6,
                fontStyle: FontStyle.italic,
                color: fg2,
              ),
            )
          else
            Text(
              task.clientRequest,
              style: const TextStyle(fontSize: 13, height: 1.6),
            ),
          const SizedBox(height: 6),
          Text(
            'Richiesta ricevuta il ${AppDate.dateTime(task.createdAt)}'
            '${task.taskCode.isEmpty ? '' : ' · ${task.taskCode}'}',
            style: TextStyle(fontSize: 11, color: fg2),
          ),
        ],
      ),
    );
  }
}
