import 'package:edtech/app/app_colors.dart';
import 'package:edtech/global/core/constants/sizes.dart';
import 'package:flutter/material.dart';
import '../../../../global/core/widgets/auth_button.dart';
import 'package:edtech/features/profile/mentor/presentation/screens/mentor_profile_screen.dart';

class InstructorProfileCard extends StatelessWidget {
  final bool isDark;
  final ColorScheme cs;

  const InstructorProfileCard({super.key, required this.isDark, required this.cs});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainerLow : Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 33,
            backgroundColor: cs.outlineVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Michael Chen',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Senior Full-Stack Developer',
                  style: TextStyle(
                    color: isDark ? cs.onSurface.withValues(alpha: 0.7) : cs.onSurface.withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 83,
            height: 22,
            child: AuthButton(
              text: 'View Profile',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MentorProfileScreen(isOwnProfile: false),
                ),
              ),
              height: 22,
              borderRadius: 11,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
