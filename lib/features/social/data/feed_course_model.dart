class FeedCourseModel {
  final int id;
  final String title;
  final String shortDescription;
  final String thumbnailUrl;
  final String level;
  final String type;
  final int price;
  final String status;
  final String createdAt;

  const FeedCourseModel({
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

  factory FeedCourseModel.fromJson(Map<String, dynamic> json) {
    return FeedCourseModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      title: json['title'] as String? ?? '',
      shortDescription: json['shortDescription'] as String? ?? '',
      thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
      level: json['level'] as String? ?? '',
      type: json['type'] as String? ?? '',
      price: json['price'] is int ? json['price'] : int.tryParse(json['price']?.toString() ?? '') ?? 0,
      status: json['status'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}
