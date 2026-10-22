import 'package:flutter/material.dart';
import '../models/task.dart';
import '../core/constants.dart';

class SegmentedProgressBar extends StatelessWidget {
  final List<TaskPhase> phases;
  final double height;

  const SegmentedProgressBar({
    super.key,
    required this.phases,
    this.height = 8,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: phases.map((phase) {
        if (phase.status == 'skip') {
          return const Expanded(child: SizedBox());
        }
        return Expanded(
          child: Container(
            height: height,
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            decoration: BoxDecoration(
              color: _color(phase.status, isDark),
              borderRadius: BorderRadius.circular(height / 2),
            ),
          ),
        );
      }).toList(),
    );
  }

  Color _color(String status, bool isDark) {
    switch (status) {
      case 'done':
        return isDark ? kDoneColorDark : kDoneColor;
      case 'active':
        return isDark ? kActiveColorDark : kActiveColor;
      case 'blocked':
        return isDark ? kBlockedColorDark : kBlockedColor;
      default:
        return isDark ? const Color(0xFF38383E) : const Color(0xFFE4E2DA);
    }
  }
}
