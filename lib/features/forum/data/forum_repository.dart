import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/forum_model.dart';

class ForumRepository {
  final SupabaseClient _client;

  ForumRepository(this._client);

  Stream<List<ForumPostModel>> getPosts(String buildingId) {
    return _client
        .from('forum_posts')
        .stream(primaryKey: ['id'])
        .eq('building_id', buildingId)
        .order('created_at', ascending: false)
        .asyncMap((rows) async {
          final posts = <ForumPostModel>[];
          for (final r in rows) {
            final map = Map<String, dynamic>.from(r as Map);
            try {
              final profile = await _client
                  .from('profiles')
                  .select('full_name, email')
                  .eq('id', map['created_by'] as String)
                  .maybeSingle();
              if (profile != null) {
                map['profiles'] = {
                  'full_name': (profile['full_name'] as String?)?.isNotEmpty == true
                      ? profile['full_name']
                      : profile['email'],
                };
              }
              final replyCount = await _client
                  .from('forum_replies')
                  .select('id')
                  .eq('post_id', map['id'] as String);
              map['reply_count'] = (replyCount as List).length;
            } catch (e) {
              debugPrint('ForumRepository.getPosts profile fetch error: $e');
            }
            posts.add(ForumPostModel.fromJson(map));
          }
          return posts;
        });
  }

  /// Stream počtu odpovedí v budove – slúži na triggering refresh reply_count
  /// v getPosts keď sa pridá alebo zmaže odpoveď.
  Stream<int> getReplyCount(String buildingId) {
    return _client
        .from('forum_replies')
        .stream(primaryKey: ['id'])
        .eq('building_id', buildingId)
        .map((rows) => rows.length);
  }

  Stream<List<ForumReplyModel>> getReplies(String postId) {
    return _client
        .from('forum_replies')
        .stream(primaryKey: ['id'])
        .eq('post_id', postId)
        .order('created_at', ascending: true)
        .asyncMap((rows) async {
          final replies = <ForumReplyModel>[];
          for (final r in rows) {
            final map = Map<String, dynamic>.from(r as Map);
            try {
              final profile = await _client
                  .from('profiles')
                  .select('full_name, email')
                  .eq('id', map['created_by'] as String)
                  .maybeSingle();
              if (profile != null) {
                map['profiles'] = {
                  'full_name': (profile['full_name'] as String?)?.isNotEmpty == true
                      ? profile['full_name']
                      : profile['email'],
                };
              }
            } catch (e) {
              debugPrint('ForumRepository.getReplies profile fetch error: $e');
            }
            replies.add(ForumReplyModel.fromJson(map));
          }
          return replies;
        });
  }

  Future<ForumPostModel> createPost({
    required String title,
    required String content,
    required String createdBy,
    required String buildingId,
  }) async {
    try {
      final response = await _client
          .from('forum_posts')
          .insert({
            'title': title,
            'content': content,
            'created_by': createdBy,
            'building_id': buildingId,
          })
          .select()
          .single();
      return ForumPostModel.fromJson(response);
    } catch (e) {
      debugPrint('ForumRepository.createPost error: $e');
      rethrow;
    }
  }

  Future<void> createReply({
    required String content,
    required String postId,
    required String createdBy,
    required String buildingId,
  }) async {
    try {
      await _client.from('forum_replies').insert({
        'content': content,
        'post_id': postId,
        'created_by': createdBy,
        'building_id': buildingId,
      });
    } catch (e) {
      debugPrint('ForumRepository.createReply error: $e');
      rethrow;
    }
  }

  Future<void> updatePost({
    required String id,
    required String title,
    required String content,
  }) async {
    try {
      await _client.from('forum_posts').update({
        'title': title,
        'content': content,
      }).eq('id', id);
    } catch (e) {
      debugPrint('ForumRepository.updatePost error: $e');
      rethrow;
    }
  }

  Future<void> deletePost(String postId) async {
    try {
      await _client.from('forum_posts').delete().eq('id', postId);
    } catch (e) {
      debugPrint('ForumRepository.deletePost error: $e');
      rethrow;
    }
  }

  Future<void> updateReply({
    required String id,
    required String content,
  }) async {
    try {
      await _client.from('forum_replies').update({'content': content}).eq('id', id);
    } catch (e) {
      debugPrint('ForumRepository.updateReply error: $e');
      rethrow;
    }
  }

  Future<void> deleteReply(String replyId) async {
    try {
      await _client.from('forum_replies').delete().eq('id', replyId);
    } catch (e) {
      debugPrint('ForumRepository.deleteReply error: $e');
      rethrow;
    }
  }

  Future<void> incrementPostLikes(String id, int currentLikes) async {
    try {
      await _client
          .from('forum_posts')
          .update({'likes_count': currentLikes + 1})
          .eq('id', id);
    } catch (e) {
      debugPrint('ForumRepository.incrementPostLikes error: $e');
      rethrow;
    }
  }

  Future<void> incrementReplyLikes(String id, int currentLikes) async {
    try {
      await _client
          .from('forum_replies')
          .update({'likes_count': currentLikes + 1})
          .eq('id', id);
    } catch (e) {
      debugPrint('ForumRepository.incrementReplyLikes error: $e');
      rethrow;
    }
  }
}
