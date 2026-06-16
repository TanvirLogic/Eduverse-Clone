class CourseFeedMentor {
  final int id;
  final String name;
  final String? avatarUrl;

  const CourseFeedMentor({
    required this.id,
    required this.name,
    this.avatarUrl,
  });

  factory CourseFeedMentor.fromJson(Map<String, dynamic> json) {
    return CourseFeedMentor(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      name: json['name'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String?,
    );
  }
}

class CourseFeedCount {
  final int enrollments;

  const CourseFeedCount({required this.enrollments});

  factory CourseFeedCount.fromJson(Map<String, dynamic> json) {
    return CourseFeedCount(
      enrollments: json['enrollments'] is int
          ? json['enrollments']
          : int.tryParse(json['enrollments']?.toString() ?? '') ?? 0,
    );
  }
}

class CourseFeedModel {
  final int id;
  final String title;
  final String shortDescription;
  final String thumbnailUrl;
  final String level;
  final String type;
  final int price;
  final String language;
  final String updatedAt;
  final CourseFeedMentor mentor;
  final CourseFeedCount count;

  const CourseFeedModel({
    required this.id,
    required this.title,
    required this.shortDescription,
    required this.thumbnailUrl,
    required this.level,
    required this.type,
    required this.price,
    required this.language,
    required this.updatedAt,
    required this.mentor,
    required this.count,
  });

  factory CourseFeedModel.fromJson(Map<String, dynamic> json) {
    return CourseFeedModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      title: json['title'] as String? ?? '',
      shortDescription: json['shortDescription'] as String? ?? '',
      thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
      level: json['level'] as String? ?? '',
      type: json['type'] as String? ?? '',
      price: json['price'] is int
          ? json['price'] as int
          : int.tryParse(json['price']?.toString() ?? '') ?? 0,
      language: json['language'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
      mentor: json['mentor'] != null
          ? CourseFeedMentor.fromJson(json['mentor'] as Map<String, dynamic>)
          : const CourseFeedMentor(id: 0, name: ''),
      count: json['_count'] != null
          ? CourseFeedCount.fromJson(json['_count'] as Map<String, dynamic>)
          : const CourseFeedCount(enrollments: 0),
    );
  }
}
