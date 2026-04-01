class DocumentModel {
  final String id;
  final String buildingId;
  final String name;
  final String fileUrl;
  final int? fileSize;
  final String createdBy;
  final DateTime createdAt;

  const DocumentModel({
    required this.id,
    required this.buildingId,
    required this.name,
    required this.fileUrl,
    this.fileSize,
    required this.createdBy,
    required this.createdAt,
  });

  factory DocumentModel.fromJson(Map<String, dynamic> json) {
    return DocumentModel(
      id: json['id'] as String,
      buildingId: json['building_id'] as String,
      name: json['name'] as String,
      fileUrl: json['file_url'] as String,
      fileSize: json['file_size'] as int?,
      createdBy: json['created_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  String get fileSizeLabel {
    if (fileSize == null) return '';
    if (fileSize! < 1024) return '${fileSize} B';
    if (fileSize! < 1024 * 1024) {
      return '${(fileSize! / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSize! / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
