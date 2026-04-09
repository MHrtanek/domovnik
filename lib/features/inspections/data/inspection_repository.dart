import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/inspection_model.dart';

class InspectionRepository {
  final SupabaseClient _client;
  InspectionRepository(this._client);

  Future<List<InspectionModel>> getInspections(String buildingId) async {
    final data = await _client
        .from('inspections')
        .select()
        .eq('building_id', buildingId)
        .order('next_date', ascending: true);
    return (data as List).map((e) => InspectionModel.fromJson(e)).toList();
  }

  Stream<List<InspectionModel>> streamInspections(String buildingId) {
    return _client
        .from('inspections')
        .stream(primaryKey: ['id'])
        .eq('building_id', buildingId)
        .order('next_date', ascending: true)
        .map((rows) => rows.map((e) => InspectionModel.fromJson(e)).toList());
  }

  Future<void> createInspection({
    required String buildingId,
    required String title,
    String? description,
    required DateTime inspectionDate,
    DateTime? nextDate,
  }) async {
    await _client.from('inspections').insert({
      'building_id': buildingId,
      'title': title,
      'description': description,
      'inspection_date': inspectionDate.toIso8601String().split('T')[0],
      'next_date': nextDate?.toIso8601String().split('T')[0],
    });
  }

  Future<void> deleteInspection(String id) async {
    await _client.from('inspections').delete().eq('id', id);
  }

  Future<void> updateInspection({
    required String id,
    required String title,
    String? description,
    required DateTime inspectionDate,
    DateTime? nextDate,
  }) async {
    await _client.from('inspections').update({
      'title': title,
      'description': description,
      'inspection_date': inspectionDate.toIso8601String().split('T')[0],
      'next_date': nextDate?.toIso8601String().split('T')[0],
    }).eq('id', id);
  }
}
