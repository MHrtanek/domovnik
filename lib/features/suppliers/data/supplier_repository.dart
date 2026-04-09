import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/supplier_model.dart';

class SupplierRepository {
  final SupabaseClient _client;
  SupplierRepository(this._client);

  Future<List<SupplierModel>> getSuppliers(String buildingId) async {
    final data = await _client
        .from('suppliers')
        .select()
        .eq('building_id', buildingId)
        .order('name', ascending: true);
    return (data as List).map((e) => SupplierModel.fromJson(e)).toList();
  }

  Stream<List<SupplierModel>> streamSuppliers(String buildingId) {
    return _client
        .from('suppliers')
        .stream(primaryKey: ['id'])
        .eq('building_id', buildingId)
        .order('name', ascending: true)
        .map((rows) => rows.map((e) => SupplierModel.fromJson(e)).toList());
  }

  Future<void> createSupplier({
    required String buildingId,
    required String name,
    String? category,
    String? phone,
    String? email,
    String? note,
  }) async {
    await _client.from('suppliers').insert({
      'building_id': buildingId,
      'name': name,
      'category': category,
      'phone': phone,
      'email': email,
      'note': note,
    });
  }

  Future<void> deleteSupplier(String id) async {
    await _client.from('suppliers').delete().eq('id', id);
  }

  Future<void> updateSupplier({
    required String id,
    required String name,
    String? category,
    String? phone,
    String? email,
    String? note,
  }) async {
    await _client.from('suppliers').update({
      'name': name,
      'category': category,
      'phone': phone,
      'email': email,
      'note': note,
    }).eq('id', id);
  }
}
