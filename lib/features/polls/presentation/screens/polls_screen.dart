import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../features/profile/presentation/providers/profile_provider.dart';
import '../../../../shared/widgets/app_bar_widget.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../models/poll_model.dart';
import '../providers/polls_provider.dart';

class PollsScreen extends ConsumerWidget {
  const PollsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pollsAsync = ref.watch(pollsProvider);
    final profileAsync = ref.watch(profileProvider);

    return Scaffold(
      appBar: const DomovnikAppBar(
        title: 'Hlasovanie',
        showBack: false,
        showLogout: true,
      ),
      floatingActionButton: profileAsync.maybeWhen(
        data: (profile) => profile?.isManager == true
            ? FloatingActionButton.extended(
                onPressed: () => context.push('/polls/create'),
                backgroundColor: AppColors.primary,
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text(
                  'Nové hlasovanie',
                  style: TextStyle(color: Colors.white),
                ),
              )
            : null,
        orElse: () => null,
      ),
      body: pollsAsync.when(
        data: (polls) {
          if (polls.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.how_to_vote_outlined,
              message: 'Žiadne hlasovania',
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(pollsProvider),
            child: ListView.builder(
              itemCount: polls.length,
              itemBuilder: (context, index) {
                final poll = polls[index];
                final isManager = profileAsync.maybeWhen(
                  data: (p) => p?.isManager == true,
                  orElse: () => false,
                );
                return _PollCard(
                  poll: poll,
                  isManager: isManager,
                  onTap: () => context.push('/polls/${poll.id}'),
                  onDelete: isManager
                      ? () => _confirmDelete(context, ref, poll)
                      : null,
                );
              },
            ),
          );
        },
        loading: () => const LoadingWidget(),
        error: (e, _) => DomovnikErrorWidget(
          message: e.toString(),
          onRetry: () => ref.invalidate(pollsProvider),
        ),
      ),
    );
  }
}

Future<void> _confirmDelete(
    BuildContext context, WidgetRef ref, PollModel poll) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Odstrániť hlasovanie'),
      content: Text('Naozaj chcete odstrániť hlasovanie „${poll.question}“? Odstránia sa aj všetky hlasy.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Zrušiť')),
        ElevatedButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
          child: const Text('Odstrániť'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  try {
    await ref.read(deletePollProvider.notifier).deletePoll(poll.id);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Chyba: $e'), backgroundColor: AppColors.error),
      );
    }
  }
}

class _PollCard extends StatelessWidget {
  final PollModel poll;
  final bool isManager;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _PollCard({
    required this.poll,
    required this.isManager,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      poll.question,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _PollStatusChip(expired: poll.isExpired, voted: poll.hasVoted),
                  if (onDelete != null) ...[
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: onDelete,
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.delete_outline,
                            size: 18, color: AppColors.error),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.people_outline,
                      size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    '${poll.totalVotes} hlasov',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    DateFormatter.formatExpiry(poll.expiresAt),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              if (poll.options.isNotEmpty) ...[
                const SizedBox(height: 12),
                ...poll.options.take(3).map((option) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              option.optionText,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${(poll.votePercentage(option) * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PollStatusChip extends StatelessWidget {
  final bool expired;
  final bool voted;

  const _PollStatusChip({required this.expired, required this.voted});

  @override
  Widget build(BuildContext context) {
    if (expired) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.textDisabled.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'Skončené',
          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      );
    }

    if (voted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'Hlasoval/a',
          style: TextStyle(
            fontSize: 11,
            color: AppColors.success,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'Aktívne',
        style: TextStyle(
          fontSize: 11,
          color: AppColors.primary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
