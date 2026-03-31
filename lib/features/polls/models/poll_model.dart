class PollOptionModel {
  final String id;
  final String pollId;
  final String optionText;
  final int voteCount;

  const PollOptionModel({
    required this.id,
    required this.pollId,
    required this.optionText,
    this.voteCount = 0,
  });

  factory PollOptionModel.fromJson(Map<String, dynamic> json) {
    return PollOptionModel(
      id: json['id'] as String,
      pollId: json['poll_id'] as String,
      optionText: json['option_text'] as String,
      voteCount: json['vote_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'poll_id': pollId,
      'option_text': optionText,
    };
  }

  PollOptionModel copyWith({int? voteCount}) {
    return PollOptionModel(
      id: id,
      pollId: pollId,
      optionText: optionText,
      voteCount: voteCount ?? this.voteCount,
    );
  }
}

class PollModel {
  final String id;
  final String question;
  final String buildingId;
  final String createdBy;
  final DateTime? expiresAt;
  final DateTime createdAt;
  final List<PollOptionModel> options;
  final bool hasVoted;

  const PollModel({
    required this.id,
    required this.question,
    required this.buildingId,
    required this.createdBy,
    this.expiresAt,
    required this.createdAt,
    this.options = const [],
    this.hasVoted = false,
  });

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  int get totalVotes => options.fold(0, (sum, o) => sum + o.voteCount);

  double votePercentage(PollOptionModel option) {
    final total = totalVotes;
    if (total == 0) return 0;
    return option.voteCount / total;
  }

  factory PollModel.fromJson(Map<String, dynamic> json) {
    final optionsJson = json['poll_options'] as List<dynamic>? ?? [];
    return PollModel(
      id: json['id'] as String,
      question: json['question'] as String,
      buildingId: json['building_id'] as String,
      createdBy: json['created_by'] as String,
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      options: optionsJson
          .map((o) => PollOptionModel.fromJson(o as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question': question,
      'building_id': buildingId,
      'created_by': createdBy,
      'expires_at': expiresAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  PollModel copyWith({
    List<PollOptionModel>? options,
    bool? hasVoted,
  }) {
    return PollModel(
      id: id,
      question: question,
      buildingId: buildingId,
      createdBy: createdBy,
      expiresAt: expiresAt,
      createdAt: createdAt,
      options: options ?? this.options,
      hasVoted: hasVoted ?? this.hasVoted,
    );
  }
}
