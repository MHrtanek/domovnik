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
import '../shared/widgets/loading_widget.dart';

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
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const _DashboardRedirect(),
      ),

      // Resident shell
      ShellRoute(
        builder: (context, state, child) => ResidentShell(child: child),
        routes: [
          GoRoute(
            path: '/resident/announcements',
            builder: (context, state) => const AnnouncementsScreen(),
          ),
          GoRoute(
            path: '/resident/tickets',
            builder: (context, state) => const TicketsListScreen(),
          ),
          GoRoute(
            path: '/resident/polls',
            builder: (context, state) => const PollsScreen(),
          ),
          GoRoute(
            path: '/resident/forum',
            builder: (context, state) => const ForumScreen(),
          ),
          GoRoute(
            path: '/resident/reservations',
            builder: (context, state) => const ReservationsScreen(),
          ),
          GoRoute(
            path: '/resident/contacts',
            builder: (context, state) => const ContactsScreen(),
          ),
          GoRoute(
            path: '/resident/documents',
            builder: (context, state) => const DocumentsScreen(),
          ),
          GoRoute(
            path: '/resident/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),

      // Manager shell
      ShellRoute(
        builder: (context, state, child) => ManagerShell(child: child),
        routes: [
          GoRoute(
            path: '/manager/dashboard',
            builder: (context, state) => const ManagerDashboardScreen(),
          ),
          GoRoute(
            path: '/manager/announcements',
            builder: (context, state) => const AnnouncementsScreen(),
          ),
          GoRoute(
            path: '/manager/tickets',
            builder: (context, state) => const TicketsListScreen(),
          ),
          GoRoute(
            path: '/manager/polls',
            builder: (context, state) => const PollsScreen(),
          ),
          GoRoute(
            path: '/manager/forum',
            builder: (context, state) => const ForumScreen(),
          ),
          GoRoute(
            path: '/manager/reservations',
            builder: (context, state) => const ReservationsScreen(),
          ),
          GoRoute(
            path: '/manager/contacts',
            builder: (context, state) => const ContactsScreen(),
          ),
          GoRoute(
            path: '/manager/documents',
            builder: (context, state) => const DocumentsScreen(),
          ),
          GoRoute(
            path: '/manager/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),

      // Full-screen routes
      GoRoute(
        path: '/tickets/create',
        builder: (context, state) => const CreateTicketScreen(),
      ),
      GoRoute(
        path: '/tickets/:id',
        builder: (context, state) =>
            TicketDetailScreen(ticketId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/announcements/create',
        builder: (context, state) => const CreateAnnouncementScreen(),
      ),
      GoRoute(
        path: '/polls/create',
        builder: (context, state) => const CreatePollScreen(),
      ),
      GoRoute(
        path: '/polls/:id',
        builder: (context, state) =>
            PollDetailScreen(pollId: state.pathParameters['id']!),
      ),
    ],
  );
});

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
            if (profile.isManager) {
              context.go('/manager/dashboard');
            } else {
              context.go('/resident/announcements');
            }
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

// ── Resident Shell ──────────────────────────────────────────────────────────

class ResidentShell extends StatelessWidget {
  final Widget child;
  const ResidentShell({super.key, required this.child});

  static const _tabs = [
    '/resident/announcements',
    '/resident/tickets',
    '/resident/polls',
    '/resident/forum',
    '/resident/reservations',
    '/resident/contacts',
    '/resident/documents',
    '/resident/profile',
  ];

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final currentIndex = _tabs.indexWhere((t) => location.startsWith(t));

    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex < 0 ? 0 : currentIndex,
        onTap: (i) => context.go(_tabs[i]),
        type: BottomNavigationBarType.fixed,
        selectedFontSize: 10,
        unselectedFontSize: 10,
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
            icon: Icon(Icons.how_to_vote_outlined),
            activeIcon: Icon(Icons.how_to_vote),
            label: 'Hlasovanie',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.forum_outlined),
            activeIcon: Icon(Icons.forum),
            label: 'Fórum',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.event_available_outlined),
            activeIcon: Icon(Icons.event_available),
            label: 'Rezervácie',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.contacts_outlined),
            activeIcon: Icon(Icons.contacts),
            label: 'Kontakty',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.folder_outlined),
            activeIcon: Icon(Icons.folder),
            label: 'Dokumenty',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}

// ── Manager Shell ───────────────────────────────────────────────────────────

class ManagerShell extends StatelessWidget {
  final Widget child;
  const ManagerShell({super.key, required this.child});

  static const _tabs = [
    '/manager/dashboard',
    '/manager/announcements',
    '/manager/tickets',
    '/manager/polls',
    '/manager/forum',
    '/manager/reservations',
    '/manager/contacts',
    '/manager/documents',
    '/manager/profile',
  ];

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final currentIndex = _tabs.indexWhere((t) => location.startsWith(t));

    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex < 0 ? 0 : currentIndex,
        onTap: (i) => context.go(_tabs[i]),
        type: BottomNavigationBarType.fixed,
        selectedFontSize: 10,
        unselectedFontSize: 10,
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
            icon: Icon(Icons.how_to_vote_outlined),
            activeIcon: Icon(Icons.how_to_vote),
            label: 'Hlasovanie',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.forum_outlined),
            activeIcon: Icon(Icons.forum),
            label: 'Fórum',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.event_available_outlined),
            activeIcon: Icon(Icons.event_available),
            label: 'Rezervácie',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.contacts_outlined),
            activeIcon: Icon(Icons.contacts),
            label: 'Kontakty',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.folder_outlined),
            activeIcon: Icon(Icons.folder),
            label: 'Dokumenty',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
