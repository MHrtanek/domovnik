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

// ── Dialog pre vytvorenie / úpravu príspevku ─────────────────────────────────

void _showPostDialog(BuildContext context, WidgetRef ref, ForumPostModel? existing) {
  final isManager = ref.read(profileProvider).maybeWhen(
    data: (p) => p?.isManager ?? false,
    orElse: () => false,
  );
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
              decoration: InputDecoration(
                labelText: 'Text *',
                helperText: isManager ? null : 'Max 500 znakov',
              ),
              maxLines: 4,
              maxLength: isManager ? null : 500,
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

// ── ForumScreen ──────────────────────────────────────────────────────────────

class ForumScreen extends ConsumerWidget {
  const ForumScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(forumPostsProvider);
    final profileAsync = ref.watch(profileProvider);
    final currentUserId = profileAsync.maybeWhen(data: (p) => p?.id, orElse: () => null);
    final isManager = profileAsync.maybeWhen(data: (p) => p?.isManager ?? false, orElse: () => false);

    return Scaffold(
      appBar: const DomovnikAppBar(title: 'Fórum', showBack: false),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showPostDialog(context, ref, null),
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
              final canAct = currentUserId == post.createdBy || isManager;
              return _PostCard(
                post: post,
                canAct: canAct,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ForumPostDetailScreen(post: post)),
                ),
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
}

// ── Karta príspevku v zozname ─────────────────────────────────────────────────

class _PostCard extends ConsumerWidget {
  final ForumPostModel post;
  final bool canAct;
  final VoidCallback onTap;

  const _PostCard({
    required this.post,
    required this.canAct,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasLiked = ref.watch(hasLikedPostProvider(post.id)).maybeWhen(
      data: (v) => v,
      orElse: () => false,
    );

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
              Text(
                post.title,
                style: Theme.of(context).textTheme.titleMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
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
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (canAct) ...[
                    _ActionIcon(
                      icon: Icons.edit_outlined,
                      onTap: () => _showPostDialog(context, ref, post),
                    ),
                    _ActionIcon(
                      icon: Icons.delete_outline,
                      color: AppColors.error,
                      onTap: () => _confirmDelete(context, ref),
                    ),
                  ],
                  _ActionIcon(
                    icon: hasLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                    color: hasLiked ? AppColors.primary : AppColors.textSecondary,
                    label: '${post.likesCount}',
                    onTap: () => _like(ref),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
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
      await ref.read(forumRepositoryProvider).deletePost(post.id);
      ref.invalidate(forumPostsProvider);
      ref.invalidate(forumRepliesProvider(post.id));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _like(WidgetRef ref) async {
    try {
      await ref.read(forumRepositoryProvider).incrementPostLikes(post.id);
      ref.invalidate(forumPostsProvider);
      ref.invalidate(hasLikedPostProvider(post.id));
    } catch (_) {}
  }
}

// ── Detail príspevku ─────────────────────────────────────────────────────────

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
    final isManager = profileAsync.maybeWhen(data: (p) => p?.isManager ?? false, orElse: () => false);

    return Scaffold(
      appBar: DomovnikAppBar(title: widget.post.title),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Karta príspevku ──────────────────────────────────────
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
                            Text(
                              widget.post.createdByName ?? 'Neznámy',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                            ),
                            const Spacer(),
                            Text(DateFormatter.formatRelative(widget.post.createdAt), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          ],
                        ),
                        Builder(builder: (context) {
                          final profile = profileAsync.valueOrNull;
                          final canAct = profile != null &&
                              (profile.id == widget.post.createdBy || profile.isManager);
                          final hasLiked = ref.watch(hasLikedPostProvider(widget.post.id))
                              .maybeWhen(data: (v) => v, orElse: () => false);
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (canAct) ...[
                                  _ActionIcon(
                                    icon: Icons.edit_outlined,
                                    onTap: () => _showPostDialog(context, ref, widget.post),
                                  ),
                                  _ActionIcon(
                                    icon: Icons.delete_outline,
                                    color: AppColors.error,
                                    onTap: () => _confirmDeletePost(context),
                                  ),
                                ],
                                _ActionIcon(
                                  icon: hasLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                                  color: hasLiked ? AppColors.primary : AppColors.textSecondary,
                                  label: '${widget.post.likesCount}',
                                  onTap: _likePost,
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                const Text('Odpovede', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 8),

                // ── Odpovede ─────────────────────────────────────────────
                repliesAsync.when(
                  data: (replies) {
                    if (replies.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'Zatiaľ žiadne odpovede',
                          style: TextStyle(color: AppColors.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }
                    return Column(
                      children: replies.map((reply) => _ReplyCard(
                        reply: reply,
                        onDelete: () async {
                          try {
                            await ref.read(forumRepositoryProvider).deleteReply(reply.id);
                            ref.invalidate(forumRepliesProvider(widget.post.id));
                            ref.invalidate(forumPostsProvider);
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Chyba: $e'), backgroundColor: AppColors.error),
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

          // ── Vstup pre odpoveď ────────────────────────────────────────
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
                    maxLength: isManager ? null : 500,
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

  Future<void> _confirmDeletePost(BuildContext context) async {
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
      ref.invalidate(forumRepliesProvider(widget.post.id));
      if (context.mounted) Navigator.of(context).pop();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _likePost() async {
    try {
      await ref.read(forumRepositoryProvider).incrementPostLikes(widget.post.id);
      ref.invalidate(forumPostsProvider);
      ref.invalidate(hasLikedPostProvider(widget.post.id));
    } catch (_) {}
  }
}

// ── Karta odpovede ────────────────────────────────────────────────────────────

class _ReplyCard extends ConsumerStatefulWidget {
  final ForumReplyModel reply;
  final VoidCallback onDelete;

  const _ReplyCard({required this.reply, required this.onDelete});

  @override
  ConsumerState<_ReplyCard> createState() => _ReplyCardState();
}

class _ReplyCardState extends ConsumerState<_ReplyCard> {
  bool _editing = false;
  late final TextEditingController _editController;

  @override
  void initState() {
    super.initState();
    _editController = TextEditingController(text: widget.reply.content);
  }

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  Future<void> _saveEdit() async {
    final text = _editController.text.trim();
    if (text.isEmpty) return;
    try {
      await ref.read(forumRepositoryProvider).updateReply(
        id: widget.reply.id,
        content: text,
      );
      ref.invalidate(forumRepliesProvider(widget.reply.postId));
      if (mounted) setState(() => _editing = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Vymazať odpoveď'),
        content: const Text('Naozaj chcete vymazať túto odpoveď?'),
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
    if (confirmed == true) widget.onDelete();
  }

  Future<void> _like() async {
    try {
      await ref.read(forumRepositoryProvider).incrementReplyLikes(widget.reply.id);
      ref.invalidate(forumRepliesProvider(widget.reply.postId));
      ref.invalidate(hasLikedReplyProvider(widget.reply.id));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);
    final canAct = profileAsync.maybeWhen(
      data: (p) => p != null && (p.id == widget.reply.createdBy || p.isManager),
      orElse: () => false,
    );
    final isManager = profileAsync.maybeWhen(
      data: (p) => p?.isManager ?? false,
      orElse: () => false,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: _editing ? _buildEditView(isManager) : _buildReadView(canAct),
      ),
    );
  }

  Widget _buildEditView(bool isManager) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _editController,
          maxLines: 4,
          minLines: 1,
          maxLength: isManager ? null : 500,
          autofocus: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => setState(() {
                _editing = false;
                _editController.text = widget.reply.content;
              }),
              child: const Text('Zrušiť'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _saveEdit,
              child: const Text('Uložiť'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReadView(bool canAct) {
    final hasLiked = ref.watch(hasLikedReplyProvider(widget.reply.id))
        .maybeWhen(data: (v) => v, orElse: () => false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.reply.content, style: const TextStyle(fontSize: 14)),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.person_outline, size: 13, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(
              widget.reply.createdByName ?? 'Neznámy',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            Text(DateFormatter.formatRelative(widget.reply.createdAt), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (canAct) ...[
              _ActionIcon(
                icon: Icons.edit_outlined,
                onTap: () => setState(() => _editing = true),
              ),
              _ActionIcon(
                icon: Icons.delete_outline,
                color: AppColors.error,
                onTap: _confirmDelete,
              ),
            ],
            _ActionIcon(
              icon: hasLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
              color: hasLiked ? AppColors.primary : AppColors.textSecondary,
              label: '${widget.reply.likesCount}',
              onTap: _like,
            ),
          ],
        ),
      ],
    );
  }
}

// ── Akčná ikona ───────────────────────────────────────────────────────────────

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String? label;
  final VoidCallback onTap;

  const _ActionIcon({
    required this.icon,
    required this.onTap,
    this.color = AppColors.textSecondary,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            if (label != null) ...[
              const SizedBox(width: 3),
              Text(label!, style: TextStyle(fontSize: 11, color: color)),
            ],
          ],
        ),
      ),
    );
  }
}
