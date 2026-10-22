import 'package:flutter/material.dart';

const Color _lightBg = Color(0xFFE8F0FF);
const Color _lightFg = Color(0xFF3B5BDB);
const Color _darkBg = Color(0xFF1E2A4A);
const Color _darkFg = Color(0xFF748FFC);

/// Badge compatto che mostra il codice univoco di un task (es. "T-3").
/// Se [taskCode] è vuoto, restituisce [SizedBox.shrink()].
class TaskCodeBadge extends StatelessWidget {
  final String taskCode;

  const TaskCodeBadge({super.key, required this.taskCode});

  @override
  Widget build(BuildContext context) {
    if (taskCode.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? _darkBg : _lightBg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        taskCode,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          fontFamily: 'monospace',
          color: isDark ? _darkFg : _lightFg,
          height: 1.2,
        ),
      ),
    );
  }
}
