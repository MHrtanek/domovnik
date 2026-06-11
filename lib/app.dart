import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/theme/app_theme.dart';
import 'features/notifications/data/fcm_service.dart';
import 'router/app_router.dart';

class DomovnikApp extends ConsumerStatefulWidget {
  const DomovnikApp({super.key});

  @override
  ConsumerState<DomovnikApp> createState() => _DomovnikAppState();
}

class _DomovnikAppState extends ConsumerState<DomovnikApp> {
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('sk', null);

    // Consume any route stored during terminated-app FCM launch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pending = FcmService.consumePendingRoute();
      if (pending != null && mounted) {
        ref.read(routerProvider).go(pending);
      }
    });

    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      // ignore: avoid_print
      print('AUTH EVENT: ${data.event}');
      // ignore: avoid_print
      print('AUTH SESSION: ${data.session?.user.email}');
      if (data.event == AuthChangeEvent.passwordRecovery) {
        ref.read(routerProvider).go('/reset-password');
      }
      if (data.event == AuthChangeEvent.signedIn) {
        // ignore: avoid_print
        print('SIGNED IN AS: ${data.session?.user.email}');
        try {
          final fcmService = FcmService();
          final token = await fcmService.getToken();
          if (token != null) {
            await fcmService.saveFcmTokenToProfile(token);
          }
        } catch (e) {
          debugPrint('FCM token save on signedIn error: $e');
        }
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Domovník',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
      locale: const Locale('sk', 'SK'),
      supportedLocales: const [
        Locale('sk', 'SK'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
