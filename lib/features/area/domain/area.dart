import 'package:cloud_firestore/cloud_firestore.dart';

class Area {
  final String id;
  final String name;
  final String shortName;
  final String location;
  final String description;
  final bool isActive;
  final bool isHidden;
  final DateTime? deletedAt;
  final String deletedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Area({
    required this.id,
    required this.name,
    required this.shortName,
    required this.location,
    required this.description,
    this.isActive = true,
    this.isHidden = false,
    this.deletedAt,
    this.deletedBy = '',
    this.createdAt,
    this.updatedAt,
  });

  bool get isDeleted => deletedAt != null;

  factory Area.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Area(
      id: doc.id,
      name: data['name'] as String? ?? '',
      shortName: data['shortName'] as String? ?? '',
      location: data['location'] as String? ?? '',
      description: data['description'] as String? ?? '',
      isActive: data['isActive'] as bool? ?? true,
      isHidden: data['isHidden'] as bool? ?? false,
      deletedAt: (data['deletedAt'] as Timestamp?)?.toDate(),
      deletedBy: data['deletedBy'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toCreateMap() {
    return {
      'name': name,
      'shortName': shortName,
      'location': location,
      'description': description,
      'isActive': isActive,
      'isHidden': isHidden,
      'deletedAt': null,
      'deletedBy': '',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return {
      'name': name,
      'shortName': shortName,
      'location': location,
      'description': description,
      'isActive': isActive,
      'isHidden': isHidden,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Area copyWith({
    String? id,
    String? name,
    String? shortName,
    String? location,
    String? description,
    bool? isActive,
    bool? isHidden,
    DateTime? deletedAt,
    String? deletedBy,
  }) {
    return Area(
      id: id ?? this.id,
      name: name ?? this.name,
      shortName: shortName ?? this.shortName,
      location: location ?? this.location,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      isHidden: isHidden ?? this.isHidden,
      deletedAt: deletedAt ?? this.deletedAt,
      deletedBy: deletedBy ?? this.deletedBy,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
