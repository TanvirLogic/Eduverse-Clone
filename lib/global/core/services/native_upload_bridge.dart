/// No-op stub — replaced by [BackgroundUploaderService].
/// Kept for backward compatibility with legacy providers
/// that are being migrated incrementally.
class NativeUploadBridge {
  static Future<void> ensureInitialized() async {}
  static Future<bool> syncQueueToNative(String _) async => true;
  static Future<bool> startQueueProcessing() async => true;
  static Future<bool> startNativeUpload({
    String? filePath,
    String? uploadUrl,
    String? fileUrl,
    String? title,
    String contentType = 'video/mp4',
    String uploadType = 'video_post',
    String? authToken,
    String? callbackUrl,
    String? callbackBody,
    String? metadata,
    int itemId = -1,
    String? uploadId,
  }) async => true;
  static Future<void> clearState() async {}
  static Future<void> openNotificationSettings() async {}
  static Future<void> cancelNativeUpload() async {}
  static Future<bool> ping() async => false;
  static Future<List<Map<String, dynamic>>> getCompletedItems() async => [];
  static Future<void> acknowledgeCompletedItems() async {}
  static Future<Map<String, dynamic>> getNativeQueueStatus() async => {
    'totalItems': 0, 'pending': 0, 'uploading': 0,
    'completed': 0, 'failed': 0, 'isUploading': false,
  };
  static Future<Map<String, dynamic>> getQueueItems() async => {
    'items': <Map<String, dynamic>>[], 'isUploading': false,
  };
  static Future<List<Map<String, dynamic>>> getPendingUploads() async => [];
  static Future<void> processPendingQueue() async {}
  static Future<void> startServiceForUpload({
    String? filePath, String? uploadUrl, String? title,
    String? contentType, String? uploadType, String? metadata, int? itemId,
  }) async {}
}
