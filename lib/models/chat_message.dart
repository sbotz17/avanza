import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants.dart';

/// [T-12] Messaggio della chat tra l'admin e la squadra su un task.
/// Vive in `projects/{p}/tasks/{t}/chat/{messageId}` (solo admin, vedi `docs/database.md`).
class ChatMessage {
  /// Chi scrive: l'admin dall'app, la squadra solo dallo script (Admin SDK).
  static const fromAdmin = 'admin';
  static const fromSquadra = 'squadra';

  static const kindDomanda = 'domanda';
  static const kindRisposta = 'risposta';
  static const kindStatoAutomatico = 'stato-automatico';

  final String id;
  final String from; // 'admin' | 'squadra'
  final String text;
  final String authorUid;
  final String authorName;
  // null finché il server non ha assegnato l'orario (scrittura locale in attesa).
  final DateTime? createdAt;
  final String kind; // 'domanda' | 'risposta' | 'stato-automatico'

  const ChatMessage({
    this.id = '',
    required this.from,
    required this.text,
    this.authorUid = '',
    this.authorName = '',
    this.createdAt,
    required this.kind,
  });

  bool get isFromAdmin => from == fromAdmin;

  factory ChatMessage.fromMap(Map<String, dynamic> d, {String id = ''}) {
    final created = d['createdAt'];
    return ChatMessage(
      id: id,
      from: d['from'] as String? ?? fromSquadra,
      text: d['text'] as String? ?? '',
      authorUid: d['authorUid'] as String? ?? '',
      authorName: d['authorName'] as String? ?? '',
      createdAt: created is Timestamp ? created.toDate() : null,
      kind: d['kind'] as String? ?? kindRisposta,
    );
  }

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) =>
      ChatMessage.fromMap(doc.data() as Map<String, dynamic>? ?? {}, id: doc.id);

  /// Campi da scrivere. `createdAt` non c'è: lo aggiunge il servizio con
  /// `FieldValue.serverTimestamp()` (le regole richiedono l'orario del server).
  Map<String, dynamic> toMap() => {
        'from': from,
        'text': text,
        'authorUid': authorUid,
        'authorName': authorName,
        'kind': kind,
      };

  /// Testo pronto per l'invio: tagliato degli spazi, oppure null se vuoto o
  /// più lungo di [kChatMaxLength] (stessi limiti delle regole Firestore).
  static String? cleanText(String raw) {
    final t = raw.trim();
    if (t.isEmpty || t.length > kChatMaxLength) return null;
    return t;
  }
}

/// [T-12] La chat con la squadra si vede SOLO se l'utente è admin e il task
/// non è completato (né `validated` né `released`). I clienti non la vedono mai.
bool canShowTaskChat({required bool isAdmin, required String status}) =>
    isAdmin && !kCompletedStatuses.contains(status);
