import 'package:flutter/material.dart';
import 'package:edtech/global/core/widgets/auth_button.dart';

class ManageModuleAddModuleSheet extends StatefulWidget {
  final Future<bool> Function(String title) onAddModule;

  const ManageModuleAddModuleSheet({
    super.key,
    required this.onAddModule,
  });

  static Future<void> show(
    BuildContext context, {
    required Future<bool> Function(String title) onAddModule,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ManageModuleAddModuleSheet(onAddModule: onAddModule),
    );
  }

  @override
  State<ManageModuleAddModuleSheet> createState() =>
      _ManageModuleAddModuleSheetState();
}

class _ManageModuleAddModuleSheetState
    extends State<ManageModuleAddModuleSheet> {
  final _titleController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Add Module',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface)),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _titleController,
                builder: (_, val, _) => Text(
                  '${val.text.length}/60',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _titleController,
            maxLines: 4,
            maxLength: 60,
            buildCounter:
                (_, {required currentLength, required isFocused, maxLength}) =>
                    null,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) =>
                FocusManager.instance.primaryFocus?.unfocus(),
            style: TextStyle(color: cs.onSurface),
            decoration: InputDecoration(
              hintText: 'Enter module title',
              hintStyle:
                  TextStyle(color: cs.onSurface.withValues(alpha: 0.5), fontSize: 14),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide(
                  color: isDark ? cs.outlineVariant : const Color(0xFFEFEFF0),
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide(color: cs.primary, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 20),
          AuthButton(
            text: 'Add Module',
            borderRadius: 24,
            isLoading: _isLoading,
            onPressed: _isLoading
                ? null
                : () async {
                    final title = _titleController.text.trim();
                    if (title.isEmpty) return;
                    setState(() => _isLoading = true);
                    final success = await widget.onAddModule(title);
                    if (!mounted) return;
                    setState(() => _isLoading = false);
                    if (success) {
                      Navigator.of(context).pop();
                    }
                  },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
