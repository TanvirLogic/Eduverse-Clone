import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:edtech/app/app.dart';
import 'package:edtech/app/urls.dart';
import 'package:edtech/features/auth/data/models/auth_controller.dart';
import 'package:edtech/features/courses/data/helpers/video_metadata_helper.dart';
import 'package:edtech/features/courses/data/models/upload_task.dart';
import 'package:edtech/features/courses/data/repositories/upload_queue_repository.dart';
import 'package:edtech/features/courses/services/background_upload_service.dart';
import 'package:edtech/features/courses/services/background_uploader_service.dart';
import 'package:edtech/global/core/services/logger_service.dart';
import 'package:edtech/global/core/services/toast_service.dart';
import 'package:edtech/global/core/services/upload_notification_service.dart';
import 'package:flutter/material.dart';

class UnifiedUploadQueueProvider extends ChangeNotifier {
  List<UploadQueueItem> _queue = [];
  UploadQueueItem? _activeItem;
  int _activeProgress = 0;
  bool _isUploading = false;
  int _progressUpdateCount = 0;

  List<UploadQueueItem> get queue => List.unmodifiable(_queue);
  UploadQueueItem? get activeItem => _activeItem;
  int get activeProgress => _activeProgress;
  bool get isBackgroundRunning => false;
  bool get isPaused => false;

  int get pendingCount =>
      _queue.where((item) => item.status == 'pending').length;

  int get completedCount =>
      _queue.where((item) => item.status == 'completed').length;

  int get failedCount =>
      _queue.where((item) => item.status == 'failed').length;

  double get totalProgress {
    if (_activeItem == null) return 0.0;
    return _activeProgress / 100.0;
  }

  UnifiedUploadQueueProvider() {
    _init();
  }

  Future<void> _init() async {
    // Register global callbacks so progress/status updates are received
    // even if the app was killed and restarted while uploads were running.
    FileDownloader().registerCallbacks(
      taskStatusCallback: (update) {
        unawaited(_onNativeTaskStatus(update));
      },
      taskProgressCallback: (update) {
        unawaited(_onNativeTaskProgress(update));
      },
    );

    // Resume tracking of previously enqueued tasks and re-deliver
    // any status/progress updates that fired while the app was suspended.
    await FileDownloader().start(
      doTrackTasks: true,
      doRescheduleKilledTasks: true,
    );

    await _loadQueue();
  }

  Future<void> _loadQueue() async {
    try {
      // Reset stale 'uploading' items that have no workerId (from before
      // the enqueue migration) so they become 'pending' and can be retried.
      final allItems = await UploadQueueRepository.getAll();
      for (final item in allItems) {
        if (item.status == 'uploading' &&
            (item.workerId == null || item.workerId!.isEmpty)) {
          await UploadQueueRepository.updateStatus(
              id: item.id!, status: 'pending');
        }
        // Remove items that never had any upload attempt (bytesUploaded == 0)
        // and are too old to be relevant — they can never be enqueued without
        // a fresh presigned URL. Items with bytesUploaded > 0 keep their
        // progress so the UI can show the user where things stand.
        if (item.status == 'pending' &&
            item.bytesUploaded == 0 &&
            (item.uploadUrl == null || item.uploadUrl!.isEmpty)) {
          final age = DateTime.now()
              .difference(DateTime.parse(item.createdAt));
          if (age.inMinutes >= 30) {
            AppLogger.i(
                '_loadQueue: removing stale pending item id=${item.id} (no uploadUrl, age=${age.inMinutes}min)');
            await UploadQueueRepository.deleteItem(item.id!);
          }
        }
      }

      _queue = await UploadQueueRepository.getActive();
      final active = allItems
          .where((item) =>
              item.status == 'uploading' || item.status == 'pending')
          .toList();
      if (active.isNotEmpty) {
        _activeItem = active.first;
        _activeProgress = active.first.bytesUploaded > 0
            ? ((active.first.bytesUploaded / active.first.fileSize) * 100).round()
            : 0;
      }
      notifyListeners();

      // Re-enqueue any pending items that have uploadUrl set
      _processNextItem();
    } catch (e) {
      AppLogger.e('_loadQueue error: $e');
      _queue = [];
    }
  }

  String _inferContentType(String filePath) {
    final ext = filePath.split('.').last.toLowerCase();
    switch (ext) {
      case 'mp4': return 'video/mp4';
      case 'mov': return 'video/quicktime';
      case 'mkv': return 'video/x-matroska';
      case 'webm': return 'video/webm';
      case 'jpg': case 'jpeg': return 'image/jpeg';
      case 'png': return 'image/png';
      case 'pdf': return 'application/pdf';
      default: return 'application/octet-stream';
    }
  }

  bool _hasInFlightFile(List<UploadQueueItem> items, String filePath) {
    return items.any((item) =>
        item.filePath == filePath &&
        (item.status == 'pending' || item.status == 'uploading'));
  }

