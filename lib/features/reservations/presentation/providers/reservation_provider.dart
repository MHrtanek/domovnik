import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/reservation_repository.dart';
import '../../models/reservation_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';

final reservationRepositoryProvider = Provider<ReservationRepository>((ref) {
  return ReservationRepository(ref.watch(supabaseClientProvider));
});

final amenitiesProvider = StreamProvider<List<AmenityModel>>((ref) async* {
  final profile = await ref.watch(profileProvider.future);
  if (profile == null || profile.buildingId == null) {
    yield [];
    return;
  }
  yield* ref
      .watch(reservationRepositoryProvider)
      .getAmenities(profile.buildingId!);
});

final allReservationsProvider =
    StreamProvider<List<ReservationModel>>((ref) async* {
  final profile = await ref.watch(profileProvider.future);
  if (profile == null || profile.buildingId == null) {
    yield [];
    return;
  }
  if (profile.isManager) {
    yield* ref
        .watch(reservationRepositoryProvider)
        .getReservations(profile.buildingId!);
  } else {
    yield* ref
        .watch(reservationRepositoryProvider)
        .getMyReservations(profile.id);
  }
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
