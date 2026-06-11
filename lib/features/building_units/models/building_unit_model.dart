class BuildingUnitModel {
  final String id;
  final String buildingId;
  final String unitType;
  final String unitNumber;
  final int floor;
  final String? residentId;
  final String? residentName;
  final String? note;
  final DateTime createdAt;

  const BuildingUnitModel({
    required this.id,
    required this.buildingId,
    required this.unitType,
    required this.unitNumber,
    required this.floor,
    this.residentId,
    this.residentName,
    this.note,
    required this.createdAt,
  });

  factory BuildingUnitModel.fromJson(Map<String, dynamic> json) {
    return BuildingUnitModel(
      id: json['id'] as String,
      buildingId: json['building_id'] as String,
      unitType: json['unit_type'] as String,
      unitNumber: json['unit_number'] as String,
      floor: (json['floor'] as num?)?.toInt() ?? 0,
      residentId: json['resident_id'] as String?,
      residentName: json['resident_name'] as String?,
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  String get unitTypeLabel => switch (unitType) {
        'byt' => 'Byt',
        'pivnica' => 'Pivnica',
        'parkovisko' => 'Parkovisko',
        _ => unitType,
      };

  BuildingUnitModel copyWith({
    String? unitNumber,
    int? floor,
    String? residentId,
    String? residentName,
    String? note,
  }) =>
      BuildingUnitModel(
        id: id,
        buildingId: buildingId,
        unitType: unitType,
        unitNumber: unitNumber ?? this.unitNumber,
        floor: floor ?? this.floor,
        residentId: residentId,
        residentName: residentName ?? this.residentName,
        note: note ?? this.note,
        createdAt: createdAt,
      );
}
