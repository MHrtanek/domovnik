import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../features/profile/presentation/providers/profile_provider.dart';
import '../../../../shared/widgets/app_bar_widget.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../providers/building_plan_provider.dart';

class BuildingPlanScreen extends ConsumerStatefulWidget {
  const BuildingPlanScreen({super.key});

  @override
  ConsumerState<BuildingPlanScreen> createState() => _BuildingPlanScreenState();
}

class _BuildingPlanScreenState extends ConsumerState<BuildingPlanScreen> {
  bool _uploading = false;

  bool _isImage(String url) {
    final lower = url.toLowerCase();
    return lower.contains('.jpg') || lower.contains('.jpeg') || lower.contains('.png');
  }

  String _contentType(String ext) {
    switch (ext.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'pdf':
        return 'application/pdf';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> _pickAndUpload(String buildingId) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;

    final ext = file.extension ?? 'pdf';
    final path = '$buildingId/building_plan.$ext';

    setState(() => _uploading = true);
    try {
      final client = ref.read(supabaseClientProvider);
      await client.storage.from('documents').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(upsert: true, contentType: _contentType(ext)),
          );
      final url = client.storage.from('documents').getPublicUrl(path);
      await ref.read(buildingPlanRepositoryProvider).savePlanUrl(buildingId, url);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Plán nahraný'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);
    final planAsync = ref.watch(buildingPlanUrlProvider);

    return profileAsync.when(
      data: (profile) {
        final isManager = profile?.isManager ?? false;
        final buildingId = profile?.buildingId;

        return Scaffold(
          appBar: const DomovnikAppBar(title: 'Plán budovy', showBack: true),
          body: planAsync.when(
            data: (url) {
              if (isManager) {
                return _ManagerView(
                  url: url,
                  uploading: _uploading,
                  isImage: url != null ? _isImage(url) : false,
                  onUpload: buildingId != null ? () => _pickAndUpload(buildingId) : null,
                );
              }

              if (url == null || url.isEmpty) {
                return const EmptyStateWidget(
                  icon: Icons.map_outlined,
                  message: 'Plán budovy zatiaľ nebol nahraný',
                );
              }

              if (_isImage(url)) {
                return InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 5.0,
                  child: Center(
                    child: CachedNetworkImage(
                      imageUrl: url,
                      placeholder: (_, __) => const LoadingWidget(),
                      errorWidget: (_, __, ___) => const DomovnikErrorWidget(message: 'Obrázok sa nedá načítať'),
                    ),
                  ),
                );
              }

              return Center(
                child: Card(
                  margin: const EdgeInsets.all(24),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.picture_as_pdf, size: 56, color: AppColors.textSecondary),
                        const SizedBox(height: 12),
                        const Text('Plán budovy', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
                          icon: const Icon(Icons.open_in_new),
                          label: const Text('Otvoriť plán'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
            loading: () => const LoadingWidget(),
            error: (e, _) => DomovnikErrorWidget(message: e.toString()),
          ),
        );
      },
      loading: () => const Scaffold(body: LoadingWidget()),
      error: (e, _) => Scaffold(body: DomovnikErrorWidget(message: e.toString())),
    );
  }
}

// ── Manager view ─────────────────────────────────────────────────────────────

class _ManagerView extends StatelessWidget {
  final String? url;
  final bool uploading;
  final bool isImage;
  final VoidCallback? onUpload;

  const _ManagerView({
    required this.url,
    required this.uploading,
    required this.isImage,
    required this.onUpload,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: uploading ? null : onUpload,
              icon: uploading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.upload_file),
              label: Text(uploading ? 'Nahrávam…' : 'Nahrať plán'),
            ),
          ),
          const SizedBox(height: 20),
          if (url == null || url!.isEmpty)
            const Expanded(
              child: EmptyStateWidget(
                icon: Icons.map_outlined,
                message: 'Nahrajte plán budovy',
              ),
            )
          else if (isImage)
            Expanded(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 5.0,
                child: Center(
                  child: CachedNetworkImage(
                    imageUrl: url!,
                    placeholder: (_, __) => const LoadingWidget(),
                    errorWidget: (_, __, ___) => const DomovnikErrorWidget(message: 'Obrázok sa nedá načítať'),
                  ),
                ),
              ),
            )
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.picture_as_pdf, size: 56, color: AppColors.textSecondary),
                    const SizedBox(height: 12),
                    const Text('PDF súbor je nahraný', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => launchUrl(Uri.parse(url!), mode: LaunchMode.externalApplication),
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Otvoriť plán'),
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
