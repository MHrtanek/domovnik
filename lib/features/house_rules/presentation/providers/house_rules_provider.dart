import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/house_rules_repository.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';

final houseRulesRepositoryProvider = Provider<HouseRulesRepository>((ref) {
  return HouseRulesRepository(ref.watch(supabaseClientProvider));
});

final houseRulesProvider = StreamProvider<String>((ref) {
  final profile = ref.watch(profileProvider).valueOrNull;
  if (profile?.buildingId == null) return const Stream.empty();
  return ref.read(houseRulesRepositoryProvider).getHouseRules(profile!.buildingId!);
});
