import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/auth/presentation/providers/auth_provider.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/auth/presentation/screens/register_screen.dart';
import '../features/profile/presentation/providers/profile_provider.dart';
import '../features/profile/presentation/screens/profile_screen.dart';
import '../features/dashboard/presentation/screens/resident_dashboard.dart';
import '../features/dashboard/presentation/screens/manager_dashboard.dart';
import '../features/tickets/presentation/screens/tickets_list_screen.dart';
import '../features/tickets/presentation/screens/create_ticket_screen.dart';
import '../features/tickets/presentation/screens/ticket_detail_screen.dart';
import '../features/announcements/presentation/screens/announcements_screen.dart';
import '../features/announcements/presentation/screens/create_announcement_screen.dart';
import '../features/polls/presentation/screens/polls_screen.dart';
import '../features/polls/presentation/screens/create_poll_screen.dart';
import '../features/polls/presentation/screens/poll_detail_screen.dart';
import '../features/contacts/presentation/screens/contacts_screen.dart';
import '../features/documents/presentation/screens/documents_screen.dart';
import '../features/forum/presentation/screens/forum_screen.dart';
import '../features/reservations/presentation/screens/reservations_screen.dart';
import '../core/constants/app_colors.dart';
import '../shared/widgets/loading_widget.dart';
import '../features/auth/presentation/screens/reset_password_screen.dart';
import '../features/inspections/presentation/screens/inspections_screen.dart';
import '../features/suppliers/presentation/screens/suppliers_screen.dart';
import '../features/chat/presentation/screens/conversations_screen.dart';
import '../features/chat/presentation/screens/chat_screen.dart';


final routerProvider = Provider<GoRouter>((ref) {
  ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/login',
    debugLogDiagnostics: true,
    redirect: (context, state) async {
      final isLoggedIn = Supabase.instance.client.auth.currentUser != null;
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';
      if (!isLoggedIn && !isAuthRoute) return '/login';
      if (isLoggedIn && isAuthRoute) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),
      GoRoute(path: '/register', builder: (c, s) => const RegisterScreen()),
      GoRoute(path: '/dashboard', builder: (c, s) => const _DashboardRedirect()),

      // Resident shell
      ShellRoute(
        builder: (context, state, child) => ResidentShell(child: child),
        routes: [
          GoRoute(path: '/resident/announcements', builder: (c, s) => const AnnouncementsScreen()),
          GoRoute(path: '/resident/tickets', builder: (c, s) => const TicketsListScreen()),
          GoRoute(path: '/resident/forum', builder: (c, s) => const ForumScreen()),
          GoRoute(path: '/resident/polls', builder: (c, s) => const PollsScreen()),
          GoRoute(path: '/resident/more', builder: (c, s) => const ResidentMoreScreen()),
          GoRoute(path: '/resident/reservations', builder: (c, s) => const ReservationsScreen()),
          GoRoute(path: '/resident/contacts', builder: (c, s) => const ContactsScreen()),
          GoRoute(path: '/resident/documents', builder: (c, s) => const DocumentsScreen()),
          GoRoute(path: '/resident/profile', builder: (c, s) => const ProfileScreen()),
          GoRoute(path: '/resident/inspections', builder: (c, s) => const InspectionsScreen()),
          GoRoute(path: '/resident/suppliers', builder: (c, s) => const SuppliersScreen()),
          GoRoute(path: '/resident/chat', builder: (c, s) => const ConversationsScreen()),
        ],
      ),

      // Manager shell
      ShellRoute(
        builder: (context, state, child) => ManagerShell(child: child),
        routes: [
          GoRoute(path: '/manager/dashboard', builder: (c, s) => const ManagerDashboardScreen()),
          GoRoute(path: '/manager/announcements', builder: (c, s) => const AnnouncementsScreen()),
          GoRoute(path: '/manager/tickets', builder: (c, s) => const TicketsListScreen()),
          GoRoute(path: '/manager/forum', builder: (c, s) => const ForumScreen()),
          GoRoute(path: '/manager/more', builder: (c, s) => const ManagerMoreScreen()),
          GoRoute(path: '/manager/polls', builder: (c, s) => const PollsScreen()),
          GoRoute(path: '/manager/reservations', builder: (c, s) => const ReservationsScreen()),
          GoRoute(path: '/manager/contacts', builder: (c, s) => const ContactsScreen()),
          GoRoute(path: '/manager/documents', builder: (c, s) => const DocumentsScreen()),
          GoRoute(path: '/manager/profile', builder: (c, s) => const ProfileScreen()),
          GoRoute(path: '/manager/inspections', builder: (c, s) => const InspectionsScreen()),
          GoRoute(path: '/manager/suppliers', builder: (c, s) => const SuppliersScreen()),
          GoRoute(path: '/manager/chat', builder: (c, s) => const ConversationsScreen()),
        ],
      ),

      // Full-screen routes
      GoRoute(path: '/tickets/create', builder: (c, s) => const CreateTicketScreen()),
      GoRoute(path: '/tickets/:id', builder: (c, s) => TicketDetailScreen(ticketId: s.pathParameters['id']!)),
      GoRoute(path: '/announcements/create', builder: (c, s) => const CreateAnnouncementScreen()),
      GoRoute(path: '/polls/create', builder: (c, s) => const CreatePollScreen()),
      GoRoute(path: '/reset-password', builder: (c, s) => const ResetPasswordScreen()),
      GoRoute(path: '/polls/:id', builder: (c, s) => PollDetailScreen(pollId: s.pathParameters['id']!)),
      GoRoute(path: '/chat/:userId', builder: (c, s) => ChatScreen(otherUserId: s.pathParameters['userId']!)),
    ],
  );
});

