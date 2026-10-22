import 'package:cloud_firestore/cloud_firestore.dart';

class TaskPhase {
  final String name;
  final String status; // done | active | pending | blocked | skip
  final String label;

  const TaskPhase({
    required this.name,
    required this.status,
    required this.label,
  });

  factory TaskPhase.fromMap(Map<String, dynamic> m) => TaskPhase(
        name: m['name'] as String? ?? '',
        status: m['status'] as String? ?? 'pending',
        label: m['label'] as String? ?? '',
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'status': status,
        'label': label,
      };

  TaskPhase copyWith({String? status, String? label}) => TaskPhase(
        name: name,
        status: status ?? this.status,
        label: label ?? this.label,
      );
}

class TaskNote {
  final String type; // ok | info | blk
  final String text;

  const TaskNote({required this.type, required this.text});

  factory TaskNote.fromMap(Map<String, dynamic> m) => TaskNote(
        type: m['type'] as String? ?? 'info',
        text: m['text'] as String? ?? '',
      );

  Map<String, dynamic> toMap() => {'type': type, 'text': text};
}

class Task {
  final String id;
  final String projectId;
  final String title;
  final String description;
  final String clientRequest;
  final String status; // backlog | active | blocked | review | validated | released
  final List<TaskPhase> phases;
  final List<TaskNote> notes;
  final double estimatedHours;
  final double actualHours;
  final double hourlyRate;
  final int order;
  final String taskCode; // es. "T-1" — identificatore breve unico nel progetto
  final int taskNumber; // numero progressivo usato per generare taskCode
  final DateTime createdAt;
  final DateTime updatedAt;

  const Task({
    required this.id,
    required this.projectId,
    required this.title,
    required this.description,
    required this.clientRequest,
    required this.status,
    required this.phases,
    required this.notes,
    required this.estimatedHours,
    required this.actualHours,
    required this.hourlyRate,
    required this.order,
    this.taskCode = '',
    this.taskNumber = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Task.fromFirestore(DocumentSnapshot doc, String projectId) {
    final d = doc.data() as Map<String, dynamic>;
    return Task(
      id: doc.id,
      projectId: projectId,
      title: d['title'] as String? ?? '',
      description: d['description'] as String? ?? '',
      clientRequest: d['clientRequest'] as String? ?? '',
      status: d['status'] as String? ?? 'backlog',
      phases: ((d['phases'] as List?)?.cast<Map<String, dynamic>>() ?? [])
          .map(TaskPhase.fromMap)
          .toList(),
      notes: ((d['notes'] as List?)?.cast<Map<String, dynamic>>() ?? [])
          .map(TaskNote.fromMap)
          .toList(),
      estimatedHours: (d['estimatedHours'] as num?)?.toDouble() ?? 0,
      actualHours: (d['actualHours'] as num?)?.toDouble() ?? 0,
      hourlyRate: (d['hourlyRate'] as num?)?.toDouble() ?? 0,
      order: (d['order'] as int?) ?? 0,
      taskCode: d['taskCode'] as String? ?? '',
      taskNumber: (d['taskNumber'] as int?) ?? 0,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'description': description,
        'clientRequest': clientRequest,
        'status': status,
        'phases': phases.map((p) => p.toMap()).toList(),
        'notes': notes.map((n) => n.toMap()).toList(),
        'estimatedHours': estimatedHours,
        'actualHours': actualHours,
        'hourlyRate': hourlyRate,
        'order': order,
        'taskCode': taskCode,
        'taskNumber': taskNumber,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  // Percentage completion based on non-skip phases
  double get pct {
    final nonSkip = phases.where((p) => p.status != 'skip').toList();
    if (nonSkip.isEmpty) return 0;
    final done = nonSkip.where((p) => p.status == 'done').length;
    return (done / nonSkip.length) * 100;
  }

  // Computed kanban column from status field
  String get kanbanCol => status;

  double get estimatedCost => estimatedHours * hourlyRate;
  double get actualCost => actualHours * hourlyRate;

  Task copyWith({
    String? title,
    String? description,
    String? clientRequest,
    String? status,
    List<TaskPhase>? phases,
    List<TaskNote>? notes,
    double? estimatedHours,
    double? actualHours,
    double? hourlyRate,
    int? order,
    String? taskCode,
    int? taskNumber,
  }) =>
      Task(
        id: id,
        projectId: projectId,
        title: title ?? this.title,
        description: description ?? this.description,
        clientRequest: clientRequest ?? this.clientRequest,
        status: status ?? this.status,
        phases: phases ?? this.phases,
        notes: notes ?? this.notes,
        estimatedHours: estimatedHours ?? this.estimatedHours,
        actualHours: actualHours ?? this.actualHours,
        hourlyRate: hourlyRate ?? this.hourlyRate,
        order: order ?? this.order,
        taskCode: taskCode ?? this.taskCode,
        taskNumber: taskNumber ?? this.taskNumber,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );
}
