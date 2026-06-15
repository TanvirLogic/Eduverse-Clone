import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:edtech/app/app_colors.dart';
import 'package:edtech/app/urls.dart';
import 'package:edtech/app/setup_network_caller.dart';
import 'package:edtech/global/core/constants/images/images.dart';
import 'package:edtech/global/core/constants/sizes.dart';
import 'package:edtech/global/core/services/toast_service.dart';
import 'package:edtech/global/core/widgets/app_back_button.dart';
import 'package:edtech/global/core/widgets/auth_button.dart';
import 'package:edtech/global/core/widgets/swipe_action_widget.dart';
import 'package:edtech/features/courses/presentation/models/manage_module_models.dart';
import 'package:edtech/features/courses/presentation/widgets/module_card.dart';
import 'package:edtech/features/courses/presentation/widgets/upload_zone.dart';
import 'package:edtech/features/courses/providers/course_upload_provider.dart';

int _nextModuleId = 1;
int _nextLessonId = 1;

class ManageModuleScreen extends StatefulWidget {
  const ManageModuleScreen({super.key});
  static const String name = '/manage-module';

  @override
  State<ManageModuleScreen> createState() => _ManageModuleScreenState();
}

class _ManageModuleScreenState extends State<ManageModuleScreen> {
  final List<CourseModule> _modules = [
    CourseModule(
      id: _nextModuleId++,
      title: "Getting Started with Web Development",
      lessons: [],
      isExpanded: false,
    ),
  ];
  bool _hasUnsavedChanges = false;
  final ValueNotifier<int> _resetNotifier = ValueNotifier(0);
  final Map<int, ValueNotifier<bool>> _revealNotifiers = {};

  ValueNotifier<bool> _revealNotifier(int moduleId) {
    return _revealNotifiers.putIfAbsent(moduleId, () => ValueNotifier(false));
  }

  List<Map<String, dynamic>> getSerializedOrder() {
    return _modules.asMap().entries.map((entry) {
      final module = entry.value;
      return {
        'module_id': module.id,
        'sort_order': entry.key,
        'title': module.title,
        'lessons': module.lessons.asMap().entries.map((le) {
          return {
            'lesson_id': le.value.id,
            'sort_order': le.key,
            'title': le.value.title,
            'type': le.value.type.name,
          };
        }).toList(),
      };
    }).toList();
  }

