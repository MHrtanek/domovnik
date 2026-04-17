import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final residentsCountProvider = StreamProvider.family<int, String>((ref, buildingId) {
  return Supabase.instance.client
      .from('profiles')
      .stream(primaryKey: ['id'])
      .eq('building_id', buildingId)
      .map((rows) => rows.where((r) => r['role'] == 'resident').length);
});