  /// Find and enqueue the next pending item that isn't already tracked
  /// by a live WorkManager task.
  Future<void> _processNextItem() async {
    if (_isUploading) return;

    // Look through pending items and find one that needs a new enqueue.
    // Items with a workerId are already handled by WorkManager natively.
    final allActive = await UploadQueueRepository.getActive();
    UploadQueueItem? candidate;

    // First, see if any item already enqueued (workerId set) is currently
    // the "active" upload — update _activeItem so the UI shows it.
    final tracked = allActive.where(
      (i) => i.workerId != null && i.workerId!.isNotEmpty,
    );
    if (tracked.isNotEmpty) {
      final first = tracked.first;
      // Query background_downloader's own database for real progress
      int liveProgress = 0;
      try {
        final record =
            await FileDownloader().database.recordForId(first.workerId!);
        if (record != null && record.progress > 0) {
          liveProgress = (record.progress * 100).round();
          // Sync real progress into our SQLite immediately
          if (first.fileSize > 0) {
            await UploadQueueRepository.updateProgress(
              id: first.id!,
              bytesUploaded: (record.progress * first.fileSize).round(),
            );
          }
        }
      } catch (_) {}
      _activeItem = first;
      _activeProgress = liveProgress > 0 ? liveProgress
          : first.bytesUploaded > 0
              ? ((first.bytesUploaded / first.fileSize) * 100).round()
              : 0;
      AppLogger.i('_processNextItem: tracked item id=${first.id} liveProgress=$liveProgress%');
    }

    // Find a pending item that actually needs enqueueing
    candidate = allActive.where((i) =>
        i.status == 'pending' &&
        (i.workerId == null || i.workerId!.isEmpty) &&
        i.uploadUrl != null &&
        i.uploadUrl!.isNotEmpty).firstOrNull;

    if (candidate == null || candidate.id == null) {
      AppLogger.i('_processNextItem: no item to enqueue');
      return;
    }

    AppLogger.i('_processNextItem: enqueueing id=${candidate.id}');

    try {
      _isUploading = true;
      _activeItem = candidate;
      _activeProgress = 0;
      await UploadQueueRepository.updateStatus(id: candidate.id!, status: 'uploading');
      notifyListeners();

      final taskId = await BackgroundUploaderService.enqueueUpload(
        itemId: candidate.id!,
        filePath: candidate.filePath,
        uploadUrl: candidate.uploadUrl!,
        contentType: _inferContentType(candidate.filePath),
        displayName: candidate.title,
      );

      if (taskId == null) {
        AppLogger.e('_processNextItem: enqueueUpload returned null for id=${candidate.id}');
        await UploadQueueRepository.markFailed(
            candidate.id!, 'Failed to start native upload');
        await _onItemTerminal(candidate.id!);
        return;
      }
      AppLogger.i('_processNextItem: enqueued successfully, taskId=$taskId');

      await UploadQueueRepository.updateWorkerId(
          id: candidate.id!, workerId: taskId);
    } catch (e) {
      AppLogger.e('_processNextItem: exception for id=${candidate.id}: $e');
      // Release the lock so remaining items are not blocked forever
      _isUploading = false;
      if (_activeItem?.id == candidate.id) {
        _activeItem = null;
        _activeProgress = 0;
      }
      await UploadQueueRepository.markFailed(
          candidate.id!, 'Enqueue error: $e');
      await _onItemTerminal(candidate.id!);
    }
  }

  // ──────────────────────────────────────────────
  //  Native callback handlers (called from registered
  //  TaskStatusCallback / TaskProgressCallback)
  // ──────────────────────────────────────────────

  Future<void> _onNativeTaskStatus(TaskStatusUpdate update) async {
    final itemId = _extractItemId(update.task);
    AppLogger.i('_onNativeTaskStatus: item=$itemId status=${update.status} taskId=${update.task.taskId}');
    if (itemId == null) return;

    // Skip if item already reached a terminal state (e.g. cancelled then a
    // stale 'failed' arrives from the now-stopped native worker's finally block)
    final allItems = await UploadQueueRepository.getAll();
    final item = allItems.where((i) => i.id == itemId).firstOrNull;
    if (item == null) return;
    if (item.status == 'completed' || item.status == 'cancelled') {
      AppLogger.i('_onNativeTaskStatus: item=$itemId already ${item.status}, skipping');
      return;
    }

    switch (update.status) {
      case TaskStatus.complete:
        await _handleNativeComplete(itemId, update.task.taskId);
      case TaskStatus.failed:
        await UploadQueueRepository.markFailed(
            itemId, 'Native upload failed');
        await _onItemTerminal(itemId);
      case TaskStatus.canceled:
        await UploadQueueRepository.updateStatus(
            id: itemId, status: 'cancelled');
        await UploadQueueRepository.updateWorkerId(
            id: itemId, workerId: '');
        await _onItemTerminal(itemId);
      default:
        break;
    }
  }

