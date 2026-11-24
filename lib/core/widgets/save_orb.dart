import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

enum SaveOrbState {
  idle,
  linkDetected,
  analyzing,
  ready,
  downloading,
  done,
}

/// Signature "Save Orb" Hero Control.
///
/// 96dp circular amber button inside an animated feedback ring.
/// States:
/// - [SaveOrbState.idle]: soft pulse, clean download arrow
/// - [SaveOrbState.linkDetected]: glowing ring with "Link found" prompt
/// - [SaveOrbState.analyzing]: spinning ring with pulsing dots
/// - [SaveOrbState.ready]: checkmark indicating link is inspected and ready
/// - [SaveOrbState.downloading]: circular progress with percentage inside & speed below
/// - [SaveOrbState.done]: complete ring bounce with haptic confirmation
class SaveOrb extends StatefulWidget {
  final SaveOrbState state;
  final double progress; // 0.0 to 1.0 for downloading state
  final String? speedText; // e.g. "4.2 MB/s"
  final VoidCallback onTap;

  const SaveOrb({
    super.key,
    required this.state,
    this.progress = 0.0,
    this.speedText,
    required this.onTap,
  });

  @override
  State<SaveOrb> createState() => _SaveOrbState();
}

class _SaveOrbState extends State<SaveOrb> with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _spinController;
  late final AnimationController _bounceController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _updateStateAnimations();
  }

  @override
  void didUpdateWidget(covariant SaveOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _updateStateAnimations();
      if (widget.state == SaveOrbState.done) {
        HapticFeedback.mediumImpact();
        _bounceController.forward(from: 0.0);
      } else if (widget.state == SaveOrbState.linkDetected) {
        HapticFeedback.lightImpact();
      }
    }
  }

  void _updateStateAnimations() {
    if (widget.state == SaveOrbState.analyzing) {
      if (!_spinController.isAnimating) {
        _spinController.repeat();
      }
    } else {
      _spinController.stop();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _spinController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isDark = AppColors.isDark(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          label: _getSemanticsLabel(),
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              widget.onTap();
            },
            child: SizedBox(
              width: 124,
              height: 124,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer Glow / Ring
                  _buildOuterRing(colors, isDark),

                  // Core 96dp Button
                  ScaleTransition(
                    scale: widget.state == SaveOrbState.done
                        ? Tween<double>(begin: 0.95, end: 1.05).animate(
                            CurvedAnimation(
                              parent: _bounceController,
                              curve: Curves.elasticOut,
                            ),
                          )
                        : const AlwaysStoppedAnimation(1.0),
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.accent,
                        boxShadow: [
                          BoxShadow(
                            color: colors.accent.withValues(alpha: isDark ? 0.45 : 0.35),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Center(
                        child: _buildInnerIcon(colors),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Dynamic Label below Orb
        _buildStateLabel(context, colors),
      ],
    );
  }

  Widget _buildOuterRing(AppColors colors, bool isDark) {
    switch (widget.state) {
      case SaveOrbState.idle:
        return AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            final alpha = 0.15 + (_pulseController.value * 0.15);
            return Container(
              width: 116 + (_pulseController.value * 4),
              height: 116 + (_pulseController.value * 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: colors.accent.withValues(alpha: alpha),
                  width: 2.5,
                ),
              ),
            );
          },
        );

      case SaveOrbState.linkDetected:
        return Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: colors.accent,
              width: 3.0,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.accent.withValues(alpha: 0.5),
                blurRadius: 16,
              ),
            ],
          ),
        );

      case SaveOrbState.analyzing:
        return RotationTransition(
          turns: _spinController,
          child: SizedBox(
            width: 118,
            height: 118,
            child: CircularProgressIndicator(
              strokeWidth: 3.5,
              valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
            ),
          ),
        );

      case SaveOrbState.downloading:
        return SizedBox(
          width: 118,
          height: 118,
          child: CircularProgressIndicator(
            value: widget.progress.clamp(0.0, 1.0),
            strokeWidth: 4.0,
            backgroundColor: colors.surfaceAlt,
            valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
          ),
        );

      case SaveOrbState.ready:
      case SaveOrbState.done:
        return Container(
          width: 118,
          height: 118,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: colors.success,
              width: 3.0,
            ),
          ),
        );
    }
  }

  Widget _buildInnerIcon(AppColors colors) {
    switch (widget.state) {
      case SaveOrbState.idle:
      case SaveOrbState.linkDetected:
        return Icon(
          Icons.arrow_downward_rounded,
          size: 42,
          color: colors.onAccent,
        );

      case SaveOrbState.analyzing:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (index) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.onAccent,
              ),
            );
          }),
        );

      case SaveOrbState.downloading:
        final pct = (widget.progress * 100).toInt();
        return Text(
          '$pct%',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: colors.onAccent,
          ),
        );

      case SaveOrbState.ready:
      case SaveOrbState.done:
        return Icon(
          Icons.check_rounded,
          size: 44,
          color: colors.onAccent,
        );
    }
  }

  Widget _buildStateLabel(BuildContext context, AppColors colors) {
    String text;
    TextStyle style = AppTypography.bodyMedium(context);

    switch (widget.state) {
      case SaveOrbState.idle:
        text = 'Tap to save or inspect link';
        style = AppTypography.caption(context);
        break;
      case SaveOrbState.linkDetected:
        text = 'Link found. Tap to preview';
        style = AppTypography.bodySemiBold(context).copyWith(color: colors.accent);
        break;
      case SaveOrbState.analyzing:
        text = 'Analyzing media...';
        style = AppTypography.bodyMedium(context).copyWith(color: colors.primary);
        break;
      case SaveOrbState.downloading:
        text = widget.speedText != null ? widget.speedText! : 'Saving media...';
        style = AppTypography.tabularFigures(context, color: colors.primary);
        break;
      case SaveOrbState.ready:
        text = 'Ready to download';
        style = AppTypography.bodySemiBold(context).copyWith(color: colors.success);
        break;
      case SaveOrbState.done:
        text = 'Saved to phone!';
        style = AppTypography.bodySemiBold(context).copyWith(color: colors.success);
        break;
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: Text(
        text,
        key: ValueKey(text),
        textAlign: TextAlign.center,
        style: style,
      ),
    );
  }

  String _getSemanticsLabel() {
    switch (widget.state) {
      case SaveOrbState.idle:
        return 'Download media';
      case SaveOrbState.linkDetected:
        return 'Link detected, tap to preview';
      case SaveOrbState.analyzing:
        return 'Analyzing media';
      case SaveOrbState.downloading:
        return 'Downloading: ${(widget.progress * 100).toInt()}%';
      case SaveOrbState.ready:
        return 'Ready to save';
      case SaveOrbState.done:
        return 'Download complete';
    }
  }
}
