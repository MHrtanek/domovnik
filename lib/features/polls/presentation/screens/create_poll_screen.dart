import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/app_bar_widget.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../providers/polls_provider.dart';

// Defined at class level to avoid re-construction and locale-init race on web
final _dateFormat = DateFormat('d. M. yyyy');

class CreatePollScreen extends ConsumerStatefulWidget {
  const CreatePollScreen({super.key});

  @override
  ConsumerState<CreatePollScreen> createState() => _CreatePollScreenState();
}

class _CreatePollScreenState extends ConsumerState<CreatePollScreen> {
  final _formKey = GlobalKey<FormState>();
  final _questionController = TextEditingController();
  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];
  DateTime? _expiresAt;
  bool _submitting = false;

  @override
  void dispose() {
    _questionController.dispose();
    for (final c in _optionControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    setState(() => _optionControllers.add(TextEditingController()));
  }

  void _removeOption(int index) {
    if (_optionControllers.length <= 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hlasovanie musí mať aspoň 2 možnosti'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }
    final controller = _optionControllers.removeAt(index);
    controller.dispose();
    setState(() {});
  }

  Future<void> _pickExpiryDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() => _expiresAt = picked.add(const Duration(
            hours: 23,
            minutes: 59,
            seconds: 59,
          )));
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final options = _optionControllers
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    if (options.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Zadajte aspoň 2 možnosti'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      await ref.read(createPollProvider.notifier).createPoll(
            question: _questionController.text.trim(),
            options: options,
            expiresAt: _expiresAt,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Hlasovanie bolo vytvorené'),
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
      appBar: const DomovnikAppBar(title: 'Nové hlasovanie'),
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
                    child: TextFormField(
                      controller: _questionController,
                      maxLines: 2,
                      textInputAction: TextInputAction.next,
                      validator: (v) =>
                          Validators.required(v, fieldName: 'Otázka'),
                      decoration: const InputDecoration(
                        labelText: 'Otázka *',
                        prefixIcon: Padding(
                          padding: EdgeInsets.only(bottom: 24),
                          child: Icon(Icons.help_outline),
                        ),
                        alignLabelWithHint: true,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Možnosti hlasovania',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),

                        ...List.generate(_optionControllers.length, (i) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _optionControllers[i],
                                    textInputAction: TextInputAction.next,
                                    validator: Validators.pollOption,
                                    decoration: InputDecoration(
                                      labelText: 'Možnosť ${i + 1} *',
                                      prefixIcon:
                                          const Icon(Icons.radio_button_unchecked),
                                    ),
                                  ),
                                ),
                                if (_optionControllers.length > 2) ...[
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline,
                                        color: AppColors.error),
                                    onPressed: () => _removeOption(i),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }),

                        TextButton.icon(
                          onPressed: _addOption,
                          icon: const Icon(Icons.add_circle_outline),
                          label: const Text('Pridať možnosť'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Trvanie hlasovania',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _expiresAt != null
                                    ? 'Do: ${_dateFormat.format(_expiresAt!)}'
                                    : 'Bez obmedzenia',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                            if (_expiresAt != null)
                              TextButton(
                                onPressed: () =>
                                    setState(() => _expiresAt = null),
                                child: const Text('Zrušiť'),
                              ),
                            Flexible(
                              child: ElevatedButton.icon(
                                onPressed: _pickExpiryDate,
                                icon: const Icon(Icons.calendar_today, size: 16),
                                label: const Text('Vybrať dátum'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.secondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    child: const Text('Vytvoriť hlasovanie'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
