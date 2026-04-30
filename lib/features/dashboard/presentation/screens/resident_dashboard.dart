import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../features/profile/presentation/providers/profile_provider.dart';
import '../../../../features/tickets/presentation/providers/tickets_provider.dart';
import '../../../../features/tickets/models/ticket_model.dart';
import '../../../../features/announcements/presentation/providers/announcements_provider.dart';
import '../../../../shared/widgets/app_bar_widget.dart';
import '../../../../shared/widgets/loading_widget.dart';

class ResidentDashboardScreen extends ConsumerWidget {
  const ResidentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    final ticketsAsync = ref.watch(ticketsProvider);
    final announcementsAsync = ref.watch(buildingAnnouncementsProvider);

    return Scaffold(
      appBar: const DomovnikAppBar(
        title: 'Domovník',
        showBack: false,
        showLogout: true,
      ),
      body: profileAsync.when(
        data: (profile) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(profileProvider);
            ref.invalidate(buildingAnnouncementsProvider);
            ref.invalidate(ticketsProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Pozdrav ───────────────────────────────────────────────
                Text(
                  'Dobrý deň, ${profile?.fullName ?? 'Obyvateľ'}!',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                if (profile?.flatNumber != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Byt č. ${profile!.flatNumber}',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                  ),
                ],
                const SizedBox(height: 24),

                // ── Stat karty ────────────────────────────────────────────
                ticketsAsync.when(
                  data: (tickets) {
                    final total = tickets.length;
                    final vRieseni = tickets.where((t) => t.status == TicketStatus.vRieseni).length;
                    return Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            label: 'Moje tikety',
                            value: '$total',
                            icon: Icons.build_outlined,
                            color: AppColors.accent,
                            onTap: () => context.go('/resident/tickets'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            label: 'V riešení',
                            value: '$vRieseni',
                            icon: Icons.autorenew_outlined,
                            color: AppColors.statusVRieseni,
                            onTap: () => context.go('/resident/tickets'),
                          ),
                        ),
                      ],
                    );
                  },
                  loading: () => const Row(
                    children: [
                      Expanded(child: _StatCard(label: 'Moje tikety', value: '–', icon: Icons.build_outlined, color: AppColors.accent, onTap: null)),
                      SizedBox(width: 12),
                      Expanded(child: _StatCard(label: 'V riešení', value: '–', icon: Icons.autorenew_outlined, color: AppColors.statusVRieseni, onTap: null)),
                    ],
                  ),
                  error: (_, __) => const SizedBox.shrink(),
                ),

                const SizedBox(height: 24),

                // ── Posledné oznamy ───────────────────────────────────────
                const _SectionHeader(title: 'Posledné oznamy', route: '/resident/announcements'),
                const SizedBox(height: 8),
                announcementsAsync.when(
                  data: (announcements) {
                    if (announcements.isEmpty) {
                      return const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('Žiadne oznamy', style: TextStyle(color: AppColors.textSecondary)),
                        ),
                      );
                    }
                    final recent = announcements.take(3).toList();
                    return Column(
                      children: recent.map((a) {
                        final snippet = a.content.length > 60
                            ? '${a.content.substring(0, 60)}…'
                            : a.content;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(
                              a.title,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: a.isUrgent ? AppColors.error : null,
                              ),
                            ),
                            subtitle: Text(snippet),
                            onTap: () => context.go('/resident/announcements'),
                          ),
                        );
                      }).toList(),
                    );
                  },
                  loading: () => const LoadingWidget(),
                  error: (e, _) => Text('Chyba: $e', style: const TextStyle(color: AppColors.error)),
                ),

                const SizedBox(height: 24),

                // ── Rýchle akcie ──────────────────────────────────────────
                const Text('Rýchle akcie', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => context.go('/resident/tickets/create'),
                        icon: const Icon(Icons.add),
                        label: const Text('Nový tiket'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => context.go('/resident/polls'),
                        icon: const Icon(Icons.how_to_vote_outlined),
                        label: const Text('Hlasovanie'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        loading: () => const LoadingWidget(),
        error: (e, _) => Center(child: Text('Chyba: $e')),
      ),
    );
  }
}

// ── Widgets ──────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final String route;

  const _SectionHeader({required this.title, required this.route});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const Spacer(),
        TextButton(
          onPressed: () => context.go(route),
          child: const Text('Zobraziť všetko →', style: TextStyle(fontSize: 13)),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(height: 6),
              Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: color)),
              const SizedBox(height: 4),
              Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}
