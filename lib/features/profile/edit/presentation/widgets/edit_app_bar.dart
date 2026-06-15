import 'package:flutter/material.dart';
import 'package:edtech/global/core/widgets/app_back_button.dart';

class EditAppBarModule extends StatelessWidget implements PreferredSizeWidget {
  const EditAppBarModule({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppBar(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      title: Text(
        "Edit Profile",
        style: TextStyle(
          color: cs.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.3,
        ),
      ),
      leading: const Padding(
        padding: EdgeInsets.all(8.0),
        child: AppBackButton(),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
