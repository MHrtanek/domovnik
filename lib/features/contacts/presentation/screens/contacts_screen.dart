import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/app_bar_widget.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../models/contact_model.dart';
import '../providers/contacts_provider.dart';

class ContactsScreen extends ConsumerWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contactsAsync = ref.watch(contactsProvider);
    final profileAsync = ref.watch(profileProvider);
    final isManager = profileAsync.maybeWhen(
      data: (p) => p?.isManager ?? false,
      orElse: () => false,
    );

    return Scaffold(
      appBar: const DomovnikAppBar(title: 'Kontaktný adresár', showBack: false),
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
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.contacts_outlined, size: 64, color: AppColors.textSecondary.withOpacity(0.4)),
                    const SizedBox(height: 16),
                    const Text(
                      'Žiadne kontakty',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isManager
                          ? 'Pridajte dôležité kontakty pre obyvateľov.'
                          : 'Správca zatiaľ nepridali žiadne kontakty.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
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
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Chyba: $e'), backgroundColor: AppColors.error));
        }
      }
    }
  }
}

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
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w500, decoration: TextDecoration.underline),
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Chyba: $e'), backgroundColor: AppColors.error));
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
      content: SizedBox(
        width: 400,
        child: Form(
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
