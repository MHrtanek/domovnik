import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/app_bar_widget.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../profile/models/profile_model.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../models/contact_model.dart';
import '../providers/contacts_provider.dart';

// Provider pre obyvateľov budovy
final residentsProvider = FutureProvider<List<ProfileModel>>((ref) async {
  final profile = await ref.watch(profileProvider.future);
  if (profile?.buildingId == null) return [];
  final data = await Supabase.instance.client
      .from('profiles')
      .select()
      .eq('building_id', profile!.buildingId!)
      .eq('role', 'resident')
      .order('full_name');
  return data.map((r) => ProfileModel.fromJson(r)).toList();
});

// Provider pre správcu budovy
final buildingManagerProvider = FutureProvider<ProfileModel?>((ref) async {
  final profile = await ref.watch(profileProvider.future);
  if (profile?.buildingId == null) return null;
  final data = await Supabase.instance.client
      .from('profiles')
      .select()
      .eq('building_id', profile!.buildingId!)
      .eq('role', 'manager')
      .maybeSingle();
  if (data == null) return null;
  return ProfileModel.fromJson(data);
});

class ContactsScreen extends ConsumerWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    final isManager = profileAsync.maybeWhen(
      data: (p) => p?.isManager ?? false,
      orElse: () => false,
    );

    return Scaffold(
      appBar: const DomovnikAppBar(
        title: 'Kontakty',
        showBack: false,
        showLogout: true,
      ),
      body: DefaultTabController(
        length: isManager ? 2 : 2,
        child: Column(
          children: [
            TabBar(
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              tabs: [
                const Tab(text: 'Adresár'),
                Tab(text: isManager ? 'Obyvatelia' : 'Správca'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  // Tab 1: Kontaktný adresár
                  _ContactsTab(isManager: isManager),
                  // Tab 2: Obyvatelia (správca) alebo Správca (obyvateľ)
                  if (isManager)
                    const _ResidentsTab()
                  else
                    const _ManagerTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tab 1: Kontaktný adresár ─────────────────────────────────────────────────

class _ContactsTab extends ConsumerWidget {
  final bool isManager;
  const _ContactsTab({required this.isManager});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contactsAsync = ref.watch(contactsProvider);

    return Scaffold(
      floatingActionButton: isManager
          ? FloatingActionButton.extended(
              onPressed: () => _showContactDialog(context, ref, null),
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Pridať kontakt', style: TextStyle(color: Colors.white)),
            )
          : null,
      body: contactsAsync.when(
        data: (contacts) {
          if (contacts.isEmpty) {
            return EmptyStateWidget(
              icon: Icons.contacts_outlined,
              message: isManager
                  ? 'Pridajte dôležité kontakty pre obyvateľov.'
                  : 'Správca zatiaľ nepridali žiadne kontakty.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(contactsProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: contacts.length,
              itemBuilder: (context, i) => _ContactCard(
                contact: contacts[i],
                isManager: isManager,
                onEdit: isManager ? () => _showContactDialog(context, ref, contacts[i]) : null,
                onDelete: isManager ? () => _confirmDelete(context, ref, contacts[i]) : null,
              ),
            ),
          );
        },
        loading: () => const LoadingWidget(),
        error: (e, _) => DomovnikErrorWidget(
          message: e.toString(),
          onRetry: () => ref.invalidate(contactsProvider),
        ),
      ),
    );
  }

  Future<void> _showContactDialog(BuildContext context, WidgetRef ref, ContactModel? existing) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _ContactDialog(existing: existing, ref: ref),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, ContactModel contact) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Odstrániť kontakt'),
        content: Text('Naozaj chcete odstrániť "${contact.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Zrušiť')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Odstrániť'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await ref.read(deleteContactProvider.notifier).deleteContact(contact.id);
          ref.invalidate(contactsProvider);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Chyba: $e'), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }
}

// ── Tab 2a: Obyvatelia (pre správcu) ────────────────────────────────────────

class _ResidentsTab extends ConsumerWidget {
  const _ResidentsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final residentsAsync = ref.watch(residentsProvider);

    return residentsAsync.when(
      data: (residents) {
        if (residents.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.people_outline,
            message: 'Žiadni obyvatelia.\nPozvite ich pomocou invite kódu z profilu.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: residents.length,
          itemBuilder: (context, i) => _ResidentCard(resident: residents[i]),
        );
      },
      loading: () => const LoadingWidget(),
      error: (e, _) => DomovnikErrorWidget(message: e.toString()),
    );
  }
}

// ── Tab 2b: Správca (pre obyvateľa) ─────────────────────────────────────────

class _ManagerTab extends ConsumerWidget {
  const _ManagerTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final managerAsync = ref.watch(buildingManagerProvider);

    return managerAsync.when(
      data: (manager) {
        if (manager == null) {
          return const EmptyStateWidget(
            icon: Icons.manage_accounts_outlined,
            message: 'Správca budovy nie je k dispozícii.',
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Profil kartu správcu
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: AppColors.primary,
                      child: Text(
                        (manager.fullName?.isNotEmpty == true
                                ? manager.fullName![0]
                                : manager.email[0])
                            .toUpperCase(),
                        style: const TextStyle(
                            fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      manager.fullName ?? 'Správca',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Správca budovy',
                        style: TextStyle(color: AppColors.secondary, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 12),
                    // Kontaktné možnosti
                    if (manager.email.isNotEmpty)
                      _ContactAction(
                        icon: Icons.email_outlined,
                        label: manager.email,
                        sublabel: 'E-mail',
                        color: AppColors.primary,
                        onTap: () async {
                          final uri = Uri(scheme: 'mailto', path: manager.email);
                          if (await canLaunchUrl(uri)) await launchUrl(uri);
                        },
                        onCopy: () async {
                          await Clipboard.setData(ClipboardData(text: manager.email));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('E-mail skopírovaný')),
                            );
                          }
                        },
                      ),
                    if (manager.phone != null && manager.phone!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _ContactAction(
                        icon: Icons.phone_outlined,
                        label: manager.phone!,
                        sublabel: 'Telefón',
                        color: const Color(0xFF2e7d32),
                        onTap: () async {
                          final uri = Uri(scheme: 'tel', path: manager.phone);
                          if (await canLaunchUrl(uri)) await launchUrl(uri);
                        },
                        onCopy: () async {
                          await Clipboard.setData(ClipboardData(text: manager.phone!));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Telefón skopírovaný')),
                            );
                          }
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const LoadingWidget(),
      error: (e, _) => DomovnikErrorWidget(message: e.toString()),
    );
  }
}

// ── Resident Card ────────────────────────────────────────────────────────────

class _ResidentCard extends StatelessWidget {
  final ProfileModel resident;
  const _ResidentCard({required this.resident});

  @override
  Widget build(BuildContext context) {
    final initials = (resident.fullName?.isNotEmpty == true
            ? resident.fullName![0]
            : resident.email[0])
        .toUpperCase();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withValues(alpha: 0.12),
          child: Text(initials, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
        ),
        title: Text(
          resident.fullName ?? 'Bez mena',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: resident.flatNumber != null
            ? Text('Byt ${resident.flatNumber}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))
            : null,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              children: [
                // Email
                _ContactAction(
                  icon: Icons.email_outlined,
                  label: resident.email,
                  sublabel: 'E-mail',
                  color: AppColors.primary,
                  onTap: () async {
                    final uri = Uri(scheme: 'mailto', path: resident.email);
                    if (await canLaunchUrl(uri)) await launchUrl(uri);
                  },
                  onCopy: () async {
                    await Clipboard.setData(ClipboardData(text: resident.email));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('E-mail skopírovaný')),
                      );
                    }
                  },
                ),
                // Telefón (ak má)
                if (resident.phone != null && resident.phone!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _ContactAction(
                    icon: Icons.phone_outlined,
                    label: resident.phone!,
                    sublabel: 'Telefón',
                    color: const Color(0xFF2e7d32),
                    onTap: () async {
                      final uri = Uri(scheme: 'tel', path: resident.phone);
                      if (await canLaunchUrl(uri)) await launchUrl(uri);
                    },
                    onCopy: () async {
                      await Clipboard.setData(ClipboardData(text: resident.phone!));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Telefón skopírovaný')),
                        );
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Contact Action ───────────────────────────────────────────────────────────

class _ContactAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback onCopy;

  const _ContactAction({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
    required this.onTap,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w500, fontSize: 14)),
        subtitle: Text(sublabel, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.copy_outlined, size: 18, color: color),
              onPressed: onCopy,
              tooltip: 'Kopírovať',
            ),
            IconButton(
              icon: Icon(icon, size: 18, color: color),
              onPressed: onTap,
              tooltip: sublabel,
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

// ── Contact Card (adresár) ───────────────────────────────────────────────────

class _ContactCard extends StatelessWidget {
  final ContactModel contact;
  final bool isManager;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _ContactCard({required this.contact, required this.isManager, this.onEdit, this.onDelete});

  Future<void> _call() async {
    final uri = Uri(scheme: 'tel', path: contact.phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withValues(alpha: 0.12),
          child: const Icon(Icons.person, color: AppColors.primary),
        ),
        title: Text(contact.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (contact.description != null && contact.description!.isNotEmpty)
              Text(contact.description!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 2),
            GestureDetector(
              onTap: _call,
              child: Text(
                contact.phone,
                style: const TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.w500, decoration: TextDecoration.underline),
              ),
            ),
          ],
        ),
        isThreeLine: contact.description != null,
        trailing: isManager
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(icon: const Icon(Icons.edit_outlined, color: AppColors.textSecondary), onPressed: onEdit),
                  IconButton(icon: const Icon(Icons.delete_outline, color: AppColors.error), onPressed: onDelete),
                ],
              )
            : null,
      ),
    );
  }
}

// ── Contact Dialog ───────────────────────────────────────────────────────────

class _ContactDialog extends StatefulWidget {
  final ContactModel? existing;
  final WidgetRef ref;

  const _ContactDialog({this.existing, required this.ref});

  @override
  State<_ContactDialog> createState() => _ContactDialogState();
}

class _ContactDialogState extends State<_ContactDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _descCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _phoneCtrl = TextEditingController(text: widget.existing?.phone ?? '');
    _descCtrl = TextEditingController(text: widget.existing?.description ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      if (widget.existing == null) {
        await widget.ref.read(createContactProvider.notifier).createContact(
              name: _nameCtrl.text.trim(),
              phone: _phoneCtrl.text.trim(),
              description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
            );
      } else {
        await widget.ref.read(updateContactProvider.notifier).updateContact(
              id: widget.existing!.id,
              name: _nameCtrl.text.trim(),
              phone: _phoneCtrl.text.trim(),
              description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
            );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Chyba: $e'), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return AlertDialog(
      title: Text(isEdit ? 'Upraviť kontakt' : 'Nový kontakt'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameCtrl,
              textInputAction: TextInputAction.next,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Meno je povinné' : null,
              decoration: const InputDecoration(labelText: 'Meno *', prefixIcon: Icon(Icons.person_outline)),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Telefón je povinný' : null,
              decoration: const InputDecoration(labelText: 'Telefón *', prefixIcon: Icon(Icons.phone_outlined)),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descCtrl,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(labelText: 'Popis (napr. Havarijná služba)', prefixIcon: Icon(Icons.label_outline)),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(), child: const Text('Zrušiť')),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(isEdit ? 'Uložiť' : 'Pridať'),
        ),
      ],
    );
  }
}