  Future<void> _onNativeTaskProgress(TaskProgressUpdate update) async {
    final itemId = _extractItemId(update.task);
    if (itemId == null) return;

    _progressUpdateCount++;
    final pct = (update.progress * 100).round();
    AppLogger.i('_onNativeTaskProgress: item=$itemId progress=$pct%');

    // Update in-memory state for immediate UI feedback
    if (_activeItem?.id == itemId) {
      _activeProgress = pct;
      notifyListeners();
    }

    // Persist progress to SQLite so it survives app restart.
    // Throttle: only write when crossing a whole-percent boundary to
    // avoid thousands of writes during a multi-GB upload.
    final items = await UploadQueueRepository.getAll();
    final item = items.where((i) => i.id == itemId).firstOrNull;
    if (item != null && item.fileSize > 0) {
      final currentStoredPct = item.fileSize > 0
          ? ((item.bytesUploaded / item.fileSize) * 100).round()
          : 0;
      if (pct != currentStoredPct) {
        final bytes = (update.progress * item.fileSize).round();
        await UploadQueueRepository.updateProgress(
          id: itemId,
          bytesUploaded: bytes,
        );
      }
    }

    // Periodic WAL checkpoint every 200 progress ticks (~every 100s)
    // to prevent unbounded WAL growth during long uploads.
    if (_progressUpdateCount % 200 == 0) {
      unawaited(UploadQueueRepository.checkpointWal());
    }
  }

  int? _extractItemId(Task task) {
    if (task.metaData.isEmpty) return null;
    try {
      final map = jsonDecode(task.metaData) as Map<String, dynamic>;
      return map['itemId'] as int?;
    } catch (_) {
      return null;
    }
  }

  /// Called when the native S3 upload completes (TaskStatus.complete).
  /// Sends the server callback, then marks the item complete.
  Future<void> _handleNativeComplete(int itemId, String taskId) async {
    AppLogger.i('_handleNativeComplete: item=$itemId taskId=$taskId');
    try {
      await UploadQueueRepository.markNativeCompleted(itemId);

      final all = await UploadQueueRepository.getAll();
      final item = all.where((i) => i.id == itemId).firstOrNull;
      if (item == null) return;

      final callbackSent = await _sendCallbackForItem(item);
      if (!callbackSent) {
        await UploadQueueRepository.markFailed(
          itemId,
          'Uploaded to S3 but server callback failed',
        );
        await _onItemTerminal(itemId);
        return;
      }

      await UploadQueueRepository.markCallbackCompleted(itemId);
      await UploadQueueRepository.markCompleted(itemId);
      await _cleanupCachedFile(item.filePath);
      await _onItemTerminal(itemId);
      ToastService.showSuccess('Upload completed');
    } catch (e) {
      AppLogger.e('_handleNativeComplete error for item $itemId: $e');
      await UploadQueueRepository.markFailed(itemId, 'Completion error: $e');
      await _onItemTerminal(itemId);
    }
  }

  /// Send server callback after S3 upload completes.
  /// Reconstructs the callback body from the item's metadata and uploadType.
  Future<bool> _sendCallbackForItem(UploadQueueItem item) async {
    final token = AuthController.accessToken;
    if (token == null) {
      AppLogger.w('_sendCallbackForItem: no auth token');
      return false;
    }

    final details = _buildCallbackDetails(item);
    if (details == null) return false;

    return BackgroundUploaderService.sendServerCallback(
      callbackUrl: details.url,
      authToken: token,
      body: details.body,
      idempotencyKey: '${item.uploadId ?? item.id}_callback',
    );
  }

