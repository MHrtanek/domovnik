import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/profile_repository.dart';
import '../../models/profile_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

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
    return ref.read(profileRepositoryProvider).getProfile(user.id);
  }

  Future<void> updateProfile({
    String? fullName,
    String? flatNumber,
  }) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return ref.read(profileRepositoryProvider).updateProfile(
            userId: user.id,
            fullName: fullName,
            flatNumber: flatNumber,
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
