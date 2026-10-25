import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/liquid_glass_tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_icon_button.dart';
import '../../../core/widgets/liquid_glass_card.dart';
import '../../../core/widgets/liquid_glass_surface.dart';
import '../domain/whatsapp_status_item.dart';
import 'whatsapp_status_controller.dart';
import 'widgets/status_preview_dialog.dart';
import 'widgets/status_thumbnail_widget.dart';

class WhatsAppStatusScreen extends ConsumerStatefulWidget {
  final bool isEmbedded;

  const WhatsAppStatusScreen({
    super.key,
    this.isEmbedded = false,
  });

  @override
  ConsumerState<WhatsAppStatusScreen> createState() => _WhatsAppStatusScreenState();
}

class _WhatsAppStatusScreenState extends ConsumerState<WhatsAppStatusScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(whatsappStatusControllerProvider.notifier).loadStatuses();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState appState) {
    if (appState == AppLifecycleState.resumed) {
      ref.read(whatsappStatusControllerProvider.notifier).loadStatuses(showLoading: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(whatsappStatusControllerProvider);
    final controller = ref.read(whatsappStatusControllerProvider.notifier);
    final hasUnsavedItems = state.filteredItems.any((i) => !state.savedPaths.contains(i.path) && !i.isSaved);

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: widget.isEmbedded
          ? null
          : AppBar(
              titleSpacing: 16,
              title: Text(
                'WhatsApp Statuses',
                style: AppTypography.screenTitle(context),
              ),
              actions: [
                AppIconButton(
                  icon: Icons.refresh_rounded,
                  tooltip: 'Refresh statuses',
                  onPressed: state.isLoading ? null : () => controller.loadStatuses(showLoading: true),
                ),
                const SizedBox(width: 8),
              ],
            ),
      body: SafeArea(
        top: !widget.isEmbedded,
        child: RefreshIndicator(
          onRefresh: () => controller.loadStatuses(showLoading: false),
          color: AppColors.primaryOf(context),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              // Header Controls (App Selector + Filter Chips)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // App Type Selector (WhatsApp vs WA Business)
                      _buildAppTypeSelector(context, state, controller),
                      AppSpacing.gapMd,

                      // Media Filter Chips (All, Photos, Videos) + Save All + Refresh
                      Row(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              child: Row(
                                children: StatusMediaTypeFilter.values.map((filter) {
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: _buildFilterChip(context, state, controller, filter),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                          if (hasUnsavedItems) ...[
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                backgroundColor: AppColors.success.withValues(alpha: 0.12),
                                shape: RoundedRectangleBorder(borderRadius: AppRadii.r8),
                              ),
                              icon: state.isSavingAll
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.success),
                                    )
                                  : const Icon(Icons.download_done_rounded, size: 16, color: AppColors.success),
                              label: Text(
                                state.isSavingAll ? 'Saving...' : 'Save all',
                                style: const TextStyle(
                                  color: AppColors.success,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                              onPressed: state.isSavingAll
                                  ? null
                                  : () async {
                                      final count = await controller.saveAllStatuses();
                                      if (context.mounted && count > 0) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Saved $count statuses to device storage'),
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      }
                                    },
                            ),
                            const SizedBox(width: 4),
                          ],
                          AppIconButton(
                            icon: Icons.refresh_rounded,
                            tooltip: 'Refresh',
                            size: 20,
                            onPressed: state.isLoading
                                ? null
                                : () => controller.loadStatuses(showLoading: true),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Permission Banner
              if (!state.hasPermission)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: _buildPermissionCard(context, controller),
                  ),
                ),

              // Content Area
              if (state.isLoading && state.items.isEmpty)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (!state.isAppInstalled)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildNotInstalledState(context, state, controller),
                )
              else if (state.needsFolderPermission)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildFolderPermissionState(context, state, controller),
                )
              else if (state.filteredItems.isEmpty && state.hasPermission)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyState(context, state, controller),
                )
              else
                _buildStatusGrid(context, state, controller),

              const SliverToBoxAdapter(
                child: SizedBox(height: 96),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppTypeSelector(
    BuildContext context,
    WhatsAppStatusState state,
    WhatsAppStatusController controller,
  ) {
    return LiquidGlassSurface(
      borderRadius: AppRadii.r12,
      blurSigma: LiquidGlassTokens.blurSubtle,
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _buildAppTabButton(
              context: context,
              label: 'WhatsApp',
              count: state.countForApp(WhatsAppAppType.whatsapp),
              isSelected: state.selectedApp == WhatsAppAppType.whatsapp,
              onTap: () => controller.setApp(WhatsAppAppType.whatsapp),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildAppTabButton(
              context: context,
              label: 'WhatsApp Business',
              count: state.countForApp(WhatsAppAppType.whatsappBusiness),
              isSelected: state.selectedApp == WhatsAppAppType.whatsappBusiness,
              onTap: () => controller.setApp(WhatsAppAppType.whatsappBusiness),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppTabButton({
    required BuildContext context,
    required String label,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = AppColors.isDark(context);

    return InkWell(
      borderRadius: AppRadii.r8,
      onTap: onTap,
      child: AnimatedContainer(
        duration: LiquidGlassTokens.durationFast,
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryOf(context)
              : Colors.transparent,
          borderRadius: AppRadii.r8,
          border: isSelected
              ? Border.all(
                  color: Colors.white.withValues(alpha: isDark ? 0.2 : 0.4),
                  width: 0.8,
                )
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? (isDark ? const Color(0xFF1C1A22) : Colors.white)
                      : AppColors.textPrimary(context),
                ),
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? Colors.black.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.25))
                      : AppColors.primaryContainer(context),
                  borderRadius: AppRadii.rPill,
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isSelected
                        ? (isDark ? const Color(0xFF1C1A22) : Colors.white)
                        : AppColors.primaryOf(context),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(
    BuildContext context,
    WhatsAppStatusState state,
    WhatsAppStatusController controller,
    StatusMediaTypeFilter filter,
  ) {
    final isSelected = state.selectedMediaType == filter;
    final isDark = AppColors.isDark(context);

    return InkWell(
      borderRadius: AppRadii.rPill,
      onTap: () => controller.setMediaType(filter),
      child: AnimatedContainer(
        duration: LiquidGlassTokens.durationFast,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryOf(context)
              : LiquidGlassTokens.surface(context, subtle: true),
          borderRadius: AppRadii.rPill,
          border: Border.all(
            color: isSelected
                ? AppColors.primaryOf(context).withValues(alpha: 0.8)
                : LiquidGlassTokens.border(context),
            width: 1,
          ),
        ),
        child: Text(
          filter.label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected
                ? (isDark ? const Color(0xFF1C1A22) : Colors.white)
                : AppColors.textSecondary(context),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusGrid(
    BuildContext context,
    WhatsAppStatusState state,
    WhatsAppStatusController controller,
  ) {
    final items = state.filteredItems;

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.75,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final item = items[index];
            return _buildStatusCard(context, item, state, controller);
          },
          childCount: items.length,
        ),
      ),
    );
  }

  Widget _buildStatusCard(
    BuildContext context,
    WhatsAppStatusItem item,
    WhatsAppStatusState state,
    WhatsAppStatusController controller,
  ) {
    final isSaving = state.savingPaths.contains(item.path);
    final isSaved = state.savedPaths.contains(item.path) || item.isSaved;

    return InkWell(
      borderRadius: AppRadii.r12,
      onTap: () => StatusPreviewDialog.show(context, item),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: AppRadii.r12,
          border: Border.all(
            color: isSaved ? AppColors.success.withValues(alpha: 0.6) : AppColors.border(context),
            width: isSaved ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Media Thumbnail
            StatusThumbnailWidget(
              item: item,
              fit: BoxFit.cover,
            ),

            // Top Video indicator or Saved Badge
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: Row(
                children: [
                  if (item.isVideo)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: AppRadii.r8,
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.play_arrow_rounded, color: Colors.white, size: 14),
                          SizedBox(width: 2),
                          Text(
                            'Video',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Spacer(),
                  if (isSaved)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        borderRadius: AppRadii.r8,
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_rounded, color: Colors.white, size: 12),
                          SizedBox(width: 2),
                          Text(
                            'Saved',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // Bottom Scrim with Size & Save Action
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 20, 10, 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.formattedSize,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: (isSaving || isSaved)
                          ? null
                          : () async {
                              final success = await controller.saveStatus(item);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      success
                                          ? 'Status saved to storage'
                                          : 'Failed to save status',
                                    ),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: isSaved ? AppColors.success : AppColors.primaryOf(context),
                          shape: BoxShape.circle,
                        ),
                        child: isSaving
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                isSaved ? Icons.check_rounded : Icons.download_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    WhatsAppStatusState state,
    WhatsAppStatusController controller,
  ) {
    final isBusiness = state.selectedApp == WhatsAppAppType.whatsappBusiness;
    final appName = isBusiness ? 'WhatsApp Business' : 'WhatsApp';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.auto_awesome_motion_outlined,
              size: 44,
              color: AppColors.textSecondary(context),
            ),
            AppSpacing.gapLg,
            Text(
              'No statuses found',
              style: AppTypography.cardTitle(context),
            ),
            AppSpacing.gapSm,
            Text(
              'View statuses in $appName first, then return here to save them to your device.',
              textAlign: TextAlign.center,
              style: AppTypography.supporting(context),
            ),
            AppSpacing.gapLg,
            AppButton.primary(
              label: 'Open $appName',
              icon: Icons.launch_rounded,
              onPressed: () => controller.openWhatsApp(),
            ),
            AppSpacing.gapSm,
            TextButton(
              onPressed: () => controller.requestFolderPermission(),
              child: const Text('Allow folder access'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotInstalledState(
    BuildContext context,
    WhatsAppStatusState state,
    WhatsAppStatusController controller,
  ) {
    final isBusiness = state.selectedApp == WhatsAppAppType.whatsappBusiness;
    final appName = isBusiness ? 'WhatsApp Business' : 'WhatsApp';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 44,
              color: AppColors.textSecondary(context),
            ),
            AppSpacing.gapLg,
            Text(
              '$appName not installed',
              style: AppTypography.cardTitle(context),
            ),
            AppSpacing.gapSm,
            Text(
              '$appName is not detected on this device. Install it to browse and save status updates.',
              textAlign: TextAlign.center,
              style: AppTypography.supporting(context),
            ),
            AppSpacing.gapLg,
            AppButton.primary(
              label: 'Install $appName',
              icon: Icons.download_rounded,
              onPressed: () => controller.openPlayStore(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionCard(
    BuildContext context,
    WhatsAppStatusController controller,
  ) {
    return LiquidGlassCard(
      blurSigma: LiquidGlassTokens.blurStandard,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer(context),
                  borderRadius: AppRadii.r8,
                ),
                child: Icon(Icons.folder_shared_rounded, color: AppColors.primaryOf(context), size: 20),
              ),
              AppSpacing.gapMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Storage permission required',
                      style: AppTypography.cardTitle(context),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Access is needed to read and save WhatsApp statuses.',
                      style: AppTypography.supporting(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
          AppSpacing.gapLg,
          AppButton.primary(
            label: 'Grant permission',
            isFullWidth: true,
            onPressed: () => controller.requestPermission(),
          ),
        ],
      ),
    );
  }

  Widget _buildFolderPermissionState(
    BuildContext context,
    WhatsAppStatusState state,
    WhatsAppStatusController controller,
  ) {
    final isBusiness = state.selectedApp == WhatsAppAppType.whatsappBusiness;
    final appName = isBusiness ? 'WhatsApp Business' : 'WhatsApp';

    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer(context),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.folder_shared_rounded,
                size: 36,
                color: AppColors.primaryOf(context),
              ),
            ),
            AppSpacing.gapLg,
            Text(
              'Select $appName media folder',
              style: AppTypography.screenTitle(context),
            ),
            AppSpacing.gapSm,
            Text(
              'Android requires one-time access to the status folder to display media.',
              textAlign: TextAlign.center,
              style: AppTypography.supporting(context),
            ),
            AppSpacing.gapLg,

            LiquidGlassCard(
              blurSigma: LiquidGlassTokens.blurStandard,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildPermissionStep(
                    context,
                    number: '1',
                    title: 'Tap "Grant permission" below',
                    subtitle: 'Android will open the $appName directory.',
                  ),
                  const Divider(height: 20),
                  _buildPermissionStep(
                    context,
                    number: '2',
                    title: 'Tap "Use this folder"',
                    subtitle: 'Select the action button at the bottom.',
                  ),
                  const Divider(height: 20),
                  _buildPermissionStep(
                    context,
                    number: '3',
                    title: 'Confirm "Allow"',
                    subtitle: 'Statuses will load automatically.',
                  ),
                ],
              ),
            ),
            AppSpacing.gapLg,

            AppButton.primary(
              label: 'Grant permission',
              icon: Icons.check_circle_outline_rounded,
              isFullWidth: true,
              onPressed: () => controller.requestFolderPermission(),
            ),
            AppSpacing.gapSm,
            TextButton(
              onPressed: () => controller.openWhatsApp(),
              child: Text('Open $appName first'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionStep(
    BuildContext context, {
    required String number,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primaryContainer(context),
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: TextStyle(
              color: AppColors.primaryOf(context),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
        AppSpacing.gapMd,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.cardTitle(context),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: AppTypography.supporting(context),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