  _CallbackDetails? _buildCallbackDetails(UploadQueueItem item) {
    switch (item.uploadType) {
      case 'course':
        final meta = item.metadata != null
            ? CourseUploadMetadata.fromJson(jsonDecode(item.metadata!))
            : null;
        return _CallbackDetails(
          url: Urls.createCourseUrl,
          body: {
            'title': meta?.courseTitle ?? item.title,
            'description': meta?.description ?? '',
            'shortDescription': meta?.shortDescription ?? '',
            'requirements': meta?.requirements ?? '',
            'thumbnailUrl': item.fileUrl,
            if (meta?.videoPath != null) 'introVideoUrl': meta!.videoPath,
            'language': meta?.language ?? '',
            'level': (meta?.level ?? '').toUpperCase(),
            'type': (meta?.type ?? 'FREE').toUpperCase(),
            'price': meta?.price ?? 0,
          },
        );

      case 'module_lesson':
        final meta = item.metadata != null
            ? ModuleLessonMetadata.fromJson(jsonDecode(item.metadata!))
            : null;
        return _CallbackDetails(
          url: Urls.courseModuleLessonUrl,
          body: {
            'title': meta?.lessonTitle ?? item.title,
            'videoUrl': item.fileUrl,
            'moduleId': meta?.moduleId,
            'duration': item.videoDuration,
            'fileSize': item.fileSize,
          },
        );

      case 'resource':
        final meta = item.metadata != null
            ? ModuleLessonMetadata.fromJson(jsonDecode(item.metadata!))
            : null;
        final ct = meta?.contentType ?? 'application/octet-stream';
        return _CallbackDetails(
          url: Urls.courseModuleResourceUrl,
          body: {
            'title': meta?.lessonTitle ?? item.title,
            'fileUrl': item.fileUrl,
            'moduleID': meta?.moduleId,
            'courseID': meta?.courseId,
            'contentType': ct,
            'fileSize': item.fileSize,
          },
        );

      case 'course_intro':
        return _CallbackDetails(
          url: Urls.courseAssetsUploadUrl,
          body: {
            'title': item.title,
            'videoUrl': item.fileUrl,
          },
        );

      default:
        // video_post
        return _CallbackDetails(
          url: Urls.videoPostUrl,
          body: {
            'title': item.title,
            'videoUrl': item.fileUrl,
            'duration': item.videoDuration,
            'fileSize': item.fileSize,
          },
        );
    }
  }

  /// Called when an item reaches a terminal state (completed/failed/cancelled).
  /// Starts the next pending item if any.
  Future<void> _onItemTerminal(int id) async {
    _isUploading = false;
    if (_activeItem?.id == id) {
      _activeItem = null;
      _activeProgress = 0;
    }
    _queue = await UploadQueueRepository.getActive();
    notifyListeners();
    _processNextItem();
  }

  // ──────────────────────────────────────────────
  //  Public queue methods
  // ──────────────────────────────────────────────

  /// Video post: queue → fetch presigned URL → start upload.
  Future<bool> addToQueue(File file, String title) async {
    try {
      final allItems = await UploadQueueRepository.getAll();
      if (_hasInFlightFile(allItems, file.path)) {
        ToastService.showError('This file is already being uploaded');
        return false;
      }

      final duration = await VideoMetadataHelper.getDurationSeconds(file.path);
      final fileSize = await VideoMetadataHelper.getFileSizeBytes(file.path);

      final permission = await _ensureNotificationPermission();
      if (!permission) {
        ToastService.showError('Notification permission required to upload');
        return false;
      }

      final item = UploadQueueItem(
        filePath: file.path,
        title: title,
        videoDuration: duration,
        fileSize: fileSize,
        status: 'pending',
        uploadType: 'video_post',
      );

      final insertResult = await UploadQueueRepository.insert(item);
      final id = insertResult['id'] as int;
      _queue = await UploadQueueRepository.getActive();
      notifyListeners();

      final ok = await _fetchAndStart(file, title, duration, fileSize, id);
      if (ok) {
        ToastService.showSuccess('Video queued for upload');
        return true;
      }
      return false;
    } catch (e) {
      AppLogger.e('addToQueue error - $e');
      return false;
    }
  }

  Future<int> addCourseToQueue({
    required String thumbnailPath,
    String? videoPath,
    required String title,
    required String shortDescription,
    required String description,
    required String requirements,
    required String language,
    required String level,
    required String type,
    required double price,
    String? introVideoUrl,
  }) async {
    final meta = CourseUploadMetadata(
      courseTitle: title,
      shortDescription: shortDescription,
      description: description,
      requirements: requirements,
      language: language,
      level: level,
      type: type,
      price: price,
      videoPath: introVideoUrl != null ? null : videoPath,
    );

    final metadataJson = jsonEncode(meta.toJson());
    final thumbFile = File(thumbnailPath);
    final thumbSize = await thumbFile.length();

    final permission = await _ensureNotificationPermission();
    if (!permission) {
      ToastService.showError('Notification permission required to upload');
      return 0;
    }

    final item = UploadQueueItem(
      filePath: thumbnailPath,
      title: 'Course: $title',
      fileSize: thumbSize,
      status: 'pending',
      uploadType: 'course',
      metadata: metadataJson,
    );

    final insertResult = await UploadQueueRepository.insert(item);
    final id = insertResult['id'] as int;
    _queue = await UploadQueueRepository.getActive();
    notifyListeners();

    final bool externalIntro = introVideoUrl != null;
    final String? effectiveVideoPath = externalIntro ? null : videoPath;

    final urls = await BackgroundUploadService.fetchCoursePresignedUrls(
      thumbnailPath: thumbnailPath,
      videoPath: effectiveVideoPath,
    );

    if (urls == null) {
      await _cleanupFailedUpload(id, thumbnailPath);
      ToastService.showError('Failed to get upload URLs');
      return 0;
    }

    final thumbnailUploadUrl = urls['thumbnailUploadUrl']!;
    final thumbnailFileUrl = urls['thumbnailFileUrl']!;

    if (!externalIntro && videoPath != null) {
      final videoUploadUrl = urls['videoUploadUrl'];
      final videoFileUrl = urls['videoFileUrl'];
      if (videoUploadUrl != null && videoFileUrl != null) {
        final videoItem = UploadQueueItem(
          filePath: videoPath,
          title: 'Course intro video: $title',
          fileSize: await File(videoPath).length(),
          status: 'pending',
          uploadType: 'course_intro',
          metadata: metadataJson,
        );
        final videoInsert = await UploadQueueRepository.insert(videoItem);
        final videoId = videoInsert['id'] as int;
        await UploadQueueRepository.updateUrls(
          id: videoId,
          uploadUrl: videoUploadUrl,
          fileUrl: videoFileUrl,
        );
        _queue = await UploadQueueRepository.getActive();
        notifyListeners();
      }
    }

    await UploadQueueRepository.updateUrls(
      id: id,
      uploadUrl: thumbnailUploadUrl,
      fileUrl: thumbnailFileUrl,
    );

    ToastService.showSuccess('Course upload queued');
    _processNextItem();
    return id;
  }

