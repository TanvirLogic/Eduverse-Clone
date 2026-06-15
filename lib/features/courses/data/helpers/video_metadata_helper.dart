import 'dart:io';

import 'package:edtech/global/core/services/video_metadata_service.dart';

class VideoMetadataHelper {
  static Future<int> getDurationSeconds(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return 0;
      }
      final metadata = await VideoMetadataService.getVideoInfo(filePath);
      if (metadata.duration > 0) {
        return metadata.duration;
      }
      return 0;
    } catch (_) {
      return 0;
    }
  }

  static Future<int> getFileSizeBytes(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return 0;
      }
      final metadata = await VideoMetadataService.getVideoInfo(filePath);
      if (metadata.fileSize > 0) {
        return metadata.fileSize;
      }
      return await file.length();
    } catch (_) {
      try {
        final file = File(filePath);
        return await file.length();
      } catch (_) {
        return 0;
      }
    }
  }
}
