import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../../../features/buildings/presentation/providers/building_provider.dart';
import '../../../../shared/widgets/app_bar_widget.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/profile_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _flatNumberController = TextEditingController();
  bool _editing = false;
  bool _saving = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _flatNumberController.dispose();
    super.dispose();
  }

  void _startEditing(profile) {
    _fullNameController.text = profile.fullName ?? '';
    _flatNumberController.text = profile.flatNumber ?? '';
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
          );
      if (mounted) setState(() => _editing = false);
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
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Odhlásiť sa'),
        content: const Text('Naozaj sa chcete odhlásiť?'),
        actions: [
          TextButton(
            onPressed: () => ctx.pop(false),
            child: const Text('Zrušiť'),
          ),
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
                    (profile.fullName?.isNotEmpty == true
                            ? profile.fullName![0]
                            : profile.email[0])
                        .toUpperCase(),
                    style: const TextStyle(
                      fontSize: 36,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  profile.fullName ?? 'Bez mena',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: profile.isManager
                        ? AppColors.secondary.withOpacity(0.1)
                        : AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    profile.isManager ? 'Správca' : 'Obyvateľ',
                    style: TextStyle(
                      color: profile.isManager
                          ? AppColors.secondary
                          : AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Building info
                buildingAsync.when(
                  data: (building) => building != null
                      ? _InfoCard(
                          icon: Icons.apartment,
                          title: 'Budova',
                          value: '${building.name}\n${building.address}',
                        )
                      : const SizedBox.shrink(),
                  loading: () => const LoadingWidget(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 12),

                // Profile form/display
                if (_editing)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Upraviť profil',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _fullNameController,
                              validator: Validators.fullName,
                              decoration: const InputDecoration(
                                labelText: 'Meno a priezvisko',
                                prefixIcon: Icon(Icons.badge_outlined),
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (profile.isResident) ...[
                              TextFormField(
                                controller: _flatNumberController,
                                decoration: const InputDecoration(
                                  labelText: 'Číslo bytu (nepovinné)',
                                  prefixIcon: Icon(Icons.door_front_door_outlined),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () =>
                                        setState(() => _editing = false),
                                    child: const Text('Zrušiť'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _saving ? null : _saveProfile,
                                    child: _saving
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
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
                  _InfoCard(
                    icon: Icons.email_outlined,
                    title: 'E-mail',
                    value: profile.email,
                  ),
                  if (profile.flatNumber != null) ...[
                    const SizedBox(height: 12),
                    _InfoCard(
                      icon: Icons.door_front_door_outlined,
                      title: 'Číslo bytu',
                      value: profile.flatNumber!,
                    ),
                  ],
                ],

                const SizedBox(height: 32),

                // Sign out
                OutlinedButton.icon(
                  onPressed: _signOut,
                  icon: const Icon(Icons.logout, color: AppColors.error),
                  label: const Text(
                    'Odhlásiť sa',
                    style: TextStyle(color: AppColors.error),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.error),
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

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        subtitle: Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
