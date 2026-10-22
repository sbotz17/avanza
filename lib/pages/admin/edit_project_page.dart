import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/firestore_service.dart';
import '../../models/project.dart';
import '../../core/constants.dart';

// Bottom sheet for creating a new project (used from HomePage)
class EditProjectSheet extends StatefulWidget {
  final String ownerId;
  final FirestoreService service;
  final Project? existing;

  const EditProjectSheet({
    super.key,
    required this.ownerId,
    required this.service,
    this.existing,
  });

  @override
  State<EditProjectSheet> createState() => _EditProjectSheetState();
}

class _EditProjectSheetState extends State<EditProjectSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _githubCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _descCtrl = TextEditingController(text: widget.existing?.description ?? '');
    _githubCtrl = TextEditingController(text: widget.existing?.githubUrl ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _githubCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      if (widget.existing == null) {
        await widget.service.createProject(
          ownerId: widget.ownerId,
          name: _nameCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          githubUrl: _githubCtrl.text.trim(),
        );
      } else {
        await widget.service.updateProject(
          widget.existing!.copyWith(
            name: _nameCtrl.text.trim(),
            description: _descCtrl.text.trim(),
            githubUrl: _githubCtrl.text.trim(),
          ),
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e')),
        );
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEdit = widget.existing != null;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? kCardDark : kCardLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    isEdit ? 'Modifica progetto' : 'Nuovo progetto',
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Nome progetto *'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Campo obbligatorio' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(labelText: 'Descrizione'),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _githubCtrl,
              decoration: const InputDecoration(
                labelText: 'GitHub URL (opzionale)',
                hintText: 'https://github.com/owner/repo',
                prefixIcon: Icon(Icons.code_rounded),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: isDark ? kActiveColorDark : kActiveColor,
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      isEdit ? 'Salva modifiche' : 'Crea progetto',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// Full page for editing a project (navigated from project page)
class EditProjectPage extends StatelessWidget {
  final String projectId;

  const EditProjectPage({super.key, required this.projectId});

  @override
  Widget build(BuildContext context) {
    final service = FirestoreService();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/project/$projectId'),
        ),
        title: const Text('Modifica progetto'),
      ),
      body: FutureBuilder<Project?>(
        future: service.getProject(projectId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final project = snap.data;
          if (project == null) {
            return const Center(child: Text('Progetto non trovato'));
          }
          return _EditProjectForm(
            project: project,
            service: service,
            onSaved: () => context.go('/project/$projectId'),
          );
        },
      ),
    );
  }
}

class _EditProjectForm extends StatefulWidget {
  final Project project;
  final FirestoreService service;
  final VoidCallback onSaved;

  const _EditProjectForm({
    required this.project,
    required this.service,
    required this.onSaved,
  });

  @override
  State<_EditProjectForm> createState() => _EditProjectFormState();
}

class _EditProjectFormState extends State<_EditProjectForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _githubCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.project.name);
    _descCtrl = TextEditingController(text: widget.project.description);
    _githubCtrl = TextEditingController(text: widget.project.githubUrl);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _githubCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.service.updateProject(
        widget.project.copyWith(
          name: _nameCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          githubUrl: _githubCtrl.text.trim(),
        ),
      );
      if (mounted) widget.onSaved();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e')),
        );
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Client code display
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? kActiveBgDark : kActiveBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.link,
                      color: isDark ? kActiveColorDark : kActiveColor),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Codice cliente',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? kActiveColorDark : kActiveColor,
                        ),
                      ),
                      Text(
                        widget.project.clientCode,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 4,
                          color: isDark ? kActiveColorDark : kActiveColor,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    'Condividi questo codice\ncon il cliente',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? kActiveColorDark : kActiveColor,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Nome progetto *'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Campo obbligatorio' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(labelText: 'Descrizione'),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _githubCtrl,
              decoration: const InputDecoration(
                labelText: 'GitHub URL (opzionale)',
                hintText: 'https://github.com/owner/repo',
                prefixIcon: Icon(Icons.code_rounded),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: isDark ? kActiveColorDark : kActiveColor,
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'Salva modifiche',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
