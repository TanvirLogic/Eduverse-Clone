import 'package:logger/logger.dart';

class AppLogger {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 500,
      colors: true,
      printEmojis: true,
      printTime: true,
    ),
  );

  static String _format(String message, String? tag) {
    if (tag == null || tag.isEmpty) return message;
    return '[$tag] $message';
  }

  static void d(String message, {String? tag}) =>
      _logger.d(_format(message, tag));

  static void i(String message, {String? tag}) =>
      _logger.i(_format(message, tag));

  static void w(String message, {String? tag}) =>
      _logger.w(_format(message, tag));

  static void e(
    String message, {
    dynamic error,
    StackTrace? stackTrace,
    String? tag,
  }) => _logger.e(_format(message, tag), error: error, stackTrace: stackTrace);
}
