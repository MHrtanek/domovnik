import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile_model.dart';

class ProfileRepository {
  final SupabaseClient _client;

  ProfileRepository(this._client);

  Future<ProfileModel?> getProfile(String userId) async {
    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (response == null) return null;
      return ProfileModel.fromJson(response);
    } catch (e) {
      debugPrint('ProfileRepository.getProfile error: $e');
      rethrow;
    }
  }

  Future<List<ProfileModel>> getResidents(String buildingId) async {
    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('building_id', buildingId)
          .eq('role', 'resident')
          .order('full_name');
      return (response as List).map((r) => ProfileModel.fromJson(r)).toList();
    } catch (e) {
      debugPrint('ProfileRepository.getResidents error: $e');
      rethrow;
    }
  }

  Future<List<ProfileModel>> getDodavatelProfiles(String buildingId) async {
    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('building_id', buildingId)
          .eq('role', 'dodavatel')
          .order('full_name');
      return (response as List).map((r) => ProfileModel.fromJson(r)).toList();
    } catch (e) {
      debugPrint('ProfileRepository.getDodavatelProfiles error: $e');
      rethrow;
    }
  }

  Future<ProfileModel?> getManagerForBuilding(String buildingId) async {
    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('building_id', buildingId)
          .eq('role', 'manager')
          .maybeSingle();
      if (response == null) return null;
      return ProfileModel.fromJson(response);
    } catch (e) {
      debugPrint('ProfileRepository.getManagerForBuilding error: $e');
      return null;
    }
  }

  Future<ProfileModel?> bootstrapProfile(User user) async {
    final meta = user.userMetadata ?? {};
    final role = meta['role'] as String? ?? 'resident';
    final fullName = meta['full_name'] as String? ?? '';
    final buildingId = meta['building_id'] as String?;
    final buildingName = meta['building_name'] as String?;
    final buildingAddress = meta['building_address'] as String?;

    try {
      await _client.rpc('handle_user_signup', params: {
        'p_email': user.email ?? '',
        'p_full_name': fullName,
        'p_role': role,
        'p_building_id': buildingId,
        'p_building_name': buildingName,
        'p_building_address': buildingAddress,
      });
    } catch (e) {
      debugPrint('ProfileRepository.bootstrapProfile: RPC error: $e');
    }

    return getProfile(user.id);
  }

  Future<ProfileModel> updateProfile({
    required String userId,
    String? fullName,
    String? flatNumber,
    String? phone,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (fullName != null) updates['full_name'] = fullName;
      if (flatNumber != null) updates['flat_number'] = flatNumber;
      updates['phone'] = phone; // môže byť null (vymazanie)

      final response = await _client
          .from('profiles')
          .update(updates)
          .eq('id', userId)
          .select()
          .single();

      return ProfileModel.fromJson(response);
    } catch (e) {
      debugPrint('ProfileRepository.updateProfile error: $e');
      rethrow;
    }
  }

  Future<void> updateFcmToken({
    required String userId,
    required String fcmToken,
  }) async {
    try {
      await _client
          .from('profiles')
          .update({'fcm_token': fcmToken})
          .eq('id', userId);
    } catch (e) {
      debugPrint('ProfileRepository.updateFcmToken error: $e');
      rethrow;
    }
  }
}
