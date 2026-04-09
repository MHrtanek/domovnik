import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../features/profile/presentation/providers/profile_provider.dart';
import '../../../../shared/widgets/app_bar_widget.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../models/forum_model.dart';
import '../providers/forum_provider.dart';

class ForumScreen extends ConsumerWidget {
  const ForumScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(forumPostsProvider);
    final profileAsync = ref.watch(profileProvider);
    final currentUserId = profileAsync.maybeWhen(data: (p) => p?.id, orElse: () => null);

    return Scaffold(
      appBar: const DomovnikAppBar(title: 'Fórum', showBack: false),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreatePostDialog(context, ref),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Nový príspevok', style: TextStyle(color: Colors.white)),
      ),
      body: postsAsync.when(
        data: (posts) {
          if (posts.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.forum_outlined,
              message: 'Zatiaľ žiadne príspevky\nBuďte prví!',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              final isOwner = currentUserId == post.createdBy;
              return _PostCard(
                post: post,
                isOwner: isOwner,
                onTap: () => _openPost(context, ref, post),
                onEdit: isOwner ? () => _showEditPostDialog(context, ref, post) : null,
              );
            },
          );
        },
        loading: () => const LoadingWidget(),
        error: (e, _) => DomovnikErrorWidget(
          message: e.toString(),
          onRetry: () => ref.invalidate(forumPostsProvider),
        ),
      ),
    );
  }

  void _showCreatePostDialog(BuildContext context, WidgetRef ref) {
    _showPostDialog(context, ref, null);
  }

  void _showEditPostDialog(BuildContext context, WidgetRef ref, ForumPostModel post) {
    _showPostDialog(context, ref, post);
  }

  void _showPostDialog(BuildContext context, WidgetRef ref, ForumPostModel? existing) {
    final titleController = TextEditingController(text: existing?.title ?? '');
    final contentController = TextEditingController(text: existing?.content ?? '');
    final formKey = GlobalKey<FormState>();
    final isEdit = existing != null;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? 'Upraviť príspevok' : 'Nový príspevok'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Nadpis *'),
                validator: (v) => v == null || v.trim().isEmpty ? 'Zadajte nadpis' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: contentController,
                decoration: const InputDecoration(labelText: 'Text *'),
                maxLines: 4,
                validator: (v) => v == null || v.trim().isEmpty ? 'Zadajte text' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Zrušiť'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.of(ctx).pop();
              if (isEdit) {
                await ref.read(forumRepositoryProvider).updatePost(
                  id: existing.id,
                  title: titleController.text.trim(),
                  content: contentController.text.trim(),
                );
                ref.invalidate(forumPostsProvider);
              } else {
                await ref.read(createForumPostProvider.notifier).createPost(
                  title: titleController.text.trim(),
                  content: contentController.text.trim(),
                );
              }
            },
            child: Text(isEdit ? 'Uložiť' : 'Pridať'),
          ),
        ],
      ),
    );
  }

  void _openPost(BuildContext context, WidgetRef ref, ForumPostModel post) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ForumPostDetailScreen(post: post),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final ForumPostModel post;
  final bool isOwner;
  final VoidCallback onTap;
  final VoidCallback? onEdit;

  const _PostCard({
    required this.post,
    required this.isOwner,
    required this.onTap,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
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
                      post.title,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isOwner)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: InkWell(
                        onTap: onEdit,
                        borderRadius: BorderRadius.circular(16),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.edit_outlined, size: 16, color: AppColors.textSecondary),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                post.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(post.createdByName ?? 'Neznámy', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  const Spacer(),
                  const Icon(Icons.chat_bubble_outline, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text('${post.replyCount}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(width: 12),
                  Text(DateFormatter.formatRelative(post.createdAt), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ForumPostDetailScreen extends ConsumerStatefulWidget {
  final ForumPostModel post;

  const ForumPostDetailScreen({super.key, required this.post});

  @override
  ConsumerState<ForumPostDetailScreen> createState() => _ForumPostDetailScreenState();
}

class _ForumPostDetailScreenState extends ConsumerState<ForumPostDetailScreen> {
  final _replyController = TextEditingController();

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repliesAsync = ref.watch(forumRepliesProvider(widget.post.id));
    final profileAsync = ref.watch(profileProvider);

    return Scaffold(
      appBar: DomovnikAppBar(title: widget.post.title),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  color: AppColors.primary.withValues(alpha: 0.05),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.post.content, style: const TextStyle(fontSize: 15)),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(Icons.person_outline, size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Text(widget.post.createdByName ?? 'Neznámy', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                            const Spacer(),
                            Text(DateFormatter.formatRelative(widget.post.createdAt), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          ],
                        ),
                        profileAsync.maybeWhen(
                          data: (profile) {
                            if (profile == null) return const SizedBox.shrink();
                            if (profile.id == widget.post.createdBy || profile.isManager) {
                              return Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: () async {
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Vymazať príspevok'),
                                        content: const Text('Naozaj chcete vymazať tento príspevok aj so všetkými odpoveďami?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.of(ctx).pop(false),
                                            child: const Text('Zrušiť'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () => Navigator.of(ctx).pop(true),
                                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                                            child: const Text('Vymazať'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirmed != true) return;
                                    try {
                                      await ref.read(forumRepositoryProvider).deletePost(widget.post.id);
                                      ref.invalidate(forumPostsProvider);
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
                                  icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 16),
                                  label: const Text('Vymazať', style: TextStyle(color: AppColors.error)),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                          orElse: () => const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Odpovede', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 8),
                repliesAsync.when(
                  data: (replies) {
                    if (replies.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text('Zatiaľ žiadne odpovede', style: TextStyle(color: AppColors.textSecondary), textAlign: TextAlign.center),
                      );
                    }
                    return Column(
                      children: replies.map((reply) => _ReplyCard(
                        reply: reply,
                        onDelete: () async {
                          try {
                            await ref.read(forumRepositoryProvider).deleteReply(reply.id);
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
                      )).toList(),
                    );
                  },
                  loading: () => const LoadingWidget(),
                  error: (e, _) => Text('Chyba: $e'),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppColors.divider)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _replyController,
                    decoration: const InputDecoration(
                      hintText: 'Napísať odpoveď...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    maxLines: 2,
                    minLines: 1,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _sendReply,
                  icon: const Icon(Icons.send, color: AppColors.primary),
                  style: IconButton.styleFrom(backgroundColor: AppColors.primary.withValues(alpha: 0.1)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;
    _replyController.clear();
    await ref.read(createForumReplyProvider.notifier).createReply(content: text, postId: widget.post.id);
  }
}

class _ReplyCard extends ConsumerWidget {
  final ForumReplyModel reply;
  final VoidCallback onDelete;

  const _ReplyCard({required this.reply, required this.onDelete});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(reply.content, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.person_outline, size: 13, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(reply.createdByName ?? 'Neznámy', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                const Spacer(),
                Text(DateFormatter.formatRelative(reply.createdAt), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                profileAsync.maybeWhen(
                  data: (profile) {
                    if (profile == null) return const SizedBox.shrink();
                    if (profile.id == reply.createdBy || profile.isManager) {
                      return IconButton(
                        icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.error),
                        onPressed: onDelete,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                  orElse: () => const SizedBox.shrink(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
