import 'dart:ui';
import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../theme/app_colors.dart';
import '../theme/liquid_glass_tokens.dart';

/// Refined Floating Liquid Glass Bottom Navigation Bar.
///
/// Features:
/// - Compact floating pill silhouette elevated above the background
/// - Subtle translucent fill with BackdropFilter blur diffusion
/// - Fine edge hairline border without heavy metallic borders
/// - 5 perfectly balanced destinations with fixed, stable dimensions
/// - Restrained active capsule indicator with smooth transitions
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
    final isReduced = LiquidGlassTokens.isReducedEffects(context);

    final destinations = [
      _NavDestination(
        icon: Icons.download_outlined,
        selectedIcon: Icons.download_rounded,
        label: 'Downloader',
      ),
      _NavDestination(
        icon: Icons.play_circle_outline_rounded,
        selectedIcon: Icons.play_circle_rounded,
        label: AppConfig.isPlayStoreBuild ? 'Player' : 'Browser',
      ),
      _NavDestination(
        icon: Icons.history_toggle_off_rounded,
        selectedIcon: Icons.history_rounded,
        label: 'Statuses',
      ),
      _NavDestination(
        icon: Icons.folder_outlined,
        selectedIcon: Icons.folder_rounded,
        label: 'Downloads',
      ),
      _NavDestination(
        icon: Icons.settings_outlined,
        selectedIcon: Icons.settings_rounded,
        label: 'Settings',
      ),
    ];

    final pillBorderRadius = BorderRadius.circular(26);

    Widget navContent = Container(
      height: 64,
      decoration: BoxDecoration(
        color: isDark ? const Color(0x9E181622) : const Color(0xEAFFFFFF),
        borderRadius: pillBorderRadius,
        border: Border.all(
          color: isDark ? const Color(0x1FFFFFFF) : const Color(0x2E7045E8),
          width: 0.8,
        ),
      ),
      child: Row(
        children: destinations.asMap().entries.map((entry) {
          final index = entry.key;
          final dest = entry.value;
          final isSelected = currentIndex == index;

          return Expanded(
            child: _NavBarItem(
              destination: dest,
              isSelected: isSelected,
              isDark: isDark,
              onTap: () => onDestinationSelected(index),
            ),
          );
        }).toList(),
      ),
    );

    Widget floatingPill = Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        borderRadius: pillBorderRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: isReduced
          ? ClipRRect(
              borderRadius: pillBorderRadius,
              child: navContent,
            )
          : ClipRRect(
              borderRadius: pillBorderRadius,
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: LiquidGlassTokens.blurElevated,
                  sigmaY: LiquidGlassTokens.blurElevated,
                ),
                child: navContent,
              ),
            ),
    );

    return SafeArea(
      top: false,
      child: floatingPill,
    );
  }
}

class _NavDestination {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const _NavDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

class _NavBarItem extends StatelessWidget {
  final _NavDestination destination;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.destination,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = AppColors.primaryOf(context);
    final inactiveColor = isDark ? const Color(0xFFA8A2B4) : const Color(0xFF777184);

    return Material(
      color: Colors.transparent,
      child: Tooltip(
        message: destination.label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          splashColor: activeColor.withValues(alpha: 0.1),
          highlightColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: LiquidGlassTokens.durationFast,
              curve: LiquidGlassTokens.curveDefault,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? (isDark ? const Color(0x33B49AFF) : const Color(0x247045E8))
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                isSelected ? destination.selectedIcon : destination.icon,
                size: 21,
                color: isSelected ? activeColor : inactiveColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              destination.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                letterSpacing: -0.1,
                color: isSelected ? activeColor : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
}