  Future<String?> addCourseIntroVideo({
    required String filePath,
    required String title,
  }) async {
    try {
      final allItems = await UploadQueueRepository.getAll();
      if (_hasInFlightFile(allItems, filePath)) {
        ToastService.showError('This video is already queued');
        return null;
      }

      final file = File(filePath);
      final fileSize = await file.length();

      final permission = await _ensureNotificationPermission();
      if (!permission) {
        ToastService.showError('Notification permission required to upload');
        return null;
      }

      final item = UploadQueueItem(
        filePath: filePath,
        title: title,
        fileSize: fileSize,
        status: 'pending',
        uploadType: 'course_intro',
      );

      final insertResult = await UploadQueueRepository.insert(item);
      final id = insertResult['id'] as int;
      _queue = await UploadQueueRepository.getActive();
      notifyListeners();

      final urls = await BackgroundUploadService.fetchCoursePresignedUrls(
        thumbnailPath: filePath,
        videoPath: filePath,
      );

      if (urls == null) {
        await _cleanupFailedUpload(id, filePath);
        ToastService.showError('Failed to get upload URL');
        return null;
      }

      final videoUploadUrl = urls['videoUploadUrl'];
      final videoFileUrl = urls['videoFileUrl'];
      if (videoUploadUrl == null || videoFileUrl == null) {
        await _cleanupFailedUpload(id, filePath);
        ToastService.showError('Server did not provide a video upload URL');
        return null;
      }

      await UploadQueueRepository.updateUrls(
        id: id,
        uploadUrl: videoUploadUrl,
        fileUrl: videoFileUrl,
      );

      ToastService.showSuccess('Intro video queued');
      _processNextItem();
      return videoFileUrl;
    } catch (e) {
      AppLogger.e('addCourseIntroVideo error: $e');
      ToastService.showError('Failed to queue intro video');
      return null;
    }
  }

  Future<Map<String, String?>?> queueCourseEditAssets({
    String? thumbnailPath,
    String? videoPath,
    required int courseId,
    required String courseTitle,
  }) async {
    if (thumbnailPath == null && videoPath == null) return {};

    try {
      final urls = await BackgroundUploadService.fetchCoursePresignedUrls(
        thumbnailPath: thumbnailPath ?? videoPath!,
        videoPath: videoPath,
      );

      if (urls == null) {
        ToastService.showError('Failed to get upload URLs');
        return null;
      }

      if (thumbnailPath != null) {
        final thumbUploadUrl = urls['thumbnailUploadUrl'];
        final thumbFileUrl = urls['thumbnailFileUrl'];
        if (thumbUploadUrl != null && thumbFileUrl != null) {
          final item = UploadQueueItem(
            filePath: thumbnailPath,
            title: 'Course thumbnail: $courseTitle',
            fileSize: await File(thumbnailPath).length(),
            status: 'pending',
            uploadType: 'course_thumb',
          );
          final insert = await UploadQueueRepository.insert(item);
          final id = insert['id'] as int;
          await UploadQueueRepository.updateUrls(
            id: id,
            uploadUrl: thumbUploadUrl,
            fileUrl: thumbFileUrl,
          );
        }
      }

      if (videoPath != null) {
        final videoUploadUrl = urls['videoUploadUrl'];
        final videoFileUrl = urls['videoFileUrl'];
        if (videoUploadUrl != null && videoFileUrl != null) {
          final item = UploadQueueItem(
            filePath: videoPath,
            title: 'Course intro: $courseTitle',
            fileSize: await File(videoPath).length(),
            status: 'pending',
            uploadType: 'course_intro',
          );
          final insert = await UploadQueueRepository.insert(item);
          final id = insert['id'] as int;
          await UploadQueueRepository.updateUrls(
            id: id,
            uploadUrl: videoUploadUrl,
            fileUrl: videoFileUrl,
          );
        }
      }

      _queue = await UploadQueueRepository.getActive();
      _processNextItem();
      ToastService.showSuccess('Assets queued for upload');

      return {
        'thumbnailFileUrl': urls['thumbnailFileUrl'],
        'videoFileUrl': urls['videoFileUrl'],
      };
    } catch (e) {
      AppLogger.e('queueCourseEditAssets error: $e');
      ToastService.showError('Failed to queue course assets');
      return null;
    }
  }

