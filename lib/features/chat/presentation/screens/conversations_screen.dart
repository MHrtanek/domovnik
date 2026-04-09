import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../features/profile/presentation/providers/profile_provider.dart';
import '../../../../shared/widgets/app_bar_widget.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../providers/chat_provider.dart';

class ConversationsScreen extends ConsumerWidget {
  const ConversationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);

    return Scaffold(
      appBar: const DomovnikAppBar(
        title: 'Správy',
        showBack: false,
        showLogout: true,
      ),
      body: profileAsync.when(
        data: (profile) {
          if (profile == null) return const LoadingWidget();
          if (!profile.isManager) {
            // Obyvateľ: priama karta pre správcu budovy
            return _ResidentManagerCard(buildingId: profile.buildingId ?? '');
          }
          // Správca: zoznam konverzácií so všetkými obyvateľmi
          return const _ManagerConversationsList();
        },
        loading: () => const LoadingWidget(),
        error: (e, _) => DomovnikErrorWidget(
          message: e.toString(),
          onRetry: () => ref.invalidate(profileProvider),
        ),
      ),
    );
  }
}

// ── Resident view ─────────────────────────────────────────────────────────────

class _ResidentManagerCard extends StatefulWidget {
  final String buildingId;

  const _ResidentManagerCard({required this.buildingId});

  @override
  State<_ResidentManagerCard> createState() => _ResidentManagerCardState();
}

class _ResidentManagerCardState extends State<_ResidentManagerCard> {
  Map<String, dynamic>? _manager;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadManager();
  }

  Future<void> _loadManager() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await Supabase.instance.client
          .rpc('get_building_manager', params: {'p_building_id': widget.buildingId});
      // RPC môže vrátiť List alebo Map – normalizuj na Map?
      Map<String, dynamic>? manager;
      if (result is Map<String, dynamic>) {
        manager = result;
      } else if (result is List && result.isNotEmpty) {
        manager = result.first as Map<String, dynamic>;
      }
      if (mounted) setState(() {
        _manager = manager;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingWidget();

    if (_error != null) {
      return DomovnikErrorWidget(message: _error!, onRetry: _loadManager);
    }

    if (_manager == null) {
      return const EmptyStateWidget(
        icon: Icons.manage_accounts_outlined,
        message: 'Správca budovy nenájdený',
      );
    }

    final name = (_manager!['full_name'] as String?)?.isNotEmpty == true
        ? _manager!['full_name'] as String
        : 'Správca';
    final managerId = _manager!['id'] as String;
    final initials = name[0].toUpperCase();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.withValues(alpha: 0.15)),
        ),
        child: InkWell(
          onTap: () => context.push('/chat/$managerId'),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Správca budovy · Napísať správu',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Manager view ──────────────────────────────────────────────────────────────

class _ManagerConversationsList extends ConsumerWidget {
  const _ManagerConversationsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(conversationsProvider);

    return conversationsAsync.when(
      data: (entries) {
        if (entries.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.chat_outlined,
            message: 'Žiadne konverzácie',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(conversationsProvider),
          child: ListView.separated(
            itemCount: entries.length,
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 76),
            itemBuilder: (context, index) {
              return _ConversationTile(
                entry: entries[index],
                onTap: () =>
                    context.push('/chat/${entries[index].profile.id}'),
              );
            },
          ),
        );
      },
      loading: () => const LoadingWidget(),
      error: (e, _) => DomovnikErrorWidget(
        message: e.toString(),
        onRetry: () => ref.invalidate(conversationsProvider),
      ),
    );
  }
}

// ── Conversation tile (manager view only) ─────────────────────────────────────

class _ConversationTile extends StatelessWidget {
  final ConversationEntry entry;
  final VoidCallback onTap;

  const _ConversationTile({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final profile = entry.profile;
    final initials = (profile.fullName?.isNotEmpty == true
            ? profile.fullName![0]
            : profile.email[0])
        .toUpperCase();
    final lastMsg = entry.lastMessage;
    final hasUnread = entry.unreadCount > 0;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            child: Text(
              initials,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          if (hasUnread)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: AppColors.error,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${entry.unreadCount}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
      title: Text(
        profile.fullName ?? profile.email,
        style: TextStyle(
          fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w500,
          fontSize: 15,
        ),
      ),
      subtitle: lastMsg != null
          ? Text(
              lastMsg.content,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: hasUnread
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                fontWeight:
                    hasUnread ? FontWeight.w500 : FontWeight.normal,
                fontSize: 13,
              ),
            )
          : const Text(
              'Žiadne správy',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
      trailing: lastMsg != null
          ? Text(
              DateFormatter.formatRelative(lastMsg.createdAt),
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            )
          : null,
      onTap: onTap,
    );
  }
}
