import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../../../features/buildings/presentation/providers/building_provider.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../providers/auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _buildingNameController = TextEditingController();
  final _buildingAddressController = TextEditingController();

  String _selectedRole = 'resident';
  String? _selectedBuildingId;
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _buildingNameController.dispose();
    _buildingAddressController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedRole == 'resident' && _selectedBuildingId == null) {
      _showError('Vyberte budovu');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ref.read(authNotifierProvider.notifier).signUp(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            fullName: _fullNameController.text.trim(),
            role: _selectedRole,
            buildingId:
                _selectedRole == 'resident' ? _selectedBuildingId : null,
            buildingName: _selectedRole == 'manager'
                ? _buildingNameController.text.trim()
                : null,
            buildingAddress: _selectedRole == 'manager'
                ? _buildingAddressController.text.trim()
                : null,
          );

      if (mounted) {
        // With email confirmation disabled (migration 005), signUp() always
        // returns a session. Navigate to dashboard; _DashboardRedirect will
        // load the profile and route to the correct shell.
        context.go('/dashboard');
      }
    } catch (e) {
      if (mounted) _showError(_mapAuthError(e.toString()));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _mapAuthError(String error) {
    if (error.contains('User already registered')) {
      return 'Účet s týmto e-mailom už existuje';
    }
    if (error.contains('Password should be at least')) {
      return 'Heslo musí mať aspoň 6 znakov';
    }
    return 'Registrácia zlyhala. Skúste to znova.';
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final buildingsAsync = ref.watch(allBuildingsProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Registrácia'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.go('/login'),
        ),
      ),
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Role selector
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Typ účtu',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _RoleOption(
                                label: 'Obyvateľ',
                                icon: Icons.person,
                                value: 'resident',
                                selected: _selectedRole == 'resident',
                                onTap: () =>
                                    setState(() => _selectedRole = 'resident'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _RoleOption(
                                label: 'Správca',
                                icon: Icons.manage_accounts,
                                value: 'manager',
                                selected: _selectedRole == 'manager',
                                onTap: () =>
                                    setState(() => _selectedRole = 'manager'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Personal info
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Osobné údaje',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: _fullNameController,
                          textInputAction: TextInputAction.next,
                          validator: Validators.fullName,
                          decoration: const InputDecoration(
                            labelText: 'Meno a priezvisko',
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          validator: Validators.email,
                          decoration: const InputDecoration(
                            labelText: 'E-mail',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.next,
                          validator: Validators.password,
                          decoration: InputDecoration(
                            labelText: 'Heslo',
                            prefixIcon: const Icon(Icons.lock_outlined),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Building info
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Budova',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),

                        if (_selectedRole == 'resident') ...[
                          buildingsAsync.when(
                            data: (buildings) {
                              if (buildings.isEmpty) {
                                return const Text(
                                  'Žiadne budovy nie sú dostupné. Požiadajte správcu.',
                                  style: TextStyle(color: AppColors.textSecondary),
                                );
                              }
                              return DropdownButtonFormField<String>(
                                value: _selectedBuildingId,
                                decoration: const InputDecoration(
                                  labelText: 'Vyberte budovu',
                                  prefixIcon: Icon(Icons.apartment_outlined),
                                ),
                                items: buildings
                                    .map((b) => DropdownMenuItem(
                                          value: b.id,
                                          child: Text('${b.name} — ${b.address}'),
                                        ))
                                    .toList(),
                                onChanged: (v) =>
                                    setState(() => _selectedBuildingId = v),
                                validator: (v) =>
                                    v == null ? 'Vyberte budovu' : null,
                              );
                            },
                            loading: () => const LoadingWidget(),
                            error: (e, _) => const Text(
                              'Nepodarilo sa načítať budovy',
                              style: TextStyle(color: AppColors.error),
                            ),
                          ),
                        ] else ...[
                          TextFormField(
                            controller: _buildingNameController,
                            textInputAction: TextInputAction.next,
                            validator: Validators.buildingName,
                            decoration: const InputDecoration(
                              labelText: 'Názov budovy',
                              prefixIcon: Icon(Icons.apartment_outlined),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _buildingAddressController,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _submit(),
                            validator: Validators.buildingAddress,
                            decoration: const InputDecoration(
                              labelText: 'Adresa budovy',
                              prefixIcon: Icon(Icons.location_on_outlined),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  child: const Text('Registrovať sa'),
                ),
                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Máte účet? ',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    GestureDetector(
                      onTap: () => context.go('/login'),
                      child: const Text(
                        'Prihláste sa',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  const _RoleOption({
    required this.label,
    required this.icon,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: selected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
