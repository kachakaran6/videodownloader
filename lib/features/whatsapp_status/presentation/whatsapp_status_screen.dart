import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';
import '../domain/whatsapp_status_item.dart';
import 'whatsapp_status_controller.dart';
import 'widgets/status_preview_dialog.dart';

class WhatsAppStatusScreen extends ConsumerStatefulWidget {
  final bool isEmbedded;

  const WhatsAppStatusScreen({
    super.key,
    this.isEmbedded = false,
  });

  @override
  ConsumerState<WhatsAppStatusScreen> createState() => _WhatsAppStatusScreenState();
}

class _WhatsAppStatusScreenState extends ConsumerState<WhatsAppStatusScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(whatsappStatusControllerProvider.notifier).loadStatuses();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(whatsappStatusControllerProvider);
    final controller = ref.read(whatsappStatusControllerProvider.notifier);
    final isDark = AppColors.isDark(context);

    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: SafeArea(
        top: !widget.isEmbedded,
        child: RefreshIndicator(
          onRefresh: () => controller.loadStatuses(showLoading: false),
          color: AppColors.primary,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              // Header Controls (App Selector + Filter Chips)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // App Type Selector (WhatsApp vs WA Business)
                      _buildAppTypeSelector(context, state, controller, isDark),
                      const SizedBox(height: 14),

                      // Media Filter Chips (All, Photos, Videos) + Refresh
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
                                    child: _buildFilterChip(context, state, controller, filter, isDark),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.refresh_rounded,
                              color: state.isLoading ? AppColors.primary : AppColors.textPrimary(context),
                            ),
                            tooltip: 'Refresh Statuses',
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

              // Permission Banner (if permission needed)
              if (!state.hasPermission)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: _buildPermissionCard(context, controller, isDark),
                  ),
                ),

              // Content Area: Loading, Folder Permission, Empty, or Status Grid
              if (state.isLoading && state.items.isEmpty)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              else if (state.needsFolderPermission)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildFolderPermissionState(context, state, controller, isDark),
                )
              else if (state.filteredItems.isEmpty && state.hasPermission)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyState(context, state, controller, isDark),
                )
              else
                _buildStatusGrid(context, state, controller, isDark),

              // Bottom spacing for floating navigation bar
              const SliverToBoxAdapter(
                child: SizedBox(height: 100),
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
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(context), width: 1.2),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildAppTabButton(
              context: context,
              label: 'WhatsApp',
              icon: Icons.chat_bubble_outline_rounded,
              count: state.countForApp(WhatsAppAppType.whatsapp),
              isSelected: state.selectedApp == WhatsAppAppType.whatsapp,
              onTap: () => controller.setApp(WhatsAppAppType.whatsapp),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildAppTabButton(
              context: context,
              label: 'WA Business',
              icon: Icons.business_center_outlined,
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
    required IconData icon,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          gradient: isSelected ? AppColors.violetGradient : null,
          color: isSelected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : AppColors.textSecondary(context),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textPrimary(context),
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white.withValues(alpha: 0.25) : AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? Colors.white : AppColors.primary,
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
    bool isDark,
  ) {
    final isSelected = state.selectedMediaType == filter;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => controller.setMediaType(filter),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : (isDark ? AppColors.surfaceElevatedDark : AppColors.surfaceLight),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border(context),
            width: 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          filter.label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.textSecondary(context),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusGrid(
    BuildContext context,
    WhatsAppStatusState state,
    WhatsAppStatusController controller,
    bool isDark,
  ) {
    final items = state.filteredItems;

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 0.72,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final item = items[index];
            return _buildStatusCard(context, item, state, controller, isDark);
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
    bool isDark,
  ) {
    final isSaving = state.savingPaths.contains(item.path);
    final isSaved = state.savedPaths.contains(item.path) || item.isSaved;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => StatusPreviewDialog.show(context, item),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSaved
                ? const Color(0xFF10B981).withValues(alpha: 0.5)
                : AppColors.border(context),
            width: isSaved ? 1.8 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Media Thumbnail / Image
            Image.file(
              File(item.path),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: isDark ? AppColors.surfaceElevatedDark : AppColors.surfaceLight,
                child: Center(
                  child: Icon(
                    item.isVideo ? Icons.videocam_rounded : Icons.image_rounded,
                    color: AppColors.textMuted(context),
                    size: 36,
                  ),
                ),
              ),
            ),

            // Top Overlay: Video Badge or Saved Badge
            Positioned(
              top: 10,
              left: 10,
              right: 10,
              child: Row(
                children: [
                  if (item.isVideo)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.play_arrow_rounded, color: Colors.white, size: 14),
                          SizedBox(width: 2),
                          Text(
                            'VIDEO',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Spacer(),
                  if (isSaved)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF10B981).withValues(alpha: 0.4),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_rounded, color: Colors.white, size: 12),
                          SizedBox(width: 2),
                          Text(
                            'SAVED',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // Bottom Gradient Scrim with Size and 1-Tap Download Button
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 24, 10, 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.85),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    // Size Badge
                    Expanded(
                      child: Text(
                        item.formattedSize,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),

                    // 1-Tap Download Action Button
                    InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: (isSaving || isSaved)
                          ? null
                          : () async {
                              final success = await controller.saveStatus(item);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        Icon(
                                          success
                                              ? Icons.check_circle_rounded
                                              : Icons.error_outline_rounded,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            success
                                                ? 'Status saved to Gallery & Downloads!'
                                                : 'Failed to save status.',
                                            style: const TextStyle(fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                      ],
                                    ),
                                    backgroundColor:
                                        success ? const Color(0xFF10B981) : AppColors.error,
                                    behavior: SnackBarBehavior.floating,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: isSaved ? null : AppColors.violetGradient,
                          color: isSaved ? const Color(0xFF10B981) : null,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: (isSaved ? const Color(0xFF10B981) : AppColors.primary)
                                  .withValues(alpha: 0.45),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
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
    ).animate().fadeIn(duration: 200.ms).scale(begin: const Offset(0.96, 0.96), end: const Offset(1, 1));
  }

  Widget _buildEmptyState(
    BuildContext context,
    WhatsAppStatusState state,
    WhatsAppStatusController controller,
    bool isDark,
  ) {
    final isBusiness = state.selectedApp == WhatsAppAppType.whatsappBusiness;
    final appName = isBusiness ? 'WhatsApp Business' : 'WhatsApp';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.hourglass_empty_rounded,
                size: 48,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No Statuses Found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'To download statuses, first open $appName and view any status. Then come back here to save it!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary(context),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                gradient: AppColors.violetGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.launch_rounded, color: Colors.white, size: 18),
                label: Text(
                  'Open $appName',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
                onPressed: () => controller.openWhatsApp(),
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => controller.requestFolderPermission(),
              icon: const Icon(Icons.folder_open_rounded, size: 16),
              label: const Text(
                'Already viewed? Grant Folder Access',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionCard(
    BuildContext context,
    WhatsAppStatusController controller,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.folder_shared_rounded, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Storage Permission Required',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Allow access to view and save WhatsApp statuses.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => controller.requestPermission(),
              child: const Text(
                'Grant Permission',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFolderPermissionState(
    BuildContext context,
    WhatsAppStatusState state,
    WhatsAppStatusController controller,
    bool isDark,
  ) {
    final isBusiness = state.selectedApp == WhatsAppAppType.whatsappBusiness;
    final appName = isBusiness ? 'WhatsApp Business' : 'WhatsApp';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.folder_shared_rounded,
                size: 48,
                color: Color(0xFF22C55E),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Allow $appName Status Access',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Android 11+ requires permission to access the $appName status folder.\n\nTap "Grant Folder Permission" below, then tap "USE THIS FOLDER" to load all statuses automatically.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary(context),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 26),
            Container(
              decoration: BoxDecoration(
                gradient: AppColors.violetGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 20),
                label: const Text(
                  'Grant Folder Permission',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
                onPressed: () => controller.requestFolderPermission(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
