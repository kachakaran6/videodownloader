import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_typography.dart';

class NavDestination {
  final IconData icon;
  final String label;

  const NavDestination({
    required this.icon,
    required this.label,
  });
}

/// Redesigned Floating Pill Navigation Bar.
///
/// Specs (Bugfix Refactor):
/// - 68dp tall, radius 28, side margins 16dp, bottom margin 12dp + safe area
/// - Surface color with 1dp outline and soft tinted shadow
/// - Five equal-width items, each with 24dp icon and 11sp label underneath (always labeled)
/// - Sliding animated primaryContainer pill (radius 20, 250ms easeOutCubic) behind selected item
/// - Selected in primary color; unselected in textTertiary
/// - Rounded icons: home, play_circle, bookmark_added, folder_open, settings
/// - Light haptic feedback on tab change
/// - Live Activity Strip above when download is running
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

  static const List<NavDestination> destinations = [
    NavDestination(
      icon: Icons.home_rounded,
      label: 'Home',
    ),
    NavDestination(
      icon: Icons.play_circle_rounded,
      label: 'Watch',
    ),
    NavDestination(
      icon: Icons.bookmark_added_rounded,
      label: 'Status',
    ),
    NavDestination(
      icon: Icons.folder_open_rounded,
      label: 'Library',
    ),
    NavDestination(
      icon: Icons.settings_rounded,
      label: 'Settings',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isDark = AppColors.isDark(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    final hasActiveDownload = activeDownloadTitle != null &&
        activeDownloadTitle!.isNotEmpty &&
        currentIndex != 3;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 12 + bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ─── Live Activity Strip (44dp) ──────────────────────────────────
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
                      blurRadius: 14,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        value: activeProgress > 0 ? activeProgress : null,
                        strokeWidth: 2.2,
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
                          fontSize: 12,
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

          // ─── Floating Navigation Bar (68dp, radius 28) ───────────────────
          Container(
            height: 68,
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: colors.outline, width: 1.0),
              boxShadow: [
                BoxShadow(
                  color: colors.primary.withValues(alpha: isDark ? 0.25 : 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = constraints.maxWidth / destinations.length;

                return Stack(
                  children: [
                    // Sliding Animated Selection Pill
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      left: currentIndex * itemWidth,
                      top: 0,
                      bottom: 0,
                      width: itemWidth,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                        decoration: BoxDecoration(
                          color: colors.primaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),

                    // Destination Row
                    Row(
                      children: destinations.asMap().entries.map((entry) {
                        final index = entry.key;
                        final dest = entry.value;
                        final isSelected = currentIndex == index;

                        return Expanded(
                          child: Semantics(
                            button: true,
                            selected: isSelected,
                            label: dest.label,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  onDestinationSelected(index);
                                },
                                borderRadius: BorderRadius.circular(20),
                                child: Center(
                                  child: Tooltip(
                                    message: dest.label,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          dest.icon,
                                          size: 24,
                                          color: isSelected ? colors.primary : colors.textTertiary,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          dest.label,
                                          maxLines: 1,
                                          style: AppTypography.caption(context).copyWith(
                                            fontSize: 11,
                                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                            color: isSelected ? colors.primary : colors.textTertiary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
