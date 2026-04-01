import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/contact_repository.dart';
import '../../models/contact_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';

final contactRepositoryProvider = Provider<ContactRepository>((ref) {
  return ContactRepository(ref.watch(supabaseClientProvider));
});

final contactsProvider = StreamProvider<List<ContactModel>>((ref) async* {
  final profile = await ref.watch(profileProvider.future);
  if (profile?.buildingId == null) {
    yield [];
    return;
  }
  yield* ref
      .watch(contactRepositoryProvider)
      .getContacts(profile!.buildingId!);
});

// ── Create ────────────────────────────────────────────────────────────────

class CreateContactNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> createContact({
    required String name,
    required String phone,
    String? description,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final profile = await ref.read(profileProvider.future);
      if (profile == null) throw Exception('Profil nie je dostupný');
      if (profile.buildingId == null) throw Exception('Nemáte priradenú budovu');
      await ref.read(contactRepositoryProvider).createContact(
            buildingId: profile.buildingId!,
            createdBy: profile.id,
            name: name,
            phone: phone,
            description: description,
          );
    });
  }
}

final createContactProvider =
    AsyncNotifierProvider<CreateContactNotifier, void>(CreateContactNotifier.new);

// ── Update ────────────────────────────────────────────────────────────────

class UpdateContactNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> updateContact({
    required String id,
    required String name,
    required String phone,
    String? description,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(contactRepositoryProvider).updateContact(
            id: id,
            name: name,
            phone: phone,
            description: description,
          );
    });
  }
}

final updateContactProvider =
    AsyncNotifierProvider<UpdateContactNotifier, void>(UpdateContactNotifier.new);

// ── Delete ────────────────────────────────────────────────────────────────

class DeleteContactNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> deleteContact(String id) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(contactRepositoryProvider).deleteContact(id);
    });
  }
}

final deleteContactProvider =
    AsyncNotifierProvider<DeleteContactNotifier, void>(DeleteContactNotifier.new);
