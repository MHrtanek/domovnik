import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../features/profile/models/profile_model.dart';
import '../../../../features/profile/presentation/providers/profile_provider.dart';
import '../../data/chat_repository.dart';
import '../../models/message_model.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(ref.watch(supabaseClientProvider));
});

// ── Správy ───────────────────────────────────────────────────────────────────

final chatMessagesProvider =
    StreamProvider.family<List<MessageModel>, String>((ref, otherUserId) {
  final profile = ref.watch(profileProvider).valueOrNull;
  if (profile == null || profile.buildingId == null) {
    return const Stream.empty();
  }
  return ref.read(chatRepositoryProvider).getMessages(
    buildingId: profile.buildingId!,
    currentUserId: profile.id,
    otherUserId: otherUserId,
  );
});

// ── Profil druhého používateľa (pre header chatu) ────────────────────────────

final chatUserProfileProvider =
    FutureProvider.family<ProfileModel?, String>((ref, userId) {
  return ref.read(profileRepositoryProvider).getProfile(userId);
});

// ── Odoslanie správy ─────────────────────────────────────────────────────────

class SendMessageNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> send({
    required String receiverId,
    required String content,
  }) async {
    state = const AsyncLoading();
    try {
      final profile = await ref.read(profileProvider.future);
      if (profile == null || profile.buildingId == null) {
        throw Exception('Profil nie je dostupný');
      }
      await ref.read(chatRepositoryProvider).sendMessage(
        buildingId: profile.buildingId!,
        senderId: profile.id,
        receiverId: receiverId,
        content: content,
      );
      state = const AsyncData(null);
    } catch (e, s) {
      state = AsyncError(e, s);
      rethrow; // surfaced in _send() → SnackBar
    }
  }
}

final sendMessageProvider =
    AsyncNotifierProvider<SendMessageNotifier, void>(SendMessageNotifier.new);

// ── Stream zmien správ v budove (trigger pre refresh konverzácií) ────────────

final _buildingMessageCountProvider = StreamProvider<int>((ref) {
  final profile = ref.watch(profileProvider).valueOrNull;
  if (profile == null || profile.buildingId == null) return const Stream.empty();
  return ref.read(chatRepositoryProvider).watchBuildingMessageCount(
    buildingId: profile.buildingId!,
    userId: profile.id,
  );
});

// ── Zoznam konverzácií ───────────────────────────────────────────────────────

class ConversationEntry {
  final ProfileModel profile;
  final int unreadCount;
  final MessageModel? lastMessage;

  const ConversationEntry({
    required this.profile,
    required this.unreadCount,
    this.lastMessage,
  });
}

final conversationsProvider = StreamProvider<List<ConversationEntry>>((ref) {
  final profile = ref.watch(profileProvider).valueOrNull;
  if (profile == null || profile.buildingId == null) return const Stream.empty();

  final buildingId = profile.buildingId!;
  final chatRepo   = ref.read(chatRepositoryProvider);
  final profileRepo = ref.read(profileRepositoryProvider);

  // Realtime stream všetkých správ v budove – trigger pre prepočet konverzácií
  final trigger = ref
      .read(supabaseClientProvider)
      .from('messages')
      .stream(primaryKey: ['id'])
      .eq('building_id', buildingId)
      .map((rows) => rows.length);

  return trigger.asyncMap((_) async {
    final List<ProfileModel> contacts;
    if (profile.isManager) {
      contacts = await profileRepo.getResidents(buildingId);
    } else {
      final manager = await profileRepo.getManagerForBuilding(buildingId);
      contacts = manager != null ? [manager] : [];
    }

    final entries = <ConversationEntry>[];
    for (final contact in contacts) {
      final unread = await chatRepo.getUnreadCount(
        buildingId: buildingId,
        senderId: contact.id,
        receiverId: profile.id,
      );
      final lastMsg = await chatRepo.getLastMessage(
        buildingId: buildingId,
        userId1: profile.id,
        userId2: contact.id,
      );
      entries.add(ConversationEntry(
        profile: contact,
        unreadCount: unread,
        lastMessage: lastMsg,
      ));
    }

    // Zoraď: najnovšia konverzácia hore, potom abecedne
    entries.sort((a, b) {
      if (a.lastMessage == null && b.lastMessage == null) {
        return (a.profile.fullName ?? '').compareTo(b.profile.fullName ?? '');
      }
      if (a.lastMessage == null) return 1;
      if (b.lastMessage == null) return -1;
      return b.lastMessage!.createdAt.compareTo(a.lastMessage!.createdAt);
    });

    return entries;
  });
});
