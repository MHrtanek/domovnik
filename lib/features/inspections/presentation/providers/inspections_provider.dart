import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/inspection_repository.dart';
import '../../models/inspection_model.dart';
import '../../../../../features/profile/presentation/providers/profile_provider.dart';

final inspectionRepositoryProvider = Provider<InspectionRepository>((ref) {
  return InspectionRepository(Supabase.instance.client);
});

final inspectionsProvider = StreamProvider<List<InspectionModel>>((ref) async* {
  final buildingId = await ref.watch(buildingIdProvider.future);
  yield* ref.read(inspectionRepositoryProvider).streamInspections(buildingId);
});
