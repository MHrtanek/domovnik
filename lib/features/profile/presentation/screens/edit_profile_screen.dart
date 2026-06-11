import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/app_bar_widget.dart';
import '../providers/profile_provider.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  bool _saving = false;
  bool _initialized = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);

    return profileAsync.when(
      data: (profile) {
        if (profile != null && !_initialized) {
          _fullNameController.text = profile.fullName ?? '';
          _initialized = true;
        }

        return Scaffold(
          appBar: const DomovnikAppBar(title: 'Upraviť profil', showBack: true),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Avatar preview
                  Center(
                    child: CircleAvatar(
                      radius: 44,
                      backgroundColor: AppColors.primary,
                      child: Text(
                        (_fullNameController.text.isNotEmpty
                                ? _fullNameController.text[0]
                                : profile?.email[0] ?? '?')
                            .toUpperCase(),
                        style: const TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  TextFormField(
                    controller: _fullNameController,
                    validator: Validators.fullName,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Meno a priezvisko',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 32),

                  ElevatedButton(
                    onPressed: _saving ? null : () async {
                      if (!_formKey.currentState!.validate()) return;
                      setState(() => _saving = true);
                      final messenger = ScaffoldMessenger.of(context);
                      final navigator = Navigator.of(context);
                      try {
                        await ref.read(profileProvider.notifier).updateProfile(
                          fullName: _fullNameController.text.trim(),
                        );
                        if (!mounted) return;
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Profil aktualizovaný'), backgroundColor: AppColors.success),
                        );
                        navigator.pop();
                      } catch (e) {
                        if (!mounted) return;
                        messenger.showSnackBar(
                          SnackBar(content: Text('Chyba: ${e.toString()}'), backgroundColor: AppColors.error),
                        );
                      } finally {
                        if (mounted) setState(() => _saving = false);
                      }
                    },
                    child: _saving
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Uložiť zmeny'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const Scaffold(
        appBar: DomovnikAppBar(title: 'Upraviť profil', showBack: true),
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const Scaffold(
        appBar: DomovnikAppBar(title: 'Upraviť profil', showBack: true),
        body: Center(child: Text('Nepodarilo sa načítať profil')),
      ),
    );
  }
}
