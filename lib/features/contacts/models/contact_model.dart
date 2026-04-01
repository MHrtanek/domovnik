class ContactModel {
  final String id;
  final String buildingId;
  final String name;
  final String phone;
  final String? description;
  final String createdBy;
  final DateTime createdAt;

  const ContactModel({
    required this.id,
    required this.buildingId,
    required this.name,
    required this.phone,
    this.description,
    required this.createdBy,
    required this.createdAt,
  });

  factory ContactModel.fromJson(Map<String, dynamic> json) {
    return ContactModel(
      id: json['id'] as String,
      buildingId: json['building_id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      description: json['description'] as String?,
      createdBy: json['created_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'building_id': buildingId,
        'name': name,
        'phone': phone,
        'description': description,
        'created_by': createdBy,
        'created_at': createdAt.toIso8601String(),
      };

  ContactModel copyWith({
    String? name,
    String? phone,
    String? description,
  }) =>
      ContactModel(
        id: id,
        buildingId: buildingId,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        description: description ?? this.description,
        createdBy: createdBy,
        createdAt: createdAt,
      );
}
