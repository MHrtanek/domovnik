import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
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

  /// Uploads a ticket photo and returns its public URL.
  /// Accepts [XFile] + pre-loaded [bytes] so it works on both web and mobile.
  Future<String> uploadTicketPhoto(XFile xfile, Uint8List bytes) async {
    try {
      final ext = xfile.name.contains('.')
          ? xfile.name.split('.').last.toLowerCase()
          : 'jpg';
      final fileName = '${_uuid.v4()}.$ext';
      final filePath = 'tickets/$fileName';
      final mimeType = xfile.mimeType ?? 'image/jpeg';

      if (kIsWeb) {
        // On web, upload via bytes
        await _client.storage
            .from(SupabaseConstants.storageBucket)
            .uploadBinary(
              filePath,
              bytes,
              fileOptions: FileOptions(contentType: mimeType),
            );
      } else {
        // On mobile, upload via File (more efficient for large files)
        await _client.storage
            .from(SupabaseConstants.storageBucket)
            .upload(
              filePath,
              File(xfile.path),
              fileOptions: FileOptions(contentType: mimeType),
            );
      }

      return _client.storage
          .from(SupabaseConstants.storageBucket)
          .getPublicUrl(filePath);
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
