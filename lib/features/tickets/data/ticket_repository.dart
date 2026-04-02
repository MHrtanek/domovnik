import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
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
        .map((rows) async {
          final List<TicketModel> tickets = [];
          for (final r in rows) {
            final map = r as Map<String, dynamic>;
            // Fetch author name separately
            try {
              final profile = await _client
                  .from('profiles')
                  .select('full_name')
                  .eq('id', map['created_by'] as String)
                  .maybeSingle();
              map['profiles'] = profile;
            } catch (_) {}
            tickets.add(TicketModel.fromJson(map));
          }
          return tickets;
        })
        .asyncMap((future) => future);
  }

  Stream<List<TicketModel>> getMyTickets(String userId) {
    return _client
        .from(SupabaseConstants.tablTickets)
        .stream(primaryKey: ['id'])
        .eq('created_by', userId)
        .order('created_at', ascending: false)
        .map((rows) async {
          final List<TicketModel> tickets = [];
          for (final r in rows) {
            final map = r as Map<String, dynamic>;
            try {
              final profile = await _client
                  .from('profiles')
                  .select('full_name')
                  .eq('id', map['created_by'] as String)
                  .maybeSingle();
              map['profiles'] = profile;
            } catch (_) {}
            tickets.add(TicketModel.fromJson(map));
          }
          return tickets;
        })
        .asyncMap((future) => future);
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

  Future<String> uploadTicketPhoto(XFile xfile, Uint8List bytes) async {
    try {
      final mimeType = xfile.mimeType ?? _mimeFromBytes(bytes);
      final ext = _extFromMime(mimeType);
      final fileName = '${_uuid.v4()}.$ext';
      const bucket = SupabaseConstants.storageBucket;
      final filePath = 'tickets/$fileName';

      await _client.storage
          .from(bucket)
          .uploadBinary(
            filePath,
            bytes,
            fileOptions: FileOptions(contentType: mimeType),
          );

      final supabaseUrl = (dotenv.env['SUPABASE_URL'] ?? '').replaceAll(RegExp(r'/$'), '');
      final url = '$supabaseUrl/storage/v1/object/public/$bucket/$filePath';
      return url;
    } catch (e) {
      debugPrint('TicketRepository.uploadTicketPhoto error: $e');
      rethrow;
    }
  }

  String _mimeFromBytes(Uint8List bytes) {
    if (bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) return 'image/jpeg';
    if (bytes.length >= 8 && bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) return 'image/png';
    if (bytes.length >= 6 && bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) return 'image/gif';
    if (bytes.length >= 4 && bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46) return 'image/webp';
    return 'image/jpeg';
  }

  String _extFromMime(String mime) {
    switch (mime) {
      case 'image/png':  return 'png';
      case 'image/gif':  return 'gif';
      case 'image/webp': return 'webp';
      default:           return 'jpg';
    }
  }

  Future<TicketModel?> getTicket(String ticketId) async {
    try {
      final response = await _client
          .from(SupabaseConstants.tablTickets)
          .select('*, profiles(full_name)')
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
