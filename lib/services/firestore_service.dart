import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
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

  // Find project by clientCode (public access)
  Future<Project?> projectByClientCode(String code) async {
    final q = await _db
        .collection('projects')
        .where('clientCode', isEqualTo: code.toUpperCase())
        .limit(1)
        .get();
    if (q.docs.isEmpty) return null;
    return Project.fromFirestore(q.docs.first);
  }

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
    await ref.set(project.toMap());
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
    final batch = _db.batch();
    for (final doc in tasks.docs) {
      batch.delete(doc.reference);
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
        estimatedHours: estimatedHours,
        actualHours: 0,
        hourlyRate: hourlyRate,
        order: nextOrder,
        taskCode: taskCode,
        taskNumber: taskNumber,
        createdAt: now,
        updatedAt: now,
      );

      txn.set(taskRef, task.toMap());
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

  Future<void> deleteTask(String projectId, String taskId) => _db
      .collection('projects')
      .doc(projectId)
      .collection('tasks')
      .doc(taskId)
      .delete();

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
    final taskRef = projectRef.collection('tasks').doc(e.taskId);
    final batch = _db.batch();
    batch.set(entryRef, e.toMap());
    batch.update(taskRef, {
      'actualHours': FieldValue.increment(e.hours),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
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
