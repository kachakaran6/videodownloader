import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_typography.dart';

/// Floating Amber "Save" Pill Button for Watch Tab.
///
/// Features:
/// - 56dp tall amber pill button (#FFAA1D / #FFC24D)
/// - Slide-up + fade animation (250ms easeOutCubic)
/// - Download arrow icon + "Save" label in bold Inter
/// - Subtle pulse / glow and detected indicator badge
/// - Semantics labeled for screen readers
/// - Positioned 16dp above the floating nav bar
class SaveFloatingButton extends StatelessWidget {
  final bool isVisible;
  final bool isPrefetching;
  final VoidCallback onTap;

  const SaveFloatingButton({
    super.key,
    required this.isVisible,
    this.isPrefetching = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isDark = AppColors.isDark(context);

    return AnimatedSlide(
      offset: isVisible ? Offset.zero : const Offset(0, 1.4),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: isVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: IgnorePointer(
          ignoring: !isVisible,
          child: Semantics(
            button: true,
            label: 'Save detected video',
            hint: 'Tap to preview quality options and save video',
            child: Material(
              color: Colors.transparent,
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  color: colors.accent,
                  borderRadius: AppRadii.rPill,
                  boxShadow: [
                    BoxShadow(
                      color: colors.accent.withValues(alpha: isDark ? 0.45 : 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onTap();
                  },
                  borderRadius: AppRadii.rPill,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Download Icon with detected dot
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Icon(
                              Icons.arrow_downward_rounded,
                              size: 24,
                              color: colors.onAccent,
                            ),
                            Positioned(
                              top: -2,
                              right: -2,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: colors.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: colors.accent, width: 1.5),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Save',
                          style: AppTypography.subtitle(context).copyWith(
                            color: colors.onAccent,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                        if (isPrefetching) ...[
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(colors.onAccent),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
