import 'dart:io';

import 'package:http/http.dart' as http;

import '../setup_network_caller.dart';

class S3UploadResult {
  final bool isSuccess;
  final String? fileUrl;
  final String? errorMessage;

  S3UploadResult({
    required this.isSuccess,
    this.fileUrl,
    this.errorMessage,
  });
}

class S3UploadService {
  static Future<S3UploadResult> uploadImage({
    required String uploadUrlEndpoint,
    required String confirmUrlEndpoint,
    required String filename,
    required List<int> bytes,
    required String contentType,
    Duration uploadTimeout = const Duration(seconds: 120),
    void Function(double progress)? onProgress,
  }) async {
    final urlResponse = await getNetworkCaller().postRequest(
      url: uploadUrlEndpoint,
      body: {'filename': filename, 'contentType': contentType},
    );

    if (!urlResponse.isSuccess) {
      return S3UploadResult(
        isSuccess: false,
        errorMessage: urlResponse.errorMessage ?? 'Failed to get upload URL',
      );
    }

    final data = urlResponse.responseData is Map
        ? (urlResponse.responseData as Map)['data']
        : null;

    if (data is! Map || data['uploadUrl'] == null || data['fileUrl'] == null) {
      return S3UploadResult(
        isSuccess: false,
        errorMessage: 'Invalid response from server',
      );
    }

    final uploadUrl = data['uploadUrl'] as String;
    final fileUrl = data['fileUrl'] as String;

    try {
      await _streamUpload(
        url: uploadUrl,
        bytes: bytes,
        contentType: contentType,
        timeout: uploadTimeout,
        onProgress: onProgress,
      );
    } catch (e) {
      return S3UploadResult(
        isSuccess: false,
        errorMessage: 'Failed to upload image to storage',
      );
    }

    final confirmResponse = await getNetworkCaller().putRequest(
      url: confirmUrlEndpoint,
      body: {'fileUrl': fileUrl},
    );

    if (confirmResponse.isSuccess) {
      return S3UploadResult(isSuccess: true, fileUrl: fileUrl);
    }

    return S3UploadResult(
      isSuccess: false,
      errorMessage: confirmResponse.errorMessage ?? 'Failed to confirm upload',
    );
  }

  static Future<void> _streamUpload({
    required String url,
    required List<int> bytes,
    required String contentType,
    required Duration timeout,
    void Function(double progress)? onProgress,
  }) async {
    final totalBytes = bytes.length;
    const chunkSize = 65536;

    final request = http.StreamedRequest('PUT', Uri.parse(url));
    request.headers['Content-Type'] = contentType;
    request.contentLength = totalBytes;

    final responseFuture = request.send().timeout(timeout);

    int offset = 0;
    while (offset < totalBytes) {
      final end = (offset + chunkSize).clamp(0, totalBytes);
      request.sink.add(bytes.sublist(offset, end));
      offset = end;
      onProgress?.call(offset / totalBytes);
      await Future.delayed(const Duration(milliseconds: 8));
    }
    await request.sink.close();

    final streamedResponse = await responseFuture;
    if (streamedResponse.statusCode != 200) {
      throw HttpException(
        'S3 upload failed with status ${streamedResponse.statusCode}',
        uri: Uri.parse(url),
      );
    }
  }

  static String inferContentType(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }
}
