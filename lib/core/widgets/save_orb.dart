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
/// Specs (Bugfix Refactor):
/// - 168dp fixed box with Clip.none so the outer ring and glow are never clipped
/// - 104dp amber orb with dark arrow
/// - One soft amber glow (blur 24, 25% alpha)
/// - Slow pulse (1.8s, scale 1.0 to 1.06)
/// - Caption below it: "Tap to save or inspect link", textSecondary 14sp, centered
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
  late final Animation<double> _scaleAnimation;
  late final AnimationController _spinController;
  late final AnimationController _bounceController;

  @override
  void initState() {
    super.initState();
    // 1.8s slow pulse from 1.0 to 1.06
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

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

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
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
              width: 168,
              height: 168,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  // Outer Feedback Ring (always unclipped inside 168dp box)
                  _buildOuterRing(colors),

                  // Core 104dp Amber Button with Scale Pulse
                  ScaleTransition(
                    scale: widget.state == SaveOrbState.done
                        ? Tween<double>(begin: 0.95, end: 1.05).animate(
                            CurvedAnimation(
                              parent: _bounceController,
                              curve: Curves.elasticOut,
                            ),
                          )
                        : _scaleAnimation,
                    child: Container(
                      width: 104,
                      height: 104,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.accent,
                        boxShadow: [
                          BoxShadow(
                            color: colors.accent.withValues(alpha: 0.25),
                            blurRadius: 24,
                            offset: Offset.zero,
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
        // Caption below Orb: 14sp, textSecondary, centered
        _buildStateLabel(context, colors),
      ],
    );
  }

  Widget _buildOuterRing(AppColors colors) {
    switch (widget.state) {
      case SaveOrbState.idle:
        return AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            final alpha = 0.12 + (_pulseController.value * 0.15);
            return Container(
              width: 132 + (_pulseController.value * 6),
              height: 132 + (_pulseController.value * 6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: colors.accent.withValues(alpha: alpha),
                  width: 2.0,
                ),
              ),
            );
          },
        );

      case SaveOrbState.linkDetected:
        return Container(
          width: 136,
          height: 136,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: colors.accent,
              width: 3.0,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.accent.withValues(alpha: 0.4),
                blurRadius: 16,
              ),
            ],
          ),
        );

      case SaveOrbState.analyzing:
        return RotationTransition(
          turns: _spinController,
          child: SizedBox(
            width: 136,
            height: 136,
            child: CircularProgressIndicator(
              strokeWidth: 3.5,
              valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
            ),
          ),
        );

      case SaveOrbState.downloading:
        return SizedBox(
          width: 136,
          height: 136,
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
          width: 136,
          height: 136,
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
    Color textColor = colors.textSecondary;
    FontWeight fontWeight = FontWeight.w500;

    switch (widget.state) {
      case SaveOrbState.idle:
        text = 'Tap to save or inspect link';
        break;
      case SaveOrbState.linkDetected:
        text = 'Link found. Tap to preview';
        textColor = colors.accent;
        fontWeight = FontWeight.w600;
        break;
      case SaveOrbState.analyzing:
        text = 'Analyzing media...';
        textColor = colors.primary;
        break;
      case SaveOrbState.downloading:
        text = widget.speedText != null ? widget.speedText! : 'Saving media...';
        textColor = colors.primary;
        fontWeight = FontWeight.w600;
        break;
      case SaveOrbState.ready:
        text = 'Ready to download';
        textColor = colors.success;
        fontWeight = FontWeight.w600;
        break;
      case SaveOrbState.done:
        text = 'Saved to phone!';
        textColor = colors.success;
        fontWeight = FontWeight.w600;
        break;
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: Text(
        text,
        key: ValueKey(text),
        textAlign: TextAlign.center,
        style: AppTypography.body(context).copyWith(
          fontSize: 14,
          color: textColor,
          fontWeight: fontWeight,
        ),
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
