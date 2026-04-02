class AmenityModel {
  final String id;
  final String buildingId;
  final String name;
  final String? description;
  final bool isActive;
  final DateTime createdAt;

  const AmenityModel({
    required this.id,
    required this.buildingId,
    required this.name,
    this.description,
    required this.isActive,
    required this.createdAt,
  });

  factory AmenityModel.fromJson(Map<String, dynamic> json) {
    return AmenityModel(
      id: json['id'] as String,
      buildingId: json['building_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class ReservationModel {
  final String id;
  final String amenityId;
  final String amenityName;
  final String buildingId;
  final String residentId;
  final String? residentName;
  final DateTime date;
  final String timeFrom;
  final String timeTo;
  final String? note;
  final DateTime createdAt;

  const ReservationModel({
    required this.id,
    required this.amenityId,
    required this.amenityName,
    required this.buildingId,
    required this.residentId,
    this.residentName,
    required this.date,
    required this.timeFrom,
    required this.timeTo,
    this.note,
    required this.createdAt,
  });

  factory ReservationModel.fromJson(Map<String, dynamic> json) {
    String? residentName;
    final profiles = json['profiles'];
    if (profiles is Map<String, dynamic>) {
      residentName = profiles['full_name'] as String?;
    }

    // Databáza vracia čas ako HH:MM:SS, skrátime na HH:MM
    String trimTime(String t) => t.length > 5 ? t.substring(0, 5) : t;

    return ReservationModel(
      id: json['id'] as String,
      amenityId: json['amenity_id'] as String,
      amenityName: json['amenity_name'] as String? ?? '',
      buildingId: json['building_id'] as String,
      residentId: json['resident_id'] as String,
      residentName: residentName,
      date: DateTime.parse(json['date'] as String),
      timeFrom: trimTime(json['time_from'] as String),
      timeTo: trimTime(json['time_to'] as String),
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
