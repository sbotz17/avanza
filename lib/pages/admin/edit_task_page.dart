import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/firestore_service.dart';
import '../../models/task.dart';
import '../../core/constants.dart';

class EditTaskPage extends StatefulWidget {
  final String projectId;
  final String? taskId; // null = new task

  const EditTaskPage({
    super.key,
    required this.projectId,
    this.taskId,
  });

  @override
  State<EditTaskPage> createState() => _EditTaskPageState();
}

class _EditTaskPageState extends State<EditTaskPage> {
  final _service = FirestoreService();
  final _formKey = GlobalKey<FormState>();
  bool _loading = true;
  bool _saving = false;

  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _requestCtrl;
  late final TextEditingController _estHoursCtrl;
  late final TextEditingController _actHoursCtrl;
  late final TextEditingController _rateCtrl;

  Task? _existingTask;
  String _status = 'backlog';
  List<TaskPhase> _phases = [];
  List<TaskNote> _notes = [];

  bool get _isNew => widget.taskId == null || widget.taskId == 'new';

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
    _descCtrl = TextEditingController();
    _requestCtrl = TextEditingController();
    _estHoursCtrl = TextEditingController(text: '0');
    _actHoursCtrl = TextEditingController(text: '0');
    _rateCtrl = TextEditingController(text: '0');
    _initPhases();
    _loadTask();
  }

  void _initPhases() {
    _phases = kPhaseNames
        .map((n) => TaskPhase(name: n, status: 'pending', label: 'In attesa'))
        .toList();
  }

  Future<void> _loadTask() async {
    if (_isNew) {
      setState(() => _loading = false);
      return;
    }
    final tasks = await _service.tasksStream(widget.projectId).first;
    final task = tasks.cast<Task?>().firstWhere(
      (t) => t?.id == widget.taskId,
      orElse: () => null,
    );
    if (task != null) {
      _existingTask = task;
      _titleCtrl.text = task.title;
      _descCtrl.text = task.description;
      _requestCtrl.text = task.clientRequest;
      _estHoursCtrl.text = task.estimatedHours.toString();
      _actHoursCtrl.text = task.actualHours.toString();
      _rateCtrl.text = task.hourlyRate.toString();
      _status = task.status;
      _phases = List.from(task.phases);
      _notes = List.from(task.notes);
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _requestCtrl.dispose();
    _estHoursCtrl.dispose();
    _actHoursCtrl.dispose();
    _rateCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      if (_isNew) {
        await _service.createTask(
          projectId: widget.projectId,
          title: _titleCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          clientRequest: _requestCtrl.text.trim(),
          estimatedHours: double.tryParse(_estHoursCtrl.text) ?? 0,
          hourlyRate: double.tryParse(_rateCtrl.text) ?? 0,
        );
      } else {
        final updated = _existingTask!.copyWith(
          title: _titleCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          clientRequest: _requestCtrl.text.trim(),
          status: _status,
          phases: _phases,
          notes: _notes,
          estimatedHours: double.tryParse(_estHoursCtrl.text) ?? 0,
          actualHours: double.tryParse(_actHoursCtrl.text) ?? 0,
          hourlyRate: double.tryParse(_rateCtrl.text) ?? 0,
        );
        await _service.updateTask(updated);
      }
      if (mounted) context.go('/project/${widget.projectId}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Errore: $e')));
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/project/${widget.projectId}'),
        ),
        title: Text(_isNew ? 'Nuovo task' : 'Modifica task'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _section('Informazioni generali'),
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: 'Titolo *'),
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
                controller: _requestCtrl,
                decoration:
                    const InputDecoration(labelText: 'Richiesta cliente'),
                maxLines: 3,
              ),

              if (!_isNew) ...[
                const SizedBox(height: 20),
                _section('Stato globale'),
                _StatusDropdown(
                  value: _status,
                  isDark: isDark,
                  onChanged: (v) => setState(() => _status = v),
                ),

                const SizedBox(height: 20),
                _section('Fasi di sviluppo'),
                ..._phases.asMap().entries.map((e) => _PhaseEditor(
                      phase: e.value,
                      isDark: isDark,
                      onChanged: (updated) => setState(
                          () => _phases[e.key] = updated),
                    )),

                const SizedBox(height: 20),
                _section('Note'),
                ..._notes.asMap().entries.map((e) => _NoteEditor(
                      note: e.value,
                      isDark: isDark,
                      onChanged: (updated) =>
                          setState(() => _notes[e.key] = updated),
                      onDelete: () =>
                          setState(() => _notes.removeAt(e.key)),
                    )),
                TextButton.icon(
                  onPressed: () => setState(
                    () => _notes.add(const TaskNote(type: 'info', text: '')),
                  ),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Aggiungi nota'),
                ),
              ],

              const SizedBox(height: 20),
              _section('Costi (admin)'),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _estHoursCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Ore stimate'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _actHoursCtrl,
                      decoration: const InputDecoration(labelText: 'Ore reali'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _rateCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Tariffa (€/h)'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),
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
                        _isNew ? 'Crea task' : 'Salva modifiche',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600),
                      ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: Theme.of(context).brightness == Brightness.dark
                ? kFg2Dark
                : kFg2Light,
          ),
        ),
      );
}

class _StatusDropdown extends StatelessWidget {
  final String value;
  final bool isDark;
  final void Function(String) onChanged;

  const _StatusDropdown({
    required this.value,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: const InputDecoration(labelText: 'Stato'),
      items: kKanbanColumns
          .map((s) => DropdownMenuItem(
                value: s,
                child: Text(kKanbanLabels[s] ?? s),
              ))
          .toList(),
      onChanged: (v) => v != null ? onChanged(v) : null,
    );
  }
}

const _phaseStatuses = ['pending', 'active', 'done', 'blocked', 'skip'];
const _phaseLabels = {
  'pending': 'In attesa',
  'active': 'In corso',
  'done': 'Completata',
  'blocked': 'Bloccata',
  'skip': 'Non richiesta',
};

class _PhaseEditor extends StatelessWidget {
  final TaskPhase phase;
  final bool isDark;
  final void Function(TaskPhase) onChanged;

  const _PhaseEditor({
    required this.phase,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              phase.name,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _phaseStatuses.contains(phase.status)
                  ? phase.status
                  : 'pending',
              decoration: const InputDecoration(
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: _phaseStatuses
                  .map((s) => DropdownMenuItem(
                        value: s,
                        child: Text(
                          _phaseLabels[s] ?? s,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  onChanged(phase.copyWith(
                    status: v,
                    label: _phaseLabels[v] ?? v,
                  ));
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteEditor extends StatelessWidget {
  final TaskNote note;
  final bool isDark;
  final void Function(TaskNote) onChanged;
  final VoidCallback onDelete;

  const _NoteEditor({
    required this.note,
    required this.isDark,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: DropdownButtonFormField<String>(
              value: note.type,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              ),
              items: const [
                DropdownMenuItem(value: 'ok', child: Text('✓ OK')),
                DropdownMenuItem(value: 'info', child: Text('→ Info')),
                DropdownMenuItem(value: 'blk', child: Text('⚠ Blk')),
              ],
              onChanged: (v) {
                if (v != null) onChanged(TaskNote(type: v, text: note.text));
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              initialValue: note.text,
              decoration:
                  const InputDecoration(labelText: 'Testo', isDense: true),
              onChanged: (v) => onChanged(TaskNote(type: note.type, text: v)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            onPressed: onDelete,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
