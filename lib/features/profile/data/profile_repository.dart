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
      return ProfileModel.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      debugPrint('ProfileRepository.getProfile error: $e');
      rethrow;
    }
  }

  Future<ProfileModel> updateProfile({
    required String userId,
    String? fullName,
    String? flatNumber,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (fullName != null) updates['full_name'] = fullName;
      if (flatNumber != null) updates['flat_number'] = flatNumber;

      final response = await _client
          .from('profiles')
          .update(updates)
          .eq('id', userId)
          .select()
          .single();

      return ProfileModel.fromJson(response as Map<String, dynamic>);
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