// ── Dashboard redirect ───────────────────────────────────────────────────────

class _DashboardRedirect extends ConsumerWidget {
  const _DashboardRedirect();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    return profileAsync.when(
      data: (profile) {
        if (profile == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.go('/login');
          });
          return const Scaffold(body: LoadingWidget());
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            context.go(profile.isManager ? '/manager/dashboard' : '/resident/announcements');
          }
        });
        return const Scaffold(body: LoadingWidget());
      },
      loading: () => const Scaffold(body: LoadingWidget()),
      error: (e, _) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) context.go('/login');
        });
        return const Scaffold(body: LoadingWidget());
      },
    );
  }
}

// ── Logout helper ────────────────────────────────────────────────────────────

Future<void> _doLogout(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Odhlásiť sa'),
      content: const Text('Naozaj sa chcete odhlásiť?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Zrušiť'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
          child: const Text('Odhlásiť'),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await ref.read(authNotifierProvider.notifier).signOut();
    if (context.mounted) context.go('/login');
  }
}

// ── Resident Shell ───────────────────────────────────────────────────────────

class ResidentShell extends ConsumerWidget {
  final Widget child;
  const ResidentShell({super.key, required this.child});

  static const _tabs = [
    '/resident/announcements',
    '/resident/tickets',
    '/resident/forum',
    '/resident/polls',
    '/resident/more',
  ];

  static const _destinations = <NavigationRailDestination>[
    NavigationRailDestination(
      icon: Icon(Icons.campaign_outlined),
      selectedIcon: Icon(Icons.campaign),
      label: Text('Oznamy'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.build_outlined),
      selectedIcon: Icon(Icons.build),
      label: Text('Tikety'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.forum_outlined),
      selectedIcon: Icon(Icons.forum),
      label: Text('Fórum'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.how_to_vote_outlined),
      selectedIcon: Icon(Icons.how_to_vote),
      label: Text('Hlasovanie'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.grid_view_outlined),
      selectedIcon: Icon(Icons.grid_view),
      label: Text('Ďalšie'),
    ),
  ];

