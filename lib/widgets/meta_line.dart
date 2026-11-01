import 'package:flutter/material.dart';
import '../core/constants.dart';

/// Riga compatta con icona e testo, usata per le date sotto il titolo di un
/// task (elenco e dettaglio). Un solo componente evita due copie divergenti.
class MetaLine extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;
  final double fontSize;
  final double iconSize;

  const MetaLine({
    super.key,
    required this.icon,
    required this.text,
    this.color,
    this.fontSize = 11,
    this.iconSize = 12,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveColor = color ?? (isDark ? kFg2Dark : kFg2Light);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: iconSize, color: effectiveColor),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: fontSize, color: effectiveColor),
          ),
        ),
      ],
    );
  }
}
