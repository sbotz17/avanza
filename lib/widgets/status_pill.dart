import 'package:flutter/material.dart';
import '../core/constants.dart';

class StatusPill extends StatelessWidget {
  final String status;
  final String? label;
  final bool dark;

  const StatusPill({
    super.key,
    required this.status,
    this.label,
    this.dark = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = dark ||
        Theme.of(context).brightness == Brightness.dark;
    final (fg, bg) = _colors(status, isDark);
    final text = label ?? _defaultLabel(status);
    final isActive = status == 'active';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: status == 'backlog' || status == 'pending'
            ? Border.all(color: isDark ? kBorderDark : kBorderLight)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isActive)
            _PulseDot(color: fg)
          else
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
            ),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: fg,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  (Color, Color) _colors(String s, bool isDark) {
    switch (s) {
      case 'released':
      case 'validated':
      case 'done':
        return isDark ? (kDoneColorDark, kDoneBgDark) : (kDoneColor, kDoneBg);
      case 'active':
      case 'review':
        return isDark ? (kActiveColorDark, kActiveBgDark) : (kActiveColor, kActiveBg);
      case 'blocked':
        return isDark
            ? (kBlockedColorDark, kBlockedBgDark)
            : (kBlockedColor, kBlockedBg);
      default:
        return isDark
            ? (kPendingColorDark, kPendingBgDark)
            : (kPendingColor, kPendingBg);
    }
  }

  String _defaultLabel(String s) {
    switch (s) {
      case 'released':
        return 'Rilasciato';
      case 'validated':
        return 'Validato';
      case 'review':
        return 'In test / QA';
      case 'active':
        return 'In corso';
      case 'blocked':
        return 'Bloccato';
      case 'done':
        return 'Completato';
      default:
        return 'In attesa';
    }
  }
}

class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({required this.color});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 1.0, end: 0.4).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _anim,
        child: Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
        ),
      );
}
