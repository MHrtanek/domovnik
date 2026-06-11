import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/profile_repository.dart';
import '../../models/profile_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class NoBuildingException implements Exception {
  const NoBuildingException();
  @override
  String toString() => 'Váš účet nie je priradený k budove. Kontaktujte správcu.';
}

/// Resolves the current user's buildingId, or throws [NoBuildingException]
/// if the profile has no building assigned. Providers that depend on buildingId
/// watch this; the error propagates as AsyncError to the UI.
final buildingIdProvider = FutureProvider<String>((ref) async {
  final profile = await ref.watch(profileProvider.future);
  if (profile == null) throw Exception('Profil nie je dostupný');
  if (profile.buildingId == null) throw const NoBuildingException();
  return profile.buildingId!;
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(supabaseClientProvider));
});

final profileProvider = AsyncNotifierProvider<ProfileNotifier, ProfileModel?>(
  ProfileNotifier.new,
);

class ProfileNotifier extends AsyncNotifier<ProfileModel?> {
  @override
  Future<ProfileModel?> build() async {
    final user = ref.watch(currentUserProvider);
    if (user == null) return null;

    final repo = ref.read(profileRepositoryProvider);
    final existing = await repo.getProfile(user.id);

    // Self-healing: if authenticated but no profile row, it means the
    // on_auth_user_created trigger didn't run (e.g. email confirmation
    // delayed the session, or the trigger failed silently).
    // Call bootstrapProfile() which reads JWT metadata and calls the
    // handle_user_signup RPC (SECURITY DEFINER) to create it now.
    if (existing == null) {
      return repo.bootstrapProfile(user);
    }

    return existing;
  }

  Future<void> updateProfile({
    String? fullName,
    String? flatNumber,
    String? phone,
  }) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return ref.read(profileRepositoryProvider).updateProfile(
            userId: user.id,
            fullName: fullName,
            flatNumber: flatNumber,
            phone: phone,
          );
    });
  }

  Future<void> refresh() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return ref.read(profileRepositoryProvider).getProfile(user.id);
    });
  }
}
