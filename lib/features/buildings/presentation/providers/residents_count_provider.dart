import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final residentsCountProvider = FutureProvider.family<int, String>((ref, buildingId) async {
  final response = await Supabase.instance.client
      .from('profiles')
      .select()
      .eq('building_id', buildingId)
      .eq('role', 'resident');
  return (response as List).length;
});
