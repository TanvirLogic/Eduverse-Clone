import 'dart:convert';
import 'dart:io';

import 'package:edtech/features/courses/data/repositories/upload_queue_repository.dart';
import 'package:edtech/global/core/services/logger_service.dart';
import 'package:edtech/global/core/services/native_upload_bridge.dart';
import 'package:edtech/global/core/services/upload_notification_service.dart';
import 'package:media_kit/media_kit.dart';

Future<void> initPlatformServices() async {
  MediaKit.ensureInitialized();
  await UploadNotificationService.init();

  await NativeUploadBridge.ensureInitialized();
  await _requestNotificationPermissionEarly();

  // Phase 1: Check if native service is alive via heartbeat.
  // If alive, skip full recovery — the service is managing state.
  final nativeAlive = await _checkNativeAlive();
  if (nativeAlive) {
    AppLogger.i('Recovery: native service is alive, skipping full recovery');
    // Still reset stale locks to catch any edge cases
    await _resetStaleLocks();
    return;
  }

  // Phase 2: Recover from native state file (last known state before crash)
  await _recoverFromNativeState();

  // Phase 3: Reset any remaining 'uploading' items to 'pending' immediately
  // (no 30-min window needed since we checked heartbeat and native state)
  await _resetStaleLocks();

  // Phase 4: Auto-resume any pending items
  await _autoResumeIfNeeded();
}

Future<void> _requestNotificationPermissionEarly() async {
  try {
    if (!await UploadNotificationService.hasNotificationPermission()) {
      await UploadNotificationService.requestNotificationPermission();
    }
  } catch (_) {}
}

/// Check if the native :upload process is alive via ping.
Future<bool> _checkNativeAlive() async {
  try {
    return await NativeUploadBridge.ping();
  } catch (_) {
    return false;
  }
}

/// Recover from native completion manifest and state file.
///
/// Only runs when native service is confirmed dead.
/// Phase A: Read the completion manifest (items that finished while Flutter was away).
/// Phase B: Read native_uploads.json for items still in progress.
Future<void> _recoverFromNativeState() async {
  try {
    // ── Phase A: Process completion manifest ──
    // native_completed.json persists items that the :upload process finished.
    // It survives state file cleanup and is only deleted after Flutter acknowledges.
    int manifestCompleted = 0;
    final completedItems = await NativeUploadBridge.getCompletedItems();
    for (final entry in completedItems) {
      final itemId = entry['id'] as int?;
      if (itemId == null) continue;
      // Check if the item still needs marking — avoid redundant operations
      try {
        final all = await UploadQueueRepository.getAll();
        final dbItem = all.cast<UploadQueueItem?>().firstWhere(
          (i) => i!.id == itemId,
          orElse: () => null,
        );
        if (dbItem != null && dbItem.status != 'completed' && dbItem.status != 'failed') {
          await UploadQueueRepository.markCompleted(itemId);
          manifestCompleted++;
        }
      } catch (_) {}
    }
    if (manifestCompleted > 0) {
      AppLogger.i('Recovery: marked $manifestCompleted item(s) completed from manifest');
    }
    // Acknowledge and delete the manifest regardless
    await NativeUploadBridge.acknowledgeCompletedItems();

    // ── Phase B: Reconcile native_uploads.json ──
    final nativeItems = await NativeUploadBridge.getPendingUploads();
    if (nativeItems.isEmpty) {
      // No active native items. Any 'uploading' items still in SQLite
      // that weren't in the manifest are treated as stale — reset them.
      final stillUploading = await UploadQueueRepository.getByStatus('uploading');
      for (final item in stillUploading) {
        if (item.status == 'completed' || item.status == 'failed') continue;
        // If the item has fileUrl AND uploadUrl, it was likely uploaded
        // but the manifest might have missed it. Mark completed to be safe.
        if (item.fileUrl != null && item.fileUrl!.isNotEmpty &&
            item.uploadUrl != null && item.uploadUrl!.isNotEmpty) {
          await UploadQueueRepository.markCompleted(item.id!);
          AppLogger.i('Recovery: item ${item.id} has URLs, marking completed');
        }
      }
      return;
    }

    int completed = 0;
    int failed = 0;
    int recovered = 0;

    for (final native in nativeItems) {
      final filePath = native['filePath'] as String?;
      final status = native['status'] as String? ?? 'pending';
      final itemId = native['id'] as int?;
      final uploadUrl = native['uploadUrl'] as String?;
      final fileUrl = native['fileUrl'] as String?;
      final title = native['title'] as String? ?? 'Upload';
      final uploadType = native['uploadType'] as String? ?? 'video_post';
      final metadata = native['metadata'] as String?;

      if (filePath == null) continue;

      if (status == 'completed') {
        if (itemId != null) {
          await UploadQueueRepository.markCompleted(itemId);
        } else {
          await _markItemCompletedInQueue(filePath);
        }
        completed++;
        continue;
      }

      if (status == 'failed') {
        final errorMsg = native['errorMessage'] as String? ?? 'Upload failed (native)';
        if (itemId != null) {
          await UploadQueueRepository.markFailed(itemId, errorMsg);
        } else {
          await _markItemFailedInQueue(filePath, errorMsg);
        }
        failed++;
        continue;
      }

      // For pending/uploading items, check if the file still exists
      final file = Uri.tryParse(filePath)?.path ?? filePath;
      if (!File(file).existsSync()) {
        if (itemId != null) {
          await UploadQueueRepository.markFailed(itemId, 'File not found after restart');
        }
        continue;
      }

      // Not on S3 and not failed — recover as pending
      final activeItems = await UploadQueueRepository.getActive();
      final alreadyQueued = activeItems.any(
        (q) => q.filePath == filePath && q.status == 'pending',
      );
      if (alreadyQueued) continue;

      final queueItem = UploadQueueItem(
        filePath: filePath,
        title: title,
        status: 'pending',
        uploadType: uploadType,
        metadata: metadata,
        uploadUrl: uploadUrl,
        fileUrl: fileUrl,
      );
      await UploadQueueRepository.insert(queueItem);
      recovered++;
    }

    // Clear the native state file since we've reconciled
    await NativeUploadBridge.clearState();

    if (recovered > 0) {
      AppLogger.i('Recovery: recovered $recovered orphaned upload(s) from native layer');
    }
    if (completed > 0) {
      AppLogger.i('Recovery: $completed item(s) marked completed from native state');
    }
    if (failed > 0) {
      AppLogger.i('Recovery: $failed item(s) marked failed from native state');
    }
  } catch (e) {
    AppLogger.e('Recovery: error recovering from native state - $e');
  }
}

