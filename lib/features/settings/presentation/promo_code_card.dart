import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/ads/ad_gate.dart';
import '../../../core/ads/promo_code_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';

/// Premium "Remove Ads" Card for Settings screen.
///
/// Handles:
/// - Offline promo code application
/// - Shake animation on invalid code
/// - 5-attempt lockout notification
/// - Elegant persistent success card with "Remove code" confirmation
class PromoCodeCard extends ConsumerStatefulWidget {
  const PromoCodeCard({super.key});

  @override
  ConsumerState<PromoCodeCard> createState() => _PromoCodeCardState();
}

class _PromoCodeCardState extends ConsumerState<PromoCodeCard>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _codeController;
  late final AnimationController _shakeController;
  String? _errorMessage;
  bool _isApplying = false;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      setState(() {
        _codeController.text = data.text!.toUpperCase().trim();
        _errorMessage = null;
      });
    }
  }

  Future<void> _applyPromoCode() async {
    final text = _codeController.text.trim();
    if (text.isEmpty) {
      _triggerShake('Please enter a promo code');
      return;
    }

    setState(() {
      _isApplying = true;
      _errorMessage = null;
    });

    final promoNotifier = ref.read(promoStateProvider.notifier);
    final result = await promoNotifier.applyCode(text);

    if (!mounted) return;
    setState(() => _isApplying = false);

    switch (result.status) {
      case PromoApplyStatus.success:
        HapticFeedback.mediumImpact();
        _codeController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.tealAccent, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(result.message)),
              ],
            ),
            backgroundColor: const Color(0xFF1E293B),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        break;

      case PromoApplyStatus.invalidCode:
      case PromoApplyStatus.lockedOut:
      case PromoApplyStatus.clockTampered:
      case PromoApplyStatus.alreadyActive:
        _triggerShake(result.message);
        break;
    }
  }

  void _triggerShake(String message) {
    HapticFeedback.vibrate();
    setState(() => _errorMessage = message);
    _shakeController.forward(from: 0.0);
  }

  Future<void> _confirmRemoveCode() async {
    final colors = AppColors.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.r20,
          side: BorderSide(color: colors.outline, width: 1),
        ),
        title: Text('Remove Promo Code?', style: AppTypography.subtitle(ctx)),
        content: Text(
          'Ads will resume showing in ClipVault. You can re-apply a valid promo code anytime.',
          style: AppTypography.body(ctx).copyWith(
            color: colors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(promoStateProvider.notifier).removePromo();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Promo code removed. Ads will resume.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final promoState = ref.watch(promoStateProvider);

    // Active state: Elegant Lagoon card
    if (promoState.isUnlocked) {
      return AppCard(
        borderColor: colors.primary.withValues(alpha: 0.5),
        backgroundColor: colors.primaryContainer.withValues(alpha: 0.2),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.verified_rounded,
                    color: colors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ads Removed',
                        style: AppTypography.subtitle(context).copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        promoState.isLifetime
                            ? 'Lifetime VIP Pass Active'
                            : '${promoState.label ?? "VIP Pass"} • ${promoState.statusDisplayLabel}',
                        style: AppTypography.caption(context).copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: _confirmRemoveCode,
                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                  label: const Text('Remove code'),
                  style: TextButton.styleFrom(
                    foregroundColor: colors.textTertiary,
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Inactive state: Input card
    return AnimatedBuilder(
      animation: _shakeController,
      builder: (context, child) {
        final offset = sin(_shakeController.value * pi * 4) * 8;
        return Transform.translate(
          offset: Offset(offset, 0),
          child: child,
        );
      },
      child: AppCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.key_rounded,
                    color: colors.accent,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Promo code',
                        style: AppTypography.subtitle(context),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Have a code? Enjoy ClipVault without ads.',
                        style: AppTypography.caption(context).copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Text input with paste button
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeController,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\-_]')),
                    ],
                    onChanged: (_) {
                      if (_errorMessage != null) {
                        setState(() => _errorMessage = null);
                      }
                    },
                    style: AppTypography.bodyMedium(context).copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                    decoration: InputDecoration(
                      hintText: 'ENTER CODE',
                      hintStyle: AppTypography.bodyMedium(context).copyWith(
                        color: colors.textTertiary,
                        letterSpacing: 1.2,
                      ),
                      filled: true,
                      fillColor: colors.surfaceAlt,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: AppRadii.r12,
                        borderSide: BorderSide(color: colors.outline, width: 1),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: AppRadii.r12,
                        borderSide: BorderSide(
                          color: _errorMessage != null ? Colors.redAccent : colors.outline,
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: AppRadii.r12,
                        borderSide: BorderSide(
                          color: _errorMessage != null ? Colors.redAccent : colors.primary,
                          width: 1.5,
                        ),
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.content_paste_rounded, size: 18),
                        tooltip: 'Paste from clipboard',
                        onPressed: _pasteFromClipboard,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _isApplying ? null : _applyPromoCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.accent,
                    foregroundColor: const Color(0xFF1E293B),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: AppRadii.r12),
                    textStyle: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  child: _isApplying
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Apply'),
                ),
              ],
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: AppTypography.caption(context).copyWith(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
