import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:edtech/global/core/constants/images/images.dart';

class ManageModuleMeta extends StatelessWidget {
  const ManageModuleMeta({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "App Development with flutter & AI",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "With 70 live classes, you'll learn everything from the very basics to advanced levels of app development!",
            style: TextStyle(
              fontSize: 13,
              color: cs.onSurface.withValues(alpha: 0.6),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _MetaTag(assetPath: Images.languageIcon, label: "Bangla"),
              const SizedBox(width: 12),
              _MetaTag(assetPath: Images.bookNoC, label: "Advanced"),
              const SizedBox(width: 12),
              _MetaTag(assetPath: Images.dollar, label: "Paid"),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaTag extends StatelessWidget {
  final String assetPath;
  final String label;

  const _MetaTag({required this.assetPath, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        SvgPicture.asset(
          assetPath,
          width: 16,
          height: 16,
          colorFilter: ColorFilter.mode(cs.primary, BlendMode.srcIn),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: cs.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}
