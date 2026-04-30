import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/announcement_model.dart';
import '../../../core/constants/supabase_constants.dart';

class AnnouncementRepository {
  final SupabaseClient _client;
  final _uuid = const Uuid();

  AnnouncementRepository(this._client);

  Stream<List<AnnouncementModel>> getAnnouncements(String buildingId) {
    return _client
        .from(SupabaseConstants.tablAnnouncements)
        .stream(primaryKey: ['id'])
        .eq('building_id', buildingId)
        .order('created_at', ascending: false)
        .map((rows) => rows
            .map((r) => AnnouncementModel.fromJson(r))
            .toList());
  }

  Future<AnnouncementModel> createAnnouncement({
    required String title,
    required String content,
    required bool isUrgent,
    required String createdBy,
    required String buildingId,
    List<String> photoUrls = const [],
  }) async {
    try {
      final response = await _client
          .from(SupabaseConstants.tablAnnouncements)
          .insert({
            'title': title,
            'content': content,
            'is_urgent': isUrgent,
            'created_by': createdBy,
            'building_id': buildingId,
            'photo_urls': photoUrls,
          })
          .select()
          .single();

      return AnnouncementModel.fromJson(response);
    } catch (e) {
      debugPrint('AnnouncementRepository.createAnnouncement error: $e');
      rethrow;
    }
  }

  Future<void> deleteAnnouncement(String id) async {
    try {
      await _client
          .from(SupabaseConstants.tablAnnouncements)
          .delete()
          .eq('id', id);
    } catch (e) {
      debugPrint('AnnouncementRepository.deleteAnnouncement error: $e');
      rethrow;
    }
  }

  /// Nahraj obrázok do storage a vráť verejnú URL.
  /// Používa rovnaký bucket ako tikety (ticket-photos), s cestou announcements/.
  Future<String> uploadAnnouncementPhoto(Uint8List bytes, String mimeType) async {
    try {
      final ext = _extFromMime(mimeType);
      final fileName = '${_uuid.v4()}.$ext';
      const bucket = SupabaseConstants.storageBucket;
      final filePath = 'announcements/$fileName';

      await _client.storage
          .from(bucket)
          .uploadBinary(
            filePath,
            bytes,
            fileOptions: FileOptions(contentType: mimeType),
          );

      final supabaseUrl = (dotenv.env['SUPABASE_URL'] ?? '').replaceAll(RegExp(r'/$'), '');
      return '$supabaseUrl/storage/v1/object/public/$bucket/$filePath';
    } catch (e) {
      debugPrint('AnnouncementRepository.uploadAnnouncementPhoto error: $e');
      rethrow;
    }
  }

  String _extFromMime(String mime) {
    switch (mime) {
      case 'image/png':  return 'png';
      case 'image/gif':  return 'gif';
      case 'image/webp': return 'webp';
      default:           return 'jpg';
    }
  }
}
