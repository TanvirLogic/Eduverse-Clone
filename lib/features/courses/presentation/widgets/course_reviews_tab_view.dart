import 'package:edtech/app/app_colors.dart';
import 'package:edtech/global/core/constants/sizes.dart';
import 'package:edtech/features/courses/data/entities/review_entity.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class CourseReviewsTabView extends StatelessWidget {
  final List<ReviewEntity> reviews;

  const CourseReviewsTabView({super.key, required this.reviews});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      itemCount: reviews.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final review = reviews[index];
        return ReviewCardItem(
          name: review.name,
          timeAgo: review.timeAgo,
          rating: review.rating,
          comment: review.comment,
          imageUrl: review.imageUrl,
          isDark: isDark,
        );
      },
    );
  }
}

class ReviewCardItem extends StatelessWidget {
  final String name;
  final String timeAgo;
  final int rating;
  final String comment;
  final String imageUrl;
  final bool isDark;

  const ReviewCardItem({
    super.key,
    required this.name,
    required this.timeAgo,
    required this.rating,
    required this.comment,
    required this.imageUrl,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainerLow : Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: cs.outlineVariant,
                backgroundImage: CachedNetworkImageProvider(imageUrl),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: List.generate(5, (starIndex) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 2.0),
                          child: Icon(
                            Icons.star_rounded,
                            size: 16,
                            color: starIndex < rating
                                ? const Color(0xFFFBBF24)
                                : cs.outlineVariant,
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
              Text(
                timeAgo,
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.5),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            comment,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.7),
              fontSize: 13.5,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
