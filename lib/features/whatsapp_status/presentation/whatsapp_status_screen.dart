import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../domain/whatsapp_status_item.dart';
import 'whatsapp_status_controller.dart';
import 'widgets/status_preview_dialog.dart';
import 'widgets/status_thumbnail_widget.dart';

/// Status Saver Screen with Lagoon & Amber styling.
///
/// Features:
/// - Segmented control: Status / Business
/// - Media filter: All / Photos / Videos
/// - Amber filled-tonal "Save all" button
/// - 2-column grid with rounded tiles
/// - Bottom-left size label & bottom-right circular save/check button
/// - Full-screen preview with swipe, save, share
/// - 100dp bottom padding
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
    final colors = AppColors.of(context);
    final state = ref.watch(whatsappStatusControllerProvider);
    final controller = ref.read(whatsappStatusControllerProvider.notifier);
    final hasUnsavedItems = state.filteredItems.any((i) => !state.savedPaths.contains(i.path) && !i.isSaved);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: widget.isEmbedded
          ? null
          : AppBar(
              title: Text('Status Saver', style: AppTypography.title(context)),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Refresh statuses',
                  onPressed: state.isLoading ? null : () => controller.loadStatuses(showLoading: true),
                ),
              ],
            ),
      body: SafeArea(
        top: !widget.isEmbedded,
        child: RefreshIndicator(
          onRefresh: () => controller.loadStatuses(showLoading: false),
          color: colors.primary,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              // Top Controls Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Segmented App Selector: Status / Business
                      _buildAppTypeSelector(context, state, controller),
                      const SizedBox(height: 12),

                      // Filter Chips + Amber "Save all" Button
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
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colors.accent,
                                foregroundColor: colors.onAccent,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: const RoundedRectangleBorder(borderRadius: AppRadii.rPill),
                                elevation: 0,
                                minimumSize: const Size(0, 36),
                              ),
                              icon: state.isSavingAll
                                  ? SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: colors.onAccent,
                                      ),
                                    )
                                  : const Icon(Icons.download_done_rounded, size: 16),
                              label: Text(
                                state.isSavingAll ? 'Saving...' : 'Save all',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                              ),
                              onPressed: state.isSavingAll
                                  ? null
                                  : () async {
                                      HapticFeedback.lightImpact();
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
                          IconButton(
                            icon: Icon(Icons.refresh_rounded, size: 20, color: colors.textSecondary),
                            tooltip: 'Refresh',
                            onPressed: state.isLoading ? null : () => controller.loadStatuses(showLoading: true),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Storage Permission Explainer Banner
              if (!state.hasPermission)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: _buildPermissionCard(context, controller),
                  ),
                ),

              // Main Content
              if (state.isLoading && state.items.isEmpty)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
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

              // 100dp bottom spacer
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
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
    final colors = AppColors.of(context);

    return Container(
      height: 44,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colors.surfaceAlt,
        borderRadius: AppRadii.r16,
        border: Border.all(color: colors.outline),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildAppTabButton(
              context: context,
              label: 'Status',
              count: state.countForApp(WhatsAppAppType.whatsapp),
              isSelected: state.selectedApp == WhatsAppAppType.whatsapp,
              onTap: () => controller.setApp(WhatsAppAppType.whatsapp),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildAppTabButton(
              context: context,
              label: 'Business',
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
    final colors = AppColors.of(context);

    return InkWell(
      borderRadius: AppRadii.r12,
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? colors.primary : Colors.transparent,
          borderRadius: AppRadii.r12,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: AppTypography.caption(context).copyWith(
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? colors.onPrimary : colors.textPrimary,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? colors.onPrimary.withValues(alpha: 0.25) : colors.primaryContainer,
                  borderRadius: AppRadii.rPill,
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? colors.onPrimary : colors.primary,
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
    final colors = AppColors.of(context);
    final isSelected = state.selectedMediaType == filter;

    return InkWell(
      borderRadius: AppRadii.rPill,
      onTap: () {
        HapticFeedback.lightImpact();
        controller.setMediaType(filter);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? colors.primaryContainer : colors.surfaceAlt,
          borderRadius: AppRadii.rPill,
          border: Border.all(
            color: isSelected ? colors.primary : colors.outline,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          filter.label,
          style: AppTypography.caption(context).copyWith(
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? colors.primary : colors.textPrimary,
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
    final colors = AppColors.of(context);
    final isSaving = state.savingPaths.contains(item.path);
    final isSaved = state.savedPaths.contains(item.path) || item.isSaved;

    return InkWell(
      borderRadius: AppRadii.r16,
      onTap: () => StatusPreviewDialog.show(context, item),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: AppRadii.r16,
          border: Border.all(
            color: isSaved ? colors.success : colors.outline,
            width: isSaved ? 1.5 : 1.0,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Thumbnail
            StatusThumbnailWidget(item: item, fit: BoxFit.cover),

            // Top Video indicator
            if (item.isVideo)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.play_arrow_rounded, color: Colors.white, size: 14),
                      SizedBox(width: 2),
                      Text('Video', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),

            // Bottom-Left Size Label
            Positioned(
              bottom: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  Formatters.formatBytes(item.fileSize),
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                ),
              ),
            ),

            // Bottom-Right Circular Save Button (turns into check once saved)
            Positioned(
              bottom: 8,
              right: 8,
              child: Material(
                color: isSaved ? colors.success : colors.accent,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: isSaved || isSaving
                      ? null
                      : () async {
                          HapticFeedback.lightImpact();
                          final success = await controller.saveStatus(item);
                          if (success && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Saved to Gallery!'), duration: Duration(seconds: 1)),
                            );
                          }
                        },
                  child: Padding(
                    padding: const EdgeInsets.all(7),
                    child: isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Icon(
                            isSaved ? Icons.check_rounded : Icons.download_rounded,
                            size: 16,
                            color: isSaved ? Colors.white : colors.onAccent,
                          ),
                  ),
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
    return const EmptyState(
      icon: Icons.history_toggle_off_rounded,
      title: 'No statuses found',
      description: 'View statuses in your messaging app first. They will automatically appear here to save.',
    );
  }

  Widget _buildPermissionCard(BuildContext context, WhatsAppStatusController controller) {
    final colors = AppColors.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.6),
        borderRadius: AppRadii.r16,
        border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.folder_shared_outlined, color: colors.primary, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Storage Access Required',
                  style: AppTypography.caption(context).copyWith(fontWeight: FontWeight.w700, color: colors.primary),
                ),
                const SizedBox(height: 2),
                Text(
                  'Allow ClipVault to read the public status media folder on your phone.',
                  style: AppTypography.caption(context).copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => controller.requestPermission(),
            child: const Text('Grant'),
          ),
        ],
      ),
    );
  }

  Widget _buildNotInstalledState(
    BuildContext context,
    WhatsAppStatusState state,
    WhatsAppStatusController controller,
  ) {
    return const EmptyState(
      icon: Icons.apps_outlined,
      title: 'App not detected',
      description: 'The selected status service was not found on this device.',
    );
  }

  Widget _buildFolderPermissionState(
    BuildContext context,
    WhatsAppStatusState state,
    WhatsAppStatusController controller,
  ) {
    return EmptyState(
      icon: Icons.folder_open_rounded,
      title: 'Select Status Folder',
      description: 'Android 11+ requires granting permission to the media folder to view statuses.',
      actionLabel: 'Select Folder',
      onAction: () => controller.requestPermission(),
    );
  }
}
