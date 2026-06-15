import 'package:edtech/app/setup_network_caller.dart';
import 'package:edtech/app/urls.dart';
import 'package:edtech/features/courses/data/models/course_feed_model.dart';
import 'package:flutter/foundation.dart';

class CourseFeedProvider extends ChangeNotifier {
  List<CourseFeedModel> _courses = [];
  List<CourseFeedModel> _enrolledCourses = [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _hasNextPage = true;

  List<CourseFeedModel> get courses => _courses;
  List<CourseFeedModel> get enrolledCourses => _enrolledCourses;
  bool get isLoading => _isLoading;
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
            .map((e) => CourseFeedModel.fromJson(e as Map<String, dynamic>))
            .toList();

        final enrolledList = (data['enrolledCourses'] as List?) ?? [];
        _enrolledCourses = enrolledList
            .map((e) => CourseFeedModel.fromJson(e as Map<String, dynamic>))
            .toList();

        _hasNextPage = data['hasNextPage'] as bool? ?? false;
      } else {
        _errorMessage = response.errorMessage ?? 'Failed to load courses';
      }
    } catch (e) {
      _errorMessage = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> refresh() async {
    await fetchFeed();
  }
}
