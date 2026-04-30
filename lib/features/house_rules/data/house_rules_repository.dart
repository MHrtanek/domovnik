import 'package:supabase_flutter/supabase_flutter.dart';

class HouseRulesRepository {
  final SupabaseClient _client;
  HouseRulesRepository(this._client);

  Stream<String> getHouseRules(String buildingId) {
    return _client
        .from('house_rules')
        .stream(primaryKey: ['id'])
        .eq('building_id', buildingId)
        .map((rows) => rows.isEmpty ? '' : (rows.first['content'] as String? ?? ''));
  }

  Future<void> saveHouseRules({
    required String buildingId,
    required String content,
    required String updatedBy,
  }) async {
    await _client.from('house_rules').upsert({
      'building_id': buildingId,
      'content': content,
      'updated_by': updatedBy,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'building_id');
  }
}