  void _saveOrder() {
    final serialized = getSerializedOrder();
    debugPrint('Saving order: $serialized');
    setState(() => _hasUnsavedChanges = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Module order saved')));
  }

  void _showRenameDialog(String currentName, ValueChanged<String> onSaved) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Enter new name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                onSaved(newName);
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _addLessonToModule(int moduleIndex, LessonType type, {String? customTitle}) {
    setState(() {
      _modules[moduleIndex].lessons.add(
        Lesson(
          id: _nextLessonId++,
          title: customTitle ?? (type == LessonType.video ? "Setting Up Your Environment" : "HTML Fundamentals"),
          duration: "18:20",
          type: type,
        ),
      );
    });
  }

  void _showAddLessonBottomSheet(int moduleIndex, LessonType type) {
    final isVideo = type == LessonType.video;
    final titleController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
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
                  Text(isVideo ? 'Upload Video' : 'Upload Resource', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: cs.onSurface)),
                  const SizedBox(height: 20),
                  UploadZone(
                    cs: cs,
                    isDark: isDark,
                    label: isVideo ? 'Upload Video File' : 'Upload Resource',
                    iconData: isVideo ? Icons.cloud_upload_outlined : Icons.description_outlined,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Title', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: cs.onSurface)),
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: titleController,
                        builder: (_, val, __) => Text(
                          '${val.text.length}/60',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: cs.onSurface.withValues(alpha: 0.6)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: titleController,
                    maxLines: 4,
                    maxLength: 60,
                    buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                    style: TextStyle(color: cs.onSurface),
                    decoration: InputDecoration(
                      hintText: isVideo ? 'Enter your video title' : 'Enter your resource title',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                      _addLessonToModule(moduleIndex, type, customTitle: titleController.text.trim().isEmpty ? null : titleController.text.trim());
                      Navigator.of(ctx).pop();
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showEditCourseBottomSheet() {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final titleCtrl = TextEditingController();
    final shortDescCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final reqCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    String language = 'English';
    String level = 'BEGINNER';
    String type = 'FREE';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
                  Text('Edit Course', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: cs.onSurface)),
                  const SizedBox(height: 20),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildSheetLabel('Title', cs),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: titleCtrl,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                            style: TextStyle(color: cs.onSurface),
                            decoration: _sheetInputDeco(cs, 'Enter your course title'),
                          ),
                          const SizedBox(height: 16),
                          _buildSheetLabel('Short Description', cs),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: shortDescCtrl,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                            style: TextStyle(color: cs.onSurface),
                            decoration: _sheetInputDeco(cs, 'Enter short description'),
                          ),
                          const SizedBox(height: 16),
                          _buildSheetLabel('Description', cs),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: descCtrl,
                            maxLines: 4,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                            style: TextStyle(color: cs.onSurface),
                            decoration: _sheetInputDeco(cs, 'Enter your description'),
                          ),
                          const SizedBox(height: 16),
                          _buildSheetLabel('Requirements', cs),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: reqCtrl,
                            maxLines: 4,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                            style: TextStyle(color: cs.onSurface),
                            decoration: _sheetInputDeco(cs, 'Enter your requirements'),
                          ),
                          const SizedBox(height: 16),
                          _buildSheetLabel('Language', cs),
                          const SizedBox(height: 8),
                          _sheetDropdown(cs, language,
                            ['English', 'Bangla', 'Spanish', 'Arabic', 'Hindi'],
                            (val) { if (val != null) setSheetState(() => language = val); },
                          ),
                          const SizedBox(height: 16),
                          _buildSheetLabel('Thumbnail', cs),
                          const SizedBox(height: 8),
                          Consumer<CourseUploadProvider>(
                            builder: (context, provider, _) {
                              final name = provider.thumbnailFile?.name;
                              return InkWell(
                                onTap: () => provider.pickThumbnail(),
                                borderRadius: BorderRadius.circular(AppSizes.radiusDef),
                                child: Ink(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: isDark ? cs.surfaceContainerHighest : Colors.white,
                                    border: Border.all(
                                      color: isDark ? cs.outlineVariant : AppColors.border,
                                      width: 1,
                                    ),
                                    borderRadius: BorderRadius.circular(AppSizes.radiusDef),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          name ?? 'Upload thumbnail',
                                          style: TextStyle(
                                            color: name != null ? cs.onSurface : cs.onSurface.withValues(alpha: 0.5),
                                            fontSize: 14,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (name != null)
                                        GestureDetector(
                                          onTap: () => provider.clearThumbnail(),
                                          child: Icon(Icons.close, size: 18, color: cs.error),
                                        ),
                                      const SizedBox(width: 8),
                                      Text(
                                        name != null ? 'Change' : 'Choose',
                                        style: TextStyle(color: AppColors.themeColor, fontWeight: FontWeight.w700, fontSize: 14),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          _buildSheetLabel('Intro Video', cs, required: false),
                          const SizedBox(height: 8),
                          Consumer<CourseUploadProvider>(
                            builder: (context, provider, _) {
                              return UploadZone(
                                cs: cs,
                                isDark: isDark,
                                onTap: () => provider.pickVideo(),
                                selectedFileName: provider.videoFile?.name,
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          _buildSheetLabel('Level', cs),
                          const SizedBox(height: 8),
                          _sheetDropdown(cs, level,
                            ['BEGINNER', 'INTERMEDIATE', 'ADVANCED'],
                            (val) { if (val != null) setSheetState(() => level = val); },
                          ),
                          const SizedBox(height: 16),
                          _buildSheetLabel('Type', cs),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(child: _sheetRadioTile(cs, 'FREE', type, isDark, (v) => setSheetState(() => type = v))),
                              const SizedBox(width: 16),
                              Expanded(child: _sheetRadioTile(cs, 'PAID', type, isDark, (v) => setSheetState(() => type = v))),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (type == 'PAID') ...[
                            _buildSheetLabel('Price', cs),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: priceCtrl,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                              style: TextStyle(color: cs.onSurface),
                              decoration: _sheetInputDeco(cs, 'Enter price'),
                            ),
                            const SizedBox(height: 16),
                          ],
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  AuthButton(
                    text: 'Save Changes',
                    borderRadius: 24,
                    onPressed: () {
                      titleCtrl.dispose();
                      shortDescCtrl.dispose();
                      descCtrl.dispose();
                      reqCtrl.dispose();
                      priceCtrl.dispose();
                      Navigator.of(ctx).pop();
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSheetLabel(String text, ColorScheme cs, {bool required = true}) {
    return RichText(
      text: TextSpan(
        text: text,
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: cs.onSurface),
        children: [
          if (required)
            const TextSpan(text: ' *', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  InputDecoration _sheetInputDeco(ColorScheme cs, String hint) {
    final isDark = cs.brightness == Brightness.dark;
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: cs.onSurface.withValues(alpha: 0.5), fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusDef),
        borderSide: BorderSide(color: isDark ? cs.outlineVariant : AppColors.border, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusDef),
        borderSide: BorderSide(color: AppColors.themeColor, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusDef),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusDef),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
      ),
    );
  }

  Widget _sheetDropdown(ColorScheme cs, String value, List<String> items, ValueChanged<String?> onChanged) {
    final isDark = cs.brightness == Brightness.dark;
    return DropdownButtonFormField<String>(
      value: value,
      items: items.map((item) {
        return DropdownMenuItem<String>(value: item, child: Text(item, style: TextStyle(color: cs.onSurface)));
      }).toList(),
      onChanged: onChanged,
      icon: Icon(Icons.keyboard_arrow_down_rounded, color: cs.onSurface.withValues(alpha: 0.5)),
      style: TextStyle(color: cs.onSurface, fontSize: 15, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusDef),
          borderSide: BorderSide(color: isDark ? cs.outlineVariant : AppColors.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusDef),
          borderSide: BorderSide(color: AppColors.themeColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusDef),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusDef),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
        ),
        filled: true,
        fillColor: isDark ? cs.surfaceContainerHighest : Colors.white,
      ),
      dropdownColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
    );
  }

  Widget _sheetRadioTile(ColorScheme cs, String tileType, String currentType, bool isDark, ValueChanged<String> onChanged) {
    final isSelected = currentType == tileType;
    return InkWell(
      onTap: () => onChanged(tileType),
      borderRadius: BorderRadius.circular(AppSizes.radiusDef),
      child: Ink(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isDark ? cs.surfaceContainerHighest : Colors.white,
          borderRadius: BorderRadius.circular(AppSizes.radiusDef),
          border: Border.all(
            color: isDark ? cs.outlineVariant : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? AppColors.themeColor : cs.onSurface.withValues(alpha: 0.5),
              size: 22,
            ),
            const SizedBox(width: 12),
            Text(
              tileType,
              style: TextStyle(
                color: isSelected ? cs.onSurface : cs.onSurface.withValues(alpha: 0.5),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddModuleBottomSheet() {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final titleController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
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
                  Text('Add Module', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: cs.onSurface)),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: titleController,
                    builder: (_, val, _) => Text(
                      '${val.text.length}/60',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: cs.onSurface.withValues(alpha: 0.6)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: titleController,
                maxLines: 4,
                maxLength: 60,
                buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                style: TextStyle(color: cs.onSurface),
                decoration: InputDecoration(
                  hintText: 'Enter module title',
                  hintStyle: TextStyle(color: cs.onSurface.withValues(alpha: 0.5), fontSize: 14),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                onPressed: () async {
                  final title = titleController.text.trim();
                  if (title.isEmpty) return;

                  final response = await getNetworkCaller().postRequest(
                    url: Urls.courseModuleUrl,
                    body: {
                      'title': title,
                      'order': _modules.length,
                      'courseID': 1,
                    },
                  );

                  if (!context.mounted) return;

                  if (response.isSuccess) {
                    _resetNotifier.value++;
                    setState(() {
                      _modules.add(
                        CourseModule(
                          id: _nextModuleId++,
                          title: title,
                          order: _modules.length,
                          courseId: 1,
                          lessons: [],
                          isExpanded: true,
                        ),
                      );
                    });
                    Navigator.of(ctx).pop();
                    ToastService.showSuccess('Module added successfully');
                  } else {
                    ToastService.showError(response.errorMessage ?? 'Failed to add module');
                  }
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showEditModuleBottomSheet(CourseModule module) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final titleController = TextEditingController(text: module.title);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
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
                  Text('Edit Module', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: cs.onSurface)),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: titleController,
                    builder: (_, val, _) => Text(
                      '${val.text.length}/60',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: cs.onSurface.withValues(alpha: 0.6)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: titleController,
                maxLines: 4,
                maxLength: 60,
                buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                autofocus: true,
                style: TextStyle(color: cs.onSurface),
                decoration: InputDecoration(
                  hintText: 'Enter module title',
                  hintStyle: TextStyle(color: cs.onSurface.withValues(alpha: 0.5), fontSize: 14),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                text: 'Save Changes',
                borderRadius: 24,
                onPressed: () async {
                  final title = titleController.text.trim();
                  if (title.isEmpty || title == module.title) {
                    Navigator.of(ctx).pop();
                    return;
                  }

                  final response = await getNetworkCaller().putRequest(
                    url: Urls.courseModuleUrl,
                    body: {
                      'moduleID': module.id,
                      'title': title,
                    },
                  );

                  if (!context.mounted) return;

                  if (response.isSuccess) {
                    _resetNotifier.value++;
                    setState(() {
                      module.title = title;
                      _hasUnsavedChanges = true;
                    });
                    Navigator.of(ctx).pop();
                    ToastService.showSuccess('Module updated successfully');
                  } else {
                    ToastService.showError(response.errorMessage ?? 'Failed to update module');
                  }
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final iconBg = isDark
        ? cs.surfaceContainerHighest
        : const Color(0xFFF5F5F5);

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 100),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderImage(cs, iconBg),
                  _buildCourseMeta(cs),
                  _buildDescriptionSection("Description", cs),
                  _buildDescriptionSection("Requirements", cs),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Divider(
                      color: const Color(0xFFE3E3E4),
                      thickness: 1.0,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      "Swipe left to delete or edit",
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.4),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildModulesList(cs, isDark),
                ],
              ),
            ),
          ),
          Positioned(bottom: 0, left: 0, right: 0, child: _buildBottomBar()),
        ],
      ),
    );
  }

  Widget _buildHeaderImage(ColorScheme cs, Color iconBg) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(
          height: 195,
          width: double.infinity,
          child: CachedNetworkImage(
            imageUrl:
                'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe',
            fit: BoxFit.cover,
          ),
        ),
        Container(
          height: 195,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.15),
                Colors.white.withValues(alpha: 0.0),
                cs.brightness == Brightness.dark
                    ? Theme.of(context).scaffoldBackgroundColor
                    : Colors.white,
              ],
              stops: const [0.0, 0.85, 1.0],
            ),
          ),
        ),
        Positioned(top: 48, left: 12, child: const AppBackButton()),
        Positioned(
          top: 48,
          right: 12,
          child: CircleAvatar(
            backgroundColor: iconBg,
              child: IconButton(
                icon: Padding(
                    padding: const EdgeInsets.all(3),
                    child: SvgPicture.asset(
                      Images.editProfile,
                      width: 20,
                      height: 20,
                      colorFilter: ColorFilter.mode(
                        cs.onSurface,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                onPressed: _showEditCourseBottomSheet,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCourseMeta(ColorScheme cs) {
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
              _buildTag(Images.languageIcon, "Bangla", cs),
              const SizedBox(width: 12),
              _buildTag(Images.bookNoC, "Advanced", cs),
              const SizedBox(width: 12),
              _buildTag(Images.dollar, "Paid", cs),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String assetPath, String label, ColorScheme cs) {
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

  Widget _buildDescriptionSection(String title, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              text:
                  "Passionate educator with over a decade of industry experience. Helping aspiring ",
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurface.withValues(alpha: 0.6),
                height: 1.4,
              ),
              children: [
                TextSpan(
                  text: "See More...",
                  style: TextStyle(
                    color: cs.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModulesList(ColorScheme cs, bool isDark) {
    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _modules.length,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      onReorder: (oldIndex, newIndex) {
        setState(() {
          if (newIndex > oldIndex) newIndex--;
          final module = _modules.removeAt(oldIndex);
          _modules.insert(newIndex, module);
          _hasUnsavedChanges = true;
        });
      },
      proxyDecorator: (child, index, animation) {
        final module = _modules[index];
        return Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isDark ? cs.surfaceContainerLow : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE3E3E4)),
            ),
            child: Text(
              module.title,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: cs.onSurface),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      },
      itemBuilder: (context, index) {
        final module = _modules[index];
        return Padding(
          key: ValueKey('module_${module.id}'),
          padding: const EdgeInsets.only(bottom: 12),
          child: ReorderableDelayedDragStartListener(
            index: index,
            child: SwipeActionWidget(
              revealNotifier: _revealNotifier(module.id),
              editIcon: SvgPicture.asset(
                Images.editProfile,
                width: 20,
                height: 20,
                colorFilter: ColorFilter.mode(cs.primary, BlendMode.srcIn),
              ),
              resetNotifier: _resetNotifier,
              onDelete: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: Text('Delete Module', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: cs.onSurface)),
                    content: Text('Delete "${module.title}"?', style: TextStyle(fontSize: 14, color: cs.onSurface)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: Text('Cancel', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6))),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: Text('Delete', style: TextStyle(color: cs.error)),
                      ),
                    ],
                  ),
                );
                if (confirmed == true && mounted) {
                  final response = await getNetworkCaller().deleteRequest(
                    url: Urls.courseModuleUrl,
                    body: {'moduleID': module.id},
                  );
                  if (!mounted) return false;
                  if (response.isSuccess) {
                    setState(() {
                      _modules.removeAt(index);
                      _hasUnsavedChanges = true;
                    });
                    ToastService.showSuccess('Module deleted successfully');
                    return true;
                  } else {
                    ToastService.showError(response.errorMessage ?? 'Failed to delete module');
                    return false;
                  }
                }
                return false;
              },
              onEdit: () => _showEditModuleBottomSheet(module),
              child: ListenableBuilder(
                listenable: _revealNotifier(module.id),
                builder: (context, _) => ModuleCard(
                  revealed: _revealNotifier(module.id).value,
                  resetNotifier: _resetNotifier,
                  module: module,
                  isDark: isDark,
                  isEditing: false,
                  onToggleExpand: () => setState(() {
                    for (final m in _modules) {
                      if (m != module) m.isExpanded = false;
                    }
                    module.isExpanded = !module.isExpanded;
                  }),
                  onRename: (newName) => setState(() {
                    module.title = newName;
                    _hasUnsavedChanges = true;
                  }),
                  onShowRenameDialog: _showRenameDialog,
                  onAddVideo: () => _showAddLessonBottomSheet(index, LessonType.video),
                  onAddResource: () => _showAddLessonBottomSheet(index, LessonType.resource),
                  onReorderLesson: (oldLessonIndex, newLessonIndex) {
                    setState(() {
                      if (newLessonIndex > oldLessonIndex) newLessonIndex--;
                      final lesson = module.lessons.removeAt(oldLessonIndex);
                      module.lessons.insert(newLessonIndex, lesson);
                      _hasUnsavedChanges = true;
                    });
                  },
                  onRenameLesson: (lessonIndex, newName) async {
                    final lesson = module.lessons[lessonIndex];
                    final response = await getNetworkCaller().putRequest(
                      url: Urls.courseLessonUrl,
                      body: {'lessonID': lesson.id, 'title': newName, 'moduleID': module.id},
                    );
                    if (!context.mounted) return;
                    if (response.isSuccess) {
                      setState(() {
                        module.lessons[lessonIndex].title = newName;
                        _hasUnsavedChanges = true;
                      });
                    } else {
                      ToastService.showError(response.errorMessage ?? 'Failed to rename lesson');
                    }
                  },
                  onDeleteLesson: (lessonIndex) async {
                    final lesson = module.lessons[lessonIndex];
                    final response = await getNetworkCaller().deleteRequest(
                      url: Urls.courseLessonUrl,
                      body: {'lessonID': lesson.id, 'moduleID': module.id},
                    );
                    if (!context.mounted) return false;
                    if (response.isSuccess) {
                      setState(() {
                        module.lessons.removeAt(lessonIndex);
                        _hasUnsavedChanges = true;
                      });
                      ToastService.showSuccess('Lesson deleted successfully');
                      return true;
                    } else {
                      ToastService.showError(response.errorMessage ?? 'Failed to delete lesson');
                      return false;
                    }
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomBar() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
      ),
      child: _hasUnsavedChanges
          ? Row(
              children: [
                Expanded(
                  flex: 3,
                  child: AuthButton(
                    text: "Add Module",
                    height: 50,
                    borderRadius: 24,
                    fontSize: 14,
                    onPressed: _showAddModuleBottomSheet,
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
                      onPressed: () {
                        _resetNotifier.value++;
                        _saveOrder();
                      },
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
              onPressed: _showAddModuleBottomSheet,
            ),
    );
  }
}
