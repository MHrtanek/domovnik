import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../shared/widgets/app_bar_widget.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../models/ticket_model.dart';
import '../providers/tickets_provider.dart';

class SupplierTicketsScreen extends ConsumerWidget {
  const SupplierTicketsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticketsAsync = ref.watch(filteredTicketsProvider);
    final filter = ref.watch(ticketFilterProvider);

    return Scaffold(
      appBar: DomovnikAppBar(
        title: 'Moje tikety',
        showBack: false,
        showLogout: true,
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _FilterChip(
                  label: 'Všetky',
                  selected: filter == TicketFilterStatus.all,
                  onTap: () => ref.read(ticketFilterProvider.notifier).state = TicketFilterStatus.all,
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'V riešení',
                  selected: filter == TicketFilterStatus.vRieseni,
                  color: AppColors.statusVRieseni,
                  onTap: () => ref.read(ticketFilterProvider.notifier).state = TicketFilterStatus.vRieseni,
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Ukončené',
                  selected: filter == TicketFilterStatus.ukoncene,
                  color: AppColors.statusUkoncene,
                  onTap: () => ref.read(ticketFilterProvider.notifier).state = TicketFilterStatus.ukoncene,
                ),
              ],
            ),
          ),
          Expanded(
            child: ticketsAsync.when(
              data: (tickets) {
                if (tickets.isEmpty) {
                  return const EmptyStateWidget(
                    icon: Icons.build_outlined,
                    message: 'Žiadne priradené tikety',
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  itemCount: tickets.length,
                  itemBuilder: (context, index) {
                    final ticket = tickets[index];
                    return _SupplierTicketCard(
                      ticket: ticket,
                      onTap: () => context.go('/supplier/tickets/${ticket.id}'),
                    );
                  },
                );
              },
              loading: () => const LoadingWidget(),
              error: (e, _) => DomovnikErrorWidget(
                message: e.toString(),
                onRetry: () => ref.invalidate(ticketsProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = color ?? AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? activeColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? activeColor : AppColors.divider),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _SupplierTicketCard extends StatelessWidget {
  final TicketModel ticket;
  final VoidCallback onTap;

  const _SupplierTicketCard({required this.ticket, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      ticket.title,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  StatusBadge(status: ticket.status),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  CategoryChip(category: ticket.category),
                  const Spacer(),
                  Text(
                    DateFormatter.formatRelative(ticket.createdAt),
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
              if (ticket.createdByName != null && ticket.createdByName!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.person_outline, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      ticket.createdByName!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
              if (ticket.description != null && ticket.description!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  ticket.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
