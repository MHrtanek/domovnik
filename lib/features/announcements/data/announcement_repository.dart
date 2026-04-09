import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/announcement_model.dart';
import '../../../core/constants/supabase_constants.dart';

class AnnouncementRepository {
  final SupabaseClient _client;

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
}
