import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class UploadNotificationService {
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  static const String _channelId = 'upload_progress';
  static const String _channelName = 'Upload Progress';
  static const String _channelDesc = 'Shows file upload progress';
  static final int _notificationId = 0;

  static Future<void> init() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await _notifications.initialize(const InitializationSettings(android: androidSettings, iOS: iosSettings));

    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.low,
    );
    await _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(androidChannel);
  }

  static Future<bool> requestNotificationPermission() async {
    final plugin = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (plugin == null) return false;
    final granted = await plugin.requestNotificationsPermission();
    return granted ?? false;
  }

  static Future<void> startService() async {
    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();
    if (!isRunning) {
      await service.startService();
    }
  }

  static Future<void> stopService() async {
    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();
    if (isRunning) {
      service.invoke('stopService');
    }
  }

  static Future<void> showProgress({
    required int progress,
    required int total,
    required String title,
    String? fileName,
  }) async {
    final pct = total > 0 ? (progress * 100 ~/ total) : 0;
    final body = fileName != null ? '$fileName — $pct%' : 'Uploading... $pct%';

    await _notifications.show(
      _notificationId,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.low,
          priority: Priority.low,
          showProgress: true,
          maxProgress: total,
          progress: progress,
          indeterminate: progress == 0,
          ongoing: true,
          autoCancel: false,
          onlyAlertOnce: true,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  static Future<void> showSuccess({required String title, String? body}) async {
    await _notifications.show(
      _notificationId,
      title,
      body ?? 'Upload completed successfully',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          showProgress: false,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  static Future<void> showError({required String title, String? body}) async {
    await _notifications.show(
      _notificationId,
      title,
      body ?? 'Upload failed',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          showProgress: false,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  static Future<void> cancel() async {
    await _notifications.cancel(_notificationId);
  }
}
