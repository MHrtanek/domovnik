import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../features/profile/presentation/providers/profile_provider.dart';
import '../../../../shared/widgets/app_bar_widget.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../models/reservation_model.dart';
import '../providers/reservation_provider.dart';

final _dateFormat = DateFormat('d. M. yyyy');
final _timeSlots = [
  '06:00', '07:00', '08:00', '09:00', '10:00', '11:00',
  '12:00', '13:00', '14:00', '15:00', '16:00', '17:00',
  '18:00', '19:00', '20:00',
];

class ReservationsScreen extends ConsumerWidget {
  const ReservationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    final amenitiesAsync = ref.watch(amenitiesProvider);
    final reservationsAsync = ref.watch(allReservationsProvider);

    return Scaffold(
      appBar: const DomovnikAppBar(
        title: 'Rezervácie',
        showBack: false,
        showLogout: true, // ← logout vpravo hore na mobile
      ),
      body: profileAsync.when(
        data: (profile) {
          if (profile == null) return const LoadingWidget();

          return DefaultTabController(
            length: profile.isManager ? 3 : 2,
            child: Column(
              children: [
                TabBar(
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorColor: AppColors.primary,
                  tabs: [
                    const Tab(text: 'Rezervovať'),
                    const Tab(text: 'Moje rezervácie'),
                    if (profile.isManager) const Tab(text: 'Správca'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _BookingTab(profile: profile),
                      _MyReservationsTab(
                        reservationsAsync: reservationsAsync,
                        isManager: profile.isManager,
                        currentUserId: profile.id,
                      ),
                      if (profile.isManager)
                        _ManageAmenitiesTab(amenitiesAsync: amenitiesAsync),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const LoadingWidget(),
        error: (e, _) => DomovnikErrorWidget(message: e.toString()),
      ),
    );
  }
}

// ── Tab 1: Rezervovať ────────────────────────────────────────────────────────

class _BookingTab extends ConsumerStatefulWidget {
  final dynamic profile;
  const _BookingTab({required this.profile});

  @override
  ConsumerState<_BookingTab> createState() => _BookingTabState();
}

class _BookingTabState extends ConsumerState<_BookingTab> {
  AmenityModel? _selectedAmenity;
  DateTime _selectedDate = DateTime.now();
  String? _selectedTimeFrom;
  String? _selectedTimeTo;
  final _noteController = TextEditingController();
  bool _submitting = false;
  List<String> _takenSlots = [];

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadTakenSlots() async {
    if (_selectedAmenity == null) return;
    final reservations = await ref
        .read(reservationRepositoryProvider)
        .getReservationsForAmenityAndDate(
          amenityId: _selectedAmenity!.id,
          date: _selectedDate,
        );
    setState(() {
      _takenSlots = reservations.map((r) => r.timeFrom).toList();
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _selectedTimeFrom = null;
        _selectedTimeTo = null;
      });
      await _loadTakenSlots();
    }
  }

  /// Vráti index slotu v _timeSlots, alebo -1 ak nie je nájdený.
  int _slotIndex(String slot) => _timeSlots.indexOf(slot);

  /// Určí, či je slot "Do" validný voči vybranému "Od".
  /// Slot "Do" musí byť NESKÔR ako "Od".
  bool _isValidToSlot(String slot) {
    if (_selectedTimeFrom == null) return false;
    return _slotIndex(slot) > _slotIndex(_selectedTimeFrom!);
  }

  Future<void> _submit() async {
    if (_selectedAmenity == null ||
        _selectedTimeFrom == null ||
        _selectedTimeTo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vyberte priestor, dátum a čas'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref.read(createReservationProvider.notifier).createReservation(
            amenityId: _selectedAmenity!.id,
            date: _selectedDate,
            timeFrom: _selectedTimeFrom!,
            timeTo: _selectedTimeTo!,
            note: _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rezervácia bola vytvorená'),
            backgroundColor: AppColors.success,
          ),
        );
        setState(() {
          _selectedTimeFrom = null;
          _selectedTimeTo = null;
          _noteController.clear();
        });
        await _loadTakenSlots();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().contains('obsadený') ||
                      e.toString().contains('unique')
                  ? 'Tento čas je už obsadený'
                  : 'Chyba: ${e.toString()}',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final amenitiesAsync = ref.watch(amenitiesProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Výber priestoru ───────────────────────────────────────────────
          const Text(
            'Spoločný priestor',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          const SizedBox(height: 8),
          amenitiesAsync.when(
            data: (amenities) {
              if (amenities.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Žiadne spoločné priestory.\nSprávca musí najprv pridať priestory.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                );
              }
              return Wrap(
                spacing: 8,
                children: amenities.map((a) {
                  final selected = _selectedAmenity?.id == a.id;
                  return ChoiceChip(
                    label: Text(a.name),
                    selected: selected,
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : AppColors.textPrimary,
                    ),
                    onSelected: (_) async {
                      setState(() {
                        _selectedAmenity = a;
                        _selectedTimeFrom = null;
                        _selectedTimeTo = null;
                      });
                      await _loadTakenSlots();
                    },
                  );
                }).toList(),
              );
            },
            loading: () => const LoadingWidget(),
            error: (e, _) => Text('Chyba: $e'),
          ),

          const SizedBox(height: 20),

          // ── Výber dátumu ──────────────────────────────────────────────────
          const Text(
            'Dátum',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.divider),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today,
                      size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(_dateFormat.format(_selectedDate)),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── Výber "Od" ────────────────────────────────────────────────────
          const Text(
            'Čas od',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _timeSlots.map((slot) {
              // Posledný slot nemôže byť "Od" (nemal by slotTo)
              final isLastSlot = slot == _timeSlots.last;
              final taken = _takenSlots.contains(slot);
              final disabled = taken || isLastSlot;
              final selected = _selectedTimeFrom == slot;
              return ChoiceChip(
                label: Text(slot),
                selected: selected,
                selectedColor: AppColors.primary,
                disabledColor: Colors.grey.shade200,
                labelStyle: TextStyle(
                  color: disabled
                      ? Colors.grey
                      : selected
                          ? Colors.white
                          : AppColors.textPrimary,
                  fontSize: 12,
                ),
                onSelected: disabled
                    ? null
                    : (_) {
                        setState(() {
                          _selectedTimeFrom = slot;
                          // Resetuj "Do" – user musí znova vybrať
                          _selectedTimeTo = null;
                        });
                      },
              );
            }).toList(),
          ),

          const SizedBox(height: 20),

          // ── Výber "Do" ────────────────────────────────────────────────────
          Row(
            children: [
              const Text(
                'Čas do',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              if (_selectedTimeFrom == null) ...[
                const SizedBox(width: 8),
                const Text(
                  '(najprv vyberte čas Od)',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _timeSlots.map((slot) {
              // "Do" musí byť neskôr ako "Od"
              final valid = _isValidToSlot(slot);
              final taken = _takenSlots.contains(slot);
              // Slot je disabled ak:
              //  - ešte nie je vybrané "Od"
              //  - slot nie je neskôr ako "Od"
              //  - slot je obsadený
              final disabled = _selectedTimeFrom == null || !valid || taken;
              final selected = _selectedTimeTo == slot;
              return ChoiceChip(
                label: Text(slot),
                selected: selected,
                selectedColor: AppColors.secondary,
                disabledColor: Colors.grey.shade100,
                labelStyle: TextStyle(
                  color: disabled
                      ? Colors.grey.shade400
                      : selected
                          ? Colors.white
                          : AppColors.textPrimary,
                  fontSize: 12,
                ),
                onSelected: disabled
                    ? null
                    : (_) {
                        setState(() => _selectedTimeTo = slot);
                      },
              );
            }).toList(),
          ),

          if (_selectedTimeFrom != null && _selectedTimeTo != null) ...[
            const SizedBox(height: 8),
            Text(
              'Rezervácia: $_selectedTimeFrom – $_selectedTimeTo',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],

          const SizedBox(height: 20),

          // ── Poznámka ──────────────────────────────────────────────────────
          TextField(
            controller: _noteController,
            decoration: const InputDecoration(
              labelText: 'Poznámka (voliteľné)',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: const Text('Rezervovať'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab 2: Moje rezervácie ───────────────────────────────────────────────────

class _MyReservationsTab extends ConsumerWidget {
  final AsyncValue<List<ReservationModel>> reservationsAsync;
  final bool isManager;
  final String currentUserId;

  const _MyReservationsTab({
    required this.reservationsAsync,
    required this.isManager,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return reservationsAsync.when(
      data: (reservations) {
        if (reservations.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.event_available_outlined,
            message: 'Žiadne rezervácie',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: reservations.length,
          itemBuilder: (context, index) {
            final r = reservations[index];
            final canDelete = r.residentId == currentUserId || isManager;
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.meeting_room_outlined,
                            color: AppColors.primary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          r.amenityName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                        const Spacer(),
                        if (canDelete)
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: AppColors.error, size: 20),
                            onPressed: () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Zrušiť rezerváciu'),
                                  content: Text(
                                    'Naozaj chcete zrušiť rezerváciu na '
                                    '${r.amenityName} '
                                    '${_dateFormat.format(r.date)} '
                                    '${r.timeFrom}–${r.timeTo}?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(ctx).pop(false),
                                      child: const Text('Nie'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () =>
                                          Navigator.of(ctx).pop(true),
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.error),
                                      child: const Text('Zrušiť'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed != true) return;
                              try {
                                await ref
                                    .read(reservationRepositoryProvider)
                                    .deleteReservation(r.id);
                                ref.invalidate(allReservationsProvider);
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Chyba: $e'),
                                      backgroundColor: AppColors.error,
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today,
                            size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          _dateFormat.format(r.date),
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.textSecondary),
                        ),
                        const SizedBox(width: 16),
                        const Icon(Icons.access_time,
                            size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          '${r.timeFrom} – ${r.timeTo}',
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    if (isManager && r.residentName != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.person_outline,
                              size: 14, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            r.residentName!,
                            style: const TextStyle(
                                fontSize: 13, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ],
                    if (r.note != null && r.note!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        r.note!,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const LoadingWidget(),
      error: (e, _) => DomovnikErrorWidget(message: e.toString()),
    );
  }
}

// ── Tab 3: Správca priestorov (manager) ──────────────────────────────────────

class _ManageAmenitiesTab extends ConsumerWidget {
  final AsyncValue<List<AmenityModel>> amenitiesAsync;

  const _ManageAmenitiesTab({required this.amenitiesAsync});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddAmenityDialog(context, ref),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Pridať priestor',
            style: TextStyle(color: Colors.white)),
      ),
      body: amenitiesAsync.when(
        data: (amenities) {
          if (amenities.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.meeting_room_outlined,
              message: 'Žiadne spoločné priestory',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: amenities.length,
            itemBuilder: (context, index) {
              final a = amenities[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.meeting_room_outlined,
                      color: AppColors.primary),
                  title: Text(a.name),
                  subtitle:
                      a.description != null ? Text(a.description!) : null,
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: AppColors.error),
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Odstrániť priestor'),
                          content: Text(
                            'Naozaj chcete odstrániť priestor „${a.name}"? '
                            'Odstránia sa aj všetky jeho rezervácie.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: const Text('Zrušiť'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.of(ctx).pop(true),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.error),
                              child: const Text('Odstrániť'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed != true) return;
                      try {
                        await ref
                            .read(reservationRepositoryProvider)
                            .deleteAmenity(a.id);
                        ref.invalidate(amenitiesProvider);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Chyba: $e'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                      }
                    },
                  ),
                ),
              );
            },
          );
        },
        loading: () => const LoadingWidget(),
        error: (e, _) => DomovnikErrorWidget(message: e.toString()),
      ),
    );
  }

  void _showAddAmenityDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nový priestor'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Názov *'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Zadajte názov' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: descController,
                decoration:
                    const InputDecoration(labelText: 'Popis (voliteľné)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Zrušiť'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.of(ctx).pop();
              final profile = await ref.read(profileProvider.future);
              if (profile?.buildingId == null) return;
              await ref.read(reservationRepositoryProvider).createAmenity(
                    name: nameController.text.trim(),
                    description: descController.text.trim().isEmpty
                        ? null
                        : descController.text.trim(),
                    buildingId: profile!.buildingId!,
                  );
              ref.invalidate(amenitiesProvider);
            },
            child: const Text('Pridať'),
          ),
        ],
      ),
    );
  }
}
