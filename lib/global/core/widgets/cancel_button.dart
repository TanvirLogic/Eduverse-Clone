import 'package:edtech/app/app_colors.dart';
import 'package:flutter/material.dart';

class CancelButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;

  const CancelButton({
    super.key,
    this.text = 'Cancel',
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.cancelFill,
        foregroundColor: AppColors.cancelText,
        elevation: 0,
      ),
      child: Text(text),
    );
  }
}
