import 'dart:async';
import 'dart:io';

import 'package:edtech/app/app.dart';
import 'package:edtech/features/auth/data/models/auth_controller.dart';
import 'package:edtech/features/courses/data/helpers/video_metadata_helper.dart';
import 'package:edtech/features/courses/data/repositories/upload_queue_repository.dart';
import 'package:edtech/features/courses/services/background_upload_service.dart';
import 'package:edtech/global/core/services/toast_service.dart';
import 'package:edtech/global/core/services/upload_notification_service.dart';
import 'package:edtech/global/core/widgets/app_alert_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

class VideoQueueUploadProvider extends ChangeNotifier {
  List<UploadQueueItem> _queue = [];
  UploadQueueItem? _activeItem;
  int _activeProgress = 0;
  bool _isBackgroundRunning = false;
  bool _isPaused = false;
  StreamSubscription? _progressSub;

  List<UploadQueueItem> get queue => List.unmodifiable(_queue);
  UploadQueueItem? get activeItem => _activeItem;
  int get activeProgress => _activeProgress;
  bool get isBackgroundRunning => _isBackgroundRunning;
  bool get isPaused => _isPaused;

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

  VideoQueueUploadProvider() {
    _init();
  }

  Future<void> _init() async {
    await _loadQueue();
    _listenToBackground();
  }

  Future<void> _loadQueue() async {
    try {
      _queue = await UploadQueueRepository.getActive();
      final allItems = await UploadQueueRepository.getAll();
      final active =
          allItems.where((item) =>
              item.status == 'uploading' || item.status == 'pending')
              .toList();
      if (active.isNotEmpty) {
        _activeItem = active.first;
      }
      notifyListeners();
    } catch (e) {
      _queue = [];
    }
  }

  void _listenToBackground() {
    try {
      _progressSub?.cancel();
      _progressSub =
          FlutterBackgroundService().on('uploadProgress').listen((data) {
            if (data is Map<String, dynamic>) {
              final queueId = data['queueId'] as int?;
              final status = data['status'] as String?;
              final progress = data['progress'] as int? ?? 0;

              if (status == 'uploading' && queueId != null) {
                _updateItemProgress(queueId, progress);
              } else if (status == 'completed' && queueId != null) {
                _markItemCompleted(queueId);
              } else if (status == 'failed' && queueId != null) {
                _markItemFailed(queueId);
              }
            }
          });
    } catch (_) {}
  }

  void _updateItemProgress(int queueId, int progress) {
    final idx = _queue.indexWhere((item) => item.id == queueId);
    if (idx >= 0) {
      _queue[idx] = _queue[idx].copyWith(status: 'uploading');
    }
    if (_activeItem?.id == queueId) {
      _activeProgress = progress;
    }
    notifyListeners();
  }

  void _markItemCompleted(int queueId) async {
    final idx = _queue.indexWhere((item) => item.id == queueId);
    if (idx >= 0) {
      _queue[idx] = _queue[idx].copyWith(status: 'completed');
    }
    if (_activeItem?.id == queueId) {
      _activeItem = null;
      _activeProgress = 0;
    }
    _checkNextActive();
    notifyListeners();
  }

  void _markItemFailed(int queueId) async {
    final idx = _queue.indexWhere((item) => item.id == queueId);
    if (idx >= 0) {
      _queue[idx] = _queue[idx].copyWith(status: 'failed');
    }
    if (_activeItem?.id == queueId) {
      _activeItem = null;
      _activeProgress = 0;
    }
    _checkNextActive();
    notifyListeners();
  }

  void _checkNextActive() {
    if (_activeItem != null) return;
    final next = _queue.where((item) => item.status == 'pending').toList();
    if (next.isNotEmpty) {
      _activeItem = next.first;
      _activeProgress = 0;
    }
  }

  Future<void> addToQueue(File file, String title) async {
    try {
      final duration = await VideoMetadataHelper.getDurationSeconds(file.path);
      final fileSize = await VideoMetadataHelper.getFileSizeBytes(file.path);

      final item = UploadQueueItem(
        filePath: file.path,
        title: title,
        videoDuration: duration,
        fileSize: fileSize,
        status: 'pending',
      );

      await UploadQueueRepository.insert(item);
      _queue = await UploadQueueRepository.getActive();
      _checkNextActive();
      notifyListeners();

      if (!_isBackgroundRunning) {
        await _startBackground();
      }

      ToastService.showSuccess('Added to upload queue');
    } catch (e) {
      ToastService.showError('Failed to add video to queue');
    }
  }

  Future<void> _startBackground() async {
    try {
      final granted = await UploadNotificationService.requestNotificationPermission();
      if (!granted) {
        final shouldRetry = await AppAlertDialog.show(
          context: App.navigatorKey.currentContext!,
          title: 'Notification Permission Required',
          content: 'Background uploads need notification permission to show progress and keep the upload alive when the app is in the background.',
          confirmText: 'Grant',
          cancelText: 'Not Now',
        );
        if (shouldRetry != true) return;
        final granted2 = await UploadNotificationService.requestNotificationPermission();
        if (!granted2) return;
      }
      _isBackgroundRunning = true;
      _isPaused = false;
      await BackgroundUploadService.startQueue(token: AuthController.accessToken);
      notifyListeners();
    } catch (e) {
      _isBackgroundRunning = false;
    }
  }

  Future<void> pauseQueue() async {
    await BackgroundUploadService.pauseQueue();
    _isPaused = true;
    notifyListeners();
    ToastService.showInfo('Upload queue paused');
  }

  Future<void> resumeQueue() async {
    await BackgroundUploadService.resumeQueue(token: AuthController.accessToken);
    _isPaused = false;
    _isBackgroundRunning = true;
    notifyListeners();
    ToastService.showInfo('Upload queue resumed');
  }

  Future<void> cancelTask(int queueId) async {
    await BackgroundUploadService.cancelItem(queueId);
    await UploadQueueRepository.updateStatus(
      id: queueId,
      status: 'cancelled',
    );
    _queue.removeWhere((item) => item.id == queueId);
    if (_activeItem?.id == queueId) {
      _activeItem = null;
      _activeProgress = 0;
    }
    notifyListeners();
    ToastService.showInfo('Upload cancelled');
  }

  Future<void> removeItem(int queueId) async {
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
    if (!_isBackgroundRunning) {
      await _startBackground();
    } else if (_isPaused) {
      await resumeQueue();
    }
    notifyListeners();
    ToastService.showInfo('Retrying upload');
  }

  @override
  void dispose() {
    _progressSub?.cancel();
    super.dispose();
  }
}
