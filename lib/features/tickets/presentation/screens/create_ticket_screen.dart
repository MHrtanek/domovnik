import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../../../features/profile/presentation/providers/profile_provider.dart';
import '../../../../shared/widgets/app_bar_widget.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../models/ticket_model.dart';
import '../providers/tickets_provider.dart';

class CreateTicketScreen extends ConsumerStatefulWidget {
  const CreateTicketScreen({super.key});

  @override
  ConsumerState<CreateTicketScreen> createState() => _CreateTicketScreenState();
}

class _CreateTicketScreenState extends ConsumerState<CreateTicketScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  TicketCategory _selectedCategory = TicketCategory.ine;

  // Viacero fotiek
  final List<XFile> _photos = [];
  final List<Uint8List> _photoBytes = [];
  bool _submitting = false;

  static const int _maxPhotos = 5;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    final picker = ImagePicker();
    final remaining = _maxPhotos - _photos.length;
    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Maximálny počet fotiek je $_maxPhotos'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    // Na webe pickMultiImage, na mobile tiež
    final picked = await picker.pickMultiImage(
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );

    if (picked.isEmpty) return;

    // Obmedzíme počet
    final toAdd = picked.take(remaining).toList();
    final newBytes = <Uint8List>[];
    for (final p in toAdd) {
      // Overíme že je to skutočne obrázok podľa mime type
      final bytes = await p.readAsBytes();
      final mime = p.mimeType ?? _mimeFromBytes(bytes);
      if (!mime.startsWith('image/')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Povolené sú len obrázky (jpg, png, webp)'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        continue;
      }
      newBytes.add(bytes);
    }

    setState(() {
      _photos.addAll(toAdd.take(newBytes.length));
      _photoBytes.addAll(newBytes);
    });
  }

  String _mimeFromBytes(Uint8List bytes) {
    if (bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8) return 'image/jpeg';
    if (bytes.length >= 8 && bytes[0] == 0x89 && bytes[1] == 0x50) return 'image/png';
    if (bytes.length >= 6 && bytes[0] == 0x47 && bytes[1] == 0x49) return 'image/gif';
    if (bytes.length >= 4 && bytes[0] == 0x52 && bytes[1] == 0x49) return 'image/webp';
    return 'unknown';
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
      await ref.read(createTicketProvider.notifier).createTicket(
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
            category: _selectedCategory,
            photos: _photos,
            photosBytes: _photoBytes,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tiket bol vytvorený'),
            backgroundColor: AppColors.success,
          ),
        );
        final isManager = ref.read(profileProvider).valueOrNull?.isManager ?? false;
        context.go(isManager ? '/manager/tickets' : '/resident/tickets');
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
      appBar: const DomovnikAppBar(title: 'Nový tiket'),
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
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _titleController,
                          textInputAction: TextInputAction.next,
                          validator: (v) => Validators.required(v, fieldName: 'Názov'),
                          decoration: const InputDecoration(
                            labelText: 'Názov problému *',
                            prefixIcon: Icon(Icons.title),
                          ),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<TicketCategory>(
                          value: _selectedCategory,
                          decoration: const InputDecoration(
                            labelText: 'Kategória *',
                            prefixIcon: Icon(Icons.category_outlined),
                          ),
                          items: TicketCategory.values
                              .map((c) => DropdownMenuItem(value: c, child: Text(c.label)))
                              .toList(),
                          onChanged: (v) => setState(() => _selectedCategory = v!),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _descriptionController,
                          maxLines: 4,
                          textInputAction: TextInputAction.newline,
                          decoration: const InputDecoration(
                            labelText: 'Popis (nepovinný)',
                            prefixIcon: Padding(
                              padding: EdgeInsets.only(bottom: 60),
                              child: Icon(Icons.description_outlined),
                            ),
                            alignLabelWithHint: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Fotografie ────────────────────────────────────────────
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Fotografie',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${_photos.length}/$_maxPhotos',
                              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                            ),
                            const Spacer(),
                            if (_photos.length < _maxPhotos)
                              TextButton.icon(
                                onPressed: _pickPhotos,
                                icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                                label: const Text('Pridať'),
                              ),
                          ],
                        ),
                        const Text(
                          'Povolené len obrázky (jpg, png, webp). Max 5 fotiek.',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        if (_photoBytes.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 120,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _photoBytes.length,
                              itemBuilder: (context, index) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.memory(
                                          _photoBytes[index],
                                          width: 120,
                                          height: 120,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      Positioned(
                                        top: 4,
                                        right: 4,
                                        child: GestureDetector(
                                          onTap: () => _removePhoto(index),
                                          child: Container(
                                            decoration: const BoxDecoration(
                                              color: Colors.black54,
                                              shape: BoxShape.circle,
                                            ),
                                            padding: const EdgeInsets.all(4),
                                            child: const Icon(Icons.close, color: Colors.white, size: 16),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: _pickPhotos,
                            child: Container(
                              height: 80,
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColors.divider, style: BorderStyle.solid),
                                borderRadius: BorderRadius.circular(8),
                                color: AppColors.surface,
                              ),
                              child: const Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.add_photo_alternate_outlined, color: AppColors.textSecondary, size: 28),
                                    SizedBox(height: 4),
                                    Text('Kliknite pre pridanie fotiek', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  child: const Text('Odoslať tiket'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
