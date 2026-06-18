import 'package:edtech/global/core/constants/sizes.dart';
import 'package:edtech/app/app_colors.dart';
import 'package:flutter/material.dart';

class AppAlertDialog extends StatelessWidget {
  final String title;
  final String? content;
  final Widget? contentWidget;
  final String? confirmText;
  final String? cancelText;
  final Color? confirmColor;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;

  const AppAlertDialog({
    super.key,
    required this.title,
    this.content,
    this.contentWidget,
    this.confirmText,
    this.cancelText,
    this.confirmColor,
    this.onConfirm,
    this.onCancel,
  });

  static Future<bool?> show({
    required BuildContext context,
    required String title,
    String content = '',
    Widget? contentWidget,
    String? confirmText,
    String? cancelText,
    Color? confirmColor,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AppAlertDialog(
        title: title,
        content: content,
        contentWidget: contentWidget,
        confirmText: confirmText,
        cancelText: cancelText,
        confirmColor: confirmColor,
        onConfirm: () => Navigator.pop(ctx, true),
        onCancel: () => Navigator.pop(ctx, false),
      ),
    );
  }

  static Future<String?> showInput({
    required BuildContext context,
    required String title,
    String? initialValue,
    String hintText = '',
    String? confirmText,
    String? cancelText,
    Color? confirmColor,
  }) {
    final controller = TextEditingController(text: initialValue);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AppAlertDialog(
        title: title,
        contentWidget: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (value) {
            final trimmed = value.trim();
            if (trimmed.isNotEmpty) {
              Navigator.pop(ctx, trimmed);
            }
          },
          decoration: InputDecoration(
            hintText: hintText,
            border: InputBorder.none,
          ),
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(ctx).colorScheme.onSurface,
          ),
        ),
        confirmText: confirmText ?? 'Save',
        cancelText: cancelText ?? 'Cancel',
        confirmColor: confirmColor ?? AppColors.themeColor,
        onConfirm: () {
          final trimmed = controller.text.trim();
          if (trimmed.isNotEmpty) {
            Navigator.pop(ctx, trimmed);
          }
        },
        onCancel: () => Navigator.pop(ctx),
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
      content: contentWidget ??
          (content != null
              ? Text(
                  content!,
                  style: TextStyle(
                    fontSize: 14,
                    color: cs.onSurface,
                  ),
                )
              : null),
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
              style: TextStyle(color: confirmColor ?? AppColors.themeColor),
            ),
          ),
      ],
    );
  }
}
