import 'package:edtech/features/courses/data/entities/course_entity.dart';
import 'package:edtech/features/courses/data/entities/module_entity.dart';
import 'package:edtech/features/courses/data/entities/review_entity.dart';

class CourseModel extends CourseEntity {
  const CourseModel({
    required super.id,
    required super.title,
    required super.description,
    required super.instructorName,
    required super.instructorTitle,
    super.level,
    super.language,
    super.price,
    super.rating,
    super.videosCount,
    super.resourcesCount,
    super.thumbnailUrl,
    super.modules,
    super.reviews,
  });

  factory CourseModel.fromJson(Map<String, dynamic> json) {
    final modules = (json['modules'] as List<dynamic>?)
            ?.map((e) => ModuleEntity.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    final reviews = (json['reviews'] as List<dynamic>?)
            ?.map((e) => ReviewEntity.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return CourseModel(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      instructorName: json['instructor_name'] ?? json['instructorName'] ?? '',
      instructorTitle: json['instructor_title'] ?? json['instructorTitle'] ?? '',
      level: json['level'] ?? '',
      language: json['language'] ?? '',
      price: (json['price'] ?? 0) is double
          ? json['price'] as double
          : double.tryParse(json['price']?.toString() ?? '') ?? 0,
      rating: (json['rating'] ?? 0) is double
          ? json['rating'] as double
          : double.tryParse(json['rating']?.toString() ?? '') ?? 0,
      videosCount: (json['videos_count'] ?? json['videosCount'] ?? 0) is int
          ? json['videos_count'] ?? json['videosCount'] ?? 0
          : int.tryParse(json['videos_count']?.toString() ?? json['videosCount']?.toString() ?? '') ?? 0,
      resourcesCount: (json['resources_count'] ?? json['resourcesCount'] ?? 0) is int
          ? json['resources_count'] ?? json['resourcesCount'] ?? 0
          : int.tryParse(json['resources_count']?.toString() ?? json['resourcesCount']?.toString() ?? '') ?? 0,
      thumbnailUrl: json['thumbnail_url'] ?? json['thumbnailUrl'] ?? '',
      modules: modules,
      reviews: reviews,
    );
  }
}
