class InspectionModel {
  final String id;
  final String buildingId;
  final String title;
  final String? description;
  final DateTime inspectionDate;
  final DateTime? nextDate;
  final String status;
  final DateTime createdAt;

  const InspectionModel({
    required this.id,
    required this.buildingId,
    required this.title,
    this.description,
    required this.inspectionDate,
    this.nextDate,
    required this.status,
    required this.createdAt,
  });

  bool get isExpiringSoon {
    if (nextDate == null) return false;
    final daysLeft = nextDate!.difference(DateTime.now()).inDays;
    return daysLeft >= 0 && daysLeft <= 30;
  }

  bool get isExpired {
    if (nextDate == null) return false;
    return nextDate!.isBefore(DateTime.now());
  }

  int? get daysUntilNext {
    if (nextDate == null) return null;
    return nextDate!.difference(DateTime.now()).inDays;
  }

  factory InspectionModel.fromJson(Map<String, dynamic> json) {
    return InspectionModel(
      id: json['id'] as String,
      buildingId: json['building_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      inspectionDate: DateTime.parse(json['inspection_date'] as String),
      nextDate: json['next_date'] != null ? DateTime.parse(json['next_date'] as String) : null,
      status: json['status'] as String? ?? 'active',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
