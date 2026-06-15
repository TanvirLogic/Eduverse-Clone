import 'package:flutter/services.dart';

class VideoMetadata {
  final int duration;
  final int fileSize;
  VideoMetadata({required this.duration, required this.fileSize});
}

class VideoMetadataService {
  static const _channel = MethodChannel('eduverse/video_metadata');

  static Future<VideoMetadata> getVideoInfo(String videoPath) async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'getVideoInfo',
        {'path': videoPath},
      );
      if (result != null) {
        return VideoMetadata(
          duration: (result['duration'] as num).toInt(),
          fileSize: (result['fileSize'] as num).toInt(),
        );
      }
    } catch (e) {
      // fallback below
    }
    return VideoMetadata(duration: 1, fileSize: 0);
  }
}
