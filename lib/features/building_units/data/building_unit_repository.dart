import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/building_unit_model.dart';

class BuildingUnitRepository {
  final SupabaseClient _client;
  static const _table = 'building_units';

  BuildingUnitRepository(this._client);

  Stream<List<BuildingUnitModel>> getUnits(String buildingId) {
    return _client
        .from(_table)
        .stream(primaryKey: ['id'])
        .eq('building_id', buildingId)
        .order('unit_number')
        .map((rows) => rows.map((r) => BuildingUnitModel.fromJson(r)).toList());
  }

  Future<void> addUnit({
    required String buildingId,
    required String unitType,
    required String unitNumber,
    int floor = 0,
    String? residentId,
    String? residentName,
    String? note,
  }) async {
    try {
      await _client.from(_table).insert({
        'building_id': buildingId,
        'unit_type': unitType,
        'unit_number': unitNumber,
        'floor': floor,
        if (residentId != null) 'resident_id': residentId,
        if (residentName != null) 'resident_name': residentName,
        if (note != null) 'note': note,
      });
    } catch (e) {
      debugPrint('BuildingUnitRepository.addUnit error: $e');
      rethrow;
    }
  }

  Future<void> updateUnit(
    String id, {
    String? unitType,
    String? unitNumber,
    int? floor,
    String? residentId,
    String? residentName,
    String? note,
  }) async {
    try {
      await _client.from(_table).update({
        if (unitType != null) 'unit_type': unitType,
        if (unitNumber != null) 'unit_number': unitNumber,
        if (floor != null) 'floor': floor,
        'resident_id': residentId,
        'resident_name': residentName,
        if (note != null) 'note': note,
      }).eq('id', id);
    } catch (e) {
      debugPrint('BuildingUnitRepository.updateUnit error: $e');
      rethrow;
    }
  }

  Future<void> deleteUnit(String id) async {
    try {
      await _client.from(_table).delete().eq('id', id);
    } catch (e) {
      debugPrint('BuildingUnitRepository.deleteUnit error: $e');
      rethrow;
    }
  }
}
