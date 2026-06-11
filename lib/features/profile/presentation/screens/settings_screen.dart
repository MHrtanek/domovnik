import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../features/notifications/data/fcm_service.dart';
import '../../../../shared/widgets/app_bar_widget.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notificationsEnabled = false;

  Future<void> _changePassword() async {
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool saving = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Zmeniť heslo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: newPasswordController,
                obscureText: obscureNew,
                decoration: InputDecoration(
                  labelText: 'Nové heslo',
                  prefixIcon: const Icon(Icons.lock_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(obscureNew ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: confirmPasswordController,
                obscureText: obscureConfirm,
                decoration: InputDecoration(
                  labelText: 'Potvrdiť heslo',
                  prefixIcon: const Icon(Icons.lock_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Zrušiť')),
            ElevatedButton(
              onPressed: saving ? null : () async {
                final newPass = newPasswordController.text;
                final confirmPass = confirmPasswordController.text;
                if (newPass.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Heslo musí mať aspoň 6 znakov'), backgroundColor: AppColors.error),
                  );
                  return;
                }
                if (newPass != confirmPass) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Heslá sa nezhodujú'), backgroundColor: AppColors.error),
                  );
                  return;
                }
                setDialogState(() => saving = true);
                try {
                  await Supabase.instance.client.auth.updateUser(UserAttributes(password: newPass));
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Heslo bolo úspešne zmenené'), backgroundColor: AppColors.success),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Chyba: ${e.toString()}'), backgroundColor: AppColors.error),
                    );
                  }
                } finally {
                  setDialogState(() => saving = false);
                }
              },
              child: saving
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Zmeniť'),
            ),
          ],
        ),
      ),
    );

    newPasswordController.dispose();
    confirmPasswordController.dispose();
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Odhlásiť sa'),
        content: const Text('Naozaj sa chcete odhlásiť?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Zrušiť')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Odhlásiť'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authNotifierProvider.notifier).signOut();
      if (mounted) context.go('/login');
    }
  }

  Widget _sectionHeader(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const DomovnikAppBar(title: 'Nastavenia', showBack: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Účet ──────────────────────────────────────────────────────────
            _sectionHeader('ÚČET'),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.person_outline, color: AppColors.primary),
                    title: const Text('Upraviť profil'),
                    trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                    onTap: () => context.push('/settings/edit-profile'),
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const Icon(Icons.lock_outline, color: AppColors.primary),
                    title: const Text('Zmeniť heslo'),
                    trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                    onTap: _changePassword,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Aplikácia ─────────────────────────────────────────────────────
            _sectionHeader('APLIKÁCIA'),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.feedback_outlined, color: AppColors.primary),
                    title: const Text('Feedback'),
                    trailing: const Icon(Icons.chevron_right, size: 20, color: AppColors.textSecondary),
                    onTap: () => context.push('/feedback'),
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const Icon(Icons.notifications_outlined, color: AppColors.primary),
                    title: const Text('Povoliť notifikácie'),
                trailing: Switch(
                  value: _notificationsEnabled,
                  activeThumbColor: AppColors.primary,
                  onChanged: (val) async {
                    final messenger = ScaffoldMessenger.of(context);
                    if (val && kIsWeb) {
                      await FcmService.requestPermissionAfterInteraction();
                    }
                    if (!mounted) return;
                    setState(() => _notificationsEnabled = val);
                    messenger.showSnackBar(
                      SnackBar(content: Text(val ? 'Notifikácie povolené' : 'Notifikácie vypnuté')),
                    );
                  },
                ),
              ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // ── Odhlásiť sa ───────────────────────────────────────────────────
            Card(
              child: ListTile(
                leading: const Icon(Icons.logout, color: AppColors.error),
                title: const Text('Odhlásiť sa', style: TextStyle(color: AppColors.error)),
                onTap: _signOut,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
