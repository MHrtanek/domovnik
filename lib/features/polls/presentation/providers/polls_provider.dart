import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/poll_repository.dart';
import '../../models/poll_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';

final pollRepositoryProvider = Provider<PollRepository>((ref) {
  return PollRepository(ref.watch(supabaseClientProvider));
});

final pollsProvider = StreamProvider<List<PollModel>>((ref) async* {
  final profile = await ref.watch(profileProvider.future);
  if (profile?.buildingId == null) {
    yield [];
    return;
  }
  yield* ref
      .watch(pollRepositoryProvider)
      .getPolls(profile!.buildingId!);
});

final pollDetailProvider =
    FutureProvider.family<PollModel?, String>((ref, pollId) async {
  return ref.watch(pollRepositoryProvider).getPollResults(pollId);
});

class CreatePollNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> createPoll({
    required String question,
    required List<String> options,
    DateTime? expiresAt,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final profile = await ref.read(profileProvider.future);
      if (profile == null) throw Exception('Profil nie je dostupný');
      if (profile.buildingId == null) throw Exception('Nemáte priradenú budovu');

      await ref.read(pollRepositoryProvider).createPoll(
            question: question,
            optionTexts: options,
            createdBy: profile.id,
            buildingId: profile.buildingId!,
            expiresAt: expiresAt,
          );
    });
  }
}

final createPollProvider =
    AsyncNotifierProvider<CreatePollNotifier, void>(CreatePollNotifier.new);

class VoteNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> vote({
    required String pollId,
    required String optionId,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final profile = await ref.read(profileProvider.future);
      if (profile == null) throw Exception('Profil nie je dostupný');
      if (profile.buildingId == null) throw Exception('Nemáte priradenú budovu');

      await ref.read(pollRepositoryProvider).vote(
            pollId: pollId,
            optionId: optionId,
            userId: profile.id,
            buildingId: profile.buildingId!,
          );

      // Refresh poll detail
      ref.invalidate(pollDetailProvider(pollId));
      ref.invalidate(pollsProvider);
    });
  }
}

final voteProvider =
    AsyncNotifierProvider<VoteNotifier, void>(VoteNotifier.new);
