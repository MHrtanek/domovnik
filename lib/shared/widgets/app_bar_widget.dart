import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';

/// AppBar pre Domovník.
///
/// [showLogout] – zobrazí ikonu odhlásenia vpravo hore.
///   • Na mobile shelloch: nastavujte `showLogout: true` (default).
///   • Na PC: logout je v NavigationRail, takže AppBar ho nepotrebuje.
///   • Na detail-screenoch (showBack: true): logout sa nezobrazuje.
class DomovnikAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool showBack;
  final Widget? leading;
  final Color? backgroundColor;
  final Color? foregroundColor;
  // showLogout: true = zobrazí logout ikonu vpravo na mobilných hlavných screenoch
  final bool showLogout;

  const DomovnikAppBar({
    super.key,
    required this.title,
    this.actions,
    this.showBack = true,
    this.leading,
    this.backgroundColor,
    this.foregroundColor,
    this.showLogout = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Na PC (šírka > 600) je logout v NavigationRail → v AppBar ho nechceme
    final isWide = MediaQuery.of(context).size.width > 600;
    final showLogoutBtn = showLogout && !isWide;

    final List<Widget> allActions = [
      if (actions != null) ...actions!,
      if (showLogoutBtn)
        IconButton(
          icon: const Icon(Icons.logout),
          tooltip: 'Odhlásiť sa',
          onPressed: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Odhlásiť sa'),
                content: const Text('Naozaj sa chcete odhlásiť?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Zrušiť'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                    ),
                    child: const Text('Odhlásiť'),
                  ),
                ],
              ),
            );
            if (confirmed == true) {
              await ref.read(authNotifierProvider.notifier).signOut();
              if (context.mounted) context.go('/login');
            }
          },
        ),
    ];

    return AppBar(
      title: Text(title),
      centerTitle: true,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      leading: leading ??
          (showBack ? BackButton(onPressed: () => context.pop()) : null),
      automaticallyImplyLeading: showBack,
      actions: allActions.isEmpty ? null : allActions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
