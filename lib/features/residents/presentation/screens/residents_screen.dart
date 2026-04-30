import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../features/profile/models/profile_model.dart';
import '../../../../shared/widgets/app_bar_widget.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../providers/residents_provider.dart';

final _searchQueryProvider = StateProvider<String>((ref) => '');

class ResidentsScreen extends ConsumerWidget {
  const ResidentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final residentsAsync = ref.watch(residentsProvider);
    final searchQuery = ref.watch(_searchQueryProvider).toLowerCase();

    return Scaffold(
      appBar: const DomovnikAppBar(title: 'Evidencia bytov', showBack: true),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              onChanged: (v) => ref.read(_searchQueryProvider.notifier).state = v,
              decoration: const InputDecoration(
                hintText: 'Hľadať podľa mena alebo čísla bytu…',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: residentsAsync.when(
              data: (residents) {
                final filtered = searchQuery.isEmpty
                    ? residents
                    : residents.where((r) {
                        return (r.fullName ?? '').toLowerCase().contains(searchQuery) ||
                            (r.flatNumber ?? '').toLowerCase().contains(searchQuery);
                      }).toList();

                if (filtered.isEmpty) {
                  return const EmptyStateWidget(
                    icon: Icons.people_outlined,
                    message: 'Žiadni obyvatelia',
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) => _ResidentCard(resident: filtered[index]),
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
}

class _ResidentCard extends StatelessWidget {
  final ProfileModel resident;
  const _ResidentCard({required this.resident});

  @override
  Widget build(BuildContext context) {
    final initials = (resident.fullName ?? '?')
        .trim()
        .split(' ')
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary,
          child: Text(
            initials,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ),
        title: Text(resident.fullName ?? 'Neznámy', style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('Byt č. ${resident.flatNumber ?? 'nezadaný'}'),
        trailing: resident.phone != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.phone_outlined, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(resident.phone!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              )
            : null,
      ),
    );
  }
}
