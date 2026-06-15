import 'package:edtech/features/courses/services/background_upload_service.dart';
import 'package:edtech/global/core/services/upload_notification_service.dart';
import 'package:media_kit/media_kit.dart';

Future<void> initPlatformServices() async {
  MediaKit.ensureInitialized();
  await UploadNotificationService.init();
  BackgroundUploadService.registerBackgroundHandler();
}
