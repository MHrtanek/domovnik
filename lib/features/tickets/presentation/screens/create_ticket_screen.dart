import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/validators.dart';
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

  XFile? _selectedPhoto;     // XFile works on both web and mobile
  Uint8List? _photoBytes;    // pre-loaded bytes for web preview

  bool _submitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );
    if (picked == null) return;

    // Pre-load bytes once so we can use Image.memory on web
    final bytes = await picked.readAsBytes();
    setState(() {
      _selectedPhoto = picked;
      _photoBytes = bytes;
    });
  }

  void _clearPhoto() => setState(() {
        _selectedPhoto = null;
        _photoBytes = null;
      });

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
            photoFile: _selectedPhoto,
            photoBytes: _photoBytes,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tiket bol vytvorený'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
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

  Widget _buildPhotoPreview() {
    if (_photoBytes != null) {
      // Works on both web and mobile
      return Image.memory(
        _photoBytes!,
        height: 180,
        width: double.infinity,
        fit: BoxFit.cover,
      );
    }
    if (!kIsWeb && _selectedPhoto != null) {
      // Mobile fallback (bytes should always be set, but just in case)
      return Image.file(
        File(_selectedPhoto!.path),
        height: 180,
        width: double.infinity,
        fit: BoxFit.cover,
      );
    }
    return const SizedBox.shrink();
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
                          validator: (v) =>
                              Validators.required(v, fieldName: 'Názov'),
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
                              .map((c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(c.label),
                                  ))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _selectedCategory = v!),
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

                // Photo picker
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Fotografia (nepovinná)',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),

                        if (_selectedPhoto != null) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: _buildPhotoPreview(),
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: _clearPhoto,
                            icon: const Icon(Icons.delete_outline,
                                color: AppColors.error),
                            label: const Text(
                              'Odstrániť fotografiu',
                              style: TextStyle(color: AppColors.error),
                            ),
                          ),
                        ] else
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () =>
                                      _pickPhoto(ImageSource.gallery),
                                  icon: const Icon(Icons.photo_library_outlined),
                                  label: const Text('Galéria'),
                                ),
                              ),
                              // Camera not available on web
                              if (!kIsWeb) ...[
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () =>
                                        _pickPhoto(ImageSource.camera),
                                    icon: const Icon(Icons.camera_alt_outlined),
                                    label: const Text('Kamera'),
                                  ),
                                ),
                              ],
                            ],
                          ),
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
