import 'package:flutter/material.dart';
import 'package:edtech/app/app_colors.dart';

class ToastService {
  static OverlayState? _overlay;

  static void initOverlay(OverlayState overlay) {
    _overlay = overlay;
  }

  static OverlayEntry? _currentEntry;

  static void showSuccess(String message) {
    _showToast(message, AppColors.themeColor, Colors.white);
  }

  static void showError(String message) {
    _showToast(friendlyMessage(message), const Color(0xFFFEE2E2), Colors.black);
  }

  static void showInfo(String message) {
    _showToast(message, AppColors.themeColor, AppColors.surface);
  }

  static void _showToast(
    String message,
    Color backgroundColor,
    Color textColor,
  ) {
    _currentEntry?.remove();
    _currentEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 16,
        left: 0,
        right: 0,
        child: Material(
          color: Colors.transparent,
          child: Align(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.75,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: textColor, fontSize: 14),
              ),
            ),
          ),
        ),
      ),
    );
    _overlay?.insert(_currentEntry!);
    Future.delayed(const Duration(seconds: 3), () {
      _currentEntry?.remove();
      _currentEntry = null;
    });
  }

  static String friendlyMessage(String rawMessage) {
    return _getFriendlyMessage(rawMessage);
  }

  static String _getFriendlyMessage(String rawMessage) {
    final lowerMessage = rawMessage.toLowerCase();

    if (lowerMessage.contains('connection error') ||
        lowerMessage.contains('socketexception') ||
        lowerMessage.contains('host lookup')) {
      return "Unable to connect. Please check your internet connection.";
    }

    if (lowerMessage.contains('timeout')) {
      return "The server is taking too long to respond. Please try again later.";
    }

    if (lowerMessage.contains('email_not_verified') ||
        lowerMessage.contains('email not verified')) {
      return "Please verify your email before signing in.";
    }

    if (lowerMessage.contains('session expired') ||
        lowerMessage.contains('token expired') ||
        lowerMessage.contains('refresh failed')) {
      return "Your session has expired. Please sign in again.";
    }

    if (lowerMessage.contains('network') ||
        lowerMessage.contains('connection reset') ||
        lowerMessage.contains('host lookup')) {
      return "Unable to connect. Please check your internet connection.";
    }

    if (lowerMessage.contains('404')) {
      return "Requested resource not found.";
    }

    if (lowerMessage.contains('500') ||
        lowerMessage.contains('internal server error')) {
      return "Server is currently busy. Please try again in a moment.";
    }

    if (lowerMessage.contains('unauthorized') ||
        lowerMessage.contains('forbidden')) {
      return "You do not have permission to perform this action.";
    }

    if (lowerMessage.contains('format-exception') ||
        lowerMessage.contains('unexpected character')) {
      return "Something went wrong. Please try again later.";
    }

    if (rawMessage.isEmpty) {
      return "An unexpected error occurred. Please try again.";
    }

    if (rawMessage.length > 100 || rawMessage.contains(':')) {
      return "An unexpected error occurred. Please try again.";
    }

    return rawMessage;
  }
}
