import 'package:flutter/material.dart';
import 'package:edtech/global/core/widgets/swipe_action_widget.dart';
import 'package:edtech/global/core/widgets/app_alert_dialog.dart';

class SocialLinksFormBlockUi extends StatelessWidget {
  final ValueNotifier<int> resetNotifier;
  final List<TextEditingController> platformControllers;
  final List<TextEditingController> urlControllers;
  final List<String> socialPlatforms;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  const SocialLinksFormBlockUi({
    super.key,
    required this.resetNotifier,
    required this.platformControllers,
    required this.urlControllers,
    required this.socialPlatforms,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    assert(
      platformControllers.length == urlControllers.length,
      'platformControllers and urlControllers must have the same length',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Social links",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          "To Delete Social link Swipe right or left",
          style: TextStyle(
            color: cs.primary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 14),
        ...List.generate(platformControllers.length, (index) {
          return Padding(
            key: ValueKey('social_link_padding_$index'),
            padding: const EdgeInsets.only(bottom: 12),
            child: _SocialLinkFormRow(
              key: ObjectKey(platformControllers[index]),
              resetNotifier: resetNotifier,
              platformController: platformControllers[index],
              urlController: urlControllers[index],
              socialPlatforms: socialPlatforms,
              onRemove: () => onRemove(index),
            ),
          );
        }),
        UnconstrainedBox(
          alignment: Alignment.centerLeft,
          child: GestureDetector(
            onTap: onAdd,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cs.primary.withValues(alpha: 0.2), width: 0.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Add a Social link",
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.add, size: 18, color: cs.primary),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SocialLinkFormRow extends StatefulWidget {
  final ValueNotifier<int> resetNotifier;
  final TextEditingController platformController;
  final TextEditingController urlController;
  final List<String> socialPlatforms;
  final VoidCallback onRemove;

  const _SocialLinkFormRow({
    super.key,
    required this.resetNotifier,
    required this.platformController,
    required this.urlController,
    required this.socialPlatforms,
    required this.onRemove,
  });

  @override
  State<_SocialLinkFormRow> createState() => _SocialLinkFormRowState();
}

class _SocialLinkFormRowState extends State<_SocialLinkFormRow> {
  final ValueNotifier<bool> _revealNotifier = ValueNotifier(false);

  @override
  void dispose() {
    _revealNotifier.dispose();
    super.dispose();
  }

  Future<bool> _confirmDelete() async {
    final confirmed = await AppAlertDialog.show(
      context: context,
      title: 'Delete Social Link',
      content: 'Are you sure you want to delete this social link?',
      confirmText: 'Delete',
      cancelText: 'Cancel',
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SwipeActionWidget(
      revealNotifier: _revealNotifier,
      resetNotifier: widget.resetNotifier,
      onDelete: () async {
        final confirmed = await _confirmDelete();
        if (confirmed) widget.onRemove();
        return confirmed;
      },
      child: ListenableBuilder(
        listenable: _revealNotifier,
        builder: (context, _) {
          final isRevealed = _revealNotifier.value;
          final borderRadius = isRevealed
              ? const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                )
              : BorderRadius.circular(14);

          return Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: borderRadius,
            ),
            clipBehavior: Clip.antiAlias,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 50,
                    child: TextFormField(
                      controller: widget.urlController,
                      style: TextStyle(fontSize: 14, color: cs.onSurface),
                      decoration: InputDecoration(
                        hintText: "Paste your Profile Link",
                        hintStyle: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.5),
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                        filled: true,
                        fillColor: Colors.transparent,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: cs.outlineVariant, width: 1),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: cs.primary, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 50,
                    child: DropdownButtonFormField<String>(
                      initialValue: widget.socialPlatforms.contains(
                        widget.platformController.text.trim(),
                      )
                          ? widget.platformController.text.trim()
                          : null,
                      isExpanded: true,
                      hint: Text(
                        "Platform",
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.5),
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      items: widget.socialPlatforms.map((platform) {
                        return DropdownMenuItem<String>(
                          value: platform,
                          child: Text(
                            platform,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 14, color: cs.onSurface),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) widget.platformController.text = value;
                      },
                      style: TextStyle(fontSize: 14, color: cs.onSurface),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.transparent,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: isRevealed
                              ? const BorderRadius.only(
                                  topLeft: Radius.circular(14),
                                  bottomLeft: Radius.circular(14),
                                )
                              : BorderRadius.circular(14),
                          borderSide: BorderSide(color: cs.outlineVariant, width: 1),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: isRevealed
                              ? const BorderRadius.only(
                                  topLeft: Radius.circular(14),
                                  bottomLeft: Radius.circular(14),
                                )
                              : BorderRadius.circular(14),
                          borderSide: BorderSide(color: cs.primary, width: 1.5),
                        ),
                      ),
                      icon: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: cs.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
