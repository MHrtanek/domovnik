import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/forum_repository.dart';
import '../../models/forum_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';

final forumRepositoryProvider = Provider<ForumRepository>((ref) {
  return ForumRepository(ref.watch(supabaseClientProvider));
});

/// Interný trigger: emituje počet odpovedí v budove.
/// Keď sa zmení (pridanie/zmazanie odpovede), forumPostsProvider
/// reštartuje stream a getPosts() re-fetchuje reply_count pre každý post.
final _forumRepliesCountProvider = StreamProvider<int>((ref) {
  final profile = ref.watch(profileProvider).valueOrNull;
  if (profile == null || profile.buildingId == null) return const Stream.empty();
  return ref.read(forumRepositoryProvider).getReplyCount(profile.buildingId!);
});

final forumPostsProvider = StreamProvider<List<ForumPostModel>>((ref) {
  final profile = ref.watch(profileProvider).valueOrNull;
  if (profile == null || profile.buildingId == null) return const Stream.empty();
  // Sleduj zmeny odpovedí aby sa reply_count aktualizoval v zozname príspevkov
  ref.watch(_forumRepliesCountProvider);
  return ref.read(forumRepositoryProvider).getPosts(profile.buildingId!);
});

final forumRepliesProvider =
    StreamProvider.family<List<ForumReplyModel>, String>((ref, postId) {
  return ref.watch(forumRepositoryProvider).getReplies(postId);
});

class CreateForumPostNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> createPost({
    required String title,
    required String content,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final profile = await ref.read(profileProvider.future);
      if (profile == null) throw Exception('Profil nie je dostupný');
      if (profile.buildingId == null) throw Exception('Nemáte priradenú budovu');

      await ref.read(forumRepositoryProvider).createPost(
            title: title,
            content: content,
            createdBy: profile.id,
            buildingId: profile.buildingId!,
          );
      await Future.delayed(const Duration(milliseconds: 500));
      ref.invalidate(forumPostsProvider);
    });
  }
}

final createForumPostProvider =
    AsyncNotifierProvider<CreateForumPostNotifier, void>(
        CreateForumPostNotifier.new);

class CreateForumReplyNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> createReply({
    required String content,
    required String postId,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final profile = await ref.read(profileProvider.future);
      if (profile == null) throw Exception('Profil nie je dostupný');
      if (profile.buildingId == null) throw Exception('Nemáte priradenú budovu');

      await ref.read(forumRepositoryProvider).createReply(
            content: content,
            postId: postId,
            createdBy: profile.id,
            buildingId: profile.buildingId!,
          );
      ref.invalidate(forumRepliesProvider(postId));
    });
  }
}

final createForumReplyProvider =
    AsyncNotifierProvider<CreateForumReplyNotifier, void>(
        CreateForumReplyNotifier.new);

final hasLikedPostProvider =
    FutureProvider.family<bool, String>((ref, postId) {
  return ref.read(forumRepositoryProvider).hasLikedPost(postId);
});

final hasLikedReplyProvider =
    FutureProvider.family<bool, String>((ref, replyId) {
  return ref.read(forumRepositoryProvider).hasLikedReply(replyId);
});

/// Celkový počet príspevkov + odpovedí v budove.
/// Sledovaný správcom v ManagerShell pre zvukové upozornenia.
final forumActivityCountProvider = Provider<int>((ref) {
  final postCount = ref.watch(forumPostsProvider).maybeWhen(
    data: (posts) => posts.length,
    orElse: () => 0,
  );
  final replyCount = ref.watch(_forumRepliesCountProvider).maybeWhen(
    data: (count) => count,
    orElse: () => 0,
  );
  return postCount + replyCount;
});
