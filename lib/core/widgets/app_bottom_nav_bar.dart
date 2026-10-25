import 'dart:ui';
import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../theme/app_colors.dart';
import '../theme/liquid_glass_tokens.dart';

/// Centralized Liquid Glass Bottom Navigation Bar.
///
/// Features:
/// - Translucent glass surface with ImageFilter.blur backdrop diffusion
/// - Dual-layer specular highlight on the upper edge
/// - 5 equally spaced destinations with fixed layout
/// - Subtle translucent capsule active indicator
/// - System gesture navigation and bottom display insets handling
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
    final isDark = LiquidGlassTokens.isDark(context);
    final surfaceColor = LiquidGlassTokens.surface(context, elevated: true);
    final borderColor = LiquidGlassTokens.border(context);
    final isReduced = LiquidGlassTokens.isReducedEffects(context);

    Widget navBar = Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(
          top: BorderSide(
            color: borderColor,
            width: 1.0,
          ),
        ),
      ),
      child: Stack(
        children: [
          // Subtle top-edge glass specular highlight
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 18,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LiquidGlassTokens.specularGradient(context),
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: NavigationBarTheme(
              data: NavigationBarThemeData(
                height: 64,
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                indicatorColor: isDark
                    ? AppColors.primaryContainerDark.withValues(alpha: 0.6)
                    : AppColors.primaryContainerLight.withValues(alpha: 0.8),
                indicatorShape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isDark
                        ? const Color(0x33B69AFF)
                        : const Color(0x4D6D3FE8),
                    width: 0.75,
                  ),
                ),
                labelTextStyle: WidgetStateProperty.resolveWith((states) {
                  final isSelected = states.contains(WidgetState.selected);
                  return TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    letterSpacing: -0.1,
                    color: isSelected
                        ? AppColors.primaryOf(context)
                        : AppColors.textSecondary(context),
                  );
                }),
                iconTheme: WidgetStateProperty.resolveWith((states) {
                  final isSelected = states.contains(WidgetState.selected);
                  return IconThemeData(
                    size: 22,
                    color: isSelected
                        ? AppColors.primaryOf(context)
                        : AppColors.textSecondary(context),
                  );
                }),
              ),
              child: NavigationBar(
                selectedIndex: currentIndex,
                onDestinationSelected: onDestinationSelected,
                backgroundColor: Colors.transparent,
                elevation: 0,
                destinations: [
                  const NavigationDestination(
                    icon: Icon(Icons.download_outlined),
                    selectedIcon: Icon(Icons.download_rounded),
                    label: 'Downloader',
                    tooltip: 'Downloader',
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.play_circle_outline_rounded),
                    selectedIcon: const Icon(Icons.play_circle_rounded),
                    label: AppConfig.isPlayStoreBuild ? 'Player' : 'Browser',
                    tooltip: AppConfig.isPlayStoreBuild ? 'Player' : 'YouTube Browser',
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.history_toggle_off_rounded),
                    selectedIcon: Icon(Icons.history_rounded),
                    label: 'Statuses',
                    tooltip: 'WhatsApp Statuses',
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.folder_outlined),
                    selectedIcon: Icon(Icons.folder_rounded),
                    label: 'Downloads',
                    tooltip: 'Downloads',
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.settings_outlined),
                    selectedIcon: Icon(Icons.settings_rounded),
                    label: 'Settings',
                    tooltip: 'Settings',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    if (isReduced) {
      return navBar;
    }

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: LiquidGlassTokens.blurElevated,
          sigmaY: LiquidGlassTokens.blurElevated,
        ),
        child: navBar,
      ),
    );
  }
}
