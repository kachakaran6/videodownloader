import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_typography.dart';

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

/// Floating Pill Navigation Bar with Live Activity Strip.
///
/// Features:
/// - 5 items: Home, Browse, Status, Library, Settings
/// - 64dp height, 24dp radius, floating 12dp above bottom with side margins
/// - Selected item displays a lagoon container pill with icon + label; others icon only
/// - Optional 44dp Live Activity Strip above the nav when a download is running and user is not on Library tab
class FloatingNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final String? activeDownloadTitle;
  final double activeProgress; // 0.0 to 1.0
  final String? activeSpeed; // e.g. "4.2 MB/s"

  const FloatingNavBar({
    super.key,
    required this.currentIndex,
    required this.onDestinationSelected,
    this.activeDownloadTitle,
    this.activeProgress = 0.0,
    this.activeSpeed,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isDark = AppColors.isDark(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    const destinations = [
      _NavDestination(
        icon: Icons.home_outlined,
        selectedIcon: Icons.home_rounded,
        label: 'Home',
      ),
      _NavDestination(
        icon: Icons.play_circle_outline_rounded,
        selectedIcon: Icons.play_circle_rounded,
        label: 'Watch',
      ),
      _NavDestination(
        icon: Icons.history_toggle_off_rounded,
        selectedIcon: Icons.history_rounded,
        label: 'Status',
      ),
      _NavDestination(
        icon: Icons.folder_outlined,
        selectedIcon: Icons.folder_rounded,
        label: 'Library',
      ),
      _NavDestination(
        icon: Icons.settings_outlined,
        selectedIcon: Icons.settings_rounded,
        label: 'Settings',
      ),
    ];

    final hasActiveDownload = activeDownloadTitle != null &&
        activeDownloadTitle!.isNotEmpty &&
        currentIndex != 3;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 12 + bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ─── 6) Live Activity Strip (44dp) ───────────────────────────────
          if (hasActiveDownload) ...[
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                onDestinationSelected(3); // Jump to Library
              },
              child: Container(
                height: 44,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: AppRadii.r20,
                  border: Border.all(color: colors.primary.withValues(alpha: 0.5), width: 1.0),
                  boxShadow: [
                    BoxShadow(
                      color: colors.primary.withValues(alpha: isDark ? 0.25 : 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        value: activeProgress.clamp(0.0, 1.0),
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
                        backgroundColor: colors.surfaceAlt,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        activeDownloadTitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption(context).copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(activeProgress * 100).toInt()}%',
                      style: AppTypography.tabularFigures(
                        context,
                        fontSize: 12,
                        color: colors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (activeSpeed != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        '($activeSpeed)',
                        style: AppTypography.tabularFigures(
                          context,
                          fontSize: 11,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right_rounded, size: 18, color: colors.textTertiary),
                  ],
                ),
              ),
            ),
          ],

          // ─── 5) Floating Pill Navigation (64dp, 24 radius) ────────────────
          Container(
            height: 64,
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: colors.outline, width: 1.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.07),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: destinations.asMap().entries.map((entry) {
                final index = entry.key;
                final dest = entry.value;
                final isSelected = currentIndex == index;

                return Expanded(
                  child: Tooltip(
                    message: dest.label,
                    child: Semantics(
                      button: true,
                      selected: isSelected,
                      label: dest.label,
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          onDestinationSelected(index);
                        },
                      borderRadius: BorderRadius.circular(20),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? colors.primaryContainer
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isSelected ? dest.selectedIcon : dest.icon,
                              size: 22,
                              color: isSelected ? colors.primary : colors.textSecondary,
                            ),
                            if (isSelected) ...[
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  dest.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.caption(context).copyWith(
                                    color: colors.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Backward compatibility alias
class AppBottomNavBar extends FloatingNavBar {
  const AppBottomNavBar({
    super.key,
    required super.currentIndex,
    required super.onDestinationSelected,
    super.activeDownloadTitle,
    super.activeProgress,
    super.activeSpeed,
  });
}
