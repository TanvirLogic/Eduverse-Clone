import 'package:edtech/app/app_colors.dart';
import 'package:edtech/features/courses/data/repositories/upload_queue_repository.dart';
import 'package:edtech/features/courses/providers/video_queue_upload_provider.dart';
import 'package:edtech/global/core/constants/sizes.dart';
import 'package:edtech/global/core/widgets/auth_button.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class QueueProgressDashboardWidget extends StatelessWidget {
  const QueueProgressDashboardWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Consumer<VideoQueueUploadProvider>(
      builder: (context, provider, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context, cs, provider),
            if (provider.queue.isNotEmpty) ...[
              const SizedBox(height: 12),
              Expanded(child: _buildQueueList(context, cs, provider)),
            ] else
              Expanded(child: _buildEmptyState(cs)),
          ],
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, ColorScheme cs, VideoQueueUploadProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Upload Queue',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
              Row(
                children: [
                  _buildStatChip(
                    cs,
                    '${provider.pendingCount}',
                    'Pending',
                    AppColors.warning,
                  ),
                  const SizedBox(width: 8),
                  _buildStatChip(
                    cs,
                    '${provider.completedCount}',
                    'Done',
                    AppColors.success,
                  ),
                  const SizedBox(width: 8),
                  _buildStatChip(
                    cs,
                    '${provider.failedCount}',
                    'Failed',
                    AppColors.error,
                  ),
                ],
              ),
            ],
          ),
          if (provider.activeItem != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: provider.totalProgress,
                minHeight: 6,
                backgroundColor: cs.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.themeColor),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${provider.activeItem!.title} — ${provider.activeProgress}%',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: cs.onSurface.withValues(alpha: 0.7),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (provider.isBackgroundRunning) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (provider.isPaused)
                  Expanded(
                    child: AuthButton(
                      text: 'Resume Queue',
                      borderRadius: 28,
                      height: 40,
                      onPressed: () => provider.resumeQueue(),
                    ),
                  )
                else
                  Expanded(
                    child: AuthButton(
                      text: 'Pause Queue',
                      borderRadius: 28,
                      height: 40,
                      onPressed: () => provider.pauseQueue(),
                    ),
                  ),
                if (provider.completedCount > 0) ...[
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => provider.clearCompleted(),
                    child: Text(
                      'Clear',
                      style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6)),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatChip(ColorScheme cs, String count, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            count,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: color.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQueueList(BuildContext context, ColorScheme cs, VideoQueueUploadProvider provider) {
    return ListView.separated(
      itemCount: provider.queue.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = provider.queue[index];
        return _buildQueueTile(context, cs, provider, item);
      },
    );
  }

  Widget _buildQueueTile(
    BuildContext context,
    ColorScheme cs,
    VideoQueueUploadProvider provider,
    UploadQueueItem item,
  ) {
    final isActive = provider.activeItem?.id == item.id;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: _buildStatusIcon(item.status, isActive),
      title: Text(
        item.title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: cs.onSurface,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(
            _statusLabel(item.status),
            style: TextStyle(
              fontSize: 12,
              color: _statusColor(item.status).withValues(alpha: 0.8),
            ),
          ),
          if (isActive && provider.activeProgress > 0) ...[
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: provider.activeProgress / 100.0,
                minHeight: 3,
                backgroundColor: cs.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.themeColor),
              ),
            ),
          ],
          if (item.status == 'failed' && item.errorMessage != null) ...[
            const SizedBox(height: 2),
            Text(
              item.errorMessage!,
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurface.withValues(alpha: 0.5),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
      trailing: _buildActionButton(context, cs, provider, item),
    );
  }

  Widget _buildStatusIcon(String status, bool isActive) {
    IconData icon;
    Color color;

    switch (status) {
      case 'pending':
        icon = Icons.hourglass_empty;
        color = AppColors.warning;
        break;
      case 'uploading':
        icon = isActive ? Icons.cloud_upload : Icons.cloud_queue;
        color = AppColors.themeColor;
        break;
      case 'completed':
        icon = Icons.check_circle;
        color = AppColors.success;
        break;
      case 'failed':
        icon = Icons.error;
        color = AppColors.error;
        break;
      case 'cancelled':
        icon = Icons.cancel;
        color = Colors.grey;
        break;
      default:
        icon = Icons.help_outline;
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 20, color: color),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Waiting in queue';
      case 'uploading':
        return 'Uploading...';
      case 'completed':
        return 'Completed';
      case 'failed':
        return 'Upload failed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return AppColors.warning;
      case 'uploading':
        return AppColors.themeColor;
      case 'completed':
        return AppColors.success;
      case 'failed':
        return AppColors.error;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  Widget? _buildActionButton(
    BuildContext context,
    ColorScheme cs,
    VideoQueueUploadProvider provider,
    UploadQueueItem item,
  ) {
    switch (item.status) {
      case 'pending':
      case 'uploading':
        return IconButton(
          icon: Icon(Icons.close, size: 18, color: cs.onSurface.withValues(alpha: 0.5)),
          onPressed: () => provider.cancelTask(item.id!),
        );
      case 'failed':
        return TextButton(
          onPressed: () => provider.retryFailed(item.id!),
          child: Text(
            'Retry',
            style: TextStyle(
              color: AppColors.themeColor,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        );
      case 'completed':
        return IconButton(
          icon: Icon(Icons.delete_outline, size: 18, color: cs.onSurface.withValues(alpha: 0.4)),
          onPressed: () => provider.removeItem(item.id!),
        );
      default:
        return null;
    }
  }

  Widget _buildEmptyState(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_upload_outlined,
            size: 64,
            color: cs.onSurface.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          Text(
            'No uploads in queue',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: cs.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Select a video to start uploading',
            style: TextStyle(
              fontSize: 14,
              color: cs.onSurface.withValues(alpha: 0.35),
            ),
          ),
        ],
      ),
    );
  }
}
