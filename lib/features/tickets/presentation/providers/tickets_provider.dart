import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/ticket_repository.dart';
import '../../models/ticket_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';

final ticketRepositoryProvider = Provider<TicketRepository>((ref) {
  return TicketRepository(ref.watch(supabaseClientProvider));
});

// Stream of all tickets for the building (manager view)
final buildingTicketsProvider =
    StreamProvider.family<List<TicketModel>, String>((ref, buildingId) {
  return ref.watch(ticketRepositoryProvider).getTickets(buildingId);
});

// Stream of current user's tickets (resident view)
final myTicketsProvider =
    StreamProvider.family<List<TicketModel>, String>((ref, userId) {
  return ref.watch(ticketRepositoryProvider).getMyTickets(userId);
});

// Unified tickets provider that picks the right stream based on role
final ticketsProvider = StreamProvider<List<TicketModel>>((ref) async* {
  final profile = await ref.watch(profileProvider.future);
  if (profile == null) {
    yield [];
    return;
  }

  if (profile.isManager && profile.buildingId != null) {
    yield* ref
        .watch(ticketRepositoryProvider)
        .getTickets(profile.buildingId!);
  } else {
    yield* ref
        .watch(ticketRepositoryProvider)
        .getMyTickets(profile.id);
  }
});

// Filter state
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
      final filtered =
          list.where((t) => t.status == statusMap[filter]).toList();
      return AsyncData(filtered);
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
    File? photoFile,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final profile = await ref.read(profileProvider.future);
      if (profile == null) throw Exception('Profil nie je dostupný');
      if (profile.buildingId == null) throw Exception('Nemáte priradenú budovu');

      final repo = ref.read(ticketRepositoryProvider);
      String? photoUrl;

      if (photoFile != null) {
        photoUrl = await repo.uploadTicketPhoto(photoFile);
      }

      await repo.createTicket(
        title: title,
        description: description,
        category: category,
        createdBy: profile.id,
        buildingId: profile.buildingId!,
        photoUrl: photoUrl,
      );
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
    });
  }
}

final updateTicketStatusProvider =
    AsyncNotifierProvider<UpdateTicketStatusNotifier, void>(
        UpdateTicketStatusNotifier.new);
