import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../features/profile/models/profile_model.dart';
import '../../../../features/profile/presentation/providers/profile_provider.dart';
import '../../../../shared/widgets/app_bar_widget.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../models/ticket_model.dart';
import '../providers/tickets_provider.dart';

class TicketDetailScreen extends ConsumerWidget {
  final String ticketId;
  const TicketDetailScreen({super.key, required this.ticketId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticketFuture = ref.watch(ticketDetailProvider(ticketId));
    final profileAsync = ref.watch(profileProvider);
    final profile = profileAsync.valueOrNull;
    final isManager = profile?.isManager ?? false;
    final isSupplier = profile?.isSupplier ?? false;

    final backRoute = isManager
        ? '/manager/tickets'
        : isSupplier
            ? '/supplier/tickets'
            : '/resident/tickets';

    return Scaffold(
      appBar: DomovnikAppBar(
        title: 'Detail tiketu',
        leading: BackButton(
          onPressed: () => context.go(backRoute),
        ),
      ),
      body: ticketFuture.when(
        data: (ticket) {
          if (ticket == null) {
            return const DomovnikErrorWidget(message: 'Tiket sa nenašiel');
          }
          return _TicketDetailBody(ticket: ticket, profileAsync: profileAsync);
        },
        loading: () => const LoadingWidget(),
        error: (e, _) => DomovnikErrorWidget(message: e.toString()),
      ),
    );
  }
}

class _TicketDetailBody extends ConsumerStatefulWidget {
  final TicketModel ticket;
  final AsyncValue<dynamic> profileAsync;

  const _TicketDetailBody({required this.ticket, required this.profileAsync});

  @override
  ConsumerState<_TicketDetailBody> createState() => _TicketDetailBodyState();
}

class _TicketDetailBodyState extends ConsumerState<_TicketDetailBody> {
  late TicketStatus _selectedStatus;
  bool _updating = false;
  String? _selectedSupplierId;
  bool _assigningSupplier = false;

  @override
  void initState() {
    super.initState();
    _selectedSupplierId = widget.ticket.supplierId;
    final isSupplier = widget.profileAsync.valueOrNull?.isSupplier ?? false;
    _selectedStatus = widget.ticket.status;
    if (isSupplier && _selectedStatus == TicketStatus.prijate) {
      _selectedStatus = TicketStatus.vRieseni;
    }
  }

  Future<void> _updateStatus() async {
    if (_selectedStatus == widget.ticket.status) return;
    setState(() => _updating = true);
    try {
      await ref
          .read(updateTicketStatusProvider.notifier)
          .updateStatus(widget.ticket.id, _selectedStatus);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Stav tiketu bol aktualizovaný'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba: ${e.toString()}'), backgroundColor: AppColors.error),
        );
        setState(() => _selectedStatus = widget.ticket.status);
      }
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _assignSupplier() async {
    if (_selectedSupplierId == widget.ticket.supplierId) return;
    setState(() => _assigningSupplier = true);
    try {
      await ref
          .read(assignSupplierProvider.notifier)
          .assignSupplier(widget.ticket.id, _selectedSupplierId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dodávateľ bol priradený'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba: ${e.toString()}'), backgroundColor: AppColors.error),
        );
        setState(() => _selectedSupplierId = widget.ticket.supplierId);
      }
    } finally {
      if (mounted) setState(() => _assigningSupplier = false);
    }
  }

  void _showPhotoFullscreen(BuildContext context, List<String> urls, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _PhotoGalleryScreen(urls: urls, initialIndex: initialIndex),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isManager = widget.profileAsync.maybeWhen(
      data: (profile) => profile?.isManager ?? false,
      orElse: () => false,
    );
    final isSupplier = widget.profileAsync.maybeWhen(
      data: (profile) => profile?.isSupplier ?? false,
      orElse: () => false,
    );

    final photos = widget.ticket.allPhotoUrls;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(widget.ticket.title, style: Theme.of(context).textTheme.headlineSmall),
                      ),
                      const SizedBox(width: 8),
                      StatusBadge(status: widget.ticket.status),
                    ],
                  ),
                  const SizedBox(height: 8),
                  CategoryChip(category: widget.ticket.category),
                  const SizedBox(height: 12),
                  _DetailRow(
                    icon: Icons.person_outline,
                    label: 'Vytvoril',
                    value: widget.ticket.createdByName ?? 'Neznámy',
                  ),
                  _DetailRow(
                    icon: Icons.calendar_today_outlined,
                    label: 'Vytvorené',
                    value: DateFormatter.formatDateTime(widget.ticket.createdAt),
                  ),
                  _DetailRow(
                    icon: Icons.update_outlined,
                    label: 'Aktualizované',
                    value: DateFormatter.formatDateTime(widget.ticket.updatedAt),
                  ),
                  if (widget.ticket.supplierName != null)
                    _DetailRow(
                      icon: Icons.engineering_outlined,
                      label: 'Dodávateľ',
                      value: widget.ticket.supplierName!,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Description
          if (widget.ticket.description != null && widget.ticket.description!.isNotEmpty) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Popis', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    Text(widget.ticket.description!, style: const TextStyle(fontSize: 15)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ── Fotografie ────────────────────────────────────────────────
          if (photos.isNotEmpty) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fotografie (${photos.length})',
                      style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    // Zoznam fotiek — plná šírka, max výška 200px
                    Column(
                      children: List.generate(photos.length, (index) {
                        return Padding(
                          padding: EdgeInsets.only(bottom: index < photos.length - 1 ? 8 : 0),
                          child: GestureDetector(
                            onTap: () => _showPhotoFullscreen(context, photos, index),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox(
                                height: 200,
                                width: double.infinity,
                                child: CachedNetworkImage(
                                    imageUrl: photos[index],
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) => Container(
                                      height: 120,
                                      color: AppColors.surface,
                                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                    ),
                                    errorWidget: (_, __, ___) => Container(
                                      height: 80,
                                      color: AppColors.surface,
                                      child: const Icon(Icons.broken_image_outlined, color: AppColors.textSecondary),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Timeline
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Priebeh riešenia', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  _TimelineStep(
                    label: 'Prijaté',
                    icon: Icons.inbox_outlined,
                    color: AppColors.statusPrijate,
                    active: true,
                    date: DateFormatter.formatDate(widget.ticket.createdAt),
                  ),
                  _TimelineStep(
                    label: 'V riešení',
                    icon: Icons.build_outlined,
                    color: AppColors.statusVRieseni,
                    active: widget.ticket.status == TicketStatus.vRieseni ||
                        widget.ticket.status == TicketStatus.ukoncene,
                  ),
                  _TimelineStep(
                    label: 'Ukončené',
                    icon: Icons.check_circle_outline,
                    color: AppColors.statusUkoncene,
                    active: widget.ticket.status == TicketStatus.ukoncene,
                    isLast: true,
                  ),
                ],
              ),
            ),
          ),

          // Status update: manager sees all statuses, supplier sees vRieseni + ukoncene
          if (isManager || isSupplier) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Zmeniť stav tiketu', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<TicketStatus>(
                      value: _selectedStatus,
                      decoration: const InputDecoration(
                        labelText: 'Stav',
                        prefixIcon: Icon(Icons.edit_outlined),
                      ),
                      items: (isSupplier
                              ? [TicketStatus.vRieseni, TicketStatus.ukoncene]
                              : TicketStatus.values)
                          .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedStatus = v!),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _updating ? null : _updateStatus,
                      child: _updating
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Aktualizovať stav'),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Supplier assignment: manager only
          if (isManager) ...[
            const SizedBox(height: 12),
            _SupplierAssignCard(
              ticket: widget.ticket,
              selectedSupplierId: _selectedSupplierId,
              assigning: _assigningSupplier,
              onChanged: (id) => setState(() => _selectedSupplierId = id),
              onAssign: _assignSupplier,
            ),
          ],
        ],
      ),
    );
  }
}

