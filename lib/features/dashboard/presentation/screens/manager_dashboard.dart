import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../features/buildings/presentation/providers/building_provider.dart';
import '../../../../features/buildings/presentation/providers/residents_count_provider.dart';
import '../../../../features/profile/presentation/providers/profile_provider.dart';
import '../../../../features/tickets/presentation/providers/tickets_provider.dart';
import '../../../../features/tickets/models/ticket_model.dart';
import '../../../../features/announcements/presentation/providers/announcements_provider.dart';
import '../../../../features/polls/presentation/providers/polls_provider.dart';
import '../../../../features/inspections/presentation/providers/inspections_provider.dart';
import '../../../../features/reservations/presentation/providers/reservation_provider.dart';
import '../../../../features/reservations/models/reservation_model.dart';
import '../../../../shared/widgets/app_bar_widget.dart';
import '../../../../shared/widgets/loading_widget.dart';

final _dateFmt = DateFormat('d. M. yyyy');

// Provider pre najbližšie rezervácie – odvodený z real-time streamu
final upcomingReservationsProvider =
    Provider<AsyncValue<List<ReservationModel>>>((ref) {
  return ref.watch(allReservationsProvider).whenData((reservations) {
    final todayDate = DateTime.now();
    final today = DateTime(todayDate.year, todayDate.month, todayDate.day);
    return reservations
        .where((r) => !r.date.isBefore(today))
        .take(5)
        .toList();
  });
});

class ManagerDashboardScreen extends ConsumerWidget {
  const ManagerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    final buildingAsync = ref.watch(currentBuildingProvider);
    final ticketsAsync = ref.watch(ticketsProvider);
    final announcementsAsync = ref.watch(buildingAnnouncementsProvider);
    final pollsAsync = ref.watch(pollsProvider);
    final inspectionsAsync = ref.watch(inspectionsProvider);
    final reservationsAsync = ref.watch(upcomingReservationsProvider);

