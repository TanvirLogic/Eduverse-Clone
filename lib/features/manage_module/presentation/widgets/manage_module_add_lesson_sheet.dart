import 'package:flutter/material.dart';
import 'package:edtech/features/manage_module/data/manage_module_models.dart';
import 'package:edtech/features/courses/presentation/widgets/upload_zone.dart';
import 'package:edtech/global/core/widgets/auth_button.dart';

class ManageModuleAddLessonSheet extends StatefulWidget {
  final LessonType lessonType;
  final void Function(String? title) onAddLesson;

  const ManageModuleAddLessonSheet({
    super.key,
    required this.lessonType,
    required this.onAddLesson,
  });

  static Future<void> show(
    BuildContext context, {
    required LessonType lessonType,
    required void Function(String? title) onAddLesson,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ManageModuleAddLessonSheet(
        lessonType: lessonType,
        onAddLesson: onAddLesson,
      ),
    );
  }

  @override
  State<ManageModuleAddLessonSheet> createState() =>
      _ManageModuleAddLessonSheetState();
}

class _ManageModuleAddLessonSheetState
    extends State<ManageModuleAddLessonSheet> {
  final _titleController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.lessonType == LessonType.video;
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
          Text(
            isVideo ? 'Upload Video' : 'Upload Resource',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w600, color: cs.onSurface),
          ),
          const SizedBox(height: 20),
          UploadZone(
            cs: cs,
            isDark: isDark,
            label: isVideo ? 'Upload Video File' : 'Upload Resource',
            iconData:
                isVideo ? Icons.cloud_upload_outlined : Icons.description_outlined,
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Title',
                  style: TextStyle(
                      fontSize: 16,
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
            style: TextStyle(color: cs.onSurface),
            decoration: InputDecoration(
              hintText:
                  isVideo ? 'Enter your video title' : 'Enter your resource title',
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
            text: isVideo ? 'Upload Video' : 'Upload Resource',
            borderRadius: 15,
            onPressed: () {
              widget.onAddLesson(
                _titleController.text.trim().isEmpty
                    ? null
                    : _titleController.text.trim(),
              );
              Navigator.of(context).pop();
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
