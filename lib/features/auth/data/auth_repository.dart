import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepository {
  final SupabaseClient _client;

  AuthRepository(this._client);

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  User? get currentUser => _client.auth.currentUser;

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      return await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } on AuthException catch (e) {
      debugPrint('AuthRepository.signIn error: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('AuthRepository.signIn unexpected error: $e');
      rethrow;
    }
  }

  /// Signs up a user.
  ///
  /// Registration metadata (role, full_name, building info) is embedded
  /// directly into [signUp]'s `data` map so it lands in
  /// `auth.users.raw_user_meta_data`. A database trigger
  /// (`on_auth_user_created`) picks those values up and atomically
  /// creates the profile and building — even before the user confirms
  /// their e-mail, which means no session is required at sign-up time.
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    required String role,
    String? buildingId,
    String? buildingName,
    String? buildingAddress,
  }) async {
    try {
      final metadata = <String, dynamic>{
        'full_name': fullName,
        'role': role,
        if (role == 'resident' && buildingId != null)
          'building_id': buildingId,
        if (role == 'manager' && buildingName != null)
          'building_name': buildingName,
        if (role == 'manager' && buildingAddress != null)
          'building_address': buildingAddress,
      };

      debugPrint('AuthRepository.signUp metadata: $metadata');

      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: metadata,          // → raw_user_meta_data → trigger fires
      );

      if (response.user == null) {
        throw Exception('Registrácia zlyhala – žiadny používateľ');
      }

      return response;
    } on AuthException catch (e) {
      debugPrint('AuthRepository.signUp auth error: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('AuthRepository.signUp unexpected error: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      debugPrint('AuthRepository.signOut error: $e');
      rethrow;
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
    } catch (e) {
      debugPrint('AuthRepository.resetPassword error: $e');
      rethrow;
    }
  }
}
