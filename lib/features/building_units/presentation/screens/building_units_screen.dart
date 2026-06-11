import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/app_bar_widget.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../models/building_unit_model.dart';
import '../providers/building_units_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';

// ── Filter state ─────────────────────────────────────────────────────────────

final _filterProvider = StateProvider<String?>((ref) => null);
final _searchQueryProvider = StateProvider<String>((ref) => '');

// ── Screen ───────────────────────────────────────────────────────────────────

class BuildingUnitsScreen extends ConsumerWidget {
  const BuildingUnitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unitsAsync = ref.watch(buildingUnitsProvider);
    final filter = ref.watch(_filterProvider);
    final query = ref.watch(_searchQueryProvider).toLowerCase();

    return Scaffold(
      appBar: const DomovnikAppBar(title: 'Evidencia jednotiek', showBack: true),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context, ref),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          _FilterBar(selected: filter, onSelect: (v) => ref.read(_filterProvider.notifier).state = v),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: TextField(
              onChanged: (v) => ref.read(_searchQueryProvider.notifier).state = v,
              decoration: const InputDecoration(
                hintText: 'Hľadať podľa čísla alebo obyvateľa…',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: unitsAsync.when(
              data: (units) {
                var filtered = filter == null
                    ? units
                    : units.where((u) => u.unitType == filter).toList();
                if (query.isNotEmpty) {
                  filtered = filtered.where((u) {
                    return u.unitNumber.toLowerCase().contains(query) ||
                        (u.residentName ?? '').toLowerCase().contains(query);
                  }).toList();
                }
                filtered.sort((a, b) {
                  final ai = int.tryParse(a.unitNumber);
                  final bi = int.tryParse(b.unitNumber);
                  if (ai != null && bi != null) return ai.compareTo(bi);
                  return a.unitNumber.compareTo(b.unitNumber);
                });

                if (filtered.isEmpty) {
                  return const EmptyStateWidget(
                    icon: Icons.domain_outlined,
                    message: 'Žiadne jednotky',
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) => _UnitCard(
                    unit: filtered[index],
                    onEdit: () => _showEditDialog(context, ref, filtered[index]),
                    onDelete: () => _confirmDelete(context, ref, filtered[index]),
                  ),
                );
              },
              loading: () => const LoadingWidget(),
              error: (e, _) => DomovnikErrorWidget(message: e.toString()),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (_) => _AddUnitDialog(
        onAdd: ({
          required String unitType,
          required String unitNumber,
          required int floor,
          String? residentName,
          String? note,
        }) async {
          final repo = ref.read(buildingUnitRepositoryProvider);
          final buildingId = await ref.read(buildingIdProvider.future);
          await repo.addUnit(
            buildingId: buildingId,
            unitType: unitType,
            unitNumber: unitNumber,
            floor: floor,
            residentName: residentName,
            note: note,
          );
        },
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, BuildingUnitModel unit) {
    showDialog<void>(
      context: context,
      builder: (_) => _EditUnitDialog(
        unit: unit,
        onSave: ({
          required String unitType,
          required String unitNumber,
          required int floor,
          String? residentName,
          String? note,
        }) async {
          await ref.read(buildingUnitRepositoryProvider).updateUnit(
                unit.id,
                unitType: unitType,
                unitNumber: unitNumber,
                floor: floor,
                residentName: residentName?.isEmpty == true ? null : residentName,
                note: note?.isEmpty == true ? null : note,
              );
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, BuildingUnitModel unit) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Zmazať jednotku'),
        content: Text('Naozaj chcete zmazať ${unit.unitTypeLabel} č. ${unit.unitNumber}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Zrušiť'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await ref.read(buildingUnitRepositoryProvider).deleteUnit(unit.id);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Chyba pri mazaní: $e'), backgroundColor: AppColors.error),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Zmazať'),
          ),
        ],
      ),
    );
  }
}

// ── Filter chips ─────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  final String? selected;
  final ValueChanged<String?> onSelect;

