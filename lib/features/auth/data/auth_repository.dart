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

  /// Signs up a user and ensures their profile + building exist.
  ///
  /// Strategy (belt-and-suspenders):
  ///   1. Embed all metadata in `signUp(data:{})` → stored in
  ///      `raw_user_meta_data` → fires `on_auth_user_created` trigger
  ///      which creates the profile atomically, no session required.
  ///   2. If `signUp()` returns a session immediately (email confirmation
  ///      is disabled), also call `handle_user_signup()` RPC as a fallback
  ///      that will upsert the profile if the trigger somehow didn't run.
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    required String role,
    String? buildingId,
    String? buildingName,
    String? buildingAddress,
  }) async {
    // ── Step 1: create the auth user with metadata ─────────────────────────
    final AuthResponse response;
    try {
      response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'role': role,
          if ((role == 'resident' || role == 'dodavatel') && buildingId != null)
            'building_id': buildingId,
          if (role == 'manager' && buildingName != null)
            'building_name': buildingName,
          if (role == 'manager' && buildingAddress != null)
            'building_address': buildingAddress,
        },
      );
    } on AuthException catch (e) {
      debugPrint('AuthRepository.signUp auth error: ${e.message}');
      rethrow;
    }

    if (response.user == null) {
      throw Exception('Registrácia zlyhala – žiadny používateľ');
    }

    debugPrint(
      'AuthRepository.signUp: user=${response.user!.id} '
      'session=${response.session != null ? "YES" : "NO (email confirm required)"}',
    );

    // ── Step 2: if we got a session, call the RPC as a belt-and-suspenders  ─
    // The trigger already ran synchronously on INSERT, so this is usually a
    // no-op. But if the trigger failed silently (Supabase catches trigger
    // exceptions in some versions), the RPC will create the profile itself.
    if (response.session != null) {
      try {
        final result = await _client.rpc('handle_user_signup', params: {
          'p_email': email,
          'p_full_name': fullName,
          'p_role': role,
          'p_building_id': buildingId,
          'p_building_name': buildingName,
          'p_building_address': buildingAddress,
        });
        debugPrint('AuthRepository.signUp RPC result: $result');
      } catch (e) {
        // Log but don't fail – the trigger may already have done the work.
        debugPrint('AuthRepository.signUp RPC fallback error (non-fatal): $e');
      }
    }

    return response;
  }

  Future<void> signOut() async {
    try {
      await _client.auth.signOut(scope: SignOutScope.global);
    } catch (e) {
      debugPrint('AuthRepository.signOut error: $e');
      rethrow;
    }
  }

  Future<void> resetPassword(String email, {String? redirectTo}) async {
    try {
      await _client.auth.resetPasswordForEmail(email, redirectTo: redirectTo);
    } catch (e) {
      debugPrint('AuthRepository.resetPassword error: $e');
      rethrow;
    }
  }
}
