import 'package:edtech/app/app_colors.dart';
import 'package:edtech/features/social/data/feed_course_model.dart';
import 'package:edtech/features/social/providers/social_feed_provider.dart';
import 'package:edtech/global/core/constants/images/images.dart';
import 'package:edtech/global/core/constants/sizes.dart';
import 'package:edtech/global/core/widgets/auth_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';

class SocialPage extends StatefulWidget {
  const SocialPage({super.key});
  static const String name = '/social';

  @override
  State<SocialPage> createState() => _SocialPageState();
}

class _SocialPageState extends State<SocialPage> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  String _currentQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _currentQuery = _searchController.text.trim());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SocialFeedProvider>().fetchFeed();
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<SocialFeedProvider>().loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final isSearchActive = _currentQuery.isNotEmpty;

    return Consumer<SocialFeedProvider>(
      builder: (context, provider, _) {
        return RefreshIndicator(
          onRefresh: provider.refresh,
          child: SingleChildScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(
              left: AppSizes.horizontalPadding,
              right: AppSizes.horizontalPadding,
              top: 8,
              bottom: 24,
            ),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Image.asset(Images.eduverseP, width: 113, height: 32),
                      SvgPicture.asset(Images.notificationIcon),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: isSearchActive
                          ? 'Code with Mosh'
                          : 'Search Videos or Content...',
                      prefixIcon: Icon(Icons.search,
                          color: cs.onSurface.withValues(alpha: 0.6)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      filled: true,
                      fillColor:
                          isDark ? cs.surfaceContainerHighest : Colors.white,
                      enabledBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppSizes.radiusXl),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppSizes.radiusXl),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (!isSearchActive)
                    _buildFeed(provider, cs, isDark)
                  else
                    _buildSearchResults(cs, isDark),
                  if (provider.isLoadingMore)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFeed(SocialFeedProvider provider, ColorScheme cs, bool isDark) {
    if (provider.isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.only(top: 80),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (provider.errorMessage != null && provider.courses.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 80),
          child: Column(
            children: [
              Icon(Icons.error_outline, size: 48, color: cs.error),
              const SizedBox(height: 16),
              Text(provider.errorMessage!,
                  style: TextStyle(color: cs.error)),
              const SizedBox(height: 16),
              AuthButton(text: 'Retry', onPressed: provider.refresh),
            ],
          ),
        ),
      );
    }

    if (provider.courses.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.only(top: 80),
          child: Text('No courses in feed yet'),
        ),
      );
    }

    return Column(
      children: [
        for (final course in provider.courses) ...[
          _VideoFeedCard(course: course, cs: cs, isDark: isDark),
          const SizedBox(height: 16),
        ],
        _PromoBanner(cs: cs, isDark: isDark),
      ],
    );
  }

  Widget _buildSearchResults(ColorScheme cs, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Search Result for "$_currentQuery"',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: cs.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 16),
        _CreatorCard(
          name: 'Code with Mosh',
          title: 'Senior Software Engineer',
          cs: cs,
          isDark: isDark,
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _VideoFeedCard extends StatelessWidget {
  final FeedCourseModel course;
  final ColorScheme cs;
  final bool isDark;

  const _VideoFeedCard({
    required this.course,
    required this.cs,
    required this.isDark,
  });

  String _timeAgo(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      final diff = DateTime.now().difference(date);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${diff.inDays ~/ 7}w ago';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainerLow : Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            child: AspectRatio(
              aspectRatio: 1.75,
              child: Stack(
                children: [
                  if (course.thumbnailUrl.isNotEmpty)
                    Image.network(
                      course.thumbnailUrl,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          Container(color: cs.surfaceContainerHighest),
                      loadingBuilder: (_, child, progress) =>
                          progress == null
                              ? child
                              : Container(
                                  color: cs.surfaceContainerHighest),
                    )
                  else
                    Container(color: cs.surfaceContainerHighest),
                  Center(
                    child: CircleAvatar(
                      radius: 26,
                      backgroundColor: Colors.black54,
                      child: Icon(Icons.play_arrow_rounded,
                          color: Colors.white, size: 32),
                    ),
                  ),
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.access_time,
                              color: Colors.white, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            _timeAgo(course.createdAt),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: cs.outlineVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        height: 1.3,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          course.shortDescription.isNotEmpty
                              ? course.shortDescription
                              : course.level,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: cs.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                        const Spacer(),
                        if (course.type == 'PAID')
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: cs.outlineVariant,
                              borderRadius:
                                  BorderRadius.circular(AppSizes.radiusSm),
                            ),
                            child: Text(
                              '\$${course.price}',
                              style: TextStyle(
                                fontSize: 11,
                                color: cs.onSurface.withValues(alpha: 0.6),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.reply_rounded,
                  color: cs.onSurface.withValues(alpha: 0.6), size: 22),
            ],
          ),
        ],
      ),
    );
  }
}

class _CreatorCard extends StatelessWidget {
  final String name;
  final String title;
  final ColorScheme cs;
  final bool isDark;

  const _CreatorCard({
    required this.name,
    required this.title,
    required this.cs,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainerLow : Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg2),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: cs.outlineVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.6),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 36,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(96, 36),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                textStyle:
                    TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              child: const Text('Visit Profile'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PromoBanner extends StatelessWidget {
  final ColorScheme cs;
  final bool isDark;

  const _PromoBanner({required this.cs, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 343,
      height: 122,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.themeColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppSizes.radiusLg2),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.themeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Ad',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.themeColor),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Upgrade Your Skills,\nAdvance Your Career',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.themeColor.withValues(alpha: 0.8),
                      height: 1.2,
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    height: 28,
                    child: AuthButton(
                      text: 'Explore',
                      height: 28,
                      borderRadius: 8,
                      onPressed: () {},
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 4,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.themeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                ),
                child: Icon(Icons.laptop_chromebook_rounded,
                    color: AppColors.themeColor.withValues(alpha: 0.4),
                    size: 40),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
