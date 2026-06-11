import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../profile/models/profile_model.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

final residentsProvider = StreamProvider<List<ProfileModel>>((ref) async* {
  final buildingId = await ref.watch(buildingIdProvider.future);
  final client = ref.watch(supabaseClientProvider);
  yield* client
      .from('profiles')
      .stream(primaryKey: ['id'])
      .eq('building_id', buildingId)
      .map((rows) => rows
          .map((r) => ProfileModel.fromJson(r))
          .where((p) => p.isResident)
          .toList()
        ..sort((a, b) => (a.flatNumber ?? '').compareTo(b.flatNumber ?? '')));
});
