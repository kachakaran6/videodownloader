import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_typography.dart';

/// Segmented Quality Chip displaying resolution and file size.
class QualityChip extends StatelessWidget {
  final String label;
  final String? sizeEstimate;
  final bool isSelected;
  final VoidCallback onTap;

  const QualityChip({
    super.key,
    required this.label,
    this.sizeEstimate,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.rPill,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? colors.primaryContainer : colors.surfaceAlt,
            borderRadius: AppRadii.rPill,
            border: Border.all(
              color: isSelected ? colors.primary : colors.outline,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: AppTypography.caption(context).copyWith(
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? colors.primary : colors.textPrimary,
                ),
              ),
              if (sizeEstimate != null) ...[
                const SizedBox(height: 2),
                Text(
                  sizeEstimate!,
                  style: AppTypography.overline(context).copyWith(
                    color: isSelected ? colors.primary : colors.textTertiary,
                    fontSize: 10,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
