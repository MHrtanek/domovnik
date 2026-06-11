import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:domovnik/core/theme/app_theme.dart';
import 'package:domovnik/features/profile/models/profile_model.dart';
import 'package:domovnik/features/profile/presentation/providers/profile_provider.dart';
import 'package:domovnik/features/tickets/models/ticket_model.dart';
import 'package:domovnik/features/tickets/presentation/providers/tickets_provider.dart';
import 'package:domovnik/features/tickets/presentation/screens/tickets_list_screen.dart';

/// Returns a fixed profile so the screen never touches Supabase.
class _FakeProfileNotifier extends ProfileNotifier {
  _FakeProfileNotifier(this._profile);
  final ProfileModel? _profile;

  @override
  Future<ProfileModel?> build() async => _profile;
}

void main() {
  setUpAll(() => initializeDateFormatting('sk', null));

  TicketModel ticket(String id, String title, TicketStatus status) =>
      TicketModel(
        id: id,
        title: title,
        category: TicketCategory.ine,
        status: status,
        createdBy: 'u1',
        buildingId: 'b1',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        updatedAt: DateTime.now(),
      );

  Widget wrap(List<TicketModel> tickets) {
    final manager = ProfileModel(
      id: 'm1',
      email: 'manager@example.sk',
      role: 'manager',
      buildingId: 'b1',
      createdAt: DateTime(2026),
    );
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const TicketsListScreen()),
    ]);
    return ProviderScope(
      overrides: [
        profileProvider.overrideWith(() => _FakeProfileNotifier(manager)),
        filteredTicketsProvider.overrideWith((ref) => AsyncData(tickets)),
      ],
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    );
  }

  testWidgets('renders a card for each ticket', (tester) async {
    await tester.pumpWidget(wrap([
      ticket('t1', 'Pokazený výťah', TicketStatus.vRieseni),
      ticket('t2', 'Kvapkajúci kohútik', TicketStatus.prijate),
    ]));
    await tester.pump();

    expect(find.text('Pokazený výťah'), findsOneWidget);
    expect(find.text('Kvapkajúci kohútik'), findsOneWidget);
    // 'V riešení' appears both as a filter chip and as the ticket's badge.
    expect(find.text('V riešení'), findsWidgets);
  });

  testWidgets('shows the empty state when there are no tickets',
      (tester) async {
    await tester.pumpWidget(wrap([]));
    await tester.pump();

    expect(find.text('Žiadne tikety'), findsOneWidget);
  });
}
