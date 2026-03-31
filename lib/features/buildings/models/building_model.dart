class BuildingModel {
  final String id;
  final String name;
  final String address;
  final String? managerId;
  final DateTime createdAt;

  const BuildingModel({
    required this.id,
    required this.name,
    required this.address,
    this.managerId,
    required this.createdAt,
  });

  factory BuildingModel.fromJson(Map<String, dynamic> json) {
    return BuildingModel(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String,
      managerId: json['manager_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'manager_id': managerId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  BuildingModel copyWith({
    String? id,
    String? name,
    String? address,
    String? managerId,
    DateTime? createdAt,
  }) {
    return BuildingModel(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      managerId: managerId ?? this.managerId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
