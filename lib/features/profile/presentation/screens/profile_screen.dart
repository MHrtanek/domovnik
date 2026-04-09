import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../../../features/buildings/presentation/providers/building_provider.dart';
import '../../../../shared/widgets/app_bar_widget.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import '../../../../features/buildings/presentation/providers/residents_count_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _flatNumberController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _editing = false;
  bool _saving = false;

  List<Map<String, dynamic>> _inviteCodes = [];
  bool _loadingCodes = false;
  bool _codesLoaded = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _flatNumberController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _startEditing(profile) {
    _fullNameController.text = profile.fullName ?? '';
    _flatNumberController.text = profile.flatNumber ?? '';
    _phoneController.text = profile.phone ?? '';
    setState(() => _editing = true);
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(profileProvider.notifier).updateProfile(
            fullName: _fullNameController.text.trim(),
            flatNumber: _flatNumberController.text.trim().isEmpty
                ? null
                : _flatNumberController.text.trim(),
            phone: _phoneController.text.trim().isEmpty
                ? null
                : _phoneController.text.trim(),
          );
      if (mounted) setState(() => _editing = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba: ${e.toString()}'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

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
            TextButton(onPressed: () => ctx.pop(), child: const Text('Zrušiť')),
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
                  if (ctx.mounted) ctx.pop();
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
          TextButton(onPressed: () => ctx.pop(false), child: const Text('Zrušiť')),
          ElevatedButton(
            onPressed: () => ctx.pop(true),
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

  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random.secure();
    return List.generate(6, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  Future<void> _loadInviteCodes(String buildingId) async {
    if (_loadingCodes) return;
    setState(() => _loadingCodes = true);
    try {
      final rows = await Supabase.instance.client
          .from('invite_codes')
          .select('id, code, used, expires_at, created_at')
          .eq('building_id', buildingId)
          .order('created_at', ascending: false)
          .limit(10);
      if (mounted) {
        setState(() {
          _inviteCodes = List<Map<String, dynamic>>.from(rows);
          _codesLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _codesLoaded = true);
    } finally {
      if (mounted) setState(() => _loadingCodes = false);
    }
  }

  Future<void> _createInviteCode(String buildingId) async {
    final profile = ref.read(profileProvider).value;
    if (profile == null) return;
    final code = _generateCode();
    try {
      await Supabase.instance.client.from('invite_codes').insert({
        'code': code,
        'building_id': buildingId,
        'created_by': profile.id,
        'expires_at': DateTime.now().add(const Duration(days: 7)).toIso8601String(),
      });
      setState(() => _codesLoaded = false);
      await _loadInviteCodes(buildingId);
      await Clipboard.setData(ClipboardData(text: code));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kód $code vytvorený a skopírovaný!'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nepodarilo sa vytvoriť kód'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _deleteInviteCode(String codeId, String buildingId) async {
    try {
      await Supabase.instance.client.from('invite_codes').delete().eq('id', codeId);
      setState(() => _codesLoaded = false);
      await _loadInviteCodes(buildingId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nepodarilo sa odstraňovať kód'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);
    final buildingAsync = ref.watch(currentBuildingProvider);

    return Scaffold(
      appBar: DomovnikAppBar(
        title: 'Profil',
        showBack: false,
        actions: [
          if (!_editing)
            profileAsync.maybeWhen(
              data: (profile) => profile != null
                  ? IconButton(
                      icon: const Icon(Icons.edit, color: Colors.white),
                      onPressed: () => _startEditing(profile),
                    )
                  : const SizedBox.shrink(),
              orElse: () => const SizedBox.shrink(),
            ),
        ],
      ),
      body: profileAsync.when(
        data: (profile) {
          if (profile == null) {
            return DomovnikErrorWidget(
              message: 'Profil sa nenašiel',
              onRetry: () => ref.read(profileProvider.notifier).refresh(),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 48,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    (profile.fullName?.isNotEmpty == true ? profile.fullName![0] : profile.email[0]).toUpperCase(),
                    style: const TextStyle(fontSize: 36, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 12),
                Text(profile.fullName ?? 'Bez mena', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: profile.isManager ? AppColors.secondary.withValues(alpha: 0.1) : AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    profile.isManager ? 'Správca' : 'Obyvateľ',
                    style: TextStyle(
                      color: profile.isManager ? AppColors.secondary : AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Budova info
                buildingAsync.when(
                  data: (building) => building != null
                      ? _InfoCard(
                          icon: Icons.apartment,
                          title: 'Budova',
                          value: '${building.name}\n${building.address}\n${ref.watch(residentsCountProvider(building.id)).maybeWhen(data: (c) => '$c obyvateľov', orElse: () => '')}',
                        )
                      : const SizedBox.shrink(),
                  loading: () => const LoadingWidget(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 12),

                // Edit form alebo info karty
                if (_editing)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text('Upraviť profil', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _fullNameController,
                              validator: Validators.fullName,
                              decoration: const InputDecoration(labelText: 'Meno a priezvisko', prefixIcon: Icon(Icons.badge_outlined)),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                labelText: 'Telefónne číslo (nepovinné)',
                                prefixIcon: Icon(Icons.phone_outlined),
                                hintText: '+421 9xx xxx xxx',
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (profile.isResident) ...[
                              TextFormField(
                                controller: _flatNumberController,
                                decoration: const InputDecoration(labelText: 'Číslo bytu (nepovinné)', prefixIcon: Icon(Icons.door_front_door_outlined)),
                              ),
                              const SizedBox(height: 12),
                            ],
                            Row(
                              children: [
                                Expanded(child: OutlinedButton(onPressed: () => setState(() => _editing = false), child: const Text('Zrušiť'))),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _saving ? null : _saveProfile,
                                    child: _saving
                                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                        : const Text('Uložiť'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else ...[
                  _InfoCard(icon: Icons.email_outlined, title: 'E-mail', value: profile.email),
                  if (profile.phone != null && profile.phone!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _InfoCard(icon: Icons.phone_outlined, title: 'Telefón', value: profile.phone!),
                  ],
                  if (profile.flatNumber != null) ...[
                    const SizedBox(height: 12),
                    _InfoCard(icon: Icons.door_front_door_outlined, title: 'Číslo bytu', value: profile.flatNumber!),
                  ],
                ],

                // Invite kódy pre správcu
                if (profile.isManager) ...[
                  const SizedBox(height: 24),
                  buildingAsync.when(
                    data: (building) {
                      if (building == null) return const SizedBox.shrink();
                      if (!_codesLoaded && !_loadingCodes) {
                        WidgetsBinding.instance.addPostFrameCallback((_) => _loadInviteCodes(building.id));
                      }
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.vpn_key_outlined, color: AppColors.primary),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text('Invite kódy pre obyvateľov', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                  ),
                                  TextButton.icon(
                                    onPressed: () => _createInviteCode(building.id),
                                    icon: const Icon(Icons.add, size: 18),
                                    label: const Text('Nový kód'),
                                  ),
                                ],
                              ),
                              const Text(
                                'Kódy platia 7 dní. Zdieľajte ich s obyvateľmi pri registrácii.',
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: 12),
                              if (_loadingCodes)
                                const Center(child: CircularProgressIndicator())
                              else if (_inviteCodes.isEmpty)
                                const Text('Žiadne kódy. Kliknite na "+ Nový kód".', style: TextStyle(color: AppColors.textSecondary, fontSize: 13))
                              else
                                ...(_inviteCodes.map((code) {
                                  final used = code['used'] == true;
                                  final expiresAt = code['expires_at'] != null ? DateTime.parse(code['expires_at']) : null;
                                  final expired = expiresAt != null && expiresAt.isBefore(DateTime.now());
                                  return ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    leading: Icon(
                                      used ? Icons.check_circle : expired ? Icons.cancel : Icons.vpn_key,
                                      color: used ? AppColors.success : expired ? AppColors.error : AppColors.primary,
                                      size: 20,
                                    ),
                                    title: Text(
                                      code['code'] as String,
                                      style: TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: used || expired ? AppColors.textSecondary : AppColors.textPrimary,
                                        decoration: used ? TextDecoration.lineThrough : null,
                                      ),
                                    ),
                                    subtitle: Text(
                                      used ? 'Použitý' : expired ? 'Vypršaný' : expiresAt != null ? 'Platný do ${expiresAt.day}.${expiresAt.month}.${expiresAt.year}' : '',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (!used && !expired)
                                          IconButton(
                                            icon: const Icon(Icons.copy, size: 18),
                                            onPressed: () async {
                                              await Clipboard.setData(ClipboardData(text: code['code'] as String));
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kód skopírovaný')));
                                              }
                                            },
                                          ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                                          onPressed: () => _deleteInviteCode(code['id'] as String, building.id),
                                        ),
                                      ],
                                    ),
                                  );
                                })),
                            ],
                          ),
                        ),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],

                const SizedBox(height: 32),

                OutlinedButton.icon(
                  onPressed: _changePassword,
                  icon: const Icon(Icons.lock_outline, color: AppColors.primary),
                  label: const Text('Zmeniť heslo', style: TextStyle(color: AppColors.primary)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primary),
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _signOut,
                  icon: const Icon(Icons.logout, color: AppColors.error),
                  label: const Text('Odhlásiť sa', style: TextStyle(color: AppColors.error)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.error),
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const LoadingWidget(),
        error: (e, _) => DomovnikErrorWidget(
          message: e.toString(),
          onRetry: () => ref.read(profileProvider.notifier).refresh(),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InfoCard({required this.icon, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(title, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        subtitle: Text(value, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
      ),
    );
  }
}
