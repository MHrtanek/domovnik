// Smoke test for the Domovník app shell.
//
// The full app (`DomovnikApp`) boots a Supabase client and FCM, which aren't
// available in the test environment. This test instead builds a minimal shell
// using the app's real theme and Slovak localization to verify those wire up
// and render without errors.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:domovnik/core/theme/app_theme.dart';

void main() {
  testWidgets('app shell builds with theme and Slovak locale',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        title: 'Domovník',
        theme: AppTheme.light,
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
        home: const Scaffold(body: Center(child: Text('Domovník'))),
      ),
    );

    expect(find.text('Domovník'), findsOneWidget);
  });
}
