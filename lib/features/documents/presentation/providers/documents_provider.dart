import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/document_repository.dart';
import '../../models/document_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';

final documentRepositoryProvider = Provider<DocumentRepository>((ref) {
  return DocumentRepository(ref.watch(supabaseClientProvider));
});

final documentsProvider = StreamProvider<List<DocumentModel>>((ref) async* {
  final profile = await ref.watch(profileProvider.future);
  if (profile?.buildingId == null) {
    yield [];
    return;
  }
  yield* ref
      .watch(documentRepositoryProvider)
      .getDocuments(profile!.buildingId!);
});

// ── Upload ────────────────────────────────────────────────────────────────

class UploadDocumentNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> upload({
    required String name,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final profile = await ref.read(profileProvider.future);
      if (profile == null) throw Exception('Profil nie je dostupný');
      if (profile.buildingId == null) throw Exception('Nemáte priradenú budovu');

      await ref.read(documentRepositoryProvider).uploadDocument(
            buildingId: profile.buildingId!,
            createdBy: profile.id,
            name: name,
            bytes: bytes,
            mimeType: mimeType,
          );
    });
  }
}

final uploadDocumentProvider =
    AsyncNotifierProvider<UploadDocumentNotifier, void>(
        UploadDocumentNotifier.new);

// ── Delete ────────────────────────────────────────────────────────────────

class DeleteDocumentNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> deleteDocument(DocumentModel doc) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(documentRepositoryProvider).deleteDocument(doc);
    });
  }
}

final deleteDocumentProvider =
    AsyncNotifierProvider<DeleteDocumentNotifier, void>(
        DeleteDocumentNotifier.new);
