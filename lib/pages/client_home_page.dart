import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../models/project.dart';
import '../providers/auth_provider.dart';
import '../services/firestore_service.dart';

/// Home del cliente: elenco dei progetti collegati al suo account e campo per
/// collegarne uno nuovo con il codice progetto (una volta sola per progetto).
class ClientHomePage extends StatefulWidget {
  const ClientHomePage({super.key});

  @override
  State<ClientHomePage> createState() => _ClientHomePageState();
}

class _ClientHomePageState extends State<ClientHomePage> {
  final _service = FirestoreService();
  final _codeCtrl = TextEditingController();
  Stream<List<String>>? _stream;
  bool _linking = false;
  String? _error;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _link(String uid) async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.length != 6) {
      setState(() => _error = 'Il codice è di 6 caratteri.');
      return;
    }
    setState(() {
      _linking = true;
      _error = null;
    });
    try {
      final project = await _service.linkProjectByCode(uid, code);
      if (!mounted) return;
      if (project == null) {
        setState(() => _error = 'Nessun progetto trovato con questo codice.');
      } else {
        _codeCtrl.clear();
        context.go('/project/${project.id}');
        return;
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Collegamento non riuscito. Controlla il codice.');
      }
    }
    if (mounted) setState(() => _linking = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final uid = auth.user?.uid;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg2 = isDark ? kFg2Dark : kFg2Light;

    if (uid == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    _stream ??= _service.linkedProjectIdsStream(uid);

    return Scaffold(
      appBar: AppBar(
        title: const Text('I miei progetti'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_outlined),
            onPressed: () => auth.signOut(),
            tooltip: 'Esci',
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'COLLEGA UN PROGETTO',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: fg2,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _codeCtrl,
                      textCapitalization: TextCapitalization.characters,
                      maxLength: 6,
                      decoration: const InputDecoration(
                        labelText: 'Codice progetto',
                        counterText: '',
                      ),
                      onSubmitted: (_) => _link(uid),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _linking ? null : () => _link(uid),
                    child: _linking
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Collega'),
                  ),
                ],
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: isDark ? kBlockedColorDark : kBlockedColor,
                      fontSize: 13,
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              StreamBuilder<List<String>>(
                stream: _stream,
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Text('Errore: ${snap.error}');
                  }
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final ids = snap.data ?? [];
                  if (ids.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Nessun progetto collegato. Inserisci qui sopra il codice '
                        'progetto che ti ha dato il tuo referente.',
                        style: TextStyle(color: fg2),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  return Column(
                    children: ids
                        .map((id) => _ProjectTile(
                              projectId: id,
                              service: _service,
                              isDark: isDark,
                              fg2: fg2,
                            ))
                        .toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectTile extends StatelessWidget {
  final String projectId;
  final FirestoreService service;
  final bool isDark;
  final Color fg2;

  const _ProjectTile({
    required this.projectId,
    required this.service,
    required this.isDark,
    required this.fg2,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Project?>(
      stream: service.projectStream(projectId),
      builder: (context, snap) {
        final project = snap.data;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: isDark ? kCardDark : kCardLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? kBorderDark : kBorderLight),
          ),
          child: ListTile(
            onTap: () => context.go('/project/$projectId'),
            title: Text(
              project?.name ?? 'Progetto',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: project == null || project.description.isEmpty
                ? null
                : Text(
                    project.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: fg2),
                  ),
            trailing: const Icon(Icons.chevron_right),
          ),
        );
      },
    );
  }
}
