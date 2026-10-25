// R-4 — modificare un progetto non deve azzerare il contatore dei codici T-N.
// Il contatore `nextTaskNumber` cambia solo alla creazione di un task (transazione
// in FirestoreService.createTask): copyWith lo deve conservare.
import 'package:flutter_test/flutter_test.dart';
import 'package:avanza/models/project.dart';

Project progetto({int next = 7}) => Project(
      id: 'p1',
      name: 'Volty',
      description: 'Gestionale',
      githubUrl: 'https://github.com/sbotz17/volty-flutter',
      clientCode: 'ABC123',
      ownerId: 'owner-1',
      nextTaskNumber: next,
      createdAt: DateTime(2026, 10, 1),
      updatedAt: DateTime(2026, 10, 2),
    );

void main() {
  group('R-4 Project.copyWith conserva il contatore', () {
    test('copyWith dei campi modificabili non azzera nextTaskNumber', () {
      final p = progetto(next: 7).copyWith(name: 'Nuovo nome');
      expect(p.nextTaskNumber, 7);
      expect(p.toMap()['nextTaskNumber'], 7);
    });

    test('copyWith senza argomenti conserva tutti gli altri campi', () {
      final p = progetto(next: 12).copyWith();
      expect(p.nextTaskNumber, 12);
      expect(p.clientCode, 'ABC123');
      expect(p.ownerId, 'owner-1');
      expect(p.createdAt, DateTime(2026, 10, 1));
    });

    test('copyWith aggiorna nome, descrizione e indirizzo GitHub', () {
      final p = progetto().copyWith(
          name: 'N', description: 'D', githubUrl: 'https://github.com/x/y');
      expect(p.name, 'N');
      expect(p.description, 'D');
      expect(p.githubUrl, 'https://github.com/x/y');
    });
  });

  group('R-4 updateProject scrive solo i campi modificabili', () {
    test('editableFields contiene solo nome, descrizione e indirizzo GitHub',
        () {
      final m = progetto(next: 7).copyWith(name: 'N').editableFields();
      expect(m.keys.toSet(), {'name', 'description', 'githubUrl'});
      expect(m['name'], 'N');
    });

    test(
        'editableFields non contiene mai contatore, codice, proprietario, createdAt',
        () {
      final m = progetto(next: 7).editableFields();
      for (final k in [
        'nextTaskNumber',
        'clientCode',
        'ownerId',
        'createdAt',
        'id'
      ]) {
        expect(m.containsKey(k), isFalse, reason: k);
      }
    });

    test(
        'progetto letto con contatore mancante (default 1): la modifica non scrive il contatore',
        () {
      final m = progetto(next: 1).editableFields();
      expect(m.containsKey('nextTaskNumber'), isFalse);
    });
  });
}
