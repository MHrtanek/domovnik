enum TicketCategory {
  vodoinstalacia('Vodoinštalácia'),
  elektrina('Elektrina'),
  vytah('Výťah'),
  spolocnePriestory('Spoločné priestory'),
  ine('Iné');

  final String label;
  const TicketCategory(this.label);

  static TicketCategory fromString(String value) {
    return TicketCategory.values.firstWhere(
      (e) => e.label == value,
      orElse: () => TicketCategory.ine,
    );
  }
}

enum TicketStatus {
  prijate('Prijaté'),
  vRieseni('V riešení'),
  ukoncene('Ukončené');

  final String label;
  const TicketStatus(this.label);

  static TicketStatus fromString(String value) {
    return TicketStatus.values.firstWhere(
      (e) => e.label == value,
      orElse: () => TicketStatus.prijate,
    );
  }
}

class TicketModel {
  final String id;
  final String title;
  final String? description;
  final TicketCategory category;
  final TicketStatus status;
  final String? photoUrl;
  final String createdBy;
  final String? createdByName;
  final String buildingId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TicketModel({
    required this.id,
    required this.title,
    this.description,
    required this.category,
    required this.status,
    this.photoUrl,
    required this.createdBy,
    this.createdByName,
    required this.buildingId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TicketModel.fromJson(Map<String, dynamic> json) {
    // Support joined profiles data: profiles: { full_name: '...' }
    String? createdByName;
    final profiles = json['profiles'];
    if (profiles is Map<String, dynamic>) {
      createdByName = profiles['full_name'] as String?;
    }

    return TicketModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      category: TicketCategory.fromString(json['category'] as String),
      status: TicketStatus.fromString(json['status'] as String),
      photoUrl: json['photo_url'] as String?,
      createdBy: json['created_by'] as String,
      createdByName: createdByName,
      buildingId: json['building_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category.label,
      'status': status.label,
      'photo_url': photoUrl,
      'created_by': createdBy,
      'building_id': buildingId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  TicketModel copyWith({
    String? id,
    String? title,
    String? description,
    TicketCategory? category,
    TicketStatus? status,
    String? photoUrl,
    String? createdBy,
    String? createdByName,
    String? buildingId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TicketModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      status: status ?? this.status,
      photoUrl: photoUrl ?? this.photoUrl,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
      buildingId: buildingId ?? this.buildingId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