/// Reset stale uploading items immediately (no 30-min window).
Future<void> _resetStaleLocks() async {
  try {
    await UploadQueueRepository.resetStaleUploading(
      heartbeatTimeout: const Duration(minutes: 2),
      fallbackTimeout: const Duration(minutes: 5),
    );
  } catch (e) {
    AppLogger.e('Recovery: error resetting stale locks - $e');
  }
}

/// Auto-resume pending items by syncing to native and starting the service.
Future<void> _autoResumeIfNeeded() async {
  try {
    final pendingCount = await UploadQueueRepository.countPending();
    if (pendingCount == 0) {
      AppLogger.i('AutoResume: no pending items');
      return;
    }

    AppLogger.i('AutoResume: $pendingCount pending item(s) found, syncing from SQLite');

    final pendingItems = await UploadQueueRepository.getByStatus('pending');
    if (pendingItems.isEmpty) return;

    final nativeQueueJson = jsonEncode(pendingItems.map((item) => {
      'id': item.id,
      'filePath': item.filePath,
      'title': item.title,
      'uploadUrl': item.uploadUrl,
      'fileUrl': item.fileUrl,
      'contentType': _inferContentType(item.filePath),
      'uploadType': item.uploadType,
      'metadata': item.metadata,
      'uploadId': item.uploadId,
    }).toList());

    await NativeUploadBridge.syncQueueToNative(nativeQueueJson);
    final started = await NativeUploadBridge.startQueueProcessing();
    if (started) {
      AppLogger.i('AutoResume: native service started with $pendingCount items');
    } else {
      AppLogger.w('AutoResume: failed to start native service');
    }
  } catch (e) {
    AppLogger.e('AutoResume: error - $e');
  }
}

Future<void> _markItemCompletedInQueue(String filePath) async {
  try {
    final active = await UploadQueueRepository.getActive();
    for (final item in active) {
      if (item.filePath == filePath &&
          item.status != 'completed' &&
          item.status != 'failed') {
        await UploadQueueRepository.markCompleted(item.id!);
        break;
      }
    }
  } catch (e) {
    AppLogger.e('MarkCompleted: error - $e');
  }
}

Future<void> _markItemFailedInQueue(String filePath, String errorMessage) async {
  try {
    final active = await UploadQueueRepository.getActive();
    for (final item in active) {
      if (item.filePath == filePath &&
          item.status != 'completed' &&
          item.status != 'failed') {
        await UploadQueueRepository.markFailed(item.id!, errorMessage);
        break;
      }
    }
  } catch (e) {
    AppLogger.e('MarkFailed: error - $e');
  }
}

String _inferContentType(String filePath) {
  final ext = filePath.split('.').last.toLowerCase();
  switch (ext) {
    case 'mp4':
      return 'video/mp4';
    case 'mov':
      return 'video/quicktime';
    case 'mkv':
      return 'video/x-matroska';
    case 'webm':
      return 'video/webm';
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'png':
      return 'image/png';
    case 'pdf':
      return 'application/pdf';
    default:
      return 'application/octet-stream';
  }
}
