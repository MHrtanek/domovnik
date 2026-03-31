class ProfileModel {
  final String id;
  final String email;
  final String? fullName;
  final String? flatNumber;
  final String role;
  final String? buildingId;
  final String? fcmToken;
  final DateTime createdAt;

  const ProfileModel({
    required this.id,
    required this.email,
    this.fullName,
    this.flatNumber,
    required this.role,
    this.buildingId,
    this.fcmToken,
    required this.createdAt,
  });

  bool get isManager => role == 'manager';
  bool get isResident => role == 'resident';

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String?,
      flatNumber: json['flat_number'] as String?,
      role: json['role'] as String,
      buildingId: json['building_id'] as String?,
      fcmToken: json['fcm_token'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'flat_number': flatNumber,
      'role': role,
      'building_id': buildingId,
      'fcm_token': fcmToken,
      'created_at': createdAt.toIso8601String(),
    };
  }

  ProfileModel copyWith({
    String? id,
    String? email,
    String? fullName,
    String? flatNumber,
    String? role,
    String? buildingId,
    String? fcmToken,
    DateTime? createdAt,
  }) {
    return ProfileModel(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      flatNumber: flatNumber ?? this.flatNumber,
      role: role ?? this.role,
      buildingId: buildingId ?? this.buildingId,
      fcmToken: fcmToken ?? this.fcmToken,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
