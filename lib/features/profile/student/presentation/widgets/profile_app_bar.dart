import 'package:edtech/global/core/constants/images/images.dart';
import 'package:edtech/app/app_colors.dart';
import 'package:edtech/app/app_routes.dart';
import 'package:edtech/global/core/widgets/app_back_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:edtech/features/profile/student/providers/student_profile_provider.dart';

/// Custom app bar for the profile page with back button and edit action.
class ProfileAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ProfileAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final scBg = Theme.of(context).scaffoldBackgroundColor;
    final profileName = context.watch<StudentProfileProvider>().profile?.name;
    return SafeArea(
      child: AppBar(
        backgroundColor: scBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Text(
          profileName ?? 'Profile',
          style: TextStyle(
            color: cs.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
        ),
        leading: const Padding(
          padding: EdgeInsets.only(left: 16),
          child: AppBackButton(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: CircleAvatar(
              backgroundColor: cs.brightness == Brightness.light
                  ? AppColors.fill
                  : cs.surfaceContainerHighest,
              child: IconButton(
                icon: Padding(
                  padding: const EdgeInsets.all(3),
                  child: SvgPicture.asset(
                    Images.editProfile,
                    width: 20,
                    height: 20,
                    colorFilter: ColorFilter.mode(cs.onSurface, BlendMode.srcIn),
                  ),
                ),
                onPressed: () {
                  Navigator.pushNamed(context, AppRoutes.editProfilePage);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
