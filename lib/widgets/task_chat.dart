import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/constants.dart';
import '../models/chat_message.dart';
import '../models/task.dart';
import '../services/firestore_service.dart';
import 'empty_state.dart';

/// [T-12] Testo fisso mostrato sopra la chat: nessuna risposta inventata.
const String kChatSentNotice =
    'La domanda è stata inviata alla squadra: ti risponde al prossimo giro di '
    'lavoro. Intanto ecco lo stato registrato.';

/// [T-12] "Stato attuale" calcolato solo dai dati già registrati nel task
/// (stato, fasi, ultime note, ultimo aggiornamento). Coppie etichetta/valore.
List<(String, String)> taskStatusSummary(Task task, {int maxNotes = 3}) {
  final phases = task.phases.where((p) => p.status != 'skip').toList();
  final done = phases.where((p) => p.status == 'done').length;
  final active = phases.where((p) => p.status == 'active').map((p) => p.name);
  final blocked = phases.where((p) => p.status == 'blocked').map((p) => p.name);
  final notes = task.notes.reversed.take(maxNotes).map((n) => n.text).toList();

  return [
    ('Stato', kKanbanLabels[task.status] ?? task.status),
    (
      'Avanzamento',
      phases.isEmpty
          ? 'nessuna fase definita'
          : '${task.pct.round()}% ($done su ${phases.length} fasi completate)'
    ),
    if (active.isNotEmpty) ('Fase in corso', active.join(', ')),
    if (blocked.isNotEmpty) ('Fase bloccata', blocked.join(', ')),
    ('Ultimo aggiornamento', DateFormat('dd/MM/yyyy HH:mm').format(task.updatedAt)),
    if (task.githubBranch != null && task.githubBranch!.isNotEmpty)
      ('Ramo GitHub', task.githubBranch!),
    if (task.githubPrNumber != null) ('Pull request', '#${task.githubPrNumber}'),
    if (notes.isNotEmpty) ('Ultime note', notes.join(' · ')),
  ];
}

/// Chat dell'admin con la squadra su un task non completato.
/// Va mostrata solo se `canShowTaskChat(...)` è vero (vedi `task_detail_page.dart`).
class TaskChat extends StatefulWidget {
  final Task task;
  final String authorUid;
  final String authorName;
  final FirestoreService service;

  const TaskChat({
    super.key,
    required this.task,
    required this.authorUid,
    required this.authorName,
    required this.service,
  });

  @override
  State<TaskChat> createState() => _TaskChatState();
}

class _TaskChatState extends State<TaskChat> {
  final _ctrl = TextEditingController();
  bool _sending = false;
  bool _asked = false; // true dopo aver inviato una domanda in questa visita
  String? _error;
  // Lo stream si crea una volta sola: ricrearlo a ogni build farebbe
  // ripartire l'ascolto e lampeggiare la lista.
  late final Stream<List<ChatMessage>> _messages;

  @override
  void initState() {
    super.initState();
    _messages =
        widget.service.chatStream(widget.task.projectId, widget.task.id);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final clean = ChatMessage.cleanText(_ctrl.text);
    if (clean == null) {
      setState(() => _error =
          'Scrivi un messaggio (massimo $kChatMaxLength caratteri).');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.service.sendChatQuestion(
        projectId: widget.task.projectId,
        taskId: widget.task.id,
        authorUid: widget.authorUid,
        authorName: widget.authorName,
        text: clean,
      );
      if (!mounted) return;
      _ctrl.clear();
      setState(() {
        _sending = false;
        _asked = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = 'Invio non riuscito. Riprova.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg2 = isDark ? kFg2Dark : kFg2Light;
    final sectionTitle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.5,
      color: fg2,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Chiedi alla squadra', style: sectionTitle),
        const SizedBox(height: 8),
        _StatusBox(task: widget.task, isDark: isDark, showNotice: _asked),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: isDark ? kCardDark : kCardLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? kBorderDark : kBorderLight),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StreamBuilder<List<ChatMessage>>(
                stream: _messages,
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Non riesco a leggere la chat.',
                        style: TextStyle(
                          color: isDark ? kBlockedColorDark : kBlockedColor,
                          fontSize: 13,
                        ),
                      ),
                    );
                  }
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final messages = snap.data ?? [];
                  if (messages.isEmpty) {
                    return const EmptyState(
                      icon: Icons.chat_bubble_outline,
                      title: 'Nessun messaggio',
                      subtitle:
                          'Scrivi qui la tua domanda sullo stato di questo task.',
                    );
                  }
                  // Dal più recente in basso: lista invertita, parte dal fondo.
                  return ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 420),
                    child: ListView.builder(
                      reverse: true,
                      shrinkWrap: true,
                      itemCount: messages.length,
                      itemBuilder: (context, i) => _Bubble(
                        message: messages[messages.length - 1 - i],
                        isDark: isDark,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      enabled: !_sending,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: kChatMaxLength,
                      textInputAction: TextInputAction.newline,
                      decoration: const InputDecoration(
                        hintText: 'Chiedi alla squadra lo stato di questo task…',
                        counterText: '',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    tooltip: 'Invia',
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 6),
                Text(
                  _error!,
                  style: TextStyle(
                    color: isDark ? kBlockedColorDark : kBlockedColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Riquadro "Stato attuale": solo dati registrati, mai testo inventato.
class _StatusBox extends StatelessWidget {
  final Task task;
  final bool isDark;
  final bool showNotice;

  const _StatusBox({
    required this.task,
    required this.isDark,
    required this.showNotice,
  });

  @override
  Widget build(BuildContext context) {
    final fg2 = isDark ? kFg2Dark : kFg2Light;
    final border = isDark ? kActiveColorDark : kActiveColor;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? kActiveBgDark : kActiveBg,
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: border, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Stato attuale',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: border,
            ),
          ),
          const SizedBox(height: 6),
          for (final (label, value) in taskStatusSummary(task))
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(
                    text: '$label: ',
                    style: TextStyle(fontWeight: FontWeight.w600, color: fg2),
                  ),
                  TextSpan(text: value),
                ]),
                style: const TextStyle(fontSize: 12, height: 1.4),
              ),
            ),
          if (showNotice) ...[
            const SizedBox(height: 6),
            Text(
              kChatSentNotice,
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: fg2),
            ),
          ],
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final ChatMessage message;
  final bool isDark;

  const _Bubble({required this.message, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final fromAdmin = message.isFromAdmin;
    final fg2 = isDark ? kFg2Dark : kFg2Light;
    final bg = fromAdmin
        ? (isDark ? kActiveBgDark : kActiveBg)
        : (isDark ? kBgDark : kBgLight);
    final who = fromAdmin
        ? (message.authorName.isEmpty ? 'Tu' : message.authorName)
        : (message.kind == ChatMessage.kindStatoAutomatico
            ? 'Stato automatico'
            : 'Squadra');
    final time = message.createdAt == null
        ? 'invio…'
        : DateFormat('dd/MM HH:mm').format(message.createdAt!);

    return Align(
      alignment: fromAdmin ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: const BoxConstraints(maxWidth: 480),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? kBorderDark : kBorderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$who · $time',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: fg2,
              ),
            ),
            const SizedBox(height: 2),
            SelectableText(
              message.text,
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
