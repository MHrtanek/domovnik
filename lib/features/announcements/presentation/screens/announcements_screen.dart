import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../features/profile/presentation/providers/profile_provider.dart';
import '../../../../shared/widgets/app_bar_widget.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../models/announcement_model.dart';
import '../providers/announcements_provider.dart';

class AnnouncementsScreen extends ConsumerWidget {
  const AnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final announcementsAsync = ref.watch(buildingAnnouncementsProvider);
    final profileAsync = ref.watch(profileProvider);
    final isManager = profileAsync.maybeWhen(
      data: (p) => p?.isManager ?? false,
      orElse: () => false,
    );

    return Scaffold(
      appBar: DomovnikAppBar(
        title: 'Oznamy',
        showBack: false,
        showLogout: true,
      ),
      floatingActionButton: isManager
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/announcements/create'),
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Nový oznam', style: TextStyle(color: Colors.white)),
            )
          : null,
      body: announcementsAsync.when(
        data: (announcements) {
          if (announcements.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.campaign_outlined, size: 64, color: AppColors.textSecondary.withValues(alpha: 0.4)),
                    const SizedBox(height: 16),
                    const Text(
                      'Žiadne oznamy',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isManager
                          ? 'Informujte obyvateľov o dôležitých veciach.'
                          : 'Správca zatiaľ nepridali žiadne oznamy.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(buildingAnnouncementsProvider),
            child: ListView.builder(
              itemCount: announcements.length,
              itemBuilder: (context, index) {
                final announcement = announcements[index];
                return _AnnouncementCard(
                  announcement: announcement,
                  isManager: isManager,
                  onDelete: isManager
                      ? () => _confirmDelete(context, ref, announcement)
                      : null,
                );
              },
            ),
          );
        },
        loading: () => const LoadingWidget(),
        error: (e, _) => DomovnikErrorWidget(
          message: e.toString(),
          onRetry: () => ref.invalidate(buildingAnnouncementsProvider),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    AnnouncementModel announcement,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Odstrániť oznam'),
        content: Text('Naozaj chcete odstrániť „${announcement.title}"?'),
        actions: [
          TextButton(onPressed: () => ctx.pop(false), child: const Text('Zrušiť')),
          ElevatedButton(
            onPressed: () => ctx.pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Odstrániť'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(createAnnouncementProvider.notifier).deleteAnnouncement(announcement.id);
        ref.invalidate(buildingAnnouncementsProvider);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Chyba: ${e.toString()}'), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }
}

void _showPhoto(BuildContext context, List<String> urls, int initialIndex) {
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => _PhotoViewScreen(urls: urls, initialIndex: initialIndex),
  ));
}

class _PhotoViewScreen extends StatefulWidget {
  final List<String> urls;
  final int initialIndex;
  const _PhotoViewScreen({required this.urls, required this.initialIndex});
  @override
  State<_PhotoViewScreen> createState() => _PhotoViewScreenState();
}

class _PhotoViewScreenState extends State<_PhotoViewScreen> {
  late int _current;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_current + 1} / ${widget.urls.length}'),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.urls.length,
        onPageChanged: (i) => setState(() => _current = i),
        itemBuilder: (context, index) => InteractiveViewer(
          child: Center(
            child: CachedNetworkImage(
              imageUrl: widget.urls[index],
              fit: BoxFit.contain,
              placeholder: (_, __) => const Center(child: CircularProgressIndicator(color: Colors.white)),
              errorWidget: (_, __, ___) => const Icon(Icons.broken_image_outlined, color: Colors.white, size: 48),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  final AnnouncementModel announcement;
  final bool isManager;
  final VoidCallback? onDelete;

  const _AnnouncementCard({
    required this.announcement,
    required this.isManager,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: announcement.isUrgent
            ? const BorderSide(color: AppColors.urgentBorder, width: 1.5)
            : BorderSide.none,
      ),
      color: announcement.isUrgent ? AppColors.urgentBackground : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (announcement.isUrgent) ...[
                  const Icon(Icons.priority_high, color: AppColors.accent, size: 20),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(
                    announcement.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: announcement.isUrgent ? AppColors.accentDark : AppColors.textPrimary,
                    ),
                  ),
                ),
                if (onDelete != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppColors.textSecondary),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: onDelete,
                  ),
              ],
            ),
            if (announcement.isUrgent) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(4)),
                child: const Text(
                  'DÔLEŽITÉ',
                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(announcement.content, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, height: 1.5)),
            if (announcement.photoUrls.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: announcement.photoUrls.length,
                  itemBuilder: (context, i) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => _showPhoto(context, announcement.photoUrls, i),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: announcement.photoUrls[i],
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(DateFormatter.formatRelative(announcement.createdAt), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
