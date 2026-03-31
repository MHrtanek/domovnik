import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'features/notifications/data/fcm_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: '.env');

  // Initialize Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  // Initialize Firebase + FCM (optional — skipped if google-services is not configured)
  try {
    await Firebase.initializeApp();
    final fcmService = FcmService();
    await fcmService.initialize();

    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser != null) {
      final token = await fcmService.getToken();
      if (token != null) {
        await fcmService.saveFcmTokenToProfile(token);
      }
    }
  } catch (e) {
    debugPrint('Firebase not configured, skipping FCM init: $e');
  }

  runApp(
    const ProviderScope(
      child: DomovnikApp(),
    ),
  );
}
