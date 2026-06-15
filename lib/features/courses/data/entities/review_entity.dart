class ReviewEntity {
  final String name;
  final String timeAgo;
  final int rating;
  final String comment;
  final String imageUrl;

  const ReviewEntity({
    required this.name,
    required this.timeAgo,
    required this.rating,
    required this.comment,
    required this.imageUrl,
  });

  factory ReviewEntity.fromJson(Map<String, dynamic> json) {
    return ReviewEntity(
      name: json['name'] ?? '',
      timeAgo: json['time_ago'] ?? json['timeAgo'] ?? '',
      rating: (json['rating'] ?? 0) is int ? json['rating'] as int : int.tryParse(json['rating']?.toString() ?? '') ?? 0,
      comment: json['comment'] ?? '',
      imageUrl: json['image_url'] ?? json['imageUrl'] ?? '',
    );
  }
}
