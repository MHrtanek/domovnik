import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/supplier_repository.dart';
import '../../models/supplier_model.dart';
import '../../../../../features/profile/presentation/providers/profile_provider.dart';

final supplierRepositoryProvider = Provider<SupplierRepository>((ref) {
  return SupplierRepository(Supabase.instance.client);
});

final suppliersProvider = StreamProvider<List<SupplierModel>>((ref) async* {
  final buildingId = await ref.watch(buildingIdProvider.future);
  yield* ref.read(supplierRepositoryProvider).streamSuppliers(buildingId);
});
