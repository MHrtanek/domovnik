import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/reservation_repository.dart';
import '../../models/reservation_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';

final reservationRepositoryProvider = Provider<ReservationRepository>((ref) {
  return ReservationRepository(ref.watch(supabaseClientProvider));
});

final amenitiesProvider = StreamProvider<List<AmenityModel>>((ref) {
  final profile = ref.watch(profileProvider).valueOrNull;
  if (profile == null || profile.buildingId == null) return const Stream.empty();
  return ref.read(reservationRepositoryProvider).getAmenities(profile.buildingId!);
});

final allReservationsProvider = StreamProvider<List<ReservationModel>>((ref) {
  final profile = ref.watch(profileProvider).valueOrNull;
  if (profile == null || profile.buildingId == null) return const Stream.empty();
  if (profile.isManager) {
    return ref.read(reservationRepositoryProvider).getReservations(profile.buildingId!);
  }
  return ref.read(reservationRepositoryProvider).getMyReservations(profile.id);
});

class CreateReservationNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> createReservation({
    required String amenityId,
    required DateTime date,
    required String timeFrom,
    required String timeTo,
    String? note,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final profile = await ref.read(profileProvider.future);
      if (profile == null) throw Exception('Profil nie je dostupný');
      if (profile.buildingId == null) throw Exception('Nemáte priradenú budovu');

      await ref.read(reservationRepositoryProvider).createReservation(
            amenityId: amenityId,
            buildingId: profile.buildingId!,
            residentId: profile.id,
            date: date,
            timeFrom: timeFrom,
            timeTo: timeTo,
            note: note,
          );
      ref.invalidate(allReservationsProvider);
    });
  }
}

final createReservationProvider =
    AsyncNotifierProvider<CreateReservationNotifier, void>(
        CreateReservationNotifier.new);
