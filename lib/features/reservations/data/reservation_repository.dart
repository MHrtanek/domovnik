import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/reservation_model.dart';

class ReservationRepository {
  final SupabaseClient _client;

  ReservationRepository(this._client);

  Stream<List<AmenityModel>> getAmenities(String buildingId) {
    return _client
        .from('amenities')
        .stream(primaryKey: ['id'])
        .eq('building_id', buildingId)
        .order('name', ascending: true)
        .map((rows) {
          final seen = <String>{};
          return rows
              .map((r) => AmenityModel.fromJson(r as Map<String, dynamic>))
              .where((a) => a.isActive && seen.add(a.id))
              .toList();
        });
  }

  Stream<List<ReservationModel>> getReservations(String buildingId) {
    return _client
        .from('reservations')
        .stream(primaryKey: ['id'])
        .eq('building_id', buildingId)
        .order('date', ascending: true)
        .asyncMap((rows) async {
          final seen = <String>{};
          final result = <ReservationModel>[];
          for (final r in rows) {
            final map = Map<String, dynamic>.from(r as Map);
            final id = map['id'] as String;
            if (!seen.add(id)) continue;
            try {
              final profile = await _client
                  .from('profiles')
                  .select('full_name')
                  .eq('id', map['resident_id'] as String)
                  .maybeSingle();
              map['profiles'] = profile;
              final amenity = await _client
                  .from('amenities')
                  .select('name')
                  .eq('id', map['amenity_id'] as String)
                  .maybeSingle();
              map['amenity_name'] = amenity?['name'] ?? '';
            } catch (_) {}
            result.add(ReservationModel.fromJson(map));
          }
          return result;
        });
  }

  Stream<List<ReservationModel>> getMyReservations(String residentId) {
    return _client
        .from('reservations')
        .stream(primaryKey: ['id'])
        .eq('resident_id', residentId)
        .order('date', ascending: true)
        .asyncMap((rows) async {
          final seen = <String>{};
          final result = <ReservationModel>[];
          for (final r in rows) {
            final map = Map<String, dynamic>.from(r as Map);
            final id = map['id'] as String;
            if (!seen.add(id)) continue;
            try {
              final amenity = await _client
                  .from('amenities')
                  .select('name')
                  .eq('id', map['amenity_id'] as String)
                  .maybeSingle();
              map['amenity_name'] = amenity?['name'] ?? '';
            } catch (_) {}
            result.add(ReservationModel.fromJson(map));
          }
          return result;
        });
  }

  Future<void> createAmenity({
    required String name,
    String? description,
    required String buildingId,
  }) async {
    try {
      await _client.from('amenities').insert({
        'name': name,
        'description': description,
        'building_id': buildingId,
      });
    } catch (e) {
      debugPrint('ReservationRepository.createAmenity error: $e');
      rethrow;
    }
  }

  Future<void> deleteAmenity(String amenityId) async {
    try {
      await _client.from('amenities').delete().eq('id', amenityId);
    } catch (e) {
      debugPrint('ReservationRepository.deleteAmenity error: $e');
      rethrow;
    }
  }

  Future<void> createReservation({
    required String amenityId,
    required String buildingId,
    required String residentId,
    required DateTime date,
    required String timeFrom,
    required String timeTo,
    String? note,
  }) async {
    try {
      final dateStr = date.toIso8601String().split('T')[0];

      // Skontroluj či čas nie je obsadený
      final existing = await _client
          .from('reservations')
          .select('id')
          .eq('amenity_id', amenityId)
          .eq('date', dateStr)
          .eq('time_from', timeFrom)
          .maybeSingle();

      if (existing != null) {
        throw Exception('Tento čas je už obsadený');
      }

      await _client.from('reservations').insert({
        'amenity_id': amenityId,
        'building_id': buildingId,
        'resident_id': residentId,
        'date': dateStr,
        'time_from': timeFrom,
        'time_to': timeTo,
        'note': note,
      });
    } catch (e) {
      debugPrint('ReservationRepository.createReservation error: $e');
      rethrow;
    }
  }

  Future<void> deleteReservation(String reservationId) async {
    try {
      await _client.from('reservations').delete().eq('id', reservationId);
    } catch (e) {
      debugPrint('ReservationRepository.deleteReservation error: $e');
      rethrow;
    }
  }

  Future<List<ReservationModel>> getReservationsForAmenityAndDate({
    required String amenityId,
    required DateTime date,
  }) async {
    try {
      final dateStr = date.toIso8601String().split('T')[0];
      final rows = await _client
          .from('reservations')
          .select()
          .eq('amenity_id', amenityId)
          .eq('date', dateStr);

      final seen = <String>{};
      return (rows as List)
          .where((r) => seen.add((r as Map)['id'] as String))
          .map((r) => ReservationModel.fromJson({
                ...r as Map<String, dynamic>,
                'amenity_name': '',
              }))
          .toList();
    } catch (e) {
      debugPrint('ReservationRepository.getReservationsForAmenityAndDate error: $e');
      rethrow;
    }
  }
}
