import 'package:flutter/material.dart';
import '../models/task.dart';
import '../core/constants.dart';

class PhaseRow extends StatelessWidget {
  final TaskPhase phase;

  const PhaseRow({super.key, required this.phase});

  @override
  Widget build(BuildContext context) {
    if (phase.status == 'skip') return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (bg, fg, icon) = _style(phase.status, isDark);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              phase.name,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
          ),
          Text(
            phase.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  (Color, Color, String) _style(String status, bool isDark) {
    switch (status) {
      case 'done':
        return (
          isDark ? kDoneBgDark : kDoneBg,
          isDark ? kDoneColorDark : kDoneColor,
          '✓',
        );
      case 'active':
        return (
          isDark ? kActiveBgDark : kActiveBg,
          isDark ? kActiveColorDark : kActiveColor,
          '●',
        );
      case 'blocked':
        return (
          isDark ? kBlockedBgDark : kBlockedBg,
          isDark ? kBlockedColorDark : kBlockedColor,
          '⚠',
        );
      default:
        return (
          isDark ? kPendingBgDark : kPendingBg,
          isDark ? kPendingColorDark : kPendingColor,
          '○',
        );
    }
  }
}
