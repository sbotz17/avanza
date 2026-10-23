import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../models/task.dart';
import '../../models/team_member.dart';
import '../../models/time_entry.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';

/// Registro ore del progetto: preventivo, costo reale, da fatturare, margine
/// e produttività per membro della squadra.
class TimeReportSection extends StatelessWidget {
  final String projectId;
  final List<Task> tasks;

  const TimeReportSection({
    super.key,
    required this.projectId,
    required this.tasks,
  });

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().user?.uid;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg2 = isDark ? kFg2Dark : kFg2Light;
    final eur = NumberFormat.currency(locale: 'it_IT', symbol: '€');
    final service = FirestoreService();

    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<List<TeamMember>>(
      stream: service.teamMembersStream(uid),
      builder: (context, memSnap) {
        final members = memSnap.data ?? [];
        return StreamBuilder<List<TimeEntry>>(
          stream: service.timeEntriesStream(projectId),
          builder: (context, entSnap) {
            final entries = entSnap.data ?? [];
            final stats = _computeStats(tasks, entries);
            final margin = stats.billed - stats.cost;
            final preventivo =
                tasks.fold<double>(0, (s, t) => s + t.estimatedCost);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'REGISTRO ORE E PRODUTTIVITÀ',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: fg2,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => context.push('/team'),
                      icon: const Icon(Icons.group_outlined, size: 18),
                      label: const Text('Squadra'),
                    ),
                    FilledButton.icon(
                      onPressed: tasks.isEmpty ||
                              members.where((m) => m.active).isEmpty
                          ? null
                          : () => showDialog<void>(
                                context: context,
                                builder: (_) => _AddTimeDialog(
                                  service: service,
                                  projectId: projectId,
                                  tasks: tasks,
                                  members:
                                      members.where((m) => m.active).toList(),
                                ),
                              ),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Registra ore'),
                    ),
                  ],
                ),
                if (members.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Prima aggiungi i membri della squadra (pulsante Squadra) '
                      'con tariffa di costo e di vendita.',
                      style: TextStyle(fontSize: 12, color: fg2),
                    ),
                  ),
                const SizedBox(height: 10),
                Row(children: [
                  _Stat(
                    label: 'Preventivo (stima × tariffa task)',
                    value: eur.format(preventivo),
                    isDark: isDark,
                  ),
                  const SizedBox(width: 10),
                  _Stat(
                    label: 'Ore registrate',
                    value: '${stats.hours.toStringAsFixed(1)}h',
                    isDark: isDark,
                  ),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  _Stat(
                    label: 'Costo reale',
                    value: eur.format(stats.cost),
                    isDark: isDark,
                  ),
                  const SizedBox(width: 10),
                  _Stat(
                    label: 'Da fatturare',
                    value: eur.format(stats.billed),
                    isDark: isDark,
                  ),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  _Stat(
                    label: 'Margine',
                    value: eur.format(margin),
                    color: margin >= 0
                        ? (isDark ? kDoneColorDark : kDoneColor)
                        : (isDark ? kBlockedColorDark : kBlockedColor),
                    isDark: isDark,
                  ),
                  const SizedBox(width: 10),
                  _Stat(
                    label: 'Scostamento vs preventivo',
                    value: eur.format(stats.billed - preventivo),
                    isDark: isDark,
                  ),
                ]),
                const SizedBox(height: 16),
                Text(
                  'PER MEMBRO',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: fg2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Produttività = ore stimate attribuite / ore reali. '
                  'Sopra 100% = più veloce della stima.',
                  style: TextStyle(fontSize: 11, color: fg2),
                ),
                const SizedBox(height: 8),
                if (stats.byMember.isEmpty)
                  Text('Nessuna ora registrata.',
                      style: TextStyle(fontSize: 13, color: fg2))
                else
                  ...stats.byMember.values.map(
                    (m) => _MemberRow(stat: m, eur: eur, isDark: isDark, fg2: fg2),
                  ),
                const SizedBox(height: 16),
                if (entries.isNotEmpty) ...[
                  Text(
                    'ULTIME REGISTRAZIONI',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: fg2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...entries.take(10).map(
                        (e) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '${DateFormat('dd/MM/yyyy').format(e.date)} · '
                            '${e.taskCode.isEmpty ? '-' : e.taskCode} · ${e.phase} · '
                            '${e.memberName} · ${e.hours.toStringAsFixed(1)}h'
                            '${e.note.isEmpty ? '' : ' · ${e.note}'}',
                            style: TextStyle(fontSize: 12, color: fg2),
                          ),
                        ),
                      ),
                ],
                const SizedBox(height: 24),
              ],
            );
          },
        );
      },
    );
  }
}

class _MemberStat {
  final String memberId;
  final String name;
  double hours = 0;
  double cost = 0;
  double billed = 0;
  double attributedEstimate = 0;
  double hoursOnEstimatedTasks = 0;

  _MemberStat(this.memberId, this.name);

  double? get productivity => hoursOnEstimatedTasks > 0 && attributedEstimate > 0
      ? attributedEstimate / hoursOnEstimatedTasks
      : null;
}

