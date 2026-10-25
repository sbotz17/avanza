// ignore_for_file: depend_on_referenced_packages
// R-4 (aggiunto dal tester) — prova di FirestoreService.updateProject FINO ALLA
// scrittura: si sostituisce la piattaforma Firestore con una finta che registra
// le chiamate `update`, cosi' si verifica davvero cosa arriva a Firestore (non solo
// la mappa di Project.editableFields). Nessuna dipendenza nuova.
import 'package:cloud_firestore_platform_interface/cloud_firestore_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:avanza/models/project.dart';
import 'package:avanza/services/firestore_service.dart';

class _Scrittura {
  _Scrittura(this.percorso, this.dati);
  final String percorso;
  final Map<FieldPath, dynamic> dati;
  Map<String, dynamic> get chiavi =>
      {for (final e in dati.entries) e.key.components.join('.'): e.value};
}

final List<_Scrittura> _scritture = [];
final List<String> _altreScritture = [];

class _FinteDoc extends DocumentReferencePlatform {
  _FinteDoc(super.firestore, super.path);

  @override
  Future<void> update(Map<FieldPath, dynamic> data) async {
    _scritture.add(_Scrittura(path, data));
  }

  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    _altreScritture.add('set $path');
  }

  @override
  Future<void> delete() async {
    _altreScritture.add('delete $path');
  }
}

class _FinteCollezione extends CollectionReferencePlatform {
  _FinteCollezione(super.firestore, super.path);

  @override
  DocumentReferencePlatform doc([String? path]) =>
      _FinteDoc(firestore, '${this.path}/${path ?? 'nuovo'}');
}

class _FinteFirestore extends FirebaseFirestorePlatform {
  _FinteFirestore() : super(appInstance: Firebase.app(), databaseChoice: '(default)');

  @override
  FirebaseFirestorePlatform delegateFor(
          {required FirebaseApp app, required String databaseId}) =>
      this;

  @override
  CollectionReferencePlatform collection(String collectionPath) =>
      _FinteCollezione(this, collectionPath);

  @override
  DocumentReferencePlatform doc(String documentPath) =>
      _FinteDoc(this, documentPath);
}

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
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    FirebaseFirestorePlatform.instance = _FinteFirestore();
  });

  setUp(() {
    _scritture.clear();
    _altreScritture.clear();
  });

  group('R-4 updateProject: cosa arriva davvero a Firestore', () {
    test('scrive solo nome, descrizione, indirizzo GitHub e updatedAt', () async {
      final p = progetto(next: 7).copyWith(name: 'Nuovo', description: 'D2');
      await FirestoreService().updateProject(p);

      expect(_scritture, hasLength(1));
      final w = _scritture.single;
      expect(w.percorso, 'projects/p1');
      expect(w.chiavi.keys.toSet(),
          {'name', 'description', 'githubUrl', 'updatedAt'});
      expect(w.chiavi['name'], 'Nuovo');
      expect(w.chiavi['description'], 'D2');
      expect(_altreScritture, isEmpty);
    });

    test('non scrive mai contatore, codice cliente, proprietario, createdAt',
        () async {
      // Anche con un progetto letto con contatore azzerato (default 1) o alto.
      for (final n in [1, 7, 9999]) {
        _scritture.clear();
        await FirestoreService().updateProject(progetto(next: n));
        final k = _scritture.single.chiavi.keys;
        for (final vietata in [
          'nextTaskNumber',
          'clientCode',
          'ownerId',
          'createdAt',
          'id'
        ]) {
          expect(k, isNot(contains(vietata)), reason: '$vietata con next=$n');
        }
      }
    });

    test('updatedAt e\' il timestamp del server, non l\'orologio del client',
        () async {
      await FirestoreService().updateProject(progetto());
      expect(_scritture.single.chiavi['updatedAt'], isA<FieldValuePlatform>());
    });
  });
}
