import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/app_bar_widget.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../models/inspection_model.dart';
import '../providers/inspections_provider.dart';

final _dateFmt = DateFormat('d. M. yyyy');

class InspectionsScreen extends ConsumerWidget {
  const InspectionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inspectionsAsync = ref.watch(inspectionsProvider);
    final profileAsync = ref.watch(profileProvider);

    final isManager = profileAsync.value?.isManager ?? false;

    return Scaffold(
      appBar: DomovnikAppBar(
        title: 'Revízie a termíny',
        showBack: false,
        showLogout: true,
      ),
      floatingActionButton: isManager
          ? FloatingActionButton.extended(
              onPressed: () => _showAddDialog(context, ref),
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Pridať revíziu', style: TextStyle(color: Colors.white)),
            )
          : null,
      body: inspectionsAsync.when(
        data: (inspections) {
          if (inspections.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.assignment_outlined,
              message: 'Žiadne revízie.\nSprávca môže pridať prvú revíziu.',
            );
          }

          final expired = inspections.where((i) => i.isExpired).toList();
          final expiringSoon = inspections.where((i) => i.isExpiringSoon && !i.isExpired).toList();
          final ok = inspections.where((i) => !i.isExpired && !i.isExpiringSoon).toList();

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              if (expired.isNotEmpty) ...[
                _SectionHeader(title: '🔴  Vypršané', color: AppColors.error),
                ...expired.map((i) => _InspectionCard(inspection: i, isManager: isManager, ref: ref)),
                const SizedBox(height: 8),
              ],
              if (expiringSoon.isNotEmpty) ...[
                _SectionHeader(title: '🟡  Blíži sa termín (do 30 dní)', color: AppColors.warning),
                ...expiringSoon.map((i) => _InspectionCard(inspection: i, isManager: isManager, ref: ref)),
                const SizedBox(height: 8),
              ],
              if (ok.isNotEmpty) ...[
                _SectionHeader(title: '🟢  V poriadku', color: AppColors.success),
                ...ok.map((i) => _InspectionCard(inspection: i, isManager: isManager, ref: ref)),
              ],
            ],
          );
        },
        loading: () => const LoadingWidget(),
        error: (e, _) => DomovnikErrorWidget(message: e.toString()),
      ),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    _showInspectionDialog(context, ref, null);
  }

  static void _showInspectionDialog(BuildContext context, WidgetRef ref, InspectionModel? existing) {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    DateTime inspectionDate = existing?.inspectionDate ?? DateTime.now();
    DateTime? nextDate = existing?.nextDate;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(existing == null ? 'Nová revízia' : 'Upraviť revíziu'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(labelText: 'Názov *', prefixIcon: Icon(Icons.assignment_outlined)),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Zadajte názov' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descCtrl,
                    decoration: const InputDecoration(labelText: 'Popis (napr. firma)', prefixIcon: Icon(Icons.notes_outlined)),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today, color: AppColors.primary),
                    title: const Text('Dátum revízie', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    subtitle: Text(_dateFmt.format(inspectionDate), style: const TextStyle(fontWeight: FontWeight.w600)),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: inspectionDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setState(() => inspectionDate = picked);
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.event_repeat, color: nextDate != null ? AppColors.primary : AppColors.textSecondary),
                    title: const Text('Ďalší termín (voliteľné)', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    subtitle: Text(
                      nextDate != null ? _dateFmt.format(nextDate!) : 'Nenastavený',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: nextDate != null ? AppColors.textPrimary : AppColors.textSecondary,
                      ),
                    ),
                    trailing: nextDate != null
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => setState(() => nextDate = null),
                          )
                        : null,
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: nextDate ?? DateTime.now().add(const Duration(days: 365)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setState(() => nextDate = picked);
                    },
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
                final repo = ref.read(inspectionRepositoryProvider);
                if (existing == null) {
                  await repo.createInspection(
                    buildingId: profile!.buildingId!,
                    title: titleCtrl.text.trim(),
                    description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                    inspectionDate: inspectionDate,
                    nextDate: nextDate,
                  );
                } else {
                  await repo.updateInspection(
                    id: existing.id,
                    title: titleCtrl.text.trim(),
                    description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                    inspectionDate: inspectionDate,
                    nextDate: nextDate,
                  );
                }
                ref.invalidate(inspectionsProvider);
              },
              child: Text(existing == null ? 'Pridať' : 'Uložiť'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Color color;
  const _SectionHeader({required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _InspectionCard extends StatelessWidget {
  final InspectionModel inspection;
  final bool isManager;
  final WidgetRef ref;

  const _InspectionCard({required this.inspection, required this.isManager, required this.ref});

  Color get _statusColor {
    if (inspection.isExpired) return AppColors.error;
    if (inspection.isExpiringSoon) return AppColors.warning;
    return AppColors.success;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 56,
              decoration: BoxDecoration(color: _statusColor, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(inspection.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  if (inspection.description != null) ...[
                    const SizedBox(height: 2),
                    Text(inspection.description!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 12, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text('Revízia: ${_dateFmt.format(inspection.inspectionDate)}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      if (inspection.nextDate != null) ...[
                        const SizedBox(width: 12),
                        const Icon(Icons.event_repeat, size: 12, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          inspection.isExpired
                              ? 'Vypršalo ${_dateFmt.format(inspection.nextDate!)}'
                              : inspection.daysUntilNext != null
                                  ? 'Za ${inspection.daysUntilNext} dní'
                                  : '',
                          style: TextStyle(fontSize: 12, color: _statusColor, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (isManager)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                    onPressed: () => InspectionsScreen._showInspectionDialog(context, ref, inspection),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Odstrániť revíziu'),
                          content: Text('Naozaj odstrániť "${inspection.title}"?'),
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
                        await ref.read(inspectionRepositoryProvider).deleteInspection(inspection.id);
                        ref.invalidate(inspectionsProvider);
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
