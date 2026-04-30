import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../profile/models/profile_model.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

final residentsProvider = StreamProvider<List<ProfileModel>>((ref) {
  final profile = ref.watch(profileProvider).valueOrNull;
  if (profile?.buildingId == null) return const Stream.empty();
  final client = ref.watch(supabaseClientProvider);
  return client
      .from('profiles')
      .stream(primaryKey: ['id'])
      .eq('building_id', profile!.buildingId!)
      .map((rows) => rows
          .map((r) => ProfileModel.fromJson(r))
          .where((p) => p.isResident)
          .toList()
        ..sort((a, b) => (a.flatNumber ?? '').compareTo(b.flatNumber ?? '')));
});
