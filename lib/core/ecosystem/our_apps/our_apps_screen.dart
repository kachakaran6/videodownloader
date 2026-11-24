import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_card.dart';
import 'app_registry_model.dart';
import 'app_registry_service.dart';

/// Screen presenting the verified Samyukt mobile applications catalog.
class OurAppsScreen extends ConsumerWidget {
  const OurAppsScreen({super.key});

  Future<void> _launchUrl(BuildContext context, String? urlString) async {
    if (urlString == null || urlString.trim().isEmpty) return;
    final uri = Uri.tryParse(urlString.trim());
    if (uri == null) return;

    HapticFeedback.lightImpact();
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open store link.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open store link.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final state = ref.watch(ourAppsNotifierProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          'Our Apps',
          style: AppTypography.subtitle(context).copyWith(
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
        backgroundColor: colors.surface,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: colors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: colors.primary,
          backgroundColor: colors.surface,
          onRefresh: () => ref.read(ourAppsNotifierProvider.notifier).loadCatalog(forceRefresh: true),
          child: _buildBody(context, ref, state, colors),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, OurAppsState state, AppColors colors) {
    if (state.isLoading && state.apps.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading applications...',
              style: AppTypography.caption(context).copyWith(color: colors.textSecondary),
            ),
          ],
        ),
      );
    }

    if (state.errorMessage != null && state.apps.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded, size: 54, color: colors.textTertiary),
              const SizedBox(height: 16),
              Text(
                'Unable to Load Apps',
                style: AppTypography.subtitle(context).copyWith(
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                state.errorMessage!,
                style: AppTypography.body(context).copyWith(
                  fontSize: 13,
                  color: colors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: AppRadii.r12),
                ),
                onPressed: () => ref.read(ourAppsNotifierProvider.notifier).loadCatalog(forceRefresh: true),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        // Header banner
        Padding(
          padding: const EdgeInsets.only(left: 4, right: 4, bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Our Projects',
                style: AppTypography.title(context).copyWith(
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Explore other applications and projects built with care by Samyukt.',
                style: AppTypography.body(context).copyWith(
                  fontSize: 13,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ),

        if (state.isFromCache)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: colors.surfaceAlt,
              borderRadius: AppRadii.r12,
              border: Border.all(color: colors.outline, width: 1),
            ),
            child: Row(
              children: [
                Icon(Icons.offline_pin_outlined, size: 18, color: colors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Viewing cached catalog. Pull down to refresh.',
                    style: AppTypography.caption(context).copyWith(
                      color: colors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

        ...state.apps.map((app) => _buildAppCard(context, app, colors)),
      ],
    );
  }

  Widget _buildAppCard(BuildContext context, AppRegistryItem app, AppColors colors) {
    final isAvailable = app.status.isAvailable;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: AppCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // App Icon
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: colors.surfaceAlt,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: colors.outline, width: 1),
                    ),
                    child: CachedNetworkImage(
                      imageUrl: app.iconUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Icon(
                        Icons.apps_rounded,
                        color: colors.primary,
                        size: 28,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Name and Status
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              app.appName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.subtitle(context).copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: colors.textPrimary,
                              ),
                            ),
                          ),
                          _buildStatusPill(context, app.status, colors),
                        ],
                      ),
                      if (app.category != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          app.category!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption(context).copyWith(
                            fontSize: 11,
                            color: colors.textTertiary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            // Tagline or Description
            if (app.tagline != null || app.description != null) ...[
              const SizedBox(height: 10),
              Text(
                app.tagline ?? app.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.body(context).copyWith(
                  fontSize: 13,
                  color: colors.textSecondary,
                  height: 1.35,
                ),
              ),
            ],

            const SizedBox(height: 14),

            // Action Button
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isAvailable && app.playStoreUrl != null && app.playStoreUrl!.isNotEmpty)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.primaryContainer,
                      foregroundColor: colors.primary,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: AppRadii.r12),
                    ),
                    onPressed: () => _launchUrl(context, app.playStoreUrl),
                    icon: const Icon(Icons.shop_outlined, size: 16),
                    label: Text(
                      'View App',
                      style: AppTypography.button(context).copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: colors.surfaceAlt,
                      borderRadius: AppRadii.r12,
                      border: Border.all(color: colors.outline, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.schedule_rounded, size: 15, color: colors.textTertiary),
                        const SizedBox(width: 6),
                        Text(
                          'Coming Soon',
                          style: AppTypography.caption(context).copyWith(
                            fontWeight: FontWeight.w600,
                            color: colors.textTertiary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusPill(BuildContext context, AppReleaseStatus status, AppColors colors) {
    final isAvailable = status.isAvailable;
    final bgColor = isAvailable ? colors.primaryContainer : colors.accent.withValues(alpha: 0.15);
    final textColor = isAvailable ? colors.primary : colors.accent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AppRadii.rPill,
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: textColor,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
