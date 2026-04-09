import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/announcement_repository.dart';
import '../../models/announcement_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';

final announcementRepositoryProvider = Provider<AnnouncementRepository>((ref) {
  return AnnouncementRepository(ref.watch(supabaseClientProvider));
});

final announcementsProvider =
    StreamProvider.family<List<AnnouncementModel>, String>((ref, buildingId) {
  return ref.watch(announcementRepositoryProvider).getAnnouncements(buildingId);
});

final buildingAnnouncementsProvider =
    StreamProvider<List<AnnouncementModel>>((ref) {
  final profile = ref.watch(profileProvider).valueOrNull;
  if (profile?.buildingId == null) return const Stream.empty();
  return ref.read(announcementRepositoryProvider).getAnnouncements(profile!.buildingId!);
});

class CreateAnnouncementNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> createAnnouncement({
    required String title,
    required String content,
    required bool isUrgent,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final profile = await ref.read(profileProvider.future);
      if (profile == null) throw Exception('Profil nie je dostupný');
      if (profile.buildingId == null) throw Exception('Nemáte priradenú budovu');

      await ref.read(announcementRepositoryProvider).createAnnouncement(
            title: title,
            content: content,
            isUrgent: isUrgent,
            createdBy: profile.id,
            buildingId: profile.buildingId!,
          );
    });
  }

  Future<void> deleteAnnouncement(String id) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(announcementRepositoryProvider).deleteAnnouncement(id);
    });
  }
}

final createAnnouncementProvider =
    AsyncNotifierProvider<CreateAnnouncementNotifier, void>(
        CreateAnnouncementNotifier.new);
