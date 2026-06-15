import 'package:edtech/global/core/constants/sizes.dart';
import 'package:flutter/material.dart';

class AppAlertDialog extends StatelessWidget {
  final String title;
  final String content;
  final String? confirmText;
  final String? cancelText;
  final Color? confirmColor;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;

  const AppAlertDialog({
    super.key,
    required this.title,
    required this.content,
    this.confirmText,
    this.cancelText,
    this.confirmColor,
    this.onConfirm,
    this.onCancel,
  });

  static Future<bool?> show({
    required BuildContext context,
    required String title,
    required String content,
    String? confirmText,
    String? cancelText,
    Color? confirmColor,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AppAlertDialog(
        title: title,
        content: content,
        confirmText: confirmText,
        cancelText: cancelText,
        confirmColor: confirmColor,
        onConfirm: () => Navigator.pop(ctx, true),
        onCancel: () => Navigator.pop(ctx, false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLg2),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: cs.onSurface,
        ),
      ),
      content: Text(
        content,
        style: TextStyle(
          fontSize: 14,
          color: cs.onSurface,
        ),
      ),
      actions: [
        if (cancelText != null)
          TextButton(
            onPressed: onCancel,
            child: Text(
              cancelText!,
              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6)),
            ),
          ),
        if (confirmText != null)
          TextButton(
            onPressed: onConfirm,
            child: Text(
              confirmText!,
              style: TextStyle(color: confirmColor ?? cs.error),
            ),
          ),
      ],
    );
  }
}
