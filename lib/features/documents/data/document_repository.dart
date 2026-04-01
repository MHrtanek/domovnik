import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/document_model.dart';

class DocumentRepository {
  final SupabaseClient _client;
  final _uuid = const Uuid();
  static const _table = 'documents';
  static const _bucket = 'documents';

  DocumentRepository(this._client);

  Stream<List<DocumentModel>> getDocuments(String buildingId) {
    return _client
        .from(_table)
        .stream(primaryKey: ['id'])
        .eq('building_id', buildingId)
        .order('created_at', ascending: false)
        .map((rows) => rows.map((r) => DocumentModel.fromJson(r)).toList());
  }

  Future<DocumentModel> uploadDocument({
    required String buildingId,
    required String createdBy,
    required String name,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    try {
      final ext = _extFromMime(mimeType);
      final fileName = '${_uuid.v4()}.$ext';
      final filePath = '$buildingId/$fileName';

      await _client.storage
          .from(_bucket)
          .uploadBinary(
            filePath,
            bytes,
            fileOptions: FileOptions(contentType: mimeType),
          );

      final supabaseUrl =
          (dotenv.env['SUPABASE_URL'] ?? '').replaceAll(RegExp(r'/$'), '');
      final fileUrl =
          '$supabaseUrl/storage/v1/object/public/$_bucket/$filePath';

      final response = await _client
          .from(_table)
          .insert({
            'building_id': buildingId,
            'created_by': createdBy,
            'name': name,
            'file_url': fileUrl,
            'file_size': bytes.length,
          })
          .select()
          .single();

      return DocumentModel.fromJson(response);
    } catch (e) {
      debugPrint('DocumentRepository.uploadDocument error: $e');
      rethrow;
    }
  }

  Future<void> deleteDocument(DocumentModel doc) async {
    try {
      // Extract storage path from URL
      final uri = Uri.parse(doc.fileUrl);
      final pathSegments = uri.pathSegments;
      // URL: .../object/public/documents/{buildingId}/{fileName}
      final bucketIndex = pathSegments.indexOf(_bucket);
      if (bucketIndex >= 0 && bucketIndex < pathSegments.length - 1) {
        final storagePath =
            pathSegments.sublist(bucketIndex + 1).join('/');
        await _client.storage.from(_bucket).remove([storagePath]);
      }
      await _client.from(_table).delete().eq('id', doc.id);
    } catch (e) {
      debugPrint('DocumentRepository.deleteDocument error: $e');
      rethrow;
    }
  }

  String _extFromMime(String mime) {
    switch (mime) {
      case 'application/pdf':
        return 'pdf';
      case 'application/msword':
        return 'doc';
      case 'application/vnd.openxmlformats-officedocument.wordprocessingml.document':
        return 'docx';
      case 'image/png':
        return 'png';
      default:
        return 'pdf';
    }
  }
}