  int _currentIndex(String location) {
    if (location.startsWith('/resident/reservations') ||
        location.startsWith('/resident/contacts') ||
        location.startsWith('/resident/documents') ||
        location.startsWith('/resident/inspections') ||
        location.startsWith('/resident/suppliers') ||
        location.startsWith('/resident/profile') ||
        location.startsWith('/resident/chat')) {
      return 4;
    }
    final idx = _tabs.indexWhere((t) => location.startsWith(t));
    return idx < 0 ? 0 : idx;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    final currentIndex = _currentIndex(location);
    final isWide = MediaQuery.of(context).size.width > 600;

    if (isWide) {
      // ── PC: NavigationRail na ľavej strane ──────────────────────────────
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: currentIndex,
              onDestinationSelected: (i) => context.go(_tabs[i]),
              labelType: NavigationRailLabelType.all,
              destinations: _destinations,
              // Logout tlačidlo dole na NavigationRail
              trailing: Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.person_outline),
                          tooltip: 'Profil',
                          onPressed: () => context.go('/resident/profile'),
                        ),
                        const Text(
                          'Profil',
                          style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 8),
                        IconButton(
                          icon: const Icon(Icons.logout),
                          tooltip: 'Odhlásiť sa',
                          onPressed: () => _doLogout(context, ref),
                        ),
                        const Text(
                          'Odhlásiť',
                          style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(child: child),
          ],
        ),
      );
    }

    // ── Mobil: BottomNavigationBar + logout v AppBar (cez showLogout) ───────
    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (i) => context.go(_tabs[i]),
        type: BottomNavigationBarType.fixed,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        selectedItemColor: AppColors.primary,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.campaign_outlined),
            activeIcon: Icon(Icons.campaign),
            label: 'Oznamy',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.build_outlined),
            activeIcon: Icon(Icons.build),
            label: 'Tikety',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.forum_outlined),
            activeIcon: Icon(Icons.forum),
            label: 'Fórum',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.how_to_vote_outlined),
            activeIcon: Icon(Icons.how_to_vote),
            label: 'Hlasovanie',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_view_outlined),
            activeIcon: Icon(Icons.grid_view),
            label: 'Ďalšie',
          ),
        ],
      ),
    );
  }
}

// ── Manager Shell ────────────────────────────────────────────────────────────

class ManagerShell extends ConsumerWidget {
  final Widget child;
  const ManagerShell({super.key, required this.child});

  static const _tabs = [
    '/manager/dashboard',
    '/manager/announcements',
    '/manager/tickets',
    '/manager/forum',
    '/manager/more',
  ];

  static const _destinations = <NavigationRailDestination>[
    NavigationRailDestination(
      icon: Icon(Icons.dashboard_outlined),
      selectedIcon: Icon(Icons.dashboard),
      label: Text('Prehľad'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.campaign_outlined),
      selectedIcon: Icon(Icons.campaign),
      label: Text('Oznamy'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.build_outlined),
      selectedIcon: Icon(Icons.build),
      label: Text('Tikety'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.forum_outlined),
      selectedIcon: Icon(Icons.forum),
      label: Text('Fórum'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.grid_view_outlined),
      selectedIcon: Icon(Icons.grid_view),
      label: Text('Ďalšie'),
    ),
  ];

  int _currentIndex(String location) {
    if (location.startsWith('/manager/polls') ||
        location.startsWith('/manager/reservations') ||
        location.startsWith('/manager/contacts') ||
        location.startsWith('/manager/documents') ||
        location.startsWith('/manager/inspections') ||
        location.startsWith('/manager/suppliers') ||
        location.startsWith('/manager/profile') ||
        location.startsWith('/manager/chat')) {
      return 4;
    }
    final idx = _tabs.indexWhere((t) => location.startsWith(t));
    return idx < 0 ? 0 : idx;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    final currentIndex = _currentIndex(location);
    final isWide = MediaQuery.of(context).size.width > 600;

    if (isWide) {
      // ── PC: NavigationRail na ľavej strane ──────────────────────────────
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: currentIndex,
              onDestinationSelected: (i) => context.go(_tabs[i]),
              labelType: NavigationRailLabelType.all,
              destinations: _destinations,
              trailing: Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.person_outline),
                          tooltip: 'Profil',
                          onPressed: () => context.go('/manager/profile'),
                        ),
                        const Text(
                          'Profil',
                          style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 8),
                        IconButton(
                          icon: const Icon(Icons.logout),
                          tooltip: 'Odhlásiť sa',
                          onPressed: () => _doLogout(context, ref),
                        ),
                        const Text(
                          'Odhlásiť',
                          style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(child: child),
          ],
        ),
      );
    }

    // ── Mobil: BottomNavigationBar ───────────────────────────────────────────
    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (i) => context.go(_tabs[i]),
        type: BottomNavigationBarType.fixed,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        selectedItemColor: AppColors.primary,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Prehľad',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.campaign_outlined),
            activeIcon: Icon(Icons.campaign),
            label: 'Oznamy',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.build_outlined),
            activeIcon: Icon(Icons.build),
            label: 'Tikety',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.forum_outlined),
            activeIcon: Icon(Icons.forum),
            label: 'Fórum',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_view_outlined),
            activeIcon: Icon(Icons.grid_view),
            label: 'Ďalšie',
          ),
        ],
      ),
    );
  }
}

