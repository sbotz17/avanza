// T-25: la vista kanban viaggia nel percorso e si ritrova tornando dal task.
import 'package:flutter_test/flutter_test.dart';
import 'package:avanza/core/routes.dart';

void main() {
  group('vista nel percorso', () {
    test('senza kanban il percorso resta pulito', () {
      expect(projectPath('p1'), '/project/p1');
      expect(taskPath('p1', 't1'), '/project/p1/task/t1');
      expect(editTaskPath('p1', 't1'), '/project/p1/task/t1/edit');
    });

    test('con kanban il percorso porta ?view=kanban', () {
      expect(projectPath('p1', kanban: true), '/project/p1?view=kanban');
      expect(taskPath('p1', 't1', kanban: true),
          '/project/p1/task/t1?view=kanban');
      expect(editTaskPath('p1', 't1', kanban: true),
          '/project/p1/task/t1/edit?view=kanban');
    });

    test('legge il kanban dalla query', () {
      expect(isKanbanQuery(const {'view': 'kanban'}), isTrue);
      expect(isKanbanQuery(const {'view': 'list'}), isFalse);
      expect(isKanbanQuery(const {}), isFalse);
    });
  });
}
