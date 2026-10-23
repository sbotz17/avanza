import 'package:cloud_firestore/cloud_firestore.dart';

/// Ore di lavoro di un membro della squadra su una fase di un task.
/// Le tariffe sono congelate al momento della registrazione, così lo storico
/// non cambia se la tariffa del membro viene modificata in seguito.
class TimeEntry {
  final String id;
  final String projectId;
  final String taskId;
  final String taskCode;
  final String memberId;
  final String memberName;
  final String phase;
  final double hours;
  final double costRate;
  final double billRate;
  final DateTime date;
  final String note;
  final String source; // 'manual' | 'squad'

  const TimeEntry({
    required this.id,
    required this.projectId,
    required this.taskId,
    required this.taskCode,
    required this.memberId,
    required this.memberName,
    required this.phase,
    required this.hours,
    required this.costRate,
    required this.billRate,
    required this.date,
    this.note = '',
    this.source = 'manual',
  });

  double get cost => hours * costRate;
  double get billed => hours * billRate;

  factory TimeEntry.fromFirestore(DocumentSnapshot doc, String projectId) {
    final d = doc.data() as Map<String, dynamic>;
    return TimeEntry(
      id: doc.id,
      projectId: projectId,
      taskId: d['taskId'] as String? ?? '',
      taskCode: d['taskCode'] as String? ?? '',
      memberId: d['memberId'] as String? ?? '',
      memberName: d['memberName'] as String? ?? '',
      phase: d['phase'] as String? ?? '',
      hours: (d['hours'] as num?)?.toDouble() ?? 0,
      costRate: (d['costRate'] as num?)?.toDouble() ?? 0,
      billRate: (d['billRate'] as num?)?.toDouble() ?? 0,
      date: (d['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      note: d['note'] as String? ?? '',
      source: d['source'] as String? ?? 'manual',
    );
  }

  Map<String, dynamic> toMap() => {
        'taskId': taskId,
        'taskCode': taskCode,
        'memberId': memberId,
        'memberName': memberName,
        'phase': phase,
        'hours': hours,
        'costRate': costRate,
        'billRate': billRate,
        'date': Timestamp.fromDate(date),
        'note': note,
        'source': source,
      };
}
