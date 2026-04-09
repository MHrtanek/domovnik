import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/poll_model.dart';
import '../../../core/constants/supabase_constants.dart';

class PollRepository {
  final SupabaseClient _client;

  PollRepository(this._client);

  Stream<List<PollModel>> getPolls(String buildingId) {
    return _client
        .from(SupabaseConstants.tablPolls)
        .stream(primaryKey: ['id'])
        .eq('building_id', buildingId)
        .order('created_at', ascending: false)
        .asyncMap((rows) async {
          final polls = <PollModel>[];
          for (final row in rows) {
            final poll = PollModel.fromJson(row);
            final enriched = await _enrichPoll(poll);
            polls.add(enriched);
          }
          return polls;
        });
  }

  Future<PollModel> _enrichPoll(PollModel poll) async {
    try {
      // Get options
      final optionsResponse = await _client
          .from(SupabaseConstants.tablPollOptions)
          .select()
          .eq('poll_id', poll.id)
          .order('id');

      final options = (optionsResponse as List<dynamic>)
          .map((o) => PollOptionModel.fromJson(o as Map<String, dynamic>))
          .toList();

      // Get vote counts per option
      final votesResponse = await _client
          .from(SupabaseConstants.tablPollVotes)
          .select('option_id')
          .eq('poll_id', poll.id);

      final votes = votesResponse as List<dynamic>;
      final voteCounts = <String, int>{};
      for (final vote in votes) {
        final optionId = (vote as Map<String, dynamic>)['option_id'] as String;
        voteCounts[optionId] = (voteCounts[optionId] ?? 0) + 1;
      }

      final enrichedOptions = options
          .map((o) => o.copyWith(voteCount: voteCounts[o.id] ?? 0))
          .toList();

      // Check if current user has voted
      final currentUserId = _client.auth.currentUser?.id;
      bool hasVoted = false;
      if (currentUserId != null) {
        final voteCheck = await _client
            .from(SupabaseConstants.tablPollVotes)
            .select('id')
            .eq('poll_id', poll.id)
            .eq('user_id', currentUserId)
            .maybeSingle();
        hasVoted = voteCheck != null;
      }

      return poll.copyWith(options: enrichedOptions, hasVoted: hasVoted);
    } catch (e) {
      debugPrint('PollRepository._enrichPoll error: $e');
      return poll;
    }
  }

  Future<PollModel> createPoll({
    required String question,
    required List<String> optionTexts,
    required String createdBy,
    required String buildingId,
    DateTime? expiresAt,
  }) async {
    try {
      final pollResponse = await _client
          .from(SupabaseConstants.tablPolls)
          .insert({
            'question': question,
            'created_by': createdBy,
            'building_id': buildingId,
            'expires_at': expiresAt?.toIso8601String(),
          })
          .select()
          .single();

      final poll = PollModel.fromJson(pollResponse);

      // Insert options
      final optionsData = optionTexts
          .map((text) => {'poll_id': poll.id, 'option_text': text})
          .toList();

      await _client
          .from(SupabaseConstants.tablPollOptions)
          .insert(optionsData);

      return await _enrichPoll(poll);
    } catch (e) {
      debugPrint('PollRepository.createPoll error: $e');
      rethrow;
    }
  }

  Future<void> vote({
    required String pollId,
    required String optionId,
    required String userId,
    required String buildingId,
  }) async {
    try {
      await _client.from(SupabaseConstants.tablPollVotes).insert({
        'poll_id': pollId,
        'option_id': optionId,
        'user_id': userId,
        'building_id': buildingId,
      });
    } catch (e) {
      debugPrint('PollRepository.vote error: $e');
      rethrow;
    }
  }

  Future<PollModel?> getPollResults(String pollId) async {
    try {
      final pollResponse = await _client
          .from(SupabaseConstants.tablPolls)
          .select()
          .eq('id', pollId)
          .maybeSingle();

      if (pollResponse == null) return null;
      final poll = PollModel.fromJson(pollResponse);
      return await _enrichPoll(poll);
    } catch (e) {
      debugPrint('PollRepository.getPollResults error: $e');
      rethrow;
    }
  }

  Future<bool> hasVoted({
    required String pollId,
    required String userId,
  }) async {
    try {
      final result = await _client
          .from(SupabaseConstants.tablPollVotes)
          .select('id')
          .eq('poll_id', pollId)
          .eq('user_id', userId)
          .maybeSingle();
      return result != null;
    } catch (e) {
      debugPrint('PollRepository.hasVoted error: $e');
      return false;
    }
  }

  Future<void> deletePoll(String pollId) async {
    try {
      // Cascade: delete votes, then options, then poll
      await _client
          .from(SupabaseConstants.tablPollVotes)
          .delete()
          .eq('poll_id', pollId);
      await _client
          .from(SupabaseConstants.tablPollOptions)
          .delete()
          .eq('poll_id', pollId);
      await _client
          .from(SupabaseConstants.tablPolls)
          .delete()
          .eq('id', pollId);
    } catch (e) {
      debugPrint('PollRepository.deletePoll error: $e');
      rethrow;
    }
  }
}
