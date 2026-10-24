import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../models/team_member.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/team_member_tile.dart';

class TeamPage extends StatelessWidget {
  const TeamPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().user?.uid;
    final service = FirestoreService();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
        ),
        title: const Text('Squadra'),
      ),
      floatingActionButton: uid == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => showMemberDialog(context, service, uid),
              icon: const Icon(Icons.add),
              label: const Text('Aggiungi membro'),
            ),
      body: uid == null
          ? const Center(child: Text('Accedi per gestire la squadra.'))
          : StreamBuilder<List<TeamMember>>(
              stream: service.teamMembersStream(uid),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(child: Text('Errore: ${snap.error}'));
                }
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                return TeamMembersView(
                  members: snap.data ?? [],
                  onOpen: (m) =>
                      showMemberDialog(context, service, uid, member: m),
                );
              },
            ),
    );
  }
}

/// Contenuto della pagina Squadra: messaggio d'aiuto se non ci sono membri,
/// altrimenti l'avviso "costo non impostato" (se serve) e la lista.
class TeamMembersView extends StatelessWidget {
  final List<TeamMember> members;
  final void Function(TeamMember) onOpen;

  const TeamMembersView(
      {super.key, required this.members, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) {
      return const EmptyState(
        icon: Icons.groups_outlined,
        title: 'Nessun membro nella squadra',
        subtitle: 'Con "Aggiungi membro" inserisci gli agenti e le '
            'persone che lavorano ai progetti: per ognuno scegli '
            'il ruolo e imposta il costo orario interno e la '
            'tariffa di vendita oraria. I costi dei progetti si '
            'calcolano da questi valori.',
      );
    }
    final missingCost =
        members.where((m) => m.active && memberCostNotSet(m)).length;
    final offset = missingCost > 0 ? 1 : 0;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      itemCount: members.length + offset,
      itemBuilder: (context, i) {
        if (offset == 1 && i == 0) {
          return MissingCostNotice(count: missingCost);
        }
        final m = members[i - offset];
        return TeamMemberTile(member: m, onTap: () => onOpen(m));
      },
    );
  }
}

/// Avviso in cima alla lista: ci sono membri attivi con costo orario 0.
class MissingCostNotice extends StatelessWidget {
  final int count;

  const MissingCostNotice({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? kBlockedColorDark : kBlockedColor;
    final bg = isDark ? kBlockedBgDark : kBlockedBg;
    final who = count == 1
        ? '1 membro attivo ha il costo orario non impostato'
        : '$count membri attivi hanno il costo orario non impostato';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$who (vale 0). Tocca il membro e inserisci il "Costo orario '
              'interno (€/h)": le ore registrate con costo 0 non generano '
              'costo.',
              style: TextStyle(fontSize: 13, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showMemberDialog(
  BuildContext context,
  FirestoreService service,
  String ownerId, {
  TeamMember? member,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => MemberDialog(
        onSave: service.saveTeamMember, ownerId: ownerId, member: member),
  );
}

/// Valore interno della voce "Altro…" del menu Ruolo (non viene mai salvato).
const String _kRoleOther = '__altro__';

/// Dialogo "Nuovo/Modifica membro". `onSave` salva il membro (in produzione
/// `FirestoreService.saveTeamMember`; nei test una funzione finta).
class MemberDialog extends StatefulWidget {
  final Future<void> Function(TeamMember) onSave;
  final String ownerId;
  final TeamMember? member;

  const MemberDialog({
    super.key,
    required this.onSave,
    required this.ownerId,
    this.member,
  });

  @override
  State<MemberDialog> createState() => _MemberDialogState();
}

class _MemberDialogState extends State<MemberDialog> {
  late final TextEditingController _name;
  late final TextEditingController _role;
  late final TextEditingController _cost;
  late final TextEditingController _bill;
  late String _kind;
  late bool _active;
  // Voce scelta nel menu Ruolo: un ruolo standard, `_kRoleOther` oppure null
  // (nessun ruolo ancora scelto).
  String? _roleChoice;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final m = widget.member;
    _name = TextEditingController(text: m?.name ?? '');
    _role = TextEditingController(text: m?.role ?? '');
    _cost = TextEditingController(text: m == null ? '' : m.costRate.toString());
    _bill = TextEditingController(text: m == null ? '' : m.billRate.toString());
    // Un ruolo già salvato che non è nell'elenco standard (o scritto in modo
    // diverso) si preseleziona come "Altro…" con il suo testo: mai perso.
    final savedRole = m?.role ?? '';
    if (savedRole.trim().isEmpty) {
      _roleChoice = null;
    } else if (kMemberRoles.contains(savedRole)) {
      _roleChoice = savedRole;
    } else {
      _roleChoice = _kRoleOther;
    }
    _kind = m?.kind ?? 'agent';
    _active = m?.active ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _role.dispose();
    _cost.dispose();
    _bill.dispose();
    super.dispose();
  }

  double _num(String s) => double.tryParse(s.trim().replaceAll(',', '.')) ?? 0;

  String get _roleToSave {
    final c = _roleChoice;
    if (c == null) return '';
    if (c == _kRoleOther) return _role.text.trim();
    return c;
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Il nome è obbligatorio.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(TeamMember(
        id: widget.member?.id ?? '',
        ownerId: widget.ownerId,
        name: _name.text.trim(),
        kind: _kind,
        role: _roleToSave,
        costRate: _num(_cost.text),
        billRate: _num(_bill.text),
        active: _active,
        createdAt: widget.member?.createdAt ?? DateTime.now(),
      ));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Salvataggio non riuscito: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.member == null ? 'Nuovo membro' : 'Modifica membro'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nome'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _kind,
              decoration: const InputDecoration(labelText: 'Tipo'),
              items: kMemberKinds
                  .map((k) => DropdownMenuItem(
                        value: k,
                        child: Text(kMemberKindLabels[k] ?? k),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _kind = v ?? _kind),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _roleChoice,
              isExpanded: true,
              hint: const Text('Scegli il ruolo'),
              decoration: const InputDecoration(labelText: 'Ruolo'),
              items: [
                ...kMemberRoles.map((r) => DropdownMenuItem(
                      value: r,
                      child: Text(memberRoleLabel(r)),
                    )),
                const DropdownMenuItem(
                  value: _kRoleOther,
                  child: Text('Altro…'),
                ),
              ],
              onChanged: (v) => setState(() => _roleChoice = v),
            ),
            if (_roleChoice == _kRoleOther) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _role,
                decoration:
                    const InputDecoration(labelText: 'Ruolo (testo libero)'),
              ),
            ],
            const SizedBox(height: 8),
            TextField(
              controller: _cost,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'Costo orario interno (€/h)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _bill,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'Tariffa di vendita oraria (€/h)'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Attivo'),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
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
          child: const Text('Salva'),
        ),
      ],
    );
  }
}
