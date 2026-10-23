// Test T-12: modello ChatMessage, regola "chi vede la chat" e riquadro "Stato attuale".
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:avanza/core/constants.dart';
import 'package:avanza/models/chat_message.dart';
import 'package:avanza/models/task.dart';
import 'package:avanza/widgets/task_chat.dart';

Task _task({
  String status = 'active',
  List<TaskPhase>? phases,
  List<TaskNote> notes = const [],
  String? branch,
  int? pr,
}) =>
    Task(
      id: 'tid',
      projectId: 'pid',
      title: 'Titolo',
      description: '',
      clientRequest: '',
      status: status,
      phases: phases ??
          const [
            TaskPhase(name: 'Analisi', status: 'done', label: 'Completato'),
            TaskPhase(name: 'Backend', status: 'active', label: 'In corso'),
            TaskPhase(name: 'Design', status: 'skip', label: 'Non necessaria'),
            TaskPhase(name: 'Test', status: 'pending', label: 'In attesa'),
          ],
      notes: notes,
      order: 0,
      taskCode: 'T-12',
      githubBranch: branch,
      githubPrNumber: pr,
      createdAt: DateTime(2026, 10, 23, 9, 0),
      updatedAt: DateTime(2026, 10, 23, 14, 30),
    );

void main() {
  group('ChatMessage', () {
    test('fromMap legge tutti i campi, incluso createdAt Timestamp', () {
      final m = ChatMessage.fromMap({
        'from': 'admin',
        'text': 'A che punto siamo?',
        'authorUid': 'u1',
        'authorName': 'Andrea',
        'kind': 'domanda',
        'createdAt': Timestamp.fromDate(DateTime(2026, 10, 23, 10, 15)),
      }, id: 'm1');
      expect(m.id, 'm1');
      expect(m.from, 'admin');
      expect(m.isFromAdmin, isTrue);
      expect(m.text, 'A che punto siamo?');
      expect(m.authorUid, 'u1');
      expect(m.authorName, 'Andrea');
      expect(m.kind, ChatMessage.kindDomanda);
      expect(m.createdAt, DateTime(2026, 10, 23, 10, 15));
    });

    test('fromMap con campi mancanti usa valori prudenti (scrittura in attesa)', () {
      final m = ChatMessage.fromMap({});
      expect(m.from, ChatMessage.fromSquadra);
      expect(m.isFromAdmin, isFalse);
      expect(m.text, '');
      expect(m.kind, ChatMessage.kindRisposta);
      expect(m.createdAt, isNull); // serverTimestamp non ancora risolto
    });

    test('toMap contiene i campi richiesti dalle regole e non createdAt', () {
      const m = ChatMessage(
        from: ChatMessage.fromAdmin,
        text: 'Ciao',
        authorUid: 'u1',
        authorName: 'Andrea',
        kind: ChatMessage.kindDomanda,
      );
      expect(m.toMap(), {
        'from': 'admin',
        'text': 'Ciao',
        'authorUid': 'u1',
        'authorName': 'Andrea',
        'kind': 'domanda',
      });
    });

    test('toMap -> fromMap è un giro completo', () {
      const m = ChatMessage(
        from: ChatMessage.fromSquadra,
        text: 'Siamo in fase di test',
        authorUid: 'squadra',
        authorName: 'Squadra',
        kind: ChatMessage.kindRisposta,
      );
      final back = ChatMessage.fromMap(m.toMap());
      expect(back.from, m.from);
      expect(back.text, m.text);
      expect(back.kind, m.kind);
      expect(back.authorName, m.authorName);
    });

    test('cleanText: toglie gli spazi, rifiuta vuoto e oltre 2000 caratteri', () {
      expect(ChatMessage.cleanText('  ciao  '), 'ciao');
      expect(ChatMessage.cleanText('   '), isNull);
      expect(ChatMessage.cleanText(''), isNull);
      expect(ChatMessage.cleanText('a' * kChatMaxLength), isNotNull);
      expect(ChatMessage.cleanText('a' * (kChatMaxLength + 1)), isNull);
    });
  });

  group('canShowTaskChat', () {
    test('admin + task non completato: si vede', () {
      for (final s in ['backlog', 'active', 'blocked', 'review']) {
        expect(canShowTaskChat(isAdmin: true, status: s), isTrue, reason: s);
      }
    });

    test('admin + task validato o rilasciato: non si vede', () {
      expect(canShowTaskChat(isAdmin: true, status: 'validated'), isFalse);
      expect(canShowTaskChat(isAdmin: true, status: 'released'), isFalse);
    });

    test('cliente (non admin): non si vede mai', () {
      for (final s in kKanbanColumns) {
        expect(canShowTaskChat(isAdmin: false, status: s), isFalse, reason: s);
      }
    });
  });

  group('taskStatusSummary', () {
    Map<String, String> asMap(Task t) => {for (final (k, v) in taskStatusSummary(t)) k: v};

    test('stato, avanzamento (fasi non necessarie escluse) e fase in corso', () {
      final m = asMap(_task());
      expect(m['Stato'], 'In corso');
      expect(m['Avanzamento'], '33% (1 su 3 fasi completate)');
      expect(m['Fase in corso'], 'Backend');
      expect(m['Ultimo aggiornamento'], '23/10/2026 14:30');
      expect(m.containsKey('Ultime note'), isFalse);
      expect(m.containsKey('Ramo GitHub'), isFalse);
    });

    test('ultime note (max 3, dalla più recente) e riferimenti GitHub', () {
      final m = asMap(_task(
        branch: 'feature/T-12-chat',
        pr: 21,
        notes: const [
          TaskNote(type: 'info', text: 'uno'),
          TaskNote(type: 'info', text: 'due'),
          TaskNote(type: 'ok', text: 'tre'),
          TaskNote(type: 'blk', text: 'quattro'),
        ],
      ));
      expect(m['Ultime note'], 'quattro · tre · due');
      expect(m['Ramo GitHub'], 'feature/T-12-chat');
      expect(m['Pull request'], '#21');
    });

    test('nessuna fase: nessun numero inventato', () {
      final m = asMap(_task(phases: const []));
      expect(m['Avanzamento'], 'nessuna fase definita');
    });
  });

  test('il testo fisso della chat è quello concordato', () {
    expect(
      kChatSentNotice,
      'La domanda è stata inviata alla squadra: ti risponde al prossimo giro di '
      'lavoro. Intanto ecco lo stato registrato.',
    );
  });
}
