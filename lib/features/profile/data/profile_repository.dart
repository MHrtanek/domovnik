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

  /// Called when a profile row doesn't exist yet for an authenticated user.
  ///
  /// This happens when:
  ///   - Email confirmation is enabled and the trigger ran before confirmation
  ///     but the profile INSERT failed silently, OR
  ///   - The user confirmed their email and now has a session but the trigger
  ///     never fired.
  ///
  /// We read the registration metadata from the user's JWT
  /// (stored in raw_user_meta_data via signUp(data:{})) and call
  /// handle_user_signup() which is SECURITY DEFINER and works with a session.
  Future<ProfileModel?> bootstrapProfile(User user) async {
    final meta = user.userMetadata ?? {};
    final role = meta['role'] as String? ?? 'resident';
    final fullName = meta['full_name'] as String? ?? '';
    final buildingId = meta['building_id'] as String?;
    final buildingName = meta['building_name'] as String?;
    final buildingAddress = meta['building_address'] as String?;

    debugPrint(
      'ProfileRepository.bootstrapProfile: user=${user.id} role=$role '
      'meta=$meta',
    );

    try {
      await _client.rpc('handle_user_signup', params: {
        'p_email': user.email ?? '',
        'p_full_name': fullName,
        'p_role': role,
        'p_building_id': buildingId,
        'p_building_name': buildingName,
        'p_building_address': buildingAddress,
      });
      debugPrint('ProfileRepository.bootstrapProfile: RPC succeeded');
    } catch (e) {
      debugPrint('ProfileRepository.bootstrapProfile: RPC error: $e');
      // Don't rethrow — fall through and try to read whatever was created
    }

    // Read back the (hopefully now-existing) profile
    return getProfile(user.id);
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
