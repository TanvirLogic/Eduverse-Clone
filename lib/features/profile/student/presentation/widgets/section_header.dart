import 'package:flutter/material.dart';
import 'package:edtech/app/app_colors.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final bool showSeeAll;
  const SectionHeader({
    super.key,
    required this.title,
    this.showSeeAll = false,
  });
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
              letterSpacing: 1,
            ),
          ),
          if (showSeeAll)
            Text(
              'See All',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.themeColor,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }
}
