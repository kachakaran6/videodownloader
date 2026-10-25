import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../theme/app_colors.dart';

/// Centralized, production-grade Material 3 Bottom Navigation Bar.
///
/// Strictly conforms to the Samyukt Design Standard:
/// - 5 equally spaced destinations.
/// - Fixed, predictable layout (no jumping widths or expanding rows).
/// - Restrained subtle active indicator (no glowing shadows or floating pills).
/// - Proper handling of system gesture navigation and display insets.
class AppBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;

  const AppBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        border: Border(
          top: BorderSide(
            color: AppColors.border(context),
            width: 1.0,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: NavigationBar(
          selectedIndex: currentIndex,
          onDestinationSelected: onDestinationSelected,
          backgroundColor: Colors.transparent,
          elevation: 0,
          height: 64,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          indicatorColor: isDark
              ? AppColors.primaryContainerDark
              : AppColors.primaryContainerLight,
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.download_outlined, size: 22),
              selectedIcon: Icon(Icons.download_rounded, size: 22),
              label: 'Downloader',
              tooltip: 'Downloader',
            ),
            NavigationDestination(
              icon: const Icon(Icons.play_circle_outline_rounded, size: 22),
              selectedIcon: const Icon(Icons.play_circle_rounded, size: 22),
              label: AppConfig.isPlayStoreBuild ? 'Player' : 'Browser',
              tooltip: AppConfig.isPlayStoreBuild ? 'Player' : 'YouTube Browser',
            ),
            const NavigationDestination(
              icon: Icon(Icons.history_toggle_off_rounded, size: 22),
              selectedIcon: Icon(Icons.history_rounded, size: 22),
              label: 'Statuses',
              tooltip: 'WhatsApp Statuses',
            ),
            const NavigationDestination(
              icon: Icon(Icons.folder_outlined, size: 22),
              selectedIcon: Icon(Icons.folder_rounded, size: 22),
              label: 'Downloads',
              tooltip: 'Downloads',
            ),
            const NavigationDestination(
              icon: Icon(Icons.settings_outlined, size: 22),
              selectedIcon: Icon(Icons.settings_rounded, size: 22),
              label: 'Settings',
              tooltip: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