  /// Video lesson: queue → fetch presigned URL → start upload.
  Future<int> addModuleLessonToQueue({
    required String videoPath,
    required String lessonTitle,
    required int moduleId,
    required int courseId,
    int? lessonId,
  }) async {
    if (!File(videoPath).existsSync()) {
      AppLogger.w('addModuleLessonToQueue: file not found at $videoPath');
      ToastService.showError('Video file not found');
      return 0;
    }

    final allItems = await UploadQueueRepository.getAll();
    if (_hasInFlightFile(allItems, videoPath)) {
      AppLogger.w('addModuleLessonToQueue: file already queued at $videoPath');
      ToastService.showError('This video is already in the upload queue');
      return 0;
    }

    final permission = await _ensureNotificationPermission();
    if (!permission) {
      ToastService.showError('Notification permission required to upload');
      return 0;
    }

    final meta = ModuleLessonMetadata(
      moduleId: moduleId,
      courseId: courseId,
      lessonTitle: lessonTitle,
      lessonId: lessonId,
    );

    final metadataJson = jsonEncode(meta.toJson());
    final videoFile = File(videoPath);
    final fileSize = await videoFile.length();
    final duration = await VideoMetadataHelper.getDurationSeconds(videoPath);

    final item = UploadQueueItem(
      filePath: videoPath,
      title: lessonTitle,
      videoDuration: duration,
      fileSize: fileSize,
      status: 'pending',
      uploadType: 'module_lesson',
      metadata: metadataJson,
    );

    final insertResult = await UploadQueueRepository.insert(item);
    final id = insertResult['id'] as int;
    _queue = await UploadQueueRepository.getActive();
    notifyListeners();

    final urls = await BackgroundUploadService.fetchPresignedUrl(
      filePath: videoPath,
      endpoint: Urls.courseModuleUploadUrl,
      buildPayload: (name) => {
        'videoFilename': name,
        'videoContentType': BackgroundUploadService.inferVideoContentType(name),
      },
      extraFields: {'moduleID': moduleId},
    );

    if (urls == null) {
      await _cleanupFailedUpload(id, videoPath);
      ToastService.showError('Failed to get upload URL');
      return 0;
    }

    await UploadQueueRepository.updateUrls(
      id: id,
      uploadUrl: urls['uploadUrl']!,
      fileUrl: urls['fileUrl']!,
    );

    ToastService.showSuccess('Video lesson queued');
    await _processNextItem();
    return id;
  }

  /// Resource: queue → fetch presigned URL → start upload.
  Future<int> addResourceToQueue({
    required String filePath,
    required String lessonTitle,
    required int moduleId,
    required int courseId,
    required String contentType,
    int? lessonId,
  }) async {
    if (!File(filePath).existsSync()) {
      AppLogger.w('addResourceToQueue: file not found at $filePath');
      ToastService.showError('Resource file not found');
      return 0;
    }

    final allItems = await UploadQueueRepository.getAll();
    if (_hasInFlightFile(allItems, filePath)) {
      AppLogger.w('addResourceToQueue: file already queued at $filePath');
      ToastService.showError('This resource is already in the upload queue');
      return 0;
    }

    final permission = await _ensureNotificationPermission();
    if (!permission) {
      ToastService.showError('Notification permission required to upload');
      return 0;
    }

    final meta = ModuleLessonMetadata(
      moduleId: moduleId,
      courseId: courseId,
      lessonTitle: lessonTitle,
      contentType: contentType,
      lessonId: lessonId,
    );

    final metadataJson = jsonEncode(meta.toJson());
    final resourceFile = File(filePath);
    final fileSize = await resourceFile.length();

    final item = UploadQueueItem(
      filePath: filePath,
      title: lessonTitle,
      fileSize: fileSize,
      status: 'pending',
      uploadType: 'resource',
      metadata: metadataJson,
    );

    final insertResult = await UploadQueueRepository.insert(item);
    final id = insertResult['id'] as int;
    _queue = await UploadQueueRepository.getActive();
    notifyListeners();

    final urls = await BackgroundUploadService.fetchPresignedUrl(
      filePath: filePath,
      endpoint: Urls.courseModuleResourceUploadUrl,
      buildPayload: (name) => {
        'filename': name,
        'contentType': contentType,
      },
      extraFields: {'moduleID': moduleId},
    );

    if (urls == null) {
      await _cleanupFailedUpload(id, filePath);
      ToastService.showError('Failed to get upload URL');
      return 0;
    }

    await UploadQueueRepository.updateUrls(
      id: id,
      uploadUrl: urls['uploadUrl']!,
      fileUrl: urls['fileUrl']!,
    );

    ToastService.showSuccess('Resource queued');
    _processNextItem();
    return id;
  }

