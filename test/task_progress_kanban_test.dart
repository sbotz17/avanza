// T-24: un task «in corso» non deve mostrare 0% e il kanban deve mostrare
// data e ora, come la vista elenco.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:avanza/models/task.dart';
import 'package:avanza/widgets/kanban_board.dart';

Task _task({
  String status = 'active',
  List<TaskPhase>? phases,
  DateTime? createdAt,
  DateTime? updatedAt,
}) =>
    Task(
      id: 't1',
      projectId: 'p1',
      title: 'Filtro clienti',
      description: '',
      clientRequest: 'Richiesta',
      status: status,
      phases: phases ??
          const [
            TaskPhase(name: 'Analisi', status: 'pending', label: 'In attesa'),
            TaskPhase(name: 'Frontend', status: 'pending', label: 'In attesa'),
          ],
      notes: const [],
      order: 0,
      taskCode: 'T-24',
      taskNumber: 24,
      createdAt: createdAt ?? DateTime(2026, 11, 1, 14, 30),
      updatedAt: updatedAt ?? DateTime(2026, 11, 1, 16, 45),
    );

void main() {
  group('Task.pct', () {
    test('task in corso senza fasi concluse: non è 0%', () {
      expect(_task().pct, greaterThan(0));
    });

    test('task in corso con una fase attiva: metà fase', () {
      final t = _task(phases: const [
        TaskPhase(name: 'Analisi', status: 'done', label: 'Fatto'),
        TaskPhase(name: 'Frontend', status: 'active', label: 'In corso'),
        TaskPhase(name: 'Test', status: 'pending', label: 'In attesa'),
      ]);
      expect(t.pct, closeTo(50, 0.01));
    });

    test('task in backlog tutto in attesa: 0%', () {
      expect(_task(status: 'backlog').pct, 0);
    });

    test('le fasi "non necessarie" non contano', () {
      final t = _task(phases: const [
        TaskPhase(name: 'Analisi', status: 'done', label: 'Fatto'),
        TaskPhase(name: 'Design', status: 'skip', label: 'Non necessaria'),
        TaskPhase(name: 'Test', status: 'done', label: 'Fatto'),
      ]);
      expect(t.pct, 100);
    });
  });

  group('KanbanBoard', () {
    testWidgets('mostra data e ora di creazione e aggiornamento', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: KanbanBoard(tasks: [_task()], onTaskTap: (_) {}),
        ),
      ));

      expect(find.text('Creato 01/11 14:30'), findsOneWidget);
      expect(find.text('Agg. 01/11 16:45'), findsOneWidget);
    });

    testWidgets('un task in corso mostra un avanzamento maggiore di zero',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: KanbanBoard(tasks: [_task()], onTaskTap: (_) {}),
        ),
      ));

      expect(find.text('0%'), findsNothing);
      expect(find.textContaining('%'), findsWidgets);
    });
  });
}
