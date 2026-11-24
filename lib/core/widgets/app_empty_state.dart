import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../theme/app_radii.dart';

/// Clean Empty State with original Lagoon & Amber geometric vector illustration.
class EmptyState extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Original Geometric Vector Illustration (Lagoon & Amber)
            SizedBox(
              width: 120,
              height: 120,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer Lagoon Soft Disk
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.primaryContainer.withValues(alpha: 0.6),
                    ),
                  ),
                  // Middle Paper/Surface Rounded Square
                  Transform.rotate(
                    angle: 0.1,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: AppRadii.r20,
                        border: Border.all(color: colors.outline, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Inner Amber Spark Orb with Icon
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.accent,
                    ),
                    child: Icon(
                      icon ?? Icons.download_rounded,
                      size: 26,
                      color: colors.onAccent,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.title(context).copyWith(fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: AppTypography.body(context, color: colors.textSecondary),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Backward compatibility alias
class AppEmptyState extends EmptyState {
  const AppEmptyState({
    super.key,
    required IconData icon,
    required super.title,
    required super.description,
    super.actionLabel,
    super.onAction,
  }) : super(icon: icon);
}
