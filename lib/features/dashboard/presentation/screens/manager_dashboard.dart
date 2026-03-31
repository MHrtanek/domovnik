import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../features/buildings/presentation/providers/building_provider.dart';
import '../../../../features/profile/presentation/providers/profile_provider.dart';
import '../../../../features/tickets/presentation/providers/tickets_provider.dart';
import '../../../../features/tickets/models/ticket_model.dart';
import '../../../../features/announcements/presentation/providers/announcements_provider.dart';
import '../../../../features/polls/presentation/providers/polls_provider.dart';
import '../../../../shared/widgets/app_bar_widget.dart';
import '../../../../shared/widgets/loading_widget.dart';

class ManagerDashboardScreen extends ConsumerWidget {
  const ManagerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    final buildingAsync = ref.watch(currentBuildingProvider);
    final ticketsAsync = ref.watch(ticketsProvider);
    final announcementsAsync = ref.watch(buildingAnnouncementsProvider);
    final pollsAsync = ref.watch(pollsProvider);

    return Scaffold(
      appBar: DomovnikAppBar(
        title: 'Správca – Prehľad',
        showBack: false,
      ),
      body: profileAsync.when(
        data: (profile) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(profileProvider);
            ref.invalidate(currentBuildingProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome
                Text(
                  'Dobrý deň, ${profile?.fullName ?? 'Správca'}!',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 4),
                buildingAsync.when(
                  data: (building) => Text(
                    building?.name ?? '',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 24),

                // Stats row
                Row(
                  children: [
                    Expanded(
                      child: ticketsAsync.when(
                        data: (tickets) {
                          final open = tickets
                              .where((t) => t.status != TicketStatus.ukoncene)
                              .length;
                          return _StatCard(
                            label: 'Otvorené tikety',
                            value: '$open',
                            icon: Icons.build_outlined,
                            color: AppColors.accent,
                          );
                        },
                        loading: () => const _StatCard(
                          label: 'Otvorené tikety',
                          value: '–',
                          icon: Icons.build_outlined,
                          color: AppColors.accent,
                        ),
                        error: (_, __) => const _StatCard(
                          label: 'Otvorené tikety',
                          value: '!',
                          icon: Icons.build_outlined,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: announcementsAsync.when(
                        data: (list) => _StatCard(
                          label: 'Oznamy',
                          value: '${list.length}',
                          icon: Icons.campaign_outlined,
                          color: AppColors.primary,
                        ),
                        loading: () => const _StatCard(
                          label: 'Oznamy',
                          value: '–',
                          icon: Icons.campaign_outlined,
                          color: AppColors.primary,
                        ),
                        error: (_, __) => const _StatCard(
                          label: 'Oznamy',
                          value: '!',
                          icon: Icons.campaign_outlined,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: pollsAsync.when(
                        data: (list) {
                          final active =
                              list.where((p) => !p.isExpired).length;
                          return _StatCard(
                            label: 'Aktívne hlasov.',
                            value: '$active',
                            icon: Icons.how_to_vote_outlined,
                            color: AppColors.secondary,
                          );
                        },
                        loading: () => const _StatCard(
                          label: 'Aktívne hlasov.',
                          value: '–',
                          icon: Icons.how_to_vote_outlined,
                          color: AppColors.secondary,
                        ),
                        error: (_, __) => const _StatCard(
                          label: 'Aktívne hlasov.',
                          value: '!',
                          icon: Icons.how_to_vote_outlined,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Ticket status breakdown
                const Text(
                  'Stav tiketov',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                ticketsAsync.when(
                  data: (tickets) => _TicketStatusBreakdown(tickets: tickets),
                  loading: () => const LoadingWidget(),
                  error: (e, _) => Text(
                    'Chyba: $e',
                    style: const TextStyle(color: AppColors.error),
                  ),
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

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TicketStatusBreakdown extends StatelessWidget {
  final List<TicketModel> tickets;

  const _TicketStatusBreakdown({required this.tickets});

  @override
  Widget build(BuildContext context) {
    final prijate =
        tickets.where((t) => t.status == TicketStatus.prijate).length;
    final vRieseni =
        tickets.where((t) => t.status == TicketStatus.vRieseni).length;
    final ukoncene =
        tickets.where((t) => t.status == TicketStatus.ukoncene).length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _StatusRow(
              label: 'Prijaté',
              count: prijate,
              color: AppColors.statusPrijate,
              total: tickets.length,
            ),
            const SizedBox(height: 12),
            _StatusRow(
              label: 'V riešení',
              count: vRieseni,
              color: AppColors.statusVRieseni,
              total: tickets.length,
            ),
            const SizedBox(height: 12),
            _StatusRow(
              label: 'Ukončené',
              count: ukoncene,
              color: AppColors.statusUkoncene,
              total: tickets.length,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final int total;

  const _StatusRow({
    required this.label,
    required this.count,
    required this.color,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = total == 0 ? 0.0 : count / total;
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(fontSize: 13),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              backgroundColor: color.withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 12,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$count',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
