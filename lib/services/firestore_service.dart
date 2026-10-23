import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_message.dart';
import '../models/project.dart';
import '../models/task.dart';
import '../models/team_member.dart';
import '../models/time_entry.dart';
import '../core/constants.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  // ── PROJECTS ──────────────────────────────────────────────────────────────

  Future<Project?> getProject(String projectId) async {
    final doc = await _db.collection('projects').doc(projectId).get();
    if (!doc.exists) return null;
    return Project.fromFirestore(doc);
  }

  Stream<Project?> projectStream(String projectId) => _db
      .collection('projects')
      .doc(projectId)
      .snapshots()
      .map((doc) => doc.exists ? Project.fromFirestore(doc) : null);

  Stream<List<Project>> projectsStream(String ownerId) => _db
      .collection('projects')
      .where('ownerId', isEqualTo: ownerId)
      .orderBy('updatedAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(Project.fromFirestore).toList());

  // ── UTENTI E ACCESSO CLIENTE ──────────────────────────────────────────────

  /// Ruolo dell'utente (`users/{uid}`). Al primo accesso senza documento
  /// viene creato come `client`: l'admin si assegna solo da console/script.
  Future<String> resolveRole(String uid, String email) async {
    final ref = _db.collection('users').doc(uid);
    final doc = await ref.get();
    if (doc.exists) return (doc.data()?['role'] as String?) ?? 'client';
    await ref.set({
      'email': email,
      'role': 'client',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return 'client';
  }

  /// Progetti collegati a un cliente (ID dei progetti).
  Stream<List<String>> linkedProjectIdsStream(String uid) => _db
      .collection('users')
      .doc(uid)
      .collection('clientProjects')
      .snapshots()
      .map((s) => s.docs.map((d) => d.id).toList());

  /// Collega un progetto all'utente tramite il codice progetto (primo accesso).
  /// Restituisce il progetto, oppure null se il codice non esiste.
  Future<Project?> linkProjectByCode(String uid, String code) async {
    final clean = code.trim().toUpperCase();
    final access = await _db.collection('clientAccess').doc(clean).get();
    if (!access.exists) return null;
    final projectId = access.data()?['projectId'] as String?;
    if (projectId == null || projectId.isEmpty) return null;
    await _db
        .collection('users')
        .doc(uid)
        .collection('clientProjects')
        .doc(projectId)
        .set({
      'code': clean,
      'projectId': projectId,
      'linkedAt': FieldValue.serverTimestamp(),
    });
    return getProject(projectId);
  }

  Future<void> unlinkProject(String uid, String projectId) => _db
      .collection('users')
      .doc(uid)
      .collection('clientProjects')
      .doc(projectId)
      .delete();

  Future<Project> createProject({
    required String ownerId,
    required String name,
    required String description,
    required String githubUrl,
  }) async {
    final code = _generateCode();
    final ref = _db.collection('projects').doc();
    final now = DateTime.now();
    final project = Project(
      id: ref.id,
      name: name,
      description: description,
      githubUrl: githubUrl,
      clientCode: code,
      ownerId: ownerId,
      nextTaskNumber: 1,
      createdAt: now,
      updatedAt: now,
    );
    final batch = _db.batch();
    batch.set(ref, project.toMap());
    batch.set(_db.collection('clientAccess').doc(code), {
      'projectId': ref.id,
      'ownerId': ownerId,
      'createdAt': Timestamp.fromDate(now),
    });
    await batch.commit();
    return project;
  }

  Future<void> updateProject(Project project) => _db
      .collection('projects')
      .doc(project.id)
      .update({...project.toMap(), 'updatedAt': FieldValue.serverTimestamp()});

  Future<void> deleteProject(String projectId) async {
    // Delete all tasks first
    final tasks = await _db
        .collection('projects')
        .doc(projectId)
        .collection('tasks')
        .get();
    final costs = await _db
        .collection('projects')
        .doc(projectId)
        .collection('taskCosts')
        .get();
    final entries = await _db
        .collection('projects')
        .doc(projectId)
        .collection('timeEntries')
        .get();
    final project = await getProject(projectId);
    final batch = _db.batch();
    for (final doc in [...tasks.docs, ...costs.docs, ...entries.docs]) {
      batch.delete(doc.reference);
    }
    if (project != null && project.clientCode.isNotEmpty) {
      batch.delete(_db.collection('clientAccess').doc(project.clientCode));
    }
    batch.delete(_db.collection('projects').doc(projectId));
    await batch.commit();
  }

  // ── TASKS ──────────────────────────────────────────────────────────────────

  Stream<List<Task>> tasksStream(String projectId) => _db
      .collection('projects')
      .doc(projectId)
      .collection('tasks')
      .orderBy('order')
      .snapshots()
      .map((s) =>
          s.docs.map((doc) => Task.fromFirestore(doc, projectId)).toList());

  Future<Task> createTask({
    required String projectId,
    required String title,
    required String description,
    required String clientRequest,
    double estimatedHours = 0,
    double hourlyRate = 0,
  }) async {
    final projectRef = _db.collection('projects').doc(projectId);
    final taskRef = projectRef.collection('tasks').doc();
    final now = DateTime.now();

    final defaultPhases = kPhaseNames
        .map((n) => TaskPhase(name: n, status: 'pending', label: 'In attesa'))
        .toList();

    // Get current max order (outside transaction — read-only, ordering, no conflict risk)
    final existing = await projectRef
        .collection('tasks')
        .orderBy('order', descending: true)
        .limit(1)
        .get();
    final nextOrder =
        existing.docs.isEmpty ? 0 : ((existing.docs.first['order'] as int) + 1);

    late Task task;

    // Use a transaction to atomically read nextTaskNumber, assign taskCode
    // and increment the counter on the project document.
    await _db.runTransaction((txn) async {
      final projectSnap = await txn.get(projectRef);
      final currentNext = (projectSnap.data()?['nextTaskNumber'] as int?) ?? 1;
      final taskNumber = currentNext;
      final taskCode = 'T-$taskNumber';

      task = Task(
        id: taskRef.id,
        projectId: projectId,
        title: title,
        description: description,
        clientRequest: clientRequest,
        status: 'backlog',
        phases: defaultPhases,
        notes: [],
        order: nextOrder,
        taskCode: taskCode,
        taskNumber: taskNumber,
        createdAt: now,
        updatedAt: now,
      );

      txn.set(taskRef, task.toMap());
      txn.set(
        projectRef.collection('taskCosts').doc(taskRef.id),
        TaskCost(estimatedHours: estimatedHours, hourlyRate: hourlyRate).toMap(),
      );
      txn.update(projectRef, {
        'nextTaskNumber': currentNext + 1,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    return task;
  }

  Future<void> updateTask(Task task) async {
    await _db
        .collection('projects')
        .doc(task.projectId)
        .collection('tasks')
        .doc(task.id)
        .update({...task.toMap(), 'updatedAt': FieldValue.serverTimestamp()});
    await _db
        .collection('projects')
        .doc(task.projectId)
        .update({'updatedAt': FieldValue.serverTimestamp()});
  }

  Future<void> deleteTask(String projectId, String taskId) async {
    final projectRef = _db.collection('projects').doc(projectId);
    final batch = _db.batch();
    batch.delete(projectRef.collection('tasks').doc(taskId));
    batch.delete(projectRef.collection('taskCosts').doc(taskId));
    await batch.commit();
  }

  // ── COSTI TASK (solo admin) ───────────────────────────────────────────────

  Stream<Map<String, TaskCost>> taskCostsStream(String projectId) => _db
      .collection('projects')
      .doc(projectId)
      .collection('taskCosts')
      .snapshots()
      .map((s) => {for (final d in s.docs) d.id: TaskCost.fromFirestore(d)});

  Future<TaskCost> getTaskCost(String projectId, String taskId) async {
    final doc = await _db
        .collection('projects')
        .doc(projectId)
        .collection('taskCosts')
        .doc(taskId)
        .get();
    return doc.exists ? TaskCost.fromFirestore(doc) : const TaskCost();
  }

  Future<void> saveTaskCost(String projectId, String taskId, TaskCost cost) =>
      _db
          .collection('projects')
          .doc(projectId)
          .collection('taskCosts')
          .doc(taskId)
          .set(cost.toMap());

  // ── TEAM ───────────────────────────────────────────────────────────────────

  Stream<List<TeamMember>> teamMembersStream(String ownerId) => _db
      .collection('teamMembers')
      .where('ownerId', isEqualTo: ownerId)
      .snapshots()
      .map((s) {
        final list = s.docs.map(TeamMember.fromFirestore).toList();
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        return list;
      });

  Future<void> saveTeamMember(TeamMember m) {
    final ref = _db.collection('teamMembers').doc(m.id.isEmpty ? null : m.id);
    return ref.set(m.toMap());
  }

  // ── TIME ENTRIES ───────────────────────────────────────────────────────────

  Stream<List<TimeEntry>> timeEntriesStream(String projectId) => _db
      .collection('projects')
      .doc(projectId)
      .collection('timeEntries')
      .orderBy('date', descending: true)
      .snapshots()
      .map((s) =>
          s.docs.map((d) => TimeEntry.fromFirestore(d, projectId)).toList());

  /// Registra le ore e aggiorna in modo atomico le ore reali del task.
  Future<void> addTimeEntry(TimeEntry e) async {
    final projectRef = _db.collection('projects').doc(e.projectId);
    final entryRef = projectRef.collection('timeEntries').doc();
    final costRef = projectRef.collection('taskCosts').doc(e.taskId);
    final batch = _db.batch();
    batch.set(entryRef, e.toMap());
    batch.set(
      costRef,
      {'actualHours': FieldValue.increment(e.hours)},
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  // ── CHAT CON LA SQUADRA (solo admin) ──────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _chatRef(
          String projectId, String taskId) =>
      _db
          .collection('projects')
          .doc(projectId)
          .collection('tasks')
          .doc(taskId)
          .collection('chat');

  /// [T-12] Messaggi della chat di un task, dal più vecchio al più recente.
  /// Le regole di Firestore ne consentono la lettura solo al proprietario (admin).
  Stream<List<ChatMessage>> chatStream(String projectId, String taskId) =>
      _chatRef(projectId, taskId)
          .orderBy('createdAt')
          .snapshots()
          .map((s) => s.docs.map(ChatMessage.fromFirestore).toList());

  /// [T-12] Invia una domanda dell'admin alla squadra. Le regole accettano solo
  /// `from == 'admin'`, `kind == 'domanda'`, `authorUid` = utente e orario del
  /// server. Le risposte della squadra le scrive solo lo script (Admin SDK).
  /// Lancia [ArgumentError] se il testo è vuoto o più lungo di [kChatMaxLength].
  Future<void> sendChatQuestion({
    required String projectId,
    required String taskId,
    required String authorUid,
    required String authorName,
    required String text,
  }) async {
    final clean = ChatMessage.cleanText(text);
    if (clean == null) {
      throw ArgumentError('Messaggio vuoto o più lungo di $kChatMaxLength caratteri.');
    }
    final msg = ChatMessage(
      from: ChatMessage.fromAdmin,
      text: clean,
      authorUid: authorUid,
      authorName: authorName,
      kind: ChatMessage.kindDomanda,
    );
    await _chatRef(projectId, taskId)
        .add({...msg.toMap(), 'createdAt': FieldValue.serverTimestamp()});
  }

  // ── HELPERS ────────────────────────────────────────────────────────────────

  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final id = _uuid.v4().replaceAll('-', '');
    return String.fromCharCodes(
      List.generate(6, (i) => chars.codeUnitAt(id.codeUnitAt(i) % chars.length)),
    );
  }
}
