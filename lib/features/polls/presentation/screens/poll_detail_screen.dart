import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../features/profile/presentation/providers/profile_provider.dart';
import '../../../../shared/widgets/app_bar_widget.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../models/poll_model.dart';
import '../providers/polls_provider.dart';

class PollDetailScreen extends ConsumerWidget {
  final String pollId;
  const PollDetailScreen({super.key, required this.pollId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pollAsync = ref.watch(pollDetailProvider(pollId));
    final profileAsync = ref.watch(profileProvider);

    final isManager = profileAsync.maybeWhen(
      data: (p) => p?.isManager == true,
      orElse: () => false,
    );

    return Scaffold(
      appBar: DomovnikAppBar(
        title: 'Hlasovanie',
        actions: isManager
            ? [
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.white),
                  tooltip: 'Odstrániť hlasovanie',
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Odstrániť hlasovanie'),
                        content: const Text(
                            'Naozaj chcete odstrániť toto hlasovanie? Odstránia sa aj všetky hlasy.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('Zrušiť'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.error),
                            child: const Text('Odstrániť'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed != true) return;
                    try {
                      await ref
                          .read(deletePollProvider.notifier)
                          .deletePoll(pollId);
                      if (context.mounted) Navigator.of(context).pop();
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Chyba: $e'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      }
                    }
                  },
                ),
              ]
            : null,
      ),
      body: pollAsync.when(
        data: (poll) {
          if (poll == null) {
            return const DomovnikErrorWidget(message: 'Hlasovanie sa nenašlo');
          }

          final userId = profileAsync.maybeWhen(
            data: (p) => p?.id,
            orElse: () => null,
          );

          return _PollDetailBody(
            poll: poll,
            userId: userId,
            onVote: (optionId) async {
              if (userId == null) return;
              try {
                await ref.read(voteProvider.notifier).vote(
                      pollId: pollId,
                      optionId: optionId,
                    );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Váš hlas bol zaznamenaný'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Chyba: ${e.toString()}'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
          );
        },
        loading: () => const LoadingWidget(),
        error: (e, _) => DomovnikErrorWidget(message: e.toString()),
      ),
    );
  }
}

class _PollDetailBody extends StatefulWidget {
  final PollModel poll;
  final String? userId;
  final Future<void> Function(String optionId) onVote;

  const _PollDetailBody({
    required this.poll,
    required this.userId,
    required this.onVote,
  });

  @override
  State<_PollDetailBody> createState() => _PollDetailBodyState();
}

class _PollDetailBodyState extends State<_PollDetailBody> {
  String? _selectedOptionId;
  bool _voting = false;

  bool get _canVote =>
      !widget.poll.hasVoted &&
      !widget.poll.isExpired &&
      widget.userId != null;

  Future<void> _submitVote() async {
    if (_selectedOptionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vyberte možnosť'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _voting = true);
    await widget.onVote(_selectedOptionId!);
    if (mounted) setState(() => _voting = false);
  }

  @override
  Widget build(BuildContext context) {
    final poll = widget.poll;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Question card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    poll.question,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.people_outline,
                          size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        '${poll.totalVotes} hlasov',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Icon(Icons.access_time_outlined,
                          size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        DateFormatter.formatExpiry(poll.expiresAt),
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  if (poll.isExpired) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.textDisabled.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Hlasovanie skončilo',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ] else if (poll.hasVoted) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Hlasoval/a ste',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.success,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Options
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _canVote ? 'Vyberte možnosť:' : 'Výsledky:',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...poll.options.map((option) => _OptionItem(
                        option: option,
                        totalVotes: poll.totalVotes,
                        percentage: poll.votePercentage(option),
                        canVote: _canVote,
                        selected: _selectedOptionId == option.id,
                        onTap: _canVote
                            ? () =>
                                setState(() => _selectedOptionId = option.id)
                            : null,
                      )),
                ],
              ),
            ),
          ),

          if (_canVote) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _voting ? null : _submitVote,
              child: _voting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Hlasovať'),
            ),
          ],
        ],
      ),
    );
  }
}

class _OptionItem extends StatelessWidget {
  final PollOptionModel option;
  final int totalVotes;
  final double percentage;
  final bool canVote;
  final bool selected;
  final VoidCallback? onTap;

  const _OptionItem({
    required this.option,
    required this.totalVotes,
    required this.percentage,
    required this.canVote,
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.divider,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (canVote) ...[
                    Icon(
                      selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: selected
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      option.optionText,
                      style: TextStyle(
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color: selected
                            ? AppColors.primary
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (!canVote)
                    Text(
                      '${option.voteCount} (${(percentage * 100).toStringAsFixed(0)}%)',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
              if (!canVote) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: percentage,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                    minHeight: 8,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
