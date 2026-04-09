import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/building_model.dart';

class BuildingRepository {
  final SupabaseClient _client;

  BuildingRepository(this._client);

  Future<BuildingModel?> getBuilding(String id) async {
    try {
      final response = await _client
          .from('buildings')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;
      return BuildingModel.fromJson(response);
    } catch (e) {
      debugPrint('BuildingRepository.getBuilding error: $e');
      rethrow;
    }
  }

  Future<List<BuildingModel>> getAllBuildings() async {
    try {
      final response = await _client
          .from('buildings')
          .select()
          .order('name');

      return (response as List<dynamic>)
          .map((b) => BuildingModel.fromJson(b as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('BuildingRepository.getAllBuildings error: $e');
      rethrow;
    }
  }

  Future<BuildingModel> createBuilding({
    required String name,
    required String address,
  }) async {
    try {
      final response = await _client
          .from('buildings')
          .insert({'name': name, 'address': address})
          .select()
          .single();

      return BuildingModel.fromJson(response);
    } catch (e) {
      debugPrint('BuildingRepository.createBuilding error: $e');
      rethrow;
    }
  }

  Future<BuildingModel> updateBuilding({
    required String id,
    String? name,
    String? address,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (address != null) updates['address'] = address;

      final response = await _client
          .from('buildings')
          .update(updates)
          .eq('id', id)
          .select()
          .single();

      return BuildingModel.fromJson(response);
    } catch (e) {
      debugPrint('BuildingRepository.updateBuilding error: $e');
      rethrow;
    }
  }
}