  // ──────────────────────────────────────────────
  //  Fetch presigned URL and start upload (video_post)
  // ──────────────────────────────────────────────

  Future<void> _cleanupFailedUpload(int id, String filePath) async {
    await UploadQueueRepository.markFailed(id, 'Upload setup failed');
    await UploadQueueRepository.cleanupFileIfCached(filePath);
    _queue = await UploadQueueRepository.getActive();
    notifyListeners();
  }

  Future<bool> _fetchAndStart(File file, String title, int duration,
      int fileSize, int id) async {
    final urls = await BackgroundUploadService.fetchPresignedUrl(
      filePath: file.path,
      endpoint: Urls.videoPostAssetsUploadUrl,
      buildPayload: (name) => {
        'videoFilename': name,
        'videoContentType': BackgroundUploadService.inferVideoContentType(name),
      },
    );

    if (urls == null) {
      await _cleanupFailedUpload(id, file.path);
      AppLogger.w('_fetchAndStart: presigned URL fetch returned null');
      ToastService.showError('Failed to get upload URL');
      return false;
    }

    await UploadQueueRepository.updateUrls(
      id: id,
      uploadUrl: urls['uploadUrl']!,
      fileUrl: urls['fileUrl']!,
    );

    _processNextItem();
    return true;
  }

  // ──────────────────────────────────────────────
  //  Permission helpers
  // ──────────────────────────────────────────────

  Future<bool> _ensureNotificationPermission() async {
    if (await UploadNotificationService.hasNotificationPermission()) return true;

    final first = await UploadNotificationService.requestNotificationPermission();
    if (first) return true;

    final shouldRetry = await _showPermissionDialog(
      title: 'Notification Permission Required',
      content:
          'Background uploads need notification permission to show progress and keep the upload alive.',
      confirmText: 'Grant',
      cancelText: 'Not Now',
    );
    if (shouldRetry != true) return false;

    final second = await UploadNotificationService.requestNotificationPermission();
    if (second) return true;

    final openSettings = await _showPermissionDialog(
      title: 'Permission Permanently Denied',
      content:
          'Please enable notifications in System Settings to use background uploads.',
      confirmText: 'Open Settings',
      cancelText: 'Cancel',
    );
    if (openSettings == true) {
      await _openNotificationSettings();
    }
    return false;
  }

  Future<void> _openNotificationSettings() async {
    // Fallback: open app settings
    await Process.run('am', [
      'start',
      '-a',
      'android.settings.APPLICATION_DETAILS_SETTINGS',
      '-d',
      'package:${Platform.resolvedExecutable}',
    ]);
  }

