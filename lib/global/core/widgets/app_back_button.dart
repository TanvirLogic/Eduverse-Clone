import 'package:edtech/app/app_colors.dart';
import 'package:flutter/material.dart';

class AppBackButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const AppBackButton({super.key, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final iconBg = cs.brightness == Brightness.light
        ? AppColors.fill
        : cs.surfaceContainerHighest;
    return CircleAvatar(
      backgroundColor: iconBg,
      child: IconButton(
        icon: Icon(Icons.arrow_back_ios_new, size: 14, color: cs.onSurface),
        onPressed: onPressed ?? () => Navigator.maybePop(context),
      ),
    );
  }
}
