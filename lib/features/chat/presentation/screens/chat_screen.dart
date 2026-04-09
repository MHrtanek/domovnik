import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/app_bar_widget.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../models/message_model.dart';
import '../providers/chat_provider.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String otherUserId;

  const ChatScreen({super.key, required this.otherUserId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _markAsRead();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _markAsRead() async {
    final profile = await ref.read(profileProvider.future);
    if (profile == null || profile.buildingId == null) return;
    await ref.read(chatRepositoryProvider).markAsRead(
      buildingId: profile.buildingId!,
      senderId: widget.otherUserId,
      receiverId: profile.id,
    );
    ref.invalidate(conversationsProvider);
  }

  void _scrollToBottom({bool animate = true}) {
    if (!_scrollController.hasClients) return;
    final target = _scrollController.position.maxScrollExtent;
    if (animate) {
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(target);
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      _controller.clear();
      await ref.read(sendMessageProvider.notifier).send(
        receiverId: widget.otherUserId,
        content: text,
      );
    } catch (e) {
      // Restore text so the user can retry
      if (mounted) {
        _controller.text = text;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba pri odosielaní: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(chatMessagesProvider(widget.otherUserId));
    final otherProfileAsync = ref.watch(chatUserProfileProvider(widget.otherUserId));
    final currentUserId = ref.watch(profileProvider).maybeWhen(
      data: (p) => p?.id ?? '',
      orElse: () => '',
    );

    // Scroll na koniec + označiť ako prečítané pri každej novej správe
    ref.listen(chatMessagesProvider(widget.otherUserId), (_, next) {
      if (next is AsyncData) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
        _markAsRead();
      }
    });

    final otherName = otherProfileAsync.maybeWhen(
      data: (p) => p?.fullName ?? p?.email ?? 'Chat',
      orElse: () => 'Chat',
    );

    return Scaffold(
      appBar: DomovnikAppBar(title: otherName),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              data: (messages) {
                if (messages.isEmpty) {
                  return const Center(
                    child: Text(
                      'Žiadne správy.\nZačnite konverzáciu!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  );
                }
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _scrollToBottom(animate: false),
                );
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final showDate = index == 0 ||
                        !_isSameDay(messages[index - 1].createdAt, msg.createdAt);
                    return Column(
                      children: [
                        if (showDate) _DateDivider(date: msg.createdAt),
                        _MessageBubble(
                          message: msg,
                          isMine: msg.isMine(currentUserId),
                        ),
                      ],
                    );
                  },
                );
              },
              loading: () => const LoadingWidget(),
              error: (e, _) => Center(
                child: Text('Chyba: $e', style: const TextStyle(color: AppColors.error)),
              ),
            ),
          ),
          _InputBar(
            controller: _controller,
            sending: _sending,
            onSend: _send,
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    final la = a.toLocal();
    final lb = b.toLocal();
    return la.year == lb.year && la.month == lb.month && la.day == lb.day;
  }
}

// ── Deliaci riadok dátumu ────────────────────────────────────────────────────

class _DateDivider extends StatelessWidget {
  final DateTime date;

  const _DateDivider({required this.date});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final local = date.toLocal();
    String label;
    if (_isSameDay(local, now)) {
      label = 'Dnes';
    } else if (_isSameDay(local, now.subtract(const Duration(days: 1)))) {
      label = 'Včera';
    } else {
      label = DateFormat('d. M. yyyy').format(local);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// ── Bublina správy ───────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMine;

  const _MessageBubble({required this.message, required this.isMine});

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('HH:mm').format(message.createdAt.toLocal());

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMine ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMine ? 18 : 4),
                  bottomRight: Radius.circular(isMine ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.07),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: isMine
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Text(
                    message.content,
                    style: TextStyle(
                      fontSize: 14,
                      color: isMine ? Colors.white : AppColors.textPrimary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        time,
                        style: TextStyle(
                          fontSize: 10,
                          color: isMine
                              ? Colors.white.withValues(alpha: 0.75)
                              : AppColors.textSecondary,
                        ),
                      ),
                      if (isMine) ...[
                        const SizedBox(width: 3),
                        Icon(
                          message.read ? Icons.done_all : Icons.done,
                          size: 12,
                          color: message.read
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.6),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Vstupný riadok ───────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  const _InputBar({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'Napísať správu…',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.newline,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: sending ? null : onSend,
              icon: sending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send, color: AppColors.primary),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
