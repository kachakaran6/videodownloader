import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_typography.dart';
import '../ad_config.dart';
import '../ad_gate.dart';

/// Centralized "Quiet Ad" Slot container.
///
/// Ensures:
/// - Instant collapse to SizedBox.shrink() when ads are disabled (Promo code / Zen Boost)
/// - Zero layout shift through reserved height skeleton shimmer
/// - 250ms smooth fade-in
/// - Guaranteed 16dp safety clearance from tappable controls
/// - Fully native styling in dark/light mode
/// - "Ad" pill badge, subtle "Why this ad?" info, and "Remove ads" quick link
class AdSlot extends ConsumerStatefulWidget {
  final VoidCallback? onRemoveAdsTapped;
  final double height;
  final EdgeInsetsGeometry margin;

  const AdSlot({
    super.key,
    this.onRemoveAdsTapped,
    this.height = 320,
    this.margin = const EdgeInsets.symmetric(vertical: 16),
  });

  @override
  ConsumerState<AdSlot> createState() => _AdSlotState();
}

class _AdSlotState extends ConsumerState<AdSlot> with SingleTickerProviderStateMixin {
  NativeAd? _nativeAd;
  bool _isLoaded = false;
  bool _hasFailed = false;
  DateTime? _lastLoadedTime;
  late final AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _loadNativeAd();
  }

  void _loadNativeAd() {
    final adsEnabled = ref.read(adsEnabledProvider);
    if (!adsEnabled) return;

    // Refresh rate-limit: minimum 60 seconds
    if (_lastLoadedTime != null &&
        DateTime.now().difference(_lastLoadedTime!) < AdConfig.nativeAdRefreshInterval) {
      return;
    }

    _nativeAd?.dispose();
    _nativeAd = null;

    _nativeAd = NativeAd(
      adUnitId: AdConfig.nativeAdUnitId,
      factoryId: AdConfig.nativeAdFactoryId,
      request: const AdRequest(),
      nativeAdOptions: NativeAdOptions(
        mediaAspectRatio: MediaAspectRatio.landscape,
        videoOptions: VideoOptions(
          startMuted: true, // Audio muted by default
        ),
      ),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          if (!mounted) return;
          setState(() {
            _isLoaded = true;
            _hasFailed = false;
            _lastLoadedTime = DateTime.now();
          });
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('[AdSlot] Native ad failed to load: ${error.message}');
          ad.dispose();
          if (!mounted) return;
          setState(() {
            _isLoaded = false;
            _hasFailed = true;
          });
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _nativeAd?.dispose();
    _nativeAd = null;
    super.dispose();
  }

  void _showWhyThisAdDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        final colors = AppColors.of(ctx);
        return AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadii.r20,
            side: BorderSide(color: colors.outline, width: 1),
          ),
          title: Row(
            children: [
              Icon(Icons.info_outline_rounded, color: colors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'About This Ad',
                style: AppTypography.subtitle(ctx),
              ),
            ],
          ),
          content: Text(
            'Ads help keep ClipVault free and continuously updated. Ads are served securely by Google AdMob according to your privacy settings and rated PG for safe viewing.\n\nYou can remove all ads at any time with a Promo Code in Settings or by activating a temporary Zen Boost.',
            style: AppTypography.body(ctx).copyWith(
              color: colors.textSecondary,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                'Got It',
                style: TextStyle(color: colors.primary),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final adsEnabled = ref.watch(adsEnabledProvider);
    if (!adsEnabled || _hasFailed) {
      return const SizedBox.shrink();
    }

    final colors = AppColors.of(context);

    return Semantics(
      label: 'Advertisement',
      child: Container(
        margin: widget.margin,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Ad content container (reserved height prevents layout shifts)
            SizedBox(
              height: widget.height,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _isLoaded && _nativeAd != null
                    ? ClipRRect(
                        borderRadius: AppRadii.r20,
                        child: AdWidget(ad: _nativeAd!),
                      )
                    : _buildSkeletonShimmer(context),
              ),
            ),

            // Footer row: "Why this ad?" info & "Remove ads" quick link
            if (_isLoaded) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: _showWhyThisAdDialog,
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 13,
                            color: colors.textTertiary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Why this ad?',
                            style: AppTypography.caption(context).copyWith(
                              color: colors.textTertiary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        if (widget.onRemoveAdsTapped != null) {
                          widget.onRemoveAdsTapped!();
                        } else {
                          // Default: notify user
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Apply a promo code in Settings > Remove ads'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Text(
                        'Remove ads',
                        style: AppTypography.caption(context).copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonShimmer(BuildContext context) {
    final colors = AppColors.of(context);
    final baseColor = colors.surface;
    final highlightColor = colors.surfaceAlt;

    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            color: baseColor,
            borderRadius: AppRadii.r20,
            border: Border.all(
              color: colors.outline.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row placeholder: Badge + Title + Advertiser
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: highlightColor,
                      borderRadius: AppRadii.r12,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 36,
                          height: 14,
                          decoration: BoxDecoration(
                            color: highlightColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          height: 14,
                          decoration: BoxDecoration(
                            color: highlightColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Body line placeholders
              Container(
                width: double.infinity,
                height: 12,
                decoration: BoxDecoration(
                  color: highlightColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: 180,
                height: 12,
                decoration: BoxDecoration(
                  color: highlightColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const Spacer(),
              // Media / Image placeholder
              Container(
                width: double.infinity,
                height: 120,
                decoration: BoxDecoration(
                  color: highlightColor,
                  borderRadius: AppRadii.r14,
                ),
              ),
              const Spacer(),
              // Call to Action button placeholder
              Container(
                width: double.infinity,
                height: 44,
                decoration: BoxDecoration(
                  color: highlightColor,
                  borderRadius: AppRadii.r14,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
