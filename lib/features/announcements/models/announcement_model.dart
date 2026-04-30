class AnnouncementModel {
  final String id;
  final String title;
  final String content;
  final bool isUrgent;
  final String createdBy;
  final String buildingId;
  final DateTime createdAt;
  final List<String> photoUrls;

  const AnnouncementModel({
    required this.id,
    required this.title,
    required this.content,
    required this.isUrgent,
    required this.createdBy,
    required this.buildingId,
    required this.createdAt,
    this.photoUrls = const [],
  });

  factory AnnouncementModel.fromJson(Map<String, dynamic> json) {
    return AnnouncementModel(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      isUrgent: json['is_urgent'] as bool? ?? false,
      createdBy: json['created_by'] as String,
      buildingId: json['building_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      photoUrls: (json['photo_urls'] as List<dynamic>? ?? [])
          .map((e) => e as String)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'is_urgent': isUrgent,
      'created_by': createdBy,
      'building_id': buildingId,
      'created_at': createdAt.toIso8601String(),
      'photo_urls': photoUrls,
    };
  }
}
