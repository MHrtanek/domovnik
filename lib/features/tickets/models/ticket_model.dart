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
  final String? photoUrl; // legacy
  final List<String> photoUrls; // nové - viacero fotiek
  final String createdBy;
  final String? createdByName;
  final String buildingId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? supplierId;
  final String? supplierName;

  const TicketModel({
    required this.id,
    required this.title,
    this.description,
    required this.category,
    required this.status,
    this.photoUrl,
    this.photoUrls = const [],
    required this.createdBy,
    this.createdByName,
    required this.buildingId,
    required this.createdAt,
    required this.updatedAt,
    this.supplierId,
    this.supplierName,
  });

  // Všetky fotky - kombinuje legacy photoUrl + nové photoUrls
  List<String> get allPhotoUrls {
    final all = <String>[];
    if (photoUrls.isNotEmpty) {
      all.addAll(photoUrls);
    } else if (photoUrl != null) {
      all.add(photoUrl!);
    }
    return all;
  }

  factory TicketModel.fromJson(Map<String, dynamic> json) {
    String? createdByName;
    final profiles = json['profiles'];
    if (profiles is Map<String, dynamic>) {
      createdByName = profiles['full_name'] as String?;
    }

    String? supplierName;
    final supplierProfile = json['supplier_profile'];
    if (supplierProfile is Map<String, dynamic>) {
      supplierName = supplierProfile['full_name'] as String?;
    }

    // Načítaj viacero fotiek z ticket_photos
    final List<String> photoUrls = [];
    final ticketPhotos = json['ticket_photos'];
    if (ticketPhotos is List) {
      for (final p in ticketPhotos) {
        if (p is Map<String, dynamic> && p['photo_url'] != null) {
          photoUrls.add(p['photo_url'] as String);
        }
      }
    }

    return TicketModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      category: TicketCategory.fromString(json['category'] as String),
      status: TicketStatus.fromString(json['status'] as String),
      photoUrl: json['photo_url'] as String?,
      photoUrls: photoUrls,
      createdBy: json['created_by'] as String,
      createdByName: createdByName,
      buildingId: json['building_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      supplierId: json['supplier_id'] as String?,
      supplierName: supplierName,
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
    List<String>? photoUrls,
    String? createdBy,
    String? createdByName,
    String? buildingId,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? supplierId = _sentinel,
    Object? supplierName = _sentinel,
  }) {
    return TicketModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      status: status ?? this.status,
      photoUrl: photoUrl ?? this.photoUrl,
      photoUrls: photoUrls ?? this.photoUrls,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
      buildingId: buildingId ?? this.buildingId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      supplierId: supplierId == _sentinel ? this.supplierId : supplierId as String?,
      supplierName: supplierName == _sentinel ? this.supplierName : supplierName as String?,
    );
  }
}

const _sentinel = Object();