// ── Fullscreen galéria ───────────────────────────────────────────────────────

class _PhotoGalleryScreen extends StatefulWidget {
  final List<String> urls;
  final int initialIndex;

  const _PhotoGalleryScreen({required this.urls, required this.initialIndex});

  @override
  State<_PhotoGalleryScreen> createState() => _PhotoGalleryScreenState();
}

class _PhotoGalleryScreenState extends State<_PhotoGalleryScreen> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_currentIndex + 1} / ${widget.urls.length}'),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.urls.length,
        onPageChanged: (i) => setState(() => _currentIndex = i),
        itemBuilder: (context, index) {
          return InteractiveViewer(
            child: Center(
              child: CachedNetworkImage(
                imageUrl: widget.urls[index],
                fit: BoxFit.contain,
                placeholder: (_, __) => const Center(child: CircularProgressIndicator(color: Colors.white)),
                errorWidget: (_, __, ___) => const Icon(Icons.broken_image_outlined, color: Colors.white, size: 48),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Supplier assignment card ─────────────────────────────────────────────────

class _SupplierAssignCard extends ConsumerWidget {
  final TicketModel ticket;
  final String? selectedSupplierId;
  final bool assigning;
  final void Function(String?) onChanged;
  final VoidCallback onAssign;

  const _SupplierAssignCard({
    required this.ticket,
    required this.selectedSupplierId,
    required this.assigning,
    required this.onChanged,
    required this.onAssign,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dodavatelAsync = ref.watch(buildingDodavatelProfilesProvider(ticket.buildingId));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Priradiť dodávateľa',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            dodavatelAsync.when(
              data: (dodavatelia) => DropdownButtonFormField<String?>(
                value: selectedSupplierId,
                decoration: const InputDecoration(
                  labelText: 'Dodávateľ',
                  prefixIcon: Icon(Icons.engineering_outlined),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('— Žiadny —')),
                  ...dodavatelia.map((ProfileModel p) => DropdownMenuItem(
                        value: p.id,
                        child: Text(p.fullName ?? p.email),
                      )),
                ],
                onChanged: onChanged,
              ),
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const Text(
                'Chyba pri načítaní dodávateľov',
                style: TextStyle(color: AppColors.error),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: assigning ? null : onAssign,
              child: assigning
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Priradiť'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text('$label: ', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

class _TimelineStep extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool active;
  final String? date;
  final bool isLast;

  const _TimelineStep({
    required this.label,
    required this.icon,
    required this.color,
    required this.active,
    this.date,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Column(
          children: [
            Icon(icon, color: active ? color : AppColors.textDisabled, size: 24),
            if (!isLast)
              Container(
                width: 2,
                height: 24,
                color: active ? color.withValues(alpha: 0.3) : AppColors.divider,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: active ? AppColors.textPrimary : AppColors.textDisabled,
                ),
              ),
              if (date != null)
                Text(date!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }
}
