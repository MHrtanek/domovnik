import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/ticket_repository.dart';
import '../../models/ticket_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/models/profile_model.dart';
import '../../../profile/presentation/providers/profile_provider.dart';

final ticketRepositoryProvider = Provider<TicketRepository>((ref) {
  return TicketRepository(ref.watch(supabaseClientProvider));
});

final buildingTicketsProvider =
    StreamProvider.family<List<TicketModel>, String>((ref, buildingId) {
  return ref.watch(ticketRepositoryProvider).getTickets(buildingId);
});

final myTicketsProvider =
    StreamProvider.family<List<TicketModel>, String>((ref, userId) {
  return ref.watch(ticketRepositoryProvider).getMyTickets(userId);
});

final ticketsProvider = StreamProvider<List<TicketModel>>((ref) {
  final profile = ref.watch(profileProvider).valueOrNull;
  if (profile == null) return const Stream.empty();
  if (profile.isManager && profile.buildingId != null) {
    return ref.read(ticketRepositoryProvider).getTickets(profile.buildingId!);
  }
  if (profile.isSupplier) {
    return ref.read(ticketRepositoryProvider).getSupplierTickets(profile.id);
  }
  return ref.read(ticketRepositoryProvider).getMyTickets(profile.id);
});

final buildingDodavatelProfilesProvider =
    FutureProvider.family<List<ProfileModel>, String>((ref, buildingId) {
  return ref.read(profileRepositoryProvider).getDodavatelProfiles(buildingId);
});

enum TicketFilterStatus { all, prijate, vRieseni, ukoncene }

final ticketFilterProvider =
    StateProvider<TicketFilterStatus>((ref) => TicketFilterStatus.all);

final filteredTicketsProvider = Provider<AsyncValue<List<TicketModel>>>((ref) {
  final tickets = ref.watch(ticketsProvider);
  final filter = ref.watch(ticketFilterProvider);

  return tickets.when(
    data: (list) {
      if (filter == TicketFilterStatus.all) return AsyncData(list);
      final statusMap = {
        TicketFilterStatus.prijate: TicketStatus.prijate,
        TicketFilterStatus.vRieseni: TicketStatus.vRieseni,
        TicketFilterStatus.ukoncene: TicketStatus.ukoncene,
      };
      return AsyncData(list.where((t) => t.status == statusMap[filter]).toList());
    },
    loading: () => const AsyncLoading(),
    error: (e, st) => AsyncError(e, st),
  );
});

class CreateTicketNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> createTicket({
    required String title,
    String? description,
    required TicketCategory category,
    // Nové: viacero fotiek
    List<XFile>? photos,
    List<Uint8List>? photosBytes,
    // Legacy (zachovaná kompatibilita)
    XFile? photoFile,
    Uint8List? photoBytes,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final profile = await ref.read(profileProvider.future);
      if (profile == null) throw Exception('Profil nie je dostupný');
      if (profile.buildingId == null) throw Exception('Nemáte priradenú budovu');

      final repo = ref.read(ticketRepositoryProvider);

      // Vytvor tiket (bez fotky - pridáme cez ticket_photos)
      final ticket = await repo.createTicket(
        title: title,
        description: description,
        category: category,
        createdBy: profile.id,
        buildingId: profile.buildingId!,
      );

      // Nahraj viacero fotiek
      final allPhotos = photos ?? (photoFile != null ? [photoFile] : []);
      final allBytes = photosBytes ?? (photoBytes != null ? [photoBytes] : []);

      for (int i = 0; i < allPhotos.length && i < allBytes.length; i++) {
        try {
          final url = await repo.uploadTicketPhoto(allPhotos[i], allBytes[i]);
          await repo.addTicketPhoto(ticket.id, url);
        } catch (e) {
          debugPrint('Failed to upload photo $i: $e');
        }
      }
    });
  }
}

final createTicketProvider =
    AsyncNotifierProvider<CreateTicketNotifier, void>(CreateTicketNotifier.new);

class UpdateTicketStatusNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> updateStatus(String ticketId, TicketStatus status) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(ticketRepositoryProvider)
          .updateTicketStatus(ticketId: ticketId, status: status);
      ref.invalidate(ticketDetailProvider(ticketId));
      ref.invalidate(ticketsProvider);
    });
  }
}

final updateTicketStatusProvider =
    AsyncNotifierProvider<UpdateTicketStatusNotifier, void>(
        UpdateTicketStatusNotifier.new);

final ticketDetailProvider =
    FutureProvider.family<TicketModel?, String>((ref, ticketId) async {
  return ref.read(ticketRepositoryProvider).getTicket(ticketId);
});

class AssignSupplierNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> assignSupplier(String ticketId, String? supplierId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(ticketRepositoryProvider).assignSupplier(
        ticketId: ticketId,
        supplierId: supplierId,
      );
      ref.invalidate(ticketDetailProvider(ticketId));
      ref.invalidate(ticketsProvider);
    });
  }
}

final assignSupplierProvider =
    AsyncNotifierProvider<AssignSupplierNotifier, void>(AssignSupplierNotifier.new);
