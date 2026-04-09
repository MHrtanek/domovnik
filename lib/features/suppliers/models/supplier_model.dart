class SupplierModel {
  final String id;
  final String buildingId;
  final String name;
  final String? category;
  final String? phone;
  final String? email;
  final String? note;
  final DateTime createdAt;

  const SupplierModel({
    required this.id,
    required this.buildingId,
    required this.name,
    this.category,
    this.phone,
    this.email,
    this.note,
    required this.createdAt,
  });

  factory SupplierModel.fromJson(Map<String, dynamic> json) {
    return SupplierModel(
      id: json['id'] as String,
      buildingId: json['building_id'] as String,
      name: json['name'] as String,
      category: json['category'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
