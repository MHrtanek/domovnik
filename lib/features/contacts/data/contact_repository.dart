import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/contact_model.dart';

class ContactRepository {
  final SupabaseClient _client;
  static const _table = 'contacts';

  ContactRepository(this._client);

  Stream<List<ContactModel>> getContacts(String buildingId) {
    return _client
        .from(_table)
        .stream(primaryKey: ['id'])
        .eq('building_id', buildingId)
        .order('name')
        .map((rows) =>
            rows.map((r) => ContactModel.fromJson(r)).toList());
  }

  Future<ContactModel> createContact({
    required String buildingId,
    required String createdBy,
    required String name,
    required String phone,
    String? description,
  }) async {
    try {
      final response = await _client
          .from(_table)
          .insert({
            'building_id': buildingId,
            'created_by': createdBy,
            'name': name,
            'phone': phone,
            'description': description,
          })
          .select()
          .single();
      return ContactModel.fromJson(response);
    } catch (e) {
      debugPrint('ContactRepository.createContact error: $e');
      rethrow;
    }
  }

  Future<ContactModel> updateContact({
    required String id,
    required String name,
    required String phone,
    String? description,
  }) async {
    try {
      final response = await _client
          .from(_table)
          .update({
            'name': name,
            'phone': phone,
            'description': description,
          })
          .eq('id', id)
          .select()
          .single();
      return ContactModel.fromJson(response);
    } catch (e) {
      debugPrint('ContactRepository.updateContact error: $e');
      rethrow;
    }
  }

  Future<void> deleteContact(String id) async {
    try {
      await _client.from(_table).delete().eq('id', id);
    } catch (e) {
      debugPrint('ContactRepository.deleteContact error: $e');
      rethrow;
    }
  }
}