class _Stats {
  double hours = 0;
  double cost = 0;
  double billed = 0;
  final Map<String, _MemberStat> byMember = {};
}

_Stats _computeStats(List<Task> tasks, List<TimeEntry> entries) {
  final stats = _Stats();
  final estimateByTask = {for (final t in tasks) t.id: t.estimatedHours};
  final hoursByTask = <String, double>{};
  final hoursByMemberTask = <String, double>{};

  for (final e in entries) {
    stats.hours += e.hours;
    stats.cost += e.cost;
    stats.billed += e.billed;
    final m = stats.byMember.putIfAbsent(
      e.memberId,
      () => _MemberStat(e.memberId, e.memberName),
    );
    m.hours += e.hours;
    m.cost += e.cost;
    m.billed += e.billed;
    hoursByTask[e.taskId] = (hoursByTask[e.taskId] ?? 0) + e.hours;
    final key = '${e.memberId}|${e.taskId}';
    hoursByMemberTask[key] = (hoursByMemberTask[key] ?? 0) + e.hours;
  }

  // La stima di ogni task è ripartita tra i membri in proporzione alle ore
  // che ciascuno ha lavorato su quel task.
  hoursByMemberTask.forEach((key, h) {
    final parts = key.split('|');
    final memberId = parts[0];
    final taskId = parts[1];
    final estimate = estimateByTask[taskId] ?? 0;
    final total = hoursByTask[taskId] ?? 0;
    if (estimate > 0 && total > 0) {
      final m = stats.byMember[memberId];
      if (m != null) {
        m.attributedEstimate += estimate * h / total;
        m.hoursOnEstimatedTasks += h;
      }
    }
  });
  return stats;
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;
  final Color? color;

  const _Stat({
    required this.label,
    required this.value,
    required this.isDark,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? kCardDark : kCardLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? kBorderDark : kBorderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 11, color: isDark ? kFg2Dark : kFg2Light)),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  final _MemberStat stat;
  final NumberFormat eur;
  final bool isDark;
  final Color fg2;

  const _MemberRow({
    required this.stat,
    required this.eur,
    required this.isDark,
    required this.fg2,
  });

  @override
  Widget build(BuildContext context) {
    final p = stat.productivity;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? kCardDark : kCardLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? kBorderDark : kBorderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(stat.name,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(
            '${stat.hours.toStringAsFixed(1)}h · costo ${eur.format(stat.cost)} · '
            'fatturato ${eur.format(stat.billed)} · '
            'produttività ${p == null ? 'n.d.' : '${(p * 100).toStringAsFixed(0)}%'}',
            style: TextStyle(fontSize: 12, color: fg2),
          ),
        ],
      ),
    );
  }
}

class _AddTimeDialog extends StatefulWidget {
  final FirestoreService service;
  final String projectId;
  final List<Task> tasks;
  final List<TeamMember> members;

  const _AddTimeDialog({
    required this.service,
    required this.projectId,
    required this.tasks,
    required this.members,
  });

  @override
  State<_AddTimeDialog> createState() => _AddTimeDialogState();
}

class _AddTimeDialogState extends State<_AddTimeDialog> {
  late TeamMember _member;
  late Task _task;
  String _phase = kPhaseNames.first;
  final _hours = TextEditingController();
  final _note = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _member = widget.members.first;
    _task = widget.tasks.first;
  }

  @override
  void dispose() {
    _hours.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final h = double.tryParse(_hours.text.trim().replaceAll(',', '.'));
    if (h == null || h <= 0) {
      setState(() => _error = 'Inserisci un numero di ore maggiore di zero.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.service.addTimeEntry(TimeEntry(
        id: '',
        projectId: widget.projectId,
        taskId: _task.id,
        taskCode: _task.taskCode,
        memberId: _member.id,
        memberName: _member.name,
        phase: _phase,
        hours: h,
        costRate: _member.costRate,
        billRate: _member.billRate,
        date: DateTime.now(),
        note: _note.text.trim(),
      ));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Registrazione non riuscita: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Registra ore'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<TeamMember>(
              initialValue: _member,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Membro'),
              items: widget.members
                  .map((m) => DropdownMenuItem(value: m, child: Text(m.name)))
                  .toList(),
              onChanged: (v) => setState(() => _member = v ?? _member),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<Task>(
              initialValue: _task,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Task'),
              items: widget.tasks
                  .map((t) => DropdownMenuItem(
                        value: t,
                        child: Text(
                          '${t.taskCode.isEmpty ? '' : '${t.taskCode} · '}${t.title}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _task = v ?? _task),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _phase,
              decoration: const InputDecoration(labelText: 'Fase'),
              items: kPhaseNames
                  .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                  .toList(),
              onChanged: (v) => setState(() => _phase = v ?? _phase),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _hours,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Ore'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _note,
              decoration: const InputDecoration(labelText: 'Nota (facoltativa)'),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: const Text('Registra'),
        ),
      ],
    );
  }
}
