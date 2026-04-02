class ForumPostModel {
  final String id;
  final String buildingId;
  final String createdBy;
  final String? createdByName;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int replyCount;

  const ForumPostModel({
    required this.id,
    required this.buildingId,
    required this.createdBy,
    this.createdByName,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.replyCount = 0,
  });

  factory ForumPostModel.fromJson(Map<String, dynamic> json) {
    String? createdByName;
    final profiles = json['profiles'];
    if (profiles is Map<String, dynamic>) {
      createdByName = profiles['full_name'] as String?;
    }

    return ForumPostModel(
      id: json['id'] as String,
      buildingId: json['building_id'] as String,
      createdBy: json['created_by'] as String,
      createdByName: createdByName,
      title: json['title'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      replyCount: json['reply_count'] as int? ?? 0,
    );
  }
}

class ForumReplyModel {
  final String id;
  final String postId;
  final String buildingId;
  final String createdBy;
  final String? createdByName;
  final String content;
  final DateTime createdAt;

  const ForumReplyModel({
    required this.id,
    required this.postId,
    required this.buildingId,
    required this.createdBy,
    this.createdByName,
    required this.content,
    required this.createdAt,
  });

  factory ForumReplyModel.fromJson(Map<String, dynamic> json) {
    String? createdByName;
    final profiles = json['profiles'];
    if (profiles is Map<String, dynamic>) {
      createdByName = profiles['full_name'] as String?;
    }

    return ForumReplyModel(
      id: json['id'] as String,
      postId: json['post_id'] as String,
      buildingId: json['building_id'] as String,
      createdBy: json['created_by'] as String,
      createdByName: createdByName,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
