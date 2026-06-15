import 'package:edtech/app/app_colors.dart';
import 'package:edtech/global/core/constants/sizes.dart';
import 'package:flutter/material.dart';
import '../../../../../../global/core/constants/images/images.dart';

/// Displays a vertically flowing row of skill badges (wraps naturally).
class SkillBadgesRow extends StatelessWidget {
  const SkillBadgesRow({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final scBg = Theme.of(context).scaffoldBackgroundColor;
    final badges = ['UI/UX Design', 'Figma', 'Adobe XD'];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: badges
          .map(
            (label) => Container(
              padding: const EdgeInsets.only(
                left: 12,
                top: 4,
                right: 4,
                bottom: 4,
              ),
              decoration: BoxDecoration(
                color: scBg,
                borderRadius: BorderRadius.circular(AppSizes.radiusLg2),
                border: Border.all(color: AppColors.border, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Image.asset(Images.blueTick, width: 18, height: 18),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}
