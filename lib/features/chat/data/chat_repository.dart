import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/message_model.dart';
import '../../../core/services/notification_service.dart';

class ChatRepository {
  final SupabaseClient _client;

  ChatRepository(this._client);

  /// Real-time stream správ medzi dvoma používateľmi v budove.
  /// Používa dva odddelené streamy (podľa sender_id) kombinované cez rxdart,
  /// pretože Supabase .stream() nepodporuje OR filtre.
  Stream<List<MessageModel>> getMessages({
    required String buildingId,
    required String currentUserId,
    required String otherUserId,
  }) {
    // Správy odoslané mnou druhému používateľovi
    final sentStream = _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('sender_id', currentUserId)
        .order('created_at', ascending: true)
        .map((rows) => rows
            .where((r) =>
                r['receiver_id'] == otherUserId &&
                r['building_id'] == buildingId)
            .map((r) => MessageModel.fromJson(r))
            .toList());

    // Správy odoslané druhým používateľom mne
    final receivedStream = _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('sender_id', otherUserId)
        .order('created_at', ascending: true)
        .map((rows) => rows
            .where((r) =>
                r['receiver_id'] == currentUserId &&
                r['building_id'] == buildingId)
            .map((r) => MessageModel.fromJson(r))
            .toList());

    return Rx.combineLatest2(sentStream, receivedStream, (sent, received) {
      final all = [...sent, ...received];
      final seen = <String>{};
      final unique = all.where((m) => seen.add(m.id)).toList();
      unique.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return unique;
    });
  }

  Future<void> sendMessage({
    required String buildingId,
    required String senderId,
    required String receiverId,
    required String content,
  }) async {
    debugPrint(
      'ChatRepository.sendMessage → '
      'buildingId=$buildingId | senderId=$senderId | receiverId=$receiverId | '
      'contentLen=${content.length}',
    );
    try {
      await _client.from('messages').insert({
        'building_id': buildingId,
        'sender_id': senderId,
        'receiver_id': receiverId,
        'content': content,
        'read': false,
      });
      debugPrint('ChatRepository.sendMessage → SUCCESS');
      NotificationService.sendToUser(
        targetUserId: receiverId,
        title: '💬 Nová správa',
        body: content.length > 100 ? '${content.substring(0, 100)}…' : content,
      );
    } catch (e) {
      debugPrint('ChatRepository.sendMessage → ERROR: $e');
      rethrow;
    }
  }

  /// Označí všetky neprečítané správy od [senderId] pre [receiverId] ako prečítané.
  Future<void> markAsRead({
    required String buildingId,
    required String senderId,
    required String receiverId,
  }) async {
    try {
      await _client
          .from('messages')
          .update({'read': true})
          .eq('building_id', buildingId)
          .eq('sender_id', senderId)
          .eq('receiver_id', receiverId)
          .eq('read', false);
    } catch (e) {
      debugPrint('ChatRepository.markAsRead error: $e');
    }
  }

  Future<int> getUnreadCount({
    required String buildingId,
    required String senderId,
    required String receiverId,
  }) async {
    try {
      final result = await _client
          .from('messages')
          .select('id')
          .eq('building_id', buildingId)
          .eq('sender_id', senderId)
          .eq('receiver_id', receiverId)
          .eq('read', false);
      return result.length;
    } catch (e) {
      debugPrint('ChatRepository.getUnreadCount error: $e');
      return 0;
    }
  }

  /// Stream správ pre aktuálneho používateľa (odoslané + prijaté) –
  /// slúži na triggering refresh konverzácií.
  Stream<int> watchBuildingMessageCount({
    required String buildingId,
    required String userId,
  }) {
    final sentStream = _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('sender_id', userId)
        .map((rows) =>
            rows.where((r) => r['building_id'] == buildingId).length);

    final receivedStream = _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('receiver_id', userId)
        .map((rows) => rows.length);

    return Rx.combineLatest2(sentStream, receivedStream, (s, r) => s + r);
  }

  Future<MessageModel?> getLastMessage({
    required String buildingId,
    required String userId1,
    required String userId2,
  }) async {
    try {
      final result = await _client
          .from('messages')
          .select()
          .eq('building_id', buildingId)
          .or('and(sender_id.eq.$userId1,receiver_id.eq.$userId2),'
              'and(sender_id.eq.$userId2,receiver_id.eq.$userId1)')
          .order('created_at', ascending: false)
          .limit(1);
      if (result.isEmpty) return null;
      return MessageModel.fromJson(result.first);
    } catch (e) {
      debugPrint('ChatRepository.getLastMessage error: $e');
      return null;
    }
  }
}
