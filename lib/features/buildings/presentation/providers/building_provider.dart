import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/building_repository.dart';
import '../../models/building_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';

final buildingRepositoryProvider = Provider<BuildingRepository>((ref) {
  return BuildingRepository(ref.watch(supabaseClientProvider));
});

final currentBuildingProvider =
    AsyncNotifierProvider<CurrentBuildingNotifier, BuildingModel?>(
  CurrentBuildingNotifier.new,
);

class CurrentBuildingNotifier extends AsyncNotifier<BuildingModel?> {
  @override
  Future<BuildingModel?> build() async {
    final profile = await ref.watch(profileProvider.future);
    if (profile?.buildingId == null) return null;
    return ref
        .read(buildingRepositoryProvider)
        .getBuilding(profile!.buildingId!);
  }
}

final allBuildingsProvider =
    AsyncNotifierProvider<AllBuildingsNotifier, List<BuildingModel>>(
  AllBuildingsNotifier.new,
);

class AllBuildingsNotifier extends AsyncNotifier<List<BuildingModel>> {
  @override
  Future<List<BuildingModel>> build() async {
    return ref.read(buildingRepositoryProvider).getAllBuildings();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(buildingRepositoryProvider).getAllBuildings(),
    );
  }
}
