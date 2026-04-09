import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/app_bar_widget.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../providers/announcements_provider.dart';

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

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    try {
      await ref.read(createAnnouncementProvider.notifier).createAnnouncement(
            title: _titleController.text.trim(),
            content: _contentController.text.trim(),
            isUrgent: _isUrgent,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Oznam bol vytvorený'),
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
                        TextFormField(
                          controller: _titleController,
                          textInputAction: TextInputAction.next,
                          validator: (v) =>
                              Validators.required(v, fieldName: 'Nadpis'),
                          decoration: const InputDecoration(
                            labelText: 'Nadpis *',
                            prefixIcon: Icon(Icons.title),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _contentController,
                          maxLines: 6,
                          textInputAction: TextInputAction.newline,
                          validator: (v) =>
                              Validators.required(v, fieldName: 'Obsah'),
                          decoration: const InputDecoration(
                            labelText: 'Obsah *',
                            alignLabelWithHint: true,
                            prefixIcon: Padding(
                              padding: EdgeInsets.only(bottom: 100),
                              child: Icon(Icons.article_outlined),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

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
}