// ── app_bar_widget.dart upgrade: showLogout default true na mobilných shelloch
// Pozri shared/widgets/app_bar_widget.dart – tam logout zostáva ako je.
// Na mobile logout je v AppBar cez showLogout: true na každom hlavnom screene.
// Na PC je logout dole v NavigationRail (viď vyššie).

// ── Resident More Screen ─────────────────────────────────────────────────────

class ResidentMoreScreen extends StatelessWidget {
  const ResidentMoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      _MoreItem(icon: Icons.chat_outlined, label: 'Správy', route: '/resident/chat', color: const Color(0xFF0277bd)),
      _MoreItem(icon: Icons.event_available_outlined, label: 'Rezervácie', route: '/resident/reservations', color: const Color(0xFF1a3a6b)),
      _MoreItem(icon: Icons.contacts_outlined, label: 'Kontakty', route: '/resident/contacts', color: const Color(0xFF2e7d32)),
      _MoreItem(icon: Icons.folder_outlined, label: 'Dokumenty', route: '/resident/documents', color: const Color(0xFFe65100)),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Ďalšie'), centerTitle: true),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 600;
          final crossCount = isWide ? 4 : 2;
          return Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: EdgeInsets.all(isWide ? 28 : 16),
              child: GridView.count(
                shrinkWrap: true,
                crossAxisCount: crossCount,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: isWide ? 1.6 : 1.2,
                children: items.map((item) => _MoreCard(item: item)).toList(),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Manager More Screen ──────────────────────────────────────────────────────

class ManagerMoreScreen extends StatelessWidget {
  const ManagerMoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      _MoreItem(icon: Icons.chat_outlined, label: 'Správy', route: '/manager/chat', color: const Color(0xFF0277bd)),
      _MoreItem(icon: Icons.how_to_vote_outlined, label: 'Hlasovanie', route: '/manager/polls', color: const Color(0xFF1565c0)),
      _MoreItem(icon: Icons.event_available_outlined, label: 'Rezervácie', route: '/manager/reservations', color: const Color(0xFF2e7d32)),
      _MoreItem(icon: Icons.contacts_outlined, label: 'Kontakty', route: '/manager/contacts', color: const Color(0xFFe65100)),
      _MoreItem(icon: Icons.folder_outlined, label: 'Dokumenty', route: '/manager/documents', color: const Color(0xFF6a1b9a)),
      _MoreItem(icon: Icons.assignment_outlined, label: 'Revízie', route: '/manager/inspections', color: const Color(0xFF00838f)),
      _MoreItem(icon: Icons.business_outlined, label: 'Dodávatelia', route: '/manager/suppliers', color: const Color(0xFF558b2f)),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Ďalšie'), centerTitle: true),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 600;
          final crossCount = isWide ? 4 : 2;
          return Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: EdgeInsets.all(isWide ? 28 : 16),
              child: GridView.count(
                shrinkWrap: true,
                crossAxisCount: crossCount,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: isWide ? 1.6 : 1.2,
                children: items.map((item) => _MoreCard(item: item)).toList(),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MoreItem {
  final IconData icon;
  final String label;
  final String route;
  final Color color;
  const _MoreItem({required this.icon, required this.label, required this.route, required this.color});
}

class _MoreCard extends StatelessWidget {
  final _MoreItem item;
  const _MoreCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.go(item.route),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icon, size: 24, color: item.color),
              ),
              const Spacer(),
              Text(
                item.label,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
