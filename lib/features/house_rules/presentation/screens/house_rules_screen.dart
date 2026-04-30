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
import '../providers/house_rules_provider.dart';

class HouseRulesScreen extends ConsumerStatefulWidget {
  const HouseRulesScreen({super.key});

  @override
  ConsumerState<HouseRulesScreen> createState() => _HouseRulesScreenState();
}

class _HouseRulesScreenState extends ConsumerState<HouseRulesScreen> {
  final _controller = TextEditingController();
  bool _initialized = false;
  bool _saving = false;
  bool _uploading = false;
  int _modeIndex = 0; // 0 = text, 1 = file
  String? _uploadedFileName;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickAndUpload(String buildingId, String userId) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx', 'doc'],
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;

    final ext = file.extension ?? 'pdf';
    final path = '$buildingId/house_rules.$ext';

    setState(() => _uploading = true);
    try {
      final client = ref.read(supabaseClientProvider);
      await client.storage.from('documents').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(upsert: true, contentType: _contentType(ext)),
          );
      final url = client.storage.from('documents').getPublicUrl(path);

      await ref.read(houseRulesRepositoryProvider).saveHouseRules(
            buildingId: buildingId,
            content: url,
            updatedBy: userId,
          );

      if (mounted) {
        setState(() => _uploadedFileName = file.name);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Súbor nahraný'), backgroundColor: AppColors.success),
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

  String _contentType(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'doc':
        return 'application/msword';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> _saveText(String buildingId, String userId) async {
    setState(() => _saving = true);
    try {
      await ref.read(houseRulesRepositoryProvider).saveHouseRules(
            buildingId: buildingId,
            content: _controller.text,
            updatedBy: userId,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Uložené'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);
    final rulesAsync = ref.watch(houseRulesProvider);

    ref.listen<AsyncValue<String>>(houseRulesProvider, (_, next) {
      if (!_initialized) {
        next.whenData((content) {
          if (!content.startsWith('http')) {
            _controller.text = content;
          }
          _initialized = true;
        });
      }
    });

    return profileAsync.when(
      data: (profile) {
        final isManager = profile?.isManager ?? false;
        final buildingId = profile?.buildingId;

        return Scaffold(
          appBar: const DomovnikAppBar(title: 'Domový poriadok', showBack: true),
          floatingActionButton: isManager && buildingId != null && _modeIndex == 0
              ? FloatingActionButton(
                  onPressed: _saving ? null : () => _saveText(buildingId, profile!.id),
                  tooltip: 'Uložiť',
                  child: _saving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save),
                )
              : null,
          body: rulesAsync.when(
            data: (content) {
              if (isManager) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: ToggleButtons(
                          isSelected: [_modeIndex == 0, _modeIndex == 1],
                          onPressed: (i) => setState(() => _modeIndex = i),
                          borderRadius: BorderRadius.circular(8),
                          children: const [
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                              child: Text('Písať text'),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                              child: Text('Nahrať súbor'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_modeIndex == 0) ...[
                        const Text(
                          'Upravujete domový poriadok',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            maxLines: null,
                            expands: true,
                            textAlignVertical: TextAlignVertical.top,
                            decoration: const InputDecoration(
                              hintText: 'Zadajte text domového poriadku…',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ] else ...[
                        const Text(
                          'Nahrajte PDF alebo Word dokument',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: ElevatedButton.icon(
                            onPressed: _uploading ? null : () => _pickAndUpload(buildingId!, profile!.id),
                            icon: _uploading
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.upload_file),
                            label: Text(_uploading ? 'Nahrávam…' : 'Nahrať PDF / Word'),
                          ),
                        ),
                        if (_uploadedFileName != null) ...[
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle, color: AppColors.success, size: 18),
                              const SizedBox(width: 6),
                              Text(_uploadedFileName!, style: const TextStyle(fontSize: 13)),
                            ],
                          ),
                        ] else if (content.startsWith('http')) ...[
                          const SizedBox(height: 16),
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.insert_drive_file, size: 18, color: AppColors.textSecondary),
                              SizedBox(width: 6),
                              Text('Aktuálny dokument je nahraný', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                            ],
                          ),
                        ],
                      ],
                    ],
                  ),
                );
              }

              // Resident view
              if (content.isEmpty) {
                return const EmptyStateWidget(
                  icon: Icons.menu_book_outlined,
                  message: 'Domový poriadok zatiaľ nebol vytvorený',
                );
              }

              if (content.startsWith('http')) {
                return Center(
                  child: Card(
                    margin: const EdgeInsets.all(24),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.picture_as_pdf, size: 48, color: AppColors.textSecondary),
                          const SizedBox(height: 12),
                          const Text(
                            'Domový poriadok',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => launchUrl(Uri.parse(content), mode: LaunchMode.externalApplication),
                            icon: const Icon(Icons.open_in_new),
                            label: const Text('Otvoriť dokument'),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Text(content, style: const TextStyle(fontSize: 15, height: 1.6)),
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
