import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
            // Obyvateľ: záznam správcu z conversationsProvider
            return const _ResidentManagerCard();
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

/// Resident view: použije rovnaký conversationsProvider ako manažér.
/// Pre rezidenta provider vráti práve jeden záznam – správcu budovy.
class _ResidentManagerCard extends ConsumerWidget {
  const _ResidentManagerCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(conversationsProvider);

    return conversationsAsync.when(
      data: (entries) {
        if (entries.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.manage_accounts_outlined,
            message: 'Správca budovy nenájdený',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(conversationsProvider),
          child: ListView(
            children: [
              _ConversationTile(
                entry: entries.first,
                onTap: () => context.push('/chat/${entries.first.profile.id}'),
              ),
            ],
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
