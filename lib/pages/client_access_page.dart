import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/firestore_service.dart';
import '../core/constants.dart';

class ClientAccessPage extends StatefulWidget {
  const ClientAccessPage({super.key});

  @override
  State<ClientAccessPage> createState() => _ClientAccessPageState();
}

class _ClientAccessPageState extends State<ClientAccessPage> {
  final _ctrl = TextEditingController();
  final _service = FirestoreService();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _access() async {
    final code = _ctrl.text.trim().toUpperCase();
    if (code.length != 6) {
      setState(() => _error = 'Il codice è di 6 caratteri.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final project = await _service.projectByClientCode(code);
    if (!mounted) return;
    setState(() => _loading = false);
    if (project == null) {
      setState(() => _error = 'Nessun progetto trovato con questo codice.');
    } else {
      context.go('/project/${project.id}?mode=client');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg2 = isDark ? kFg2Dark : kFg2Light;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/login'),
        ),
        title: const Text('Accedi al progetto'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: isDark ? kActiveBgDark : kActiveBg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.link_rounded,
                    color: isDark ? kActiveColorDark : kActiveColor,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Codice progetto',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Inserisci il codice di 6 caratteri ricevuto dal tuo sviluppatore.',
                  style: TextStyle(fontSize: 14, color: fg2),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _ctrl,
                  textCapitalization: TextCapitalization.characters,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 8,
                  ),
                  decoration: InputDecoration(
                    hintText: 'ABC123',
                    hintStyle: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 8,
                      color: fg2.withOpacity(0.4),
                    ),
                    counterText: '',
                  ),
                  onChanged: (_) => setState(() => _error = null),
                  onSubmitted: (_) => _access(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: isDark ? kBlockedColorDark : kBlockedColor,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _loading ? null : _access,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: isDark ? kActiveColorDark : kActiveColor,
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Apri progetto',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
