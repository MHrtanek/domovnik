import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:domovnik/features/auth/presentation/screens/login_screen.dart';

void main() {
  // LoginScreen navigates via GoRouter's context.go, so wrap it in a minimal
  // router. ProviderScope supplies the Riverpod container.
  Widget wrap() {
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const LoginScreen()),
      GoRoute(
          path: '/dashboard',
          builder: (_, __) => const Scaffold(body: Text('dashboard'))),
      GoRoute(
          path: '/register',
          builder: (_, __) => const Scaffold(body: Text('register'))),
    ]);
    return ProviderScope(child: MaterialApp.router(routerConfig: router));
  }

  testWidgets('shows validation errors when submitting an empty form',
      (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Prihlásiť sa'));
    await tester.pumpAndSettle();

    expect(find.text('E-mail je povinný'), findsOneWidget);
    expect(find.text('Heslo je povinné'), findsOneWidget);
  });

  testWidgets('demo button is present and reports when not configured',
      (tester) async {
    // No demo credentials configured.
    dotenv.testLoad(fileInput: '');

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    final demoButton = find.byKey(const Key('demo_login_button'));
    expect(demoButton, findsOneWidget);

    await tester.tap(demoButton);
    await tester.pump(); // surface the SnackBar

    expect(find.text('Demo účet nie je nakonfigurovaný.'), findsOneWidget);
  });
}
