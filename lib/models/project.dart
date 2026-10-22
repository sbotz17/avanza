import 'package:cloud_firestore/cloud_firestore.dart';

class Project {
  final String id;
  final String name;
  final String description;
  final String githubUrl;
  final String clientCode;
  final String ownerId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Project({
    required this.id,
    required this.name,
    required this.description,
    required this.githubUrl,
    required this.clientCode,
    required this.ownerId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Project.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Project(
      id: doc.id,
      name: d['name'] as String? ?? '',
      description: d['description'] as String? ?? '',
      githubUrl: d['githubUrl'] as String? ?? '',
      clientCode: d['clientCode'] as String? ?? '',
      ownerId: d['ownerId'] as String? ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'description': description,
        'githubUrl': githubUrl,
        'clientCode': clientCode,
        'ownerId': ownerId,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  Project copyWith({
    String? name,
    String? description,
    String? githubUrl,
  }) =>
      Project(
        id: id,
        name: name ?? this.name,
        description: description ?? this.description,
        githubUrl: githubUrl ?? this.githubUrl,
        clientCode: clientCode,
        ownerId: ownerId,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );
}
