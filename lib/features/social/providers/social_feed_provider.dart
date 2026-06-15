import 'package:edtech/app/setup_network_caller.dart';
import 'package:edtech/app/urls.dart';
import 'package:edtech/features/social/data/feed_course_model.dart';
import 'package:flutter/foundation.dart';

class SocialFeedProvider extends ChangeNotifier {
  List<FeedCourseModel> _courses = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _errorMessage;
  int _page = 1;
  bool _hasNextPage = true;

  List<FeedCourseModel> get courses => _courses;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  String? get errorMessage => _errorMessage;
  bool get hasNextPage => _hasNextPage;

  Future<void> fetchFeed() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await getNetworkCaller().getRequest(
        url: Urls.socialFeedUrl,
      );

      if (response.isSuccess) {
        final data = response.responseData['data'];
        final courseList = (data['courses'] as List?) ?? [];
        _courses = courseList
            .map((e) => FeedCourseModel.fromJson(e as Map<String, dynamic>))
            .toList();
        _hasNextPage = data['hasNextPage'] as bool? ?? false;
        _page = 1;
      } else {
        _errorMessage = response.errorMessage ?? 'Failed to load feed';
      }
    } catch (e) {
      _errorMessage = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasNextPage) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final nextPage = _page + 1;
      final response = await getNetworkCaller().getRequest(
        url: '${Urls.socialFeedUrl}?page=$nextPage',
      );

      if (response.isSuccess) {
        final data = response.responseData['data'];
        final courseList = (data['courses'] as List?) ?? [];
        final newCourses = courseList
            .map((e) => FeedCourseModel.fromJson(e as Map<String, dynamic>))
            .toList();
        _courses.addAll(newCourses);
        _hasNextPage = data['hasNextPage'] as bool? ?? false;
        _page = nextPage;
      }
    } catch (_) {}

    _isLoadingMore = false;
    notifyListeners();
  }

  Future<void> refresh() async {
    _page = 1;
    await fetchFeed();
  }
}