  Future<bool?> _showPermissionDialog({
    required String title,
    required String content,
    required String confirmText,
    required String cancelText,
  }) {
    final ctx = App.navigatorKey.currentContext;
    if (ctx == null) return Future.value(false);
    return showDialog<bool>(
      context: ctx,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(cancelText),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  //  Queue management
  // ──────────────────────────────────────────────

  Future<void> pauseQueue() async {
    ToastService.showInfo('Queue management handled by system notifications');
  }

  Future<void> resumeQueue() async {
    _processNextItem();
    ToastService.showInfo('Upload queue resumed');
  }

  Future<void> cancelTask(int queueId) async {
    // Cancel via native task if we have its workerId
    final items = await UploadQueueRepository.getAll();
    final item = items.where((i) => i.id == queueId).firstOrNull;
    if (item?.workerId != null && item!.workerId!.isNotEmpty) {
      await BackgroundUploaderService.cancelUploadByWorkerId(item.workerId!);
    }
    await UploadQueueRepository.updateStatus(
        id: queueId, status: 'cancelled');
    _queue.removeWhere((item) => item.id == queueId);
    if (_activeItem?.id == queueId) {
      _activeItem = null;
      _activeProgress = 0;
      _processNextItem();
    }
    notifyListeners();
    ToastService.showInfo('Upload cancelled');
  }

  Future<void> removeItem(int queueId) async {
    final items = await UploadQueueRepository.getAll();
    final item = items.where((i) => i.id == queueId).firstOrNull;
    if (item?.workerId != null && item!.workerId!.isNotEmpty) {
      await BackgroundUploaderService.cancelUploadByWorkerId(item.workerId!);
    }
    await UploadQueueRepository.deleteItem(queueId);
    _queue.removeWhere((item) => item.id == queueId);
    notifyListeners();
  }

  Future<void> clearCompleted() async {
    await UploadQueueRepository.clearCompleted();
    _queue.removeWhere((item) => item.status == 'completed');
    notifyListeners();
  }

  Future<void> retryFailed(int queueId) async {
    await UploadQueueRepository.incrementRetryCount(queueId);
    await UploadQueueRepository.updateStatus(
      id: queueId,
      status: 'pending',
      errorMessage: null,
    );
    final idx = _queue.indexWhere((item) => item.id == queueId);
    if (idx >= 0) {
      _queue[idx] = _queue[idx].copyWith(
        status: 'pending',
        errorMessage: null,
      );
    }
    notifyListeners();

    final item = _queue.firstWhere(
      (i) => i.id == queueId,
      orElse: () =>
          _queue.isNotEmpty
              ? _queue[0]
              : UploadQueueItem(
                  filePath: '', title: '', status: '', uploadType: ''),
    );
    if (item.filePath.isEmpty) return;

    final result = await _retryItem(item, queueId);
    if (result) {
      ToastService.showInfo('Retrying upload');
    }
  }

  Future<bool> _retryItem(UploadQueueItem item, int queueId) async {
    late String endpoint;
    Map<String, dynamic> Function(String) buildPayload = (_) => {};
    Map<String, dynamic> extraFields = {};

    switch (item.uploadType) {
      case 'course':
        endpoint = Urls.courseAssetsUploadUrl;
        buildPayload = (name) => {
              'thumbnailFilename': name,
              'thumbnailContentType':
                  BackgroundUploadService.inferImageContentType(name),
            };
        break;
      case 'module_lesson':
        endpoint = Urls.courseModuleUploadUrl;
        buildPayload = (name) => {
              'videoFilename': name,
              'videoContentType':
                  BackgroundUploadService.inferVideoContentType(name),
            };
        if (item.metadata != null) {
          final meta =
              ModuleLessonMetadata.fromJson(jsonDecode(item.metadata!));
          extraFields = {'moduleID': meta.moduleId};
        }
        break;
      case 'resource':
        endpoint = Urls.courseModuleResourceUploadUrl;
        buildPayload = (name) {
          final ct = item.metadata != null
              ? (jsonDecode(item.metadata!) as Map)['contentType'] ??
                  'application/octet-stream'
              : 'application/octet-stream';
          return {'filename': name, 'contentType': ct};
        };
        if (item.metadata != null) {
          final meta =
              ModuleLessonMetadata.fromJson(jsonDecode(item.metadata!));
          extraFields = {'moduleID': meta.moduleId};
        }
        break;
      case 'course_intro':
        endpoint = Urls.courseAssetsUploadUrl;
        buildPayload = (name) => {
              'thumbnailFilename': 'keep.jpg',
              'thumbnailContentType': 'image/jpeg',
              'videoFilename': name,
              'videoContentType':
                  BackgroundUploadService.inferVideoContentType(name),
            };
        break;
      default:
        endpoint = Urls.videoPostAssetsUploadUrl;
        buildPayload = (name) => {
              'videoFilename': name,
              'videoContentType':
                  BackgroundUploadService.inferVideoContentType(name),
            };
    }

    final urls = await BackgroundUploadService.fetchPresignedUrl(
      filePath: item.filePath,
      endpoint: endpoint,
      buildPayload: buildPayload,
      extraFields: extraFields,
    );

    if (urls == null) {
      ToastService.showError('Failed to get upload URL for retry');
      return false;
    }

    await UploadQueueRepository.updateUrls(
      id: queueId,
      uploadUrl: urls['uploadUrl']!,
      fileUrl: urls['fileUrl']!,
    );

    _processNextItem();
    return true;
  }

  void onNativeUploadCompleted(int id, String fileUrl) {
    UploadQueueRepository.markCompleted(id);
    final idx = _queue.indexWhere((item) => item.id == id);
    if (idx >= 0) {
      _queue[idx] = _queue[idx].copyWith(
        status: 'completed',
        fileUrl: fileUrl,
      );
      _cleanupCachedFile(_queue[idx].filePath);
    }
    if (_activeItem?.id == id) {
      _activeItem = null;
      _activeProgress = 0;
    }
    notifyListeners();
    ToastService.showSuccess('Upload completed');
  }

  Future<void> _cleanupCachedFile(String filePath) async {
    await UploadQueueRepository.cleanupFileIfCached(filePath);
  }

  void onNativeUploadFailed(int id, String error) {
    UploadQueueRepository.markFailed(id, error);
    final idx = _queue.indexWhere((item) => item.id == id);
    if (idx >= 0) {
      _queue[idx] = _queue[idx].copyWith(
        status: 'failed',
        errorMessage: error,
      );
    }
    notifyListeners();
  }
}

class _CallbackDetails {
  final String url;
  final Map<String, dynamic> body;
  const _CallbackDetails({required this.url, required this.body});
}
