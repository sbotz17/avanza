import 'package:cloud_firestore/cloud_firestore.dart';

const List<String> kMemberKinds = ['agent', 'person'];

const Map<String, String> kMemberKindLabels = {
  'agent': 'Agente',
  'person': 'Persona',
};

class TeamMember {
  final String id;
  final String ownerId;
  final String name;
  final String kind; // 'agent' | 'person'
  final String role;
  final double costRate; // costo interno orario
  final double billRate; // tariffa di vendita oraria
  final bool active;
  final DateTime createdAt;

  const TeamMember({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.kind,
    required this.role,
    required this.costRate,
    required this.billRate,
    required this.active,
    required this.createdAt,
  });

  factory TeamMember.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return TeamMember(
      id: doc.id,
      ownerId: d['ownerId'] as String? ?? '',
      name: d['name'] as String? ?? '',
      kind: d['kind'] as String? ?? 'person',
      role: d['role'] as String? ?? '',
      costRate: (d['costRate'] as num?)?.toDouble() ?? 0,
      billRate: (d['billRate'] as num?)?.toDouble() ?? 0,
      active: d['active'] as bool? ?? true,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'ownerId': ownerId,
        'name': name,
        'kind': kind,
        'role': role,
        'costRate': costRate,
        'billRate': billRate,
        'active': active,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
