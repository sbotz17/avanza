import 'package:flutter/material.dart';
import '../core/constants.dart';

/// Avviso esplicito quando uno o più operatori hanno il costo orario a zero:
/// senza tariffa interna la spesa per operatore vale zero e il margine è
/// gonfiato. Meglio dirlo che mostrare euro a zero come se fossero reali.
class CostRateNotice extends StatelessWidget {
  final List<String> memberNames;

  const CostRateNotice({super.key, required this.memberNames});

  @override
  Widget build(BuildContext context) {
    if (memberNames.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final n = memberNames.length;
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? kBlockedBgDark : kBlockedBg,
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(
            color: isDark ? kBlockedColorDark : kBlockedColor,
            width: 3,
          ),
        ),
      ),
      child: Text(
        'Attenzione: $n ${n == 1 ? 'operatore ha' : 'operatori hanno'} '
        'il costo orario a 0 (${memberNames.join(', ')}). '
        'Le spese per operatore e il margine non sono valorizzati: '
        'imposta il costo orario nella pagina Squadra.',
        style: TextStyle(
          fontSize: 12,
          color: isDark ? kBlockedColorDark : kBlockedColor,
        ),
      ),
    );
  }
}
