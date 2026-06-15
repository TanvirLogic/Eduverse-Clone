import 'package:edtech/features/manage_module/data/manage_module_models.dart';
import 'package:flutter/material.dart';
import 'package:edtech/app/urls.dart';
import 'package:edtech/app/setup_network_caller.dart';
import 'package:edtech/global/core/services/toast_service.dart';

class ManageModuleProvider extends ChangeNotifier {
  int _nextModuleId = 1;
  int _nextLessonId = 1;

  final List<CourseModule> _modules = [
    CourseModule(
      id: 1,
      title: "Getting Started with Web Development",
      lessons: [],
      isExpanded: false,
    ),
    CourseModule(
      id: 2,
      title: "Getting Started with Web Development",
      lessons: [],
      isExpanded: false,
    ),
  ];
  bool _hasUnsavedChanges = false;

  List<CourseModule> get modules => _modules;
  bool get hasUnsavedChanges => _hasUnsavedChanges;

  int get nextModuleId => _nextModuleId;
  int get nextLessonId => _nextLessonId;

  void incrementModuleId() => _nextModuleId++;
  void incrementLessonId() => _nextLessonId++;

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

  void saveOrder() {
    final serialized = getSerializedOrder();
    debugPrint('Saving order: $serialized');
    _hasUnsavedChanges = false;
    notifyListeners();
    ToastService.showInfo("Module Managed Succesfully");
  }

  void addLessonToModule(
    int moduleIndex,
    LessonType type, {
    String? customTitle,
  }) {
    _modules[moduleIndex].lessons.add(
      Lesson(
        id: _nextLessonId++,
        title:
            customTitle ??
            (type == LessonType.video
                ? "Setting Up Your Environment"
                : "HTML Fundamentals"),
        duration: "18:20",
        type: type,
      ),
    );
    _hasUnsavedChanges = true;
    notifyListeners();
  }

  void reorderModule(int oldIndex, int newIndex) {
    final module = _modules.removeAt(oldIndex);
    _modules.insert(newIndex, module);
    _hasUnsavedChanges = true;
    notifyListeners();
  }

  void toggleExpand(CourseModule module) {
    for (final m in _modules) {
      if (m != module) m.isExpanded = false;
    }
    module.isExpanded = !module.isExpanded;
    notifyListeners();
  }

  void renameModule(CourseModule module, String newName) {
    module.title = newName;
    _hasUnsavedChanges = true;
    notifyListeners();
  }

  void reorderLesson(
    CourseModule module,
    int oldLessonIndex,
    int newLessonIndex,
  ) {
    if (newLessonIndex > oldLessonIndex) newLessonIndex--;
    final lesson = module.lessons.removeAt(oldLessonIndex);
    module.lessons.insert(newLessonIndex, lesson);
    _hasUnsavedChanges = true;
    notifyListeners();
  }

  Future<bool> addModule(String title) async {
    final response = await getNetworkCaller().postRequest(
      url: Urls.courseModuleUrl,
      body: {'title': title, 'order': _modules.length, 'courseID': 1},
    );
    if (response.isSuccess) {
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
      _hasUnsavedChanges = true;
      notifyListeners();
      ToastService.showSuccess('Module added successfully');
      return true;
    } else {
      ToastService.showError(response.errorMessage ?? 'Failed to add module');
      return false;
    }
  }

  Future<bool> deleteModule(CourseModule module) async {
    final response = await getNetworkCaller().deleteRequest(
      url: Urls.courseModuleUrl,
      body: {'moduleID': module.id},
    );
    if (response.isSuccess) {
      _modules.removeWhere((m) => m.id == module.id);
      _hasUnsavedChanges = true;
      notifyListeners();
      ToastService.showSuccess('Module deleted successfully');
      return true;
    } else {
      ToastService.showError(
        response.errorMessage ?? 'Failed to delete module',
      );
      return false;
    }
  }

  Future<bool> editModule(CourseModule module, String title) async {
    final response = await getNetworkCaller().putRequest(
      url: Urls.courseModuleUrl,
      body: {'moduleID': module.id, 'title': title},
    );
    if (response.isSuccess) {
      module.title = title;
      _hasUnsavedChanges = true;
      notifyListeners();
      ToastService.showSuccess('Module updated successfully');
      return true;
    } else {
      ToastService.showError(
        response.errorMessage ?? 'Failed to update module',
      );
      return false;
    }
  }

  Future<bool> renameLesson(
    CourseModule module,
    int lessonIndex,
    String newName,
  ) async {
    final lesson = module.lessons[lessonIndex];
    final response = await getNetworkCaller().putRequest(
      url: Urls.courseLessonUrl,
      body: {'lessonID': lesson.id, 'title': newName, 'moduleID': module.id},
    );
    if (response.isSuccess) {
      module.lessons[lessonIndex].title = newName;
      _hasUnsavedChanges = true;
      notifyListeners();
      return true;
    } else {
      ToastService.showError(
        response.errorMessage ?? 'Failed to rename lesson',
      );
      return false;
    }
  }

  Future<bool> deleteLesson(CourseModule module, int lessonIndex) async {
    final lesson = module.lessons[lessonIndex];
    final response = await getNetworkCaller().deleteRequest(
      url: Urls.courseLessonUrl,
      body: {'lessonID': lesson.id, 'moduleID': module.id},
    );
    if (response.isSuccess) {
      module.lessons.removeAt(lessonIndex);
      _hasUnsavedChanges = true;
      notifyListeners();
      ToastService.showSuccess('Lesson deleted successfully');
      return true;
    } else {
      ToastService.showError(
        response.errorMessage ?? 'Failed to delete lesson',
      );
      return false;
    }
  }
}
