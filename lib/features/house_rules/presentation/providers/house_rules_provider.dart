import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/house_rules_repository.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';

final houseRulesRepositoryProvider = Provider<HouseRulesRepository>((ref) {
  return HouseRulesRepository(ref.watch(supabaseClientProvider));
});

final houseRulesProvider = StreamProvider<String>((ref) async* {
  final buildingId = await ref.watch(buildingIdProvider.future);
  yield* ref.read(houseRulesRepositoryProvider).getHouseRules(buildingId);
});
