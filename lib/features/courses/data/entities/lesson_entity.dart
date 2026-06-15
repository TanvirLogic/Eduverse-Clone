class LessonEntity {
  final String title;
  final String duration;
  final bool isLocked;

  const LessonEntity({
    required this.title,
    required this.duration,
    this.isLocked = true,
  });

  factory LessonEntity.fromJson(Map<String, dynamic> json) {
    return LessonEntity(
      title: json['title'] ?? '',
      duration: json['duration'] ?? '',
      isLocked: json['is_locked'] == true || json['isLocked'] == true,
    );
  }
}
