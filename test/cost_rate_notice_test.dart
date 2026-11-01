// T-23: quando il costo orario di un operatore è 0 la spesa per operatore non è
// valorizzata. L'avviso lo dice in chiaro invece di mostrare euro a zero.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:avanza/core/cost_summary.dart';
import 'package:avanza/models/team_member.dart';
import 'package:avanza/widgets/cost_rate_notice.dart';

TeamMember _member(String name, {double cost = 0, bool active = true}) =>
    TeamMember(
      id: name,
      ownerId: 'u1',
      name: name,
      kind: 'agent',
      role: '',
      costRate: cost,
      billRate: 65,
      active: active,
      createdAt: DateTime(2026, 11, 1),
    );

Widget _wrap(Widget child) => MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(body: child),
    );

void main() {
  group('missingCostMemberNames', () {
    test('prende solo gli attivi con costo 0 e ignora chi ha una tariffa', () {
      final names = missingCostMemberNames([
        _member('tester'),
        _member('validatore', cost: 30),
        _member('disattivato', active: false),
      ]);

      expect(names, ['tester']);
    });

    test('un costo negativo non è una tariffa valida', () {
      expect(missingCostMemberNames([_member('x', cost: -1)]), ['x']);
    });
  });

  group('memberCostNotSetLabel', () {
    test('ore lavorate con costo 0: tariffa non impostata', () {
      expect(memberCostNotSetLabel(2, 0), 'costo non impostato (tariffa 0)');
    });

    test('costo valorizzato: nessun avviso', () {
      expect(memberCostNotSetLabel(2, 60), isNull);
    });

    test('nessuna ora: nessun avviso anche con costo 0', () {
      expect(memberCostNotSetLabel(0, 0), isNull);
    });
  });

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
