import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../models/team_member.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';

class TeamPage extends StatelessWidget {
  const TeamPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().user?.uid;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg2 = isDark ? kFg2Dark : kFg2Light;
    final eur = NumberFormat.currency(locale: 'it_IT', symbol: '€');
    final service = FirestoreService();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
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
                final members = snap.data ?? [];
                if (members.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Nessun membro. Aggiungi agenti e persone con la loro '
                        'tariffa di costo e di vendita oraria.',
                        style: TextStyle(color: fg2),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                  itemCount: members.length,
                  itemBuilder: (context, i) {
                    final m = members[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: isDark ? kCardDark : kCardLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: isDark ? kBorderDark : kBorderLight),
                      ),
                      child: ListTile(
                        onTap: () =>
                            showMemberDialog(context, service, uid, member: m),
                        title: Text(
                          m.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            decoration:
                                m.active ? null : TextDecoration.lineThrough,
                          ),
                        ),
                        subtitle: Text(
                          '${kMemberKindLabels[m.kind] ?? m.kind}'
                          '${m.role.isEmpty ? '' : ' · ${m.role}'}\n'
                          'Costo ${eur.format(m.costRate)}/h · '
                          'Vendita ${eur.format(m.billRate)}/h',
                          style: TextStyle(fontSize: 12, color: fg2),
                        ),
                        isThreeLine: true,
                        trailing: m.active
                            ? null
                            : Text('Non attivo',
                                style: TextStyle(fontSize: 11, color: fg2)),
                      ),
                    );
                  },
                );
              },
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
    builder: (_) =>
        _MemberDialog(service: service, ownerId: ownerId, member: member),
  );
}

class _MemberDialog extends StatefulWidget {
  final FirestoreService service;
  final String ownerId;
  final TeamMember? member;

  const _MemberDialog({
    required this.service,
    required this.ownerId,
    this.member,
  });

  @override
  State<_MemberDialog> createState() => _MemberDialogState();
}

class _MemberDialogState extends State<_MemberDialog> {
  late final TextEditingController _name;
  late final TextEditingController _role;
  late final TextEditingController _cost;
  late final TextEditingController _bill;
  late String _kind;
  late bool _active;
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
      await widget.service.saveTeamMember(TeamMember(
        id: widget.member?.id ?? '',
        ownerId: widget.ownerId,
        name: _name.text.trim(),
        kind: _kind,
        role: _role.text.trim(),
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
            TextField(
              controller: _role,
              decoration: const InputDecoration(
                  labelText: 'Ruolo (es. analista, dba, tester)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _cost,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'Costo orario interno (€/h)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _bill,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
