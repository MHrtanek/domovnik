import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/theme/app_theme.dart';
import 'router/app_router.dart';

class DomovnikApp extends ConsumerStatefulWidget {
  const DomovnikApp({super.key});

  @override
  ConsumerState<DomovnikApp> createState() => _DomovnikAppState();
}

class _DomovnikAppState extends ConsumerState<DomovnikApp> {
  @override
  void initState() {
    super.initState();
    initializeDateFormatting('sk', null);
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