    return Scaffold(
      appBar: const DomovnikAppBar(
        title: 'Správca – Prehľad',
        showBack: false,
        showLogout: true,
      ),
      body: profileAsync.when(
        data: (profile) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(profileProvider);
            ref.invalidate(currentBuildingProvider);
            ref.invalidate(inspectionsProvider);
            final buildingId = profile?.buildingId;
            if (buildingId != null) {
              ref.invalidate(residentsCountProvider(buildingId));
            }
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Pozdrav ───────────────────────────────────────────────
                Text(
                  'Dobrý deň, ${profile?.fullName ?? 'Správca'}!',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 4),
                buildingAsync.when(
                  data: (building) => Text(
                    building?.name ?? '',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 24),

                // ── Stat karty ────────────────────────────────────────────
                buildingAsync.when(
                  data: (building) {
                    if (building == null) return const SizedBox.shrink();
                    return Column(
                      children: [
                        Row(
                          children: [
                            // Počet obyvateľov
                            Expanded(
                              child: ref.watch(residentsCountProvider(building.id)).when(
                                data: (count) => _StatCard(
                                  label: 'Obyvatelia',
                                  value: '$count',
                                  icon: Icons.people_outlined,
                                  color: const Color(0xFF1565c0),
                                  onTap: null,
                                ),
                                loading: () => const _StatCard(label: 'Obyvatelia', value: '–', icon: Icons.people_outlined, color: Color(0xFF1565c0)),
                                error: (_, __) => const _StatCard(label: 'Obyvatelia', value: '!', icon: Icons.people_outlined, color: AppColors.error),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Otvorené tikety
                            Expanded(
                              child: ticketsAsync.when(
                                data: (tickets) {
                                  final open = tickets.where((t) => t.status != TicketStatus.ukoncene).length;
                                  return _StatCard(
                                    label: 'Otvorené tikety',
                                    value: '$open',
                                    icon: Icons.build_outlined,
                                    color: AppColors.accent,
                                    onTap: () => context.go('/manager/tickets'),
                                  );
                                },
                                loading: () => const _StatCard(label: 'Otvorené tikety', value: '–', icon: Icons.build_outlined, color: AppColors.accent),
                                error: (_, __) => const _StatCard(label: 'Otvorené tikety', value: '!', icon: Icons.build_outlined, color: AppColors.error),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            // Oznamy
                            Expanded(
                              child: announcementsAsync.when(
                                data: (list) => _StatCard(
                                  label: 'Oznamy',
                                  value: '${list.length}',
                                  icon: Icons.campaign_outlined,
                                  color: AppColors.primary,
                                  onTap: () => context.go('/manager/announcements'),
                                ),
                                loading: () => const _StatCard(label: 'Oznamy', value: '–', icon: Icons.campaign_outlined, color: AppColors.primary),
                                error: (_, __) => const _StatCard(label: 'Oznamy', value: '!', icon: Icons.campaign_outlined, color: AppColors.error),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Aktívne hlasovanie
                            Expanded(
                              child: pollsAsync.when(
                                data: (list) {
                                  final active = list.where((p) => !p.isExpired).length;
                                  return _StatCard(
                                    label: 'Aktívne hlasov.',
                                    value: '$active',
                                    icon: Icons.how_to_vote_outlined,
                                    color: AppColors.secondary,
                                    onTap: () => context.go('/manager/more'),
                                  );
                                },
                                loading: () => const _StatCard(label: 'Aktívne hlasov.', value: '–', icon: Icons.how_to_vote_outlined, color: AppColors.secondary),
                                error: (_, __) => const _StatCard(label: 'Aktívne hlasov.', value: '!', icon: Icons.how_to_vote_outlined, color: AppColors.error),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                  loading: () => const LoadingWidget(),
                  error: (_, __) => const SizedBox.shrink(),
                ),

                const SizedBox(height: 24),

                // ── Stav tiketov ──────────────────────────────────────────
                _SectionHeader(title: 'Stav tiketov', route: '/manager/tickets', ref: ref),
                const SizedBox(height: 8),
                ticketsAsync.when(
                  data: (tickets) => _TicketStatusBreakdown(tickets: tickets),
                  loading: () => const LoadingWidget(),
                  error: (e, _) => Text('Chyba: $e', style: const TextStyle(color: AppColors.error)),
                ),

                const SizedBox(height: 24),

                // ── Upozornenia na revízie ────────────────────────────────
                inspectionsAsync.when(
                  data: (inspections) {
                    final urgent = inspections.where((i) => i.isExpired || i.isExpiringSoon).toList();
                    if (urgent.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionHeader(title: '⚠️  Revízie vyžadujú pozornosť', route: '/manager/inspections', ref: ref),
                        const SizedBox(height: 8),
                        ...urgent.map((i) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Icon(
                              Icons.assignment_outlined,
                              color: i.isExpired ? AppColors.error : AppColors.warning,
                            ),
                            title: Text(i.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(
                              i.isExpired
                                  ? 'Vypršalo ${i.nextDate != null ? _dateFmt.format(i.nextDate!) : ""}'
                                  : 'Za ${i.daysUntilNext} dní',
                              style: TextStyle(
                                color: i.isExpired ? AppColors.error : AppColors.warning,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textSecondary),
                            onTap: () => context.go('/manager/inspections'),
                          ),
                        )),
                        const SizedBox(height: 24),
                      ],
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),

                // ── Najbližšie priestory ──────────────────────────────────
                _SectionHeader(title: 'Najbližšie priestory', route: '/manager/reservations', ref: ref),
                const SizedBox(height: 8),
                reservationsAsync.when(
                  data: (reservations) {
                    if (reservations.isEmpty) {
                      return const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('Žiadne nadchádzajúce rezervácie', style: TextStyle(color: AppColors.textSecondary)),
                        ),
                      );
                    }
                    return Column(
                      children: reservations.map((r) {
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: const Icon(Icons.event_available_outlined, color: AppColors.primary),
                            title: Text(
                              r.amenityName.isEmpty ? 'Priestor' : r.amenityName,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text('${r.residentName ?? 'Obyvateľ'} · ${r.timeFrom} – ${r.timeTo}'),
                            trailing: Text(
                              _dateFmt.format(r.date),
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                  loading: () => const LoadingWidget(),
                  error: (_, __) => const SizedBox.shrink(),
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
  final WidgetRef ref;

  const _SectionHeader({required this.title, required this.route, required this.ref});

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

class _TicketStatusBreakdown extends StatelessWidget {
  final List<TicketModel> tickets;
  const _TicketStatusBreakdown({required this.tickets});

  @override
  Widget build(BuildContext context) {
    final prijate = tickets.where((t) => t.status == TicketStatus.prijate).length;
    final vRieseni = tickets.where((t) => t.status == TicketStatus.vRieseni).length;
    final ukoncene = tickets.where((t) => t.status == TicketStatus.ukoncene).length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _StatusRow(label: 'Prijaté', count: prijate, color: AppColors.statusPrijate, total: tickets.length),
            const SizedBox(height: 12),
            _StatusRow(label: 'V riešení', count: vRieseni, color: AppColors.statusVRieseni, total: tickets.length),
            const SizedBox(height: 12),
            _StatusRow(label: 'Ukončené', count: ukoncene, color: AppColors.statusUkoncene, total: tickets.length),
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

  const _StatusRow({required this.label, required this.count, required this.color, required this.total});

  @override
  Widget build(BuildContext context) {
    final fraction = total == 0 ? 0.0 : count / total;
    return Row(
      children: [
        SizedBox(width: 90, child: Text(label, style: const TextStyle(fontSize: 13))),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 12,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text('$count', style: TextStyle(fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }
}
