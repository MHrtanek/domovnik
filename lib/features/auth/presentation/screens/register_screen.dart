import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/validators.dart';
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
  final _inviteCodeController = TextEditingController();

  String _selectedRole = 'resident';
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _buildingNameController.dispose();
    _buildingAddressController.dispose();
    _inviteCodeController.dispose();
    super.dispose();
  }

  Future<void> _submitManager() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.from('registration_requests').insert({
        'email': _emailController.text.trim(),
        'full_name': _fullNameController.text.trim(),
        'building_name': _buildingNameController.text.trim(),
        'building_address': _buildingAddressController.text.trim(),
      });
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: const Text('Žiadosť odoslaná'),
            content: const Text(
              'Vaša žiadosť o registráciu bola odoslaná. '
              'Po schválení administrátorom dostanete e-mail s ďalšími pokynmi.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.go('/login');
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) _showError('Nepodarilo sa odoslať žiadosť. Skúste znova.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitResident() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final code = _inviteCodeController.text.trim().toUpperCase();
      final result = await Supabase.instance.client
          .from('invite_codes')
          .select('id, building_id, used, expires_at')
          .eq('code', code)
          .maybeSingle();

      if (result == null) throw Exception('Neplatný kód');
      if (result['used'] == true) throw Exception('Kód bol už použitý');
      final expiresAt = result['expires_at'];
      if (expiresAt != null &&
          DateTime.parse(expiresAt).isBefore(DateTime.now())) {
        throw Exception('Kód vypršal');
      }

      final buildingId = result['building_id'] as String;
      final codeId = result['id'] as String;

      await ref.read(authNotifierProvider.notifier).signUp(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            fullName: _fullNameController.text.trim(),
            role: 'resident',
            buildingId: buildingId,
          );

      await Supabase.instance.client
          .from('invite_codes')
          .update({'used': true}).eq('id', codeId);

      if (mounted) context.go('/dashboard');
    } catch (e) {
      if (mounted) {
        String msg = 'Registrácia zlyhala';
        final err = e.toString();
        if (err.contains('Neplatný kód')) msg = 'Neplatný invite kód';
        if (err.contains('použitý')) msg = 'Tento kód bol už použitý';
        if (err.contains('vypršal')) msg = 'Platnosť kódu vypršala';
        if (err.contains('User already registered')) {
          msg = 'Účet s týmto e-mailom už existuje';
        }
        _showError(msg);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                        const Text('Typ účtu',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
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

                // Osobné údaje
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Osobné údaje',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
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
                        if (_selectedRole == 'resident') ...[
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
                                icon: Icon(_obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined),
                                onPressed: () => setState(() =>
                                    _obscurePassword = !_obscurePassword),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Budova / kód
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedRole == 'resident' ? 'Invite kód' : 'Budova',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 12),
                        if (_selectedRole == 'resident') ...[
                          TextFormField(
                            controller: _inviteCodeController,
                            textCapitalization: TextCapitalization.characters,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _submitResident(),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Zadajte kód'
                                : null,
                            decoration: const InputDecoration(
                              labelText: 'Invite kód od správcu',
                              prefixIcon: Icon(Icons.vpn_key_outlined),
                              hintText: 'napr. ABC123',
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
                            onFieldSubmitted: (_) => _submitManager(),
                            validator: Validators.buildingAddress,
                            decoration: const InputDecoration(
                              labelText: 'Adresa budovy',
                              prefixIcon: Icon(Icons.location_on_outlined),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.info_outline,
                                    color: AppColors.primary, size: 18),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Vaša žiadosť bude overená administrátorom pred aktiváciou účtu.',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: AppColors.primary),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : (_selectedRole == 'resident'
                          ? _submitResident
                          : _submitManager),
                  child: Text(_selectedRole == 'manager'
                      ? 'Odoslať žiadosť'
                      : 'Registrovať sa'),
                ),
                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Máte účet? ',
                        style: TextStyle(color: AppColors.textSecondary)),
                    GestureDetector(
                      onTap: () => context.go('/login'),
                      child: const Text('Prihláste sa',
                          style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600)),
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
          color: selected ? AppColors.primary.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                size: 32,
                color:
                    selected ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? AppColors.primary
                        : AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }
}
