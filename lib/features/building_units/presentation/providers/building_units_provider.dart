import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/building_unit_repository.dart';
import '../../models/building_unit_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';

final buildingUnitRepositoryProvider = Provider<BuildingUnitRepository>((ref) {
  return BuildingUnitRepository(ref.watch(supabaseClientProvider));
});

final buildingUnitsProvider = StreamProvider<List<BuildingUnitModel>>((ref) async* {
  final buildingId = await ref.watch(buildingIdProvider.future);
  yield* ref.watch(buildingUnitRepositoryProvider).getUnits(buildingId);
});
