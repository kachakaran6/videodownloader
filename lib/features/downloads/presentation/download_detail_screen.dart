import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'download_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';

class DownloadDetailScreen extends ConsumerWidget {
  const DownloadDetailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadState = ref.watch(downloadControllerProvider);
    final item = downloadState.item;
    final progress = downloadState.progress;

    if (item == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Download Status')),
        body: const Center(child: Text('No active download.')),
      );
    }

    final isDone = downloadState.isCompleted;
    final isDownloading = downloadState.isDownloading;
    final hasError = downloadState.errorMessage != null && !isDownloading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Download Status'),
        actions: [
          if (isDone)
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Share',
              onPressed: () {
                ref.read(downloadControllerProvider.notifier).shareFile(item.filePath, item.title);
              },
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Media Header Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.card(context),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border(context)),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.isDark(context)
                          ? Colors.black.withValues(alpha: 0.25)
                          : AppColors.primary.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Thumbnail
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 100,
                        height: 65,
                        child: item.thumbnailUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: item.thumbnailUrl,
                                fit: BoxFit.cover,
                                errorWidget: (_, _, _) => Container(
                                  color: AppColors.surfaceElevated(context),
                                  child: const Icon(Icons.movie_outlined, color: AppColors.primary),
                                ),
                              )
                            : Container(
                                color: AppColors.surfaceElevated(context),
                                child: const Icon(Icons.movie_outlined, color: AppColors.primary),
                              ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Title, Author, and Quality badge
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary(context),
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  item.qualityLabel,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  item.author,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary(context),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Progress Section
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Status Icon / Visual
                      if (isDownloading)
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppColors.primaryGradient,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.4),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.arrow_downward_rounded,
                            size: 40,
                            color: Colors.white,
                          ),
                        ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(
                              begin: const Offset(0.95, 0.95),
                              end: const Offset(1.05, 1.05),
                              duration: 1000.ms,
                            )
                      else if (isDone)
                        Container(
                          width: 80,
                          height: 80,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.success,
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            size: 48,
                            color: Colors.white,
                          ),
                        ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack)
                      else
                        Container(
                          width: 80,
                          height: 80,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.error,
                          ),
                          child: const Icon(
                            Icons.error_outline_rounded,
                            size: 44,
                            color: Colors.white,
                          ),
                        ),

                      const SizedBox(height: 24),

                      // Stage Title
                      Text(
                        isDone
                            ? 'Ready for Offline Use'
                            : (hasError
                                ? 'Download Failed'
                                : (progress?.stage ?? 'Preparing...')),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Percentage or Error message
                      if (isDownloading && progress != null) ...[
                        Text(
                          '${(progress.progress * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Progress Bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: progress.progress,
                            minHeight: 10,
                            backgroundColor: AppColors.surfaceElevated(context),
                            valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Metrics Grid: Downloaded/Total, Speed, ETA
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: AppColors.card(context),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border(context)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildMetric(
                                context,
                                'Downloaded',
                                '${Formatters.formatBytes(progress.downloadedBytes)} / ${Formatters.formatBytes(progress.totalBytes)}',
                              ),
                              _buildMetric(
                                context,
                                'Speed',
                                Formatters.formatSpeed(progress.speedBytesPerSecond),
                              ),
                              _buildMetric(
                                context,
                                'ETA',
                                Formatters.formatEta(progress.etaSeconds),
                              ),
                            ],
                          ),
                        ),
                      ] else if (hasError) ...[
                        Text(
                          downloadState.errorMessage ?? 'An error occurred during download.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.error,
                          ),
                        ),
                      ] else if (isDone) ...[
                        Text(
                          'Saved: ${Formatters.formatBytes(item.fileSizeBytes)}',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Path: ${item.filePath}',
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted(context),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Bottom Actions
              if (isDownloading)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('Cancel Download'),
                  onPressed: () {
                    ref.read(downloadControllerProvider.notifier).cancelDownload();
                  },
                )
              else if (isDone)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                        ),
                        icon: const Icon(Icons.play_circle_fill_rounded, size: 22),
                        label: const Text('Play Video'),
                        onPressed: () {
                          ref.read(downloadControllerProvider.notifier).openFile(item.filePath);
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.share_outlined, size: 18),
                            label: const Text('Share / Export'),
                            onPressed: () {
                              ref.read(downloadControllerProvider.notifier).shareFile(item.filePath, item.title);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.check_rounded, size: 18, color: AppColors.success),
                            label: const Text('Done'),
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              else
                ElevatedButton.icon(
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Back to Home'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetric(BuildContext context, String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted(context),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary(context),
          ),
        ),
      ],
    );
  }
}
