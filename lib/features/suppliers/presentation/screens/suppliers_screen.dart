import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/app_bar_widget.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../models/supplier_model.dart';
import '../providers/suppliers_provider.dart';

const _categories = [
  'Elektrikár', 'Inštalatér', 'Výťahy', 'Plyn', 'Upratovanie',
  'Záhradníctvo', 'Strecha', 'Maľovanie', 'Iné',
];

class SuppliersScreen extends ConsumerWidget {
  const SuppliersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suppliersAsync = ref.watch(suppliersProvider);
    final isManager = ref.watch(profileProvider).value?.isManager ?? false;

    return Scaffold(
      appBar: DomovnikAppBar(
        title: 'Dodávatelia',
        showBack: false,
        showLogout: true,
      ),
      floatingActionButton: isManager
          ? FloatingActionButton.extended(
              onPressed: () => _showDialog(context, ref, null),
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Pridať dodávateľa', style: TextStyle(color: Colors.white)),
            )
          : null,
      body: suppliersAsync.when(
        data: (suppliers) {
          if (suppliers.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.business_outlined,
              message: 'Žiadni dodávatelia.\nSprávca môže pridať prvého dodávateľa.',
            );
          }

          // Zoskup podľa kategórie
          final grouped = <String, List<SupplierModel>>{};
          for (final s in suppliers) {
            final cat = s.category ?? 'Iné';
            grouped.putIfAbsent(cat, () => []).add(s);
          }

          return ListView(
            padding: const EdgeInsets.all(12),
            children: grouped.entries.map((entry) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 6),
                    child: Text(
                      entry.key,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                    ),
                  ),
                  ...entry.value.map((s) => _SupplierCard(supplier: s, isManager: isManager, ref: ref)),
                ],
              );
            }).toList(),
          );
        },
        loading: () => const LoadingWidget(),
        error: (e, _) => DomovnikErrorWidget(message: e.toString()),
      ),
    );
  }

  static void _showDialog(BuildContext context, WidgetRef ref, SupplierModel? existing) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final emailCtrl = TextEditingController(text: existing?.email ?? '');
    final noteCtrl = TextEditingController(text: existing?.note ?? '');
    String? selectedCategory = existing?.category;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(existing == null ? 'Nový dodávateľ' : 'Upraviť dodávateľa'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Názov firmy *', prefixIcon: Icon(Icons.business_outlined)),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Zadajte názov' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    decoration: const InputDecoration(labelText: 'Kategória', prefixIcon: Icon(Icons.category_outlined)),
                    items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) => setState(() => selectedCategory = v),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Telefón', prefixIcon: Icon(Icons.phone_outlined)),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'E-mail', prefixIcon: Icon(Icons.email_outlined)),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: noteCtrl,
                    decoration: const InputDecoration(labelText: 'Poznámka', prefixIcon: Icon(Icons.notes_outlined)),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Zrušiť')),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                Navigator.of(ctx).pop();
                final profile = await ref.read(profileProvider.future);
                if (profile?.buildingId == null) return;
                final repo = ref.read(supplierRepositoryProvider);
                if (existing == null) {
                  await repo.createSupplier(
                    buildingId: profile!.buildingId!,
                    name: nameCtrl.text.trim(),
                    category: selectedCategory,
                    phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                    email: emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
                    note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
                  );
                } else {
                  await repo.updateSupplier(
                    id: existing.id,
                    name: nameCtrl.text.trim(),
                    category: selectedCategory,
                    phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                    email: emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
                    note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
                  );
                }
                ref.invalidate(suppliersProvider);
              },
              child: Text(existing == null ? 'Pridať' : 'Uložiť'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupplierCard extends StatelessWidget {
  final SupplierModel supplier;
  final bool isManager;
  final WidgetRef ref;

  const _SupplierCard({required this.supplier, required this.isManager, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.business_outlined, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(supplier.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  if (supplier.phone != null)
                    GestureDetector(
                      onTap: () async {
                        await Clipboard.setData(ClipboardData(text: supplier.phone!));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Telefón skopírovaný')),
                          );
                        }
                      },
                      child: Row(
                        children: [
                          const Icon(Icons.phone_outlined, size: 13, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(supplier.phone!, style: const TextStyle(fontSize: 13, color: AppColors.primary)),
                        ],
                      ),
                    ),
                  if (supplier.email != null)
                    Row(
                      children: [
                        const Icon(Icons.email_outlined, size: 13, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(supplier.email!, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      ],
                    ),
                  if (supplier.note != null)
                    Text(supplier.note!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            if (isManager)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                    onPressed: () => SuppliersScreen._showDialog(context, ref, supplier),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Odstrániť dodávateľa'),
                          content: Text('Naozaj odstrániť "${supplier.name}"?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Nie')),
                            ElevatedButton(
                              onPressed: () => Navigator.of(ctx).pop(true),
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                              child: const Text('Odstrániť'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        await ref.read(supplierRepositoryProvider).deleteSupplier(supplier.id);
                        ref.invalidate(suppliersProvider);
                      }
                    },
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
