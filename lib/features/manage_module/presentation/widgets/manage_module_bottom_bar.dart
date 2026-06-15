import 'package:flutter/material.dart';
import 'package:edtech/global/core/widgets/auth_button.dart';

class ManageModuleBottomBar extends StatelessWidget {
  final bool hasUnsavedChanges;
  final VoidCallback onAddModule;
  final VoidCallback onSaveOrder;

  const ManageModuleBottomBar({
    super.key,
    required this.hasUnsavedChanges,
    required this.onAddModule,
    required this.onSaveOrder,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
      ),
      child: hasUnsavedChanges
          ? Row(
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
                      onPressed: onSaveOrder,
                      child: Text(
                        "Save Changes",
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
            )
          : AuthButton(
              text: "Add Module",
              height: 50,
              borderRadius: 24,
              onPressed: onAddModule,
            ),
    );
  }
}
