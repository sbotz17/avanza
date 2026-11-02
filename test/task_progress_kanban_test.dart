// T-24: un task «in corso» non deve mostrare 0% e il kanban deve mostrare
// data e ora, come la vista elenco.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:avanza/models/task.dart';
import 'package:avanza/widgets/kanban_board.dart';

Task _task({
  String id = 't1',
  String title = 'Filtro clienti',
  String status = 'active',
  List<TaskPhase>? phases,
  DateTime? createdAt,
  DateTime? updatedAt,
}) =>
    Task(
      id: id,
      projectId: 'p1',
      title: title,
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

  // [R-5] Il kanban può essere più alto e più largo dello schermo: le schede
  // oltre il bordo devono restare raggiungibili in entrambi i sensi.
  group('KanbanBoard scorrimento', () {
    Future<void> pumpTallAndWideBoard(WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 300);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final tasks = [
        for (var i = 0; i < 25; i++)
          _task(id: 't$i', title: 'Task numero $i', status: 'active'),
      ];
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: KanbanBoard(tasks: tasks, onTaskTap: (_) {}),
        ),
      ));
    }

    SingleChildScrollView scrollViewFor(WidgetTester tester, Axis axis) =>
        tester
            .widgetList<SingleChildScrollView>(
                find.byType(SingleChildScrollView))
            .firstWhere((v) => v.scrollDirection == axis);

    testWidgets('ha uno scorrimento verticale e uno orizzontale', (tester) async {
      await pumpTallAndWideBoard(tester);

      final vertical = scrollViewFor(tester, Axis.vertical);
      final horizontal = scrollViewFor(tester, Axis.horizontal);

      // Il contenuto esce davvero dallo schermo nei due sensi.
      expect(vertical.controller!.position.maxScrollExtent, greaterThan(0));
      expect(horizontal.controller!.position.maxScrollExtent, greaterThan(0));
    });

    testWidgets('si trascina in verticale e in orizzontale', (tester) async {
      await pumpTallAndWideBoard(tester);

      final vertical = scrollViewFor(tester, Axis.vertical).controller!;
      final horizontal = scrollViewFor(tester, Axis.horizontal).controller!;

      await tester.dragFrom(const Offset(200, 150), const Offset(0, -150));
      await tester.pumpAndSettle();
      expect(vertical.offset, greaterThan(0));
      expect(horizontal.offset, 0);

      await tester.dragFrom(const Offset(200, 150), const Offset(-150, 0));
      await tester.pumpAndSettle();
      expect(horizontal.offset, greaterThan(0));
    });
  });
}
