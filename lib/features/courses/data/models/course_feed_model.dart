class CourseFeedModel {
  final String id;
  final String title;
  final String shortDescription;
  final String thumbnailUrl;
  final String level;
  final String type;
  final int price;
  final String status;
  final String createdAt;

  const CourseFeedModel({
    required this.id,
    required this.title,
    required this.shortDescription,
    required this.thumbnailUrl,
    required this.level,
    required this.type,
    required this.price,
    required this.status,
    required this.createdAt,
  });

  factory CourseFeedModel.fromJson(Map<String, dynamic> json) {
    return CourseFeedModel(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      shortDescription: json['shortDescription'] as String? ?? '',
      thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
      level: json['level'] as String? ?? '',
      type: json['type'] as String? ?? '',
      price: json['price'] is int
          ? json['price'] as int
          : int.tryParse(json['price']?.toString() ?? '') ?? 0,
      status: json['status'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}
