import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/building_plan_repository.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';

final buildingPlanRepositoryProvider = Provider<BuildingPlanRepository>((ref) {
  return BuildingPlanRepository(ref.watch(supabaseClientProvider));
});

final buildingPlanUrlProvider = StreamProvider<String?>((ref) async* {
  final buildingId = await ref.watch(buildingIdProvider.future);
  yield* ref.read(buildingPlanRepositoryProvider).getPlanUrl(buildingId);
});
