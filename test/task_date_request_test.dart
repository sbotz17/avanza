// T-21: il task mostra data e ora di creazione/aggiornamento e la richiesta
// originale a cui si riferisce. Test dei widget, senza Firebase.
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:avanza/core/date_format.dart';
import 'package:avanza/models/task.dart';
import 'package:avanza/widgets/task_card.dart';
import 'package:avanza/widgets/task_request_card.dart';

Task _task({
  String clientRequest = 'Aggiungere il filtro per cliente',
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  final created = createdAt ?? DateTime(2026, 11, 1, 14, 30);
  return Task(
    id: 't1',
    projectId: 'p1',
    title: 'Filtro clienti',
    description: 'Filtro nella lista',
    clientRequest: clientRequest,
    status: 'active',
    phases: const [
      TaskPhase(name: 'Analisi', status: 'done', label: 'Completato'),
      TaskPhase(name: 'Frontend', status: 'active', label: 'In corso'),
    ],
    notes: const [],
    order: 0,
    taskCode: 'T-21',
    taskNumber: 21,
    createdAt: created,
    updatedAt: updatedAt ?? DateTime(2026, 11, 1, 16, 45),
  );
}

Widget _wrap(Widget child) => MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  group('AppDate', () {
    test('formatta data e ora in italiano', () {
      expect(AppDate.dateTime(DateTime(2026, 11, 1, 9, 5)), '01/11/2026 09:05');
    });

    test('una data sentinella diventa "data non disponibile"', () {
      expect(AppDate.dateTime(DateTime.fromMillisecondsSinceEpoch(0)),
          'data non disponibile');
    });
  });

  group('Task.fromMap', () {
    test('senza date usa la sentinella, non l ora di apertura', () {
      final t = Task.fromMap({'title': 'Vecchio task'}, 't1', 'p1');
      expect(t.createdAt.year, 1970);
      expect(t.updatedAt.year, 1970);
      expect(AppDate.dateTime(t.createdAt), 'data non disponibile');
    });

    test('legge le date Firestore quando ci sono', () {
      final when = DateTime(2026, 11, 1, 14, 30);
      final t = Task.fromMap(
        {
          'title': 'Task nuovo',
          'createdAt': Timestamp.fromDate(when),
          'updatedAt': Timestamp.fromDate(when.add(const Duration(hours: 2))),
        },
        't2',
        'p1',
      );
      expect(t.createdAt, when);
      expect(AppDate.dateTime(t.createdAt), '01/11/2026 14:30');
    });
  });

  group('TaskCard', () {
    testWidgets('mostra creato il e aggiornato il con data e ora', (tester) async {
      await tester.pumpWidget(_wrap(TaskCard(task: _task(), onTap: () {})));

      expect(find.text('Creato il 01/11/2026 14:30'), findsOneWidget);
      expect(find.text('Aggiornato il 01/11/2026 16:45'), findsOneWidget);
    });

    testWidgets('un task senza data non inventa l orario di apertura',
        (tester) async {
      await tester.pumpWidget(_wrap(TaskCard(
        task: _task(
          createdAt: DateTime.fromMillisecondsSinceEpoch(0),
          updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
        ),
        onTap: () {},
      )));

      expect(find.textContaining('data non disponibile'), findsNWidgets(2));
    });
  });

  group('TaskRequestCard', () {
    testWidgets('mostra la richiesta originale e la data di ricezione',
        (tester) async {
      await tester.pumpWidget(_wrap(TaskRequestCard(task: _task())));

      expect(find.text('Aggiungere il filtro per cliente'), findsOneWidget);
      expect(
        find.text('Richiesta ricevuta il 01/11/2026 14:30 · T-21'),
        findsOneWidget,
      );
    });

    testWidgets('senza richiesta lo dice invece di lasciare il vuoto',
        (tester) async {
      await tester.pumpWidget(_wrap(TaskRequestCard(task: _task(clientRequest: ''))));

      expect(
        find.text('Nessuna richiesta registrata per questo task.'),
        findsOneWidget,
      );
    });
  });
}
