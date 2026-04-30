import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/building_plan_repository.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';

final buildingPlanRepositoryProvider = Provider<BuildingPlanRepository>((ref) {
  return BuildingPlanRepository(ref.watch(supabaseClientProvider));
});

final buildingPlanUrlProvider = StreamProvider<String?>((ref) {
  final profile = ref.watch(profileProvider).valueOrNull;
  if (profile?.buildingId == null) return const Stream.empty();
  return ref.read(buildingPlanRepositoryProvider).getPlanUrl(profile!.buildingId!);
});
