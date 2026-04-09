class MessageModel {
  final String id;
  final String buildingId;
  final String senderId;
  final String receiverId;
  final String content;
  final bool read;
  final DateTime createdAt;

  const MessageModel({
    required this.id,
    required this.buildingId,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.read,
    required this.createdAt,
  });

  bool isMine(String currentUserId) => senderId == currentUserId;

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] as String,
      buildingId: json['building_id'] as String,
      senderId: json['sender_id'] as String,
      receiverId: json['receiver_id'] as String,
      content: json['content'] as String,
      read: (json['read'] as bool?) ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
