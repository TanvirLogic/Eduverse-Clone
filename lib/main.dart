import 'package:edtech/app/app.dart';
import 'package:edtech/features/courses/services/background_upload_service.dart';
import 'package:edtech/global/core/services/upload_notification_service.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await UploadNotificationService.init();
  BackgroundUploadService.registerBackgroundHandler();
  final prefs = await SharedPreferences.getInstance();
  runApp(App(prefs: prefs));
}
