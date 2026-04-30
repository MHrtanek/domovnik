import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../features/profile/presentation/providers/profile_provider.dart';
import '../../../../shared/widgets/app_bar_widget.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../providers/announcements_provider.dart';

const _titleMaxLength = 100;
const _contentMaxLength = 2000;
const _maxPhotos = 5;
const _maxPhotoBytes = 5 * 1024 * 1024; // 5 MB
const _allowedMimes = {'image/jpeg', 'image/png', 'image/gif', 'image/webp'};

class CreateAnnouncementScreen extends ConsumerStatefulWidget {
  const CreateAnnouncementScreen({super.key});

  @override
  ConsumerState<CreateAnnouncementScreen> createState() =>
      _CreateAnnouncementScreenState();
}

class _CreateAnnouncementScreenState
    extends ConsumerState<CreateAnnouncementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  bool _isUrgent = false;
  bool _submitting = false;

  int _titleLen = 0;
  int _contentLen = 0;

  final List<XFile> _photos = [];
  final List<Uint8List> _photoBytes = [];

  @override
  void initState() {
    super.initState();
    _titleController.addListener(() => setState(() => _titleLen = _titleController.text.length));
    _contentController.addListener(() => setState(() => _contentLen = _contentController.text.length));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    final remaining = _maxPhotos - _photos.length;
    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Maximálny počet obrázkov je $_maxPhotos'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(imageQuality: 85);
    if (picked.isEmpty) return;

    final toAdd = picked.take(remaining).toList();
    for (final file in toAdd) {
      final bytes = await file.readAsBytes();

      // Validácia MIME
      final mime = file.mimeType ?? _mimeFromExt(file.name);
      if (!_allowedMimes.contains(mime)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Povolené sú len obrázky (jpg, jpeg, png, gif, webp)'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        continue;
      }

      // Validácia veľkosti
      if (bytes.length > _maxPhotoBytes) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Obrázok ${file.name} je väčší ako 5 MB'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        continue;
      }

      setState(() {
        _photos.add(file);
        _photoBytes.add(bytes);
      });
    }
  }

  void _removePhoto(int index) {
    setState(() {
      _photos.removeAt(index);
      _photoBytes.removeAt(index);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    try {
      // Nahraj obrázky
      final photoUrls = <String>[];
      for (int i = 0; i < _photos.length; i++) {
        final mime = _photos[i].mimeType ?? _mimeFromExt(_photos[i].name);
        final url = await ref
            .read(announcementRepositoryProvider)
            .uploadAnnouncementPhoto(_photoBytes[i], mime);
        photoUrls.add(url);
      }

      await ref.read(createAnnouncementProvider.notifier).createAnnouncement(
            title: _titleController.text.trim(),
            content: _contentController.text.trim(),
            isUrgent: _isUrgent,
            photoUrls: photoUrls,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Oznam bol vytvorený'),
            backgroundColor: AppColors.success,
          ),
        );
        final isManager = ref.read(profileProvider).valueOrNull?.isManager ?? false;
        context.go(isManager ? '/manager/announcements' : '/resident/announcements');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chyba: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const DomovnikAppBar(title: 'Nový oznam'),
      body: LoadingOverlay(
        isLoading: _submitting,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // ── Nadpis ──────────────────────────────────────
                        TextFormField(
                          controller: _titleController,
                          textInputAction: TextInputAction.next,
                          maxLength: _titleMaxLength,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Zadajte nadpis';
                            return null;
                          },
                          decoration: InputDecoration(
                            labelText: 'Nadpis *',
                            prefixIcon: const Icon(Icons.title),
                            counterText: '$_titleLen/$_titleMaxLength',
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ── Obsah ────────────────────────────────────────
                        TextFormField(
                          controller: _contentController,
                          maxLines: 6,
                          maxLength: _contentMaxLength,
                          textInputAction: TextInputAction.newline,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Zadajte obsah';
                            return null;
                          },
                          decoration: InputDecoration(
                            labelText: 'Obsah *',
                            alignLabelWithHint: true,
                            prefixIcon: const Padding(
                              padding: EdgeInsets.only(bottom: 100),
                              child: Icon(Icons.article_outlined),
                            ),
                            counterText: '$_contentLen/$_contentMaxLength',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // ── Dôležité ─────────────────────────────────────────────
                Card(
                  child: SwitchListTile(
                    title: const Text(
                      'Dôležité oznámenie',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: const Text(
                      'Zobrazí sa zvýraznené oranžovou farbou',
                      style: TextStyle(fontSize: 12),
                    ),
                    secondary: Icon(
                      Icons.priority_high,
                      color: _isUrgent ? AppColors.accent : AppColors.textDisabled,
                    ),
                    value: _isUrgent,
                    activeThumbColor: AppColors.accent,
                    onChanged: (v) => setState(() => _isUrgent = v),
                  ),
                ),
                const SizedBox(height: 12),

                // ── Obrázky ──────────────────────────────────────────────
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Obrázky',
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                            ),
                            const Spacer(),
                            Text(
                              '${_photos.length}/$_maxPhotos',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Max 5 MB na obrázok · jpg, jpeg, png, gif, webp',
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                        if (_photos.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 90,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _photos.length,
                              itemBuilder: (context, index) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.memory(
                                          _photoBytes[index],
                                          width: 90,
                                          height: 90,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      Positioned(
                                        top: 2,
                                        right: 2,
                                        child: GestureDetector(
                                          onTap: () => _removePhoto(index),
                                          child: Container(
                                            padding: const EdgeInsets.all(2),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(alpha: 0.6),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(Icons.close, size: 14, color: Colors.white),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        if (_photos.length < _maxPhotos)
                          OutlinedButton.icon(
                            onPressed: _pickPhotos,
                            icon: const Icon(Icons.add_photo_alternate_outlined),
                            label: const Text('Pridať obrázok'),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  child: const Text('Zverejniť oznam'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _mimeFromExt(String filename) {
    final ext = filename.toLowerCase().split('.').last;
    switch (ext) {
      case 'png':  return 'image/png';
      case 'gif':  return 'image/gif';
      case 'webp': return 'image/webp';
      default:     return 'image/jpeg';
    }
  }
}
