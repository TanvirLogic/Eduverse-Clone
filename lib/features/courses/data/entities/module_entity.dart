import 'lesson_entity.dart';

class ModuleEntity {
  final String title;
  final String lessonsCount;
  final List<LessonEntity> lessons;

  const ModuleEntity({
    required this.title,
    required this.lessonsCount,
    this.lessons = const [],
  });

  factory ModuleEntity.fromJson(Map<String, dynamic> json) {
    final lessons = (json['lessons'] as List<dynamic>?)
            ?.map((e) => LessonEntity.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return ModuleEntity(
      title: json['title'] ?? '',
      lessonsCount: json['lessons_count']?.toString() ?? json['lessonsCount']?.toString() ?? '${lessons.length} Lessons',
      lessons: lessons,
    );
  }
}
