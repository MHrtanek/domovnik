import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'features/notifications/data/fcm_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.implicit,
      autoRefreshToken: true, // vždy true – session riadime my
    ),
  );

  // ── "Zapamätať ma" logika ─────────────────────────────────────────────────
  // Ak user nezaškrtol "Zapamätať ma", odhlásime ho pri každom novom
  // cold-štarte (zatvorenie/obnovenie prehliadača = nový cold-start vo webe).
  final prefs = await SharedPreferences.getInstance();
  final sessionOnly = prefs.getBool('session_only') ?? false;
  if (sessionOnly && Supabase.instance.client.auth.currentUser != null) {
    await Supabase.instance.client.auth.signOut();
  }
  // ─────────────────────────────────────────────────────────────────────────

  // FCM funguje len na mobile (Android/iOS) – na webe nie je Firebase nakonfigurovaný
  if (!kIsWeb) {
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
  }

  runApp(
    const ProviderScope(
      child: DomovnikApp(),
    ),
  );
}
