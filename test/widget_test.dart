// Flutter widget tests for Avanza.
// Firebase is not initialized in tests — integration tests would require
// a Firebase emulator setup.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:avanza/widgets/task_code_badge.dart';

void main() {
  test('placeholder test', () {
    expect(1 + 1, equals(2));
  });

  group('TaskCodeBadge', () {
    testWidgets('mostra il codice quando taskCode non è vuoto', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TaskCodeBadge(taskCode: 'T-3'),
          ),
        ),
      );
      expect(find.text('T-3'), findsOneWidget);
    });

    testWidgets('restituisce SizedBox.shrink quando taskCode è vuoto',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TaskCodeBadge(taskCode: ''),
          ),
        ),
      );
      expect(find.text('T-3'), findsNothing);
      // Il widget deve essere presente ma senza dimensioni effettive
      expect(find.byType(SizedBox), findsWidgets);
    });

    testWidgets('usa colori corretti in light mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.light),
          home: const Scaffold(
            body: TaskCodeBadge(taskCode: 'T-1'),
          ),
        ),
      );
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(TaskCodeBadge),
          matching: find.byType(Container),
        ),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, const Color(0xFFE8F0FF));
    });

    testWidgets('usa colori corretti in dark mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.dark),
          home: const Scaffold(
            body: TaskCodeBadge(taskCode: 'T-1'),
          ),
        ),
      );
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(TaskCodeBadge),
          matching: find.byType(Container),
        ),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, const Color(0xFF1E2A4A));
    });
  });
}
