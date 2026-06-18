import 'package:flutter/material.dart';
import 'package:edtech/global/core/widgets/auth_button.dart';

class ManageModuleBottomBar extends StatelessWidget {
  final VoidCallback onAddModule;
  final VoidCallback onPublish;

  const ManageModuleBottomBar({
    super.key,
    required this.onAddModule,
    required this.onPublish,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: AuthButton(
              text: "Add Module",
              height: 50,
              borderRadius: 24,
              fontSize: 14,
              onPressed: onAddModule,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 4,
            child: SizedBox(
              height: 50,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  side: BorderSide(color: cs.primary),
                ),
                onPressed: onPublish,
                child: Text(
                  "Publish",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: cs.primary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
