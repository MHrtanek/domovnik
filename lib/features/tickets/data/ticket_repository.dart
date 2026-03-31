import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/ticket_model.dart';
import '../../../core/constants/supabase_constants.dart';

class TicketRepository {
  final SupabaseClient _client;
  final _uuid = const Uuid();

  TicketRepository(this._client);

  Stream<List<TicketModel>> getTickets(String buildingId) {
    return _client
        .from(SupabaseConstants.tablTickets)
        .stream(primaryKey: ['id'])
        .eq('building_id', buildingId)
        .order('created_at', ascending: false)
        .map((rows) => rows
            .map((r) => TicketModel.fromJson(r as Map<String, dynamic>))
            .toList());
  }

  Stream<List<TicketModel>> getMyTickets(String userId) {
    return _client
        .from(SupabaseConstants.tablTickets)
        .stream(primaryKey: ['id'])
        .eq('created_by', userId)
        .order('created_at', ascending: false)
        .map((rows) => rows
            .map((r) => TicketModel.fromJson(r as Map<String, dynamic>))
            .toList());
  }

  Future<TicketModel> createTicket({
    required String title,
    String? description,
    required TicketCategory category,
    required String createdBy,
    required String buildingId,
    String? photoUrl,
  }) async {
    try {
      final response = await _client
          .from(SupabaseConstants.tablTickets)
          .insert({
            'title': title,
            'description': description,
            'category': category.label,
            'created_by': createdBy,
            'building_id': buildingId,
            'photo_url': photoUrl,
          })
          .select()
          .single();

      return TicketModel.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      debugPrint('TicketRepository.createTicket error: $e');
      rethrow;
    }
  }

  Future<TicketModel> updateTicketStatus({
    required String ticketId,
    required TicketStatus status,
  }) async {
    try {
      final response = await _client
          .from(SupabaseConstants.tablTickets)
          .update({'status': status.label})
          .eq('id', ticketId)
          .select()
          .single();

      return TicketModel.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      debugPrint('TicketRepository.updateTicketStatus error: $e');
      rethrow;
    }
  }

  Future<String> uploadTicketPhoto(File file) async {
    try {
      final fileExt = file.path.split('.').last;
      final fileName = '${_uuid.v4()}.$fileExt';
      final filePath = 'tickets/$fileName';

      await _client.storage
          .from(SupabaseConstants.storageBucket)
          .upload(filePath, file);

      final url = _client.storage
          .from(SupabaseConstants.storageBucket)
          .getPublicUrl(filePath);

      return url;
    } catch (e) {
      debugPrint('TicketRepository.uploadTicketPhoto error: $e');
      rethrow;
    }
  }

  Future<TicketModel?> getTicket(String ticketId) async {
    try {
      final response = await _client
          .from(SupabaseConstants.tablTickets)
          .select()
          .eq('id', ticketId)
          .maybeSingle();

      if (response == null) return null;
      return TicketModel.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      debugPrint('TicketRepository.getTicket error: $e');
      rethrow;
    }
  }
}
