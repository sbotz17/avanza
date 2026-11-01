// T-23: quando il costo orario di un operatore è 0 la spesa per operatore non è
// valorizzata. L'avviso lo dice in chiaro invece di mostrare euro a zero.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:avanza/widgets/cost_rate_notice.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(body: child),
    );

void main() {
  group('CostRateNotice', () {
    testWidgets('elenca gli operatori senza costo orario', (tester) async {
      await tester.pumpWidget(_wrap(
        const CostRateNotice(memberNames: ['tester', 'validatore']),
      ));

      expect(find.textContaining('2 operatori hanno il costo orario a 0'),
          findsOneWidget);
      expect(find.textContaining('tester, validatore'), findsOneWidget);
    });

    testWidgets('usa il singolare per un solo operatore', (tester) async {
      await tester.pumpWidget(
        _wrap(const CostRateNotice(memberNames: ['tester'])),
      );

      expect(find.textContaining('1 operatore ha il costo orario a 0'),
          findsOneWidget);
    });

    testWidgets('senza operatori non mostra nulla', (tester) async {
      await tester.pumpWidget(_wrap(const CostRateNotice(memberNames: [])));

      expect(find.textContaining('Attenzione'), findsNothing);
    });
  });
}
