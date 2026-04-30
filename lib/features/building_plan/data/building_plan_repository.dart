import 'package:supabase_flutter/supabase_flutter.dart';

class BuildingPlanRepository {
  final SupabaseClient _client;
  BuildingPlanRepository(this._client);

  Stream<String?> getPlanUrl(String buildingId) {
    return _client
        .from('building_plan')
        .stream(primaryKey: ['building_id'])
        .eq('building_id', buildingId)
        .map((rows) => rows.isEmpty ? null : rows.first['file_url'] as String?);
  }

  Future<void> savePlanUrl(String buildingId, String url) async {
    await _client.from('building_plan').upsert({
      'building_id': buildingId,
      'file_url': url,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }
}
