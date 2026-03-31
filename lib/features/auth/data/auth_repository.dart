import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../buildings/models/building_model.dart';

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

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    required String role,
    String? buildingId,
    // For manager: building details to create
    String? buildingName,
    String? buildingAddress,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw Exception('Registrácia zlyhala');
      }

      final userId = response.user!.id;
      String? finalBuildingId = buildingId;

      // If registering as manager, create the building first
      if (role == 'manager' && buildingName != null && buildingAddress != null) {
        final buildingResponse = await _client
            .from('buildings')
            .insert({
              'name': buildingName,
              'address': buildingAddress,
            })
            .select()
            .single();
        finalBuildingId = (buildingResponse as Map<String, dynamic>)['id'] as String;
      }

      // Create profile
      await _client.from('profiles').insert({
        'id': userId,
        'email': email,
        'full_name': fullName,
        'role': role,
        'building_id': finalBuildingId,
      });

      // If manager, update building with manager_id
      if (role == 'manager' && finalBuildingId != null) {
        await _client
            .from('buildings')
            .update({'manager_id': userId})
            .eq('id', finalBuildingId);
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