  const _FilterBar({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    const filters = [
      (null, 'Všetky'),
      ('byt', 'Byty'),
      ('pivnica', 'Pivnice'),
      ('parkovisko', 'Parkoviská'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: filters.map((f) {
          final isSelected = selected == f.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(f.$2),
              selected: isSelected,
              onSelected: (_) => onSelect(isSelected ? null : f.$1),
              selectedColor: AppColors.primary.withValues(alpha: 0.15),
              checkmarkColor: AppColors.primary,
              labelStyle: TextStyle(
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Unit card ─────────────────────────────────────────────────────────────────

IconData _iconFor(String unitType) => switch (unitType) {
      'byt' => Icons.apartment,
      'pivnica' => Icons.storage,
      'parkovisko' => Icons.local_parking,
      _ => Icons.domain_outlined,
    };

class _UnitCard extends StatelessWidget {
  final BuildingUnitModel unit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _UnitCard({
    required this.unit,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      unit.unitTypeLabel,
      if (unit.floor > 0) '${unit.floor}. poschodie',
    ].join(' · ');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary,
          child: Icon(_iconFor(unit.unitType), color: Colors.white, size: 20),
        ),
        title: Text(
          'č. ${unit.unitNumber}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            Text(
              unit.residentName ?? 'Neobsadená',
              style: TextStyle(
                fontSize: 13,
                color: unit.residentName != null ? AppColors.textPrimary : AppColors.textDisabled,
              ),
            ),
            if (unit.note != null && unit.note!.isNotEmpty)
              Text(
                unit.note!,
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
          ],
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, size: 20, color: AppColors.textSecondary),
          onSelected: (v) {
            if (v == 'edit') onEdit();
            if (v == 'delete') onDelete();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Upraviť')),
            PopupMenuItem(value: 'delete', child: Text('Zmazať')),
          ],
        ),
        onLongPress: onEdit,
      ),
    );
  }
}

// ── Add dialog ────────────────────────────────────────────────────────────────

typedef _OnAdd = Future<void> Function({
  required String unitType,
  required String unitNumber,
  required int floor,
  String? residentName,
  String? note,
});

class _AddUnitDialog extends StatefulWidget {
  final _OnAdd onAdd;
  const _AddUnitDialog({required this.onAdd});

  @override
  State<_AddUnitDialog> createState() => _AddUnitDialogState();
}

class _AddUnitDialogState extends State<_AddUnitDialog> {
  final _formKey = GlobalKey<FormState>();
  String _unitType = 'byt';
  final _unitNumberCtrl = TextEditingController();
  final _floorCtrl = TextEditingController(text: '0');
  final _residentNameCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _unitNumberCtrl.dispose();
    _floorCtrl.dispose();
    _residentNameCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.onAdd(
        unitType: _unitType,
        unitNumber: _unitNumberCtrl.text.trim(),
        floor: int.tryParse(_floorCtrl.text.trim()) ?? 0,
        residentName: _residentNameCtrl.text.trim().isEmpty ? null : _residentNameCtrl.text.trim(),
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Chyba: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Pridať jednotku'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InputDecorator(
                decoration: const InputDecoration(labelText: 'Typ'),
                child: DropdownButton<String>(
                  value: _unitType,
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: 'byt', child: Text('Byt')),
                    DropdownMenuItem(value: 'pivnica', child: Text('Pivnica')),
                    DropdownMenuItem(value: 'parkovisko', child: Text('Parkovisko')),
                  ],
                  onChanged: (v) => setState(() => _unitType = v!),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _unitNumberCtrl,
                decoration: const InputDecoration(labelText: 'Číslo *'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Povinné pole' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _floorCtrl,
                decoration: const InputDecoration(labelText: 'Poschodie'),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v != null && v.trim().isNotEmpty && int.tryParse(v.trim()) == null) {
                    return 'Zadajte číslo';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _residentNameCtrl,
                decoration: const InputDecoration(labelText: 'Meno obyvateľa'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _noteCtrl,
                decoration: const InputDecoration(labelText: 'Poznámka'),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Zrušiť'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Pridať'),
        ),
      ],
    );
  }
}

// ── Edit dialog ───────────────────────────────────────────────────────────────

typedef _OnSave = Future<void> Function({
  required String unitType,
  required String unitNumber,
  required int floor,
  String? residentName,
  String? note,
});

class _EditUnitDialog extends StatefulWidget {
  final BuildingUnitModel unit;
  final _OnSave onSave;
  const _EditUnitDialog({required this.unit, required this.onSave});

  @override
  State<_EditUnitDialog> createState() => _EditUnitDialogState();
}

class _EditUnitDialogState extends State<_EditUnitDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _unitType = widget.unit.unitType;
  late final _unitNumberCtrl = TextEditingController(text: widget.unit.unitNumber);
  late final _floorCtrl = TextEditingController(text: widget.unit.floor.toString());
  late final _residentNameCtrl = TextEditingController(text: widget.unit.residentName ?? '');
  late final _noteCtrl = TextEditingController(text: widget.unit.note ?? '');
  bool _saving = false;

  @override
  void dispose() {
    _unitNumberCtrl.dispose();
    _floorCtrl.dispose();
    _residentNameCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(
        unitType: _unitType,
        unitNumber: _unitNumberCtrl.text.trim(),
        floor: int.tryParse(_floorCtrl.text.trim()) ?? 0,
        residentName: _residentNameCtrl.text.trim().isEmpty ? null : _residentNameCtrl.text.trim(),
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Chyba: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Upraviť ${widget.unit.unitTypeLabel} č. ${widget.unit.unitNumber}'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InputDecorator(
                decoration: const InputDecoration(labelText: 'Typ'),
                child: DropdownButton<String>(
                  value: _unitType,
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: 'byt', child: Text('Byt')),
                    DropdownMenuItem(value: 'pivnica', child: Text('Pivnica')),
                    DropdownMenuItem(value: 'parkovisko', child: Text('Parkovisko')),
                  ],
                  onChanged: (v) => setState(() => _unitType = v!),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _unitNumberCtrl,
                decoration: const InputDecoration(labelText: 'Číslo *'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Povinné pole' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _floorCtrl,
                decoration: const InputDecoration(labelText: 'Poschodie'),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v != null && v.trim().isNotEmpty && int.tryParse(v.trim()) == null) {
                    return 'Zadajte číslo';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _residentNameCtrl,
                decoration: const InputDecoration(labelText: 'Meno obyvateľa'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _noteCtrl,
                decoration: const InputDecoration(labelText: 'Poznámka'),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Zrušiť'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Uložiť'),
        ),
      ],
    );
  }
}
