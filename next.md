# Eduverse — Next Phase Development Plan

> **Follow the patterns from `project.md` (Crafty Bay) exactly.** Same architecture, same naming, same style. This doc defines what to build next and how.

---

## 1. Architecture (Mirror Crafty Bay Exactly)

```
lib/
├── main.dart
├── app/                          # App-level config (same as Crafty Bay)
│   ├── app.dart                  # MultiProvider root
│   ├── app_routes.dart           # onGenerateRoute (all routes here)
│   ├── app_colors.dart           # Color constants
│   ├── app_theme.dart            # ThemeData light + dark
│   ├── urls.dart                 # All API endpoint builders
│   ├── setup_network_caller.dart # getNetworkCaller() factory
│   └── providers/
│       └── theme_provider.dart
│
├── global/core/                  # Shared infra (already exists)
│   ├── services/                 # network_caller, secure_storage, etc.
│   ├── models/                   # network_response.dart
│   ├── config/                   # app_config.dart
│   ├── constants/                # sizes, images
│   └── widgets/                  # reusable widgets
│
├── features/                     # Feature-first (exact Crafty Bay structure)
│   ├── auth/                     # 🔐 Mostly built
│   │   ├── data/
│   │   │   ├── entities/
│   │   │   ├── models/
│   │   │   └── services/
│   │   ├── providers/            # ChangeNotifier pattern
│   │   └── presentation/
│   │       ├── screens/
│   │       └── widgets/
│   │
│   ├── courses/                  # 📚 Next priority
│   │   ├── data/
│   │   │   ├── entities/         # Already built
│   │   │   └── models/           # Already built
│   │   ├── providers/            # 🔴 NEED API INTEGRATION
│   │   └── presentation/
│   │       ├── screens/
│   │       └── widgets/
│   │
│   ├── profile/                  # 👤 Mostly built
│   │   ├── student/
│   │   ├── mentor/
│   │   ├── avatar/
│   │   └── edit/
│   │
│   ├── hub/                      # ⚙️ Settings
│   │   ├── providers/
│   │   └── presentation/
│   │
│   ├── home/                     # 🏠 Main nav shell
│   │
│   ├── social/                   # 📱 Social feed
│   │
│   └── notifications/            # 🔔 Notifications
│
└── l10n/                         # 🌐 Localization (future)
```

---

## 2. Coding Rules (Copy from Crafty Bay)

### 2.1 Provider Pattern (EXACT)
```dart
// Import ONLY foundation.dart (never material.dart)
import 'package:flutter/foundation.dart';

class SomeProvider extends ChangeNotifier {
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<SomeModel> _items = [];
  List<SomeModel> get items => _items;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<bool> fetchData() async {
    bool isSuccess = false;
    _isLoading = true;
    notifyListeners();

    final response = await getNetworkCaller().getRequest(url: Urls.someUrl);

    if (response.isSuccess) {
      List<SomeModel> list = [];
      for (Map<String, dynamic> json in response.responseData['data']['results']) {
        list.add(SomeModel.fromJson(json));
      }
      _items = list;
      _errorMessage = null;
      isSuccess = true;
    } else {
      _errorMessage = response.errorMessage;
    }

    _isLoading = false;
    notifyListeners();
    return isSuccess;
  }
}
```

### 2.2 Screen Pattern (EXACT)
```dart
class SomeScreen extends StatefulWidget {
  static const String name = '/some-screen';  // Static route name
  const SomeScreen({super.key});
  @override
  State<SomeScreen> createState() => _SomeScreenState();
}

class _SomeScreenState extends State<SomeScreen> {
  final TextEditingController _controller = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final SomeProvider _provider = SomeProvider();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: ChangeNotifierProvider(
        create: (_) => _provider,
        child: Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Consumer<SomeProvider>(
                  builder: (context, provider, _) => /* UI */,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
```

### 2.3 Model Pattern (EXACT)
```dart
// Entity: pure Dart, no serialization
class SomeEntity {
  final String id;
  final String title;
  const SomeEntity({required this.id, required this.title});
}

// Model: extends entity, adds fromJson/toJson
class SomeModel extends SomeEntity {
  const SomeModel({required super.id, required super.title});

  factory SomeModel.fromJson(Map<String, dynamic> json) {
    return SomeModel(
      id: json['_id'],
      title: json['title'],
    );
  }

  Map<String, dynamic> toJson() => {'_id': id, 'title': title};
}
```

### 2.4 URL Pattern (EXACT)
```dart
class Urls {
  static const String _baseUrl = 'https://api.eduverseapp.com/api/v1';

  static const String someEndpoint = '$_baseUrl/some/path';
  static String parameterizedEndpoint(String id) => '$_baseUrl/items/$id';
  static String paginatedEndpoint(int page, int limit) =>
      '$_baseUrl/items?page=$page&limit=$limit';
}
```

### 2.5 Naming (EXACT)
- **Files**: `snake_case` → `product_details_screen.dart`
- **Classes**: `PascalCase` → `ProductDetailsScreen`
- **Methods**: `camelCase` → `fetchProductList()`
- **Private fields**: `_camelCase` → `_isLoading`
- **Constants**: `camelCase` → `static const takaSign = '৳'`
- **Route names**: `camelCase` → `static const name = '/product-details'`

### 2.6 File Structure per Dart File (EXACT)
```
1. dart: imports (dart:convert, dart:ui)
2. package: imports (flutter, provider, http)
3. package:edtech imports (app/, core/, features/)
   (ordered by proximity: same feature → common → app → core)
```

---

## 3. Priority Build Order

### Phase 1 — Fix Stubbed Features (API Integration)
| # | Feature | What to do |
|---|---------|------------|
| 1 | **Course List** | Create real `CourseListProvider` with pagination from API |
| 2 | **Course Details** | Replace mock data with real API call in `CourseDetailProvider` |
| 3 | **Enrolled Course** | Replace mock data with real API in `EnrolledCourseProvider` |
| 4 | **Social Feed** | Create `SocialFeedProvider` + real API integration |
| 5 | **Notifications** | Create `NotificationProvider` + API integration |

### Phase 2 — Missing Features
| # | Feature | What to do |
|---|---------|------------|
| 6 | **Search** | Implement search API in Courses + Social |
| 7 | **Wishlist / Saved Courses** | New feature: saved courses provider + screen |
| 8 | **Payments** | Payment gateway integration |
| 9 | **Ads API** | Create `AdsProvider` for Ads Manager + Create screens |
| 10 | **Push Notifications** | FCM integration |

### Phase 3 — Polish & Scale
| # | Feature | What to do |
|---|---------|------------|
| 11 | **Pagination** | Ensure all list providers have pagination (like Crafty Bay's `CategoryListProvider`) |
| 12 | **Pull-to-refresh** | Add `RefreshIndicator` to all list screens |
| 13 | **Error handling** | Add retry buttons, empty states, offline detection |
| 14 | **Skeleton loading** | Use `ShimmerWidget` from global/core/widgets/ |
| 15 | **Localization** | Add l10n with flutter_localizations |
| 16 | **Testing** | Provider unit tests + widget tests |

---

## 4. Provider Pagination Template (Copy from Crafty Bay)

```dart
class SomeListProvider extends ChangeNotifier {
  final int _pageSize = 30;
  int _currentPageNo = 0;
  int? _lastPageNo;
  bool _initialLoading = false;
  bool _loadingMoreData = false;
  List<SomeModel> _items = [];
  String? _errorMessage;

  bool get initialLoading => _initialLoading;
  bool get loadingMoreData => _loadingMoreData;
  List<SomeModel> get items => _items;
  String? get errorMessage => _errorMessage;

  Future<bool> fetchList() async {
    bool isSuccess = false;

    if (_currentPageNo == 0) {
      _items.clear();
      _initialLoading = true;
    } else if (_currentPageNo < (_lastPageNo ?? 1)) {
      _loadingMoreData = true;
    } else {
      return false;
    }
    notifyListeners();

    _currentPageNo++;
    final response = await getNetworkCaller().getRequest(
      url: Urls.somePaginatedUrl(_pageSize, _currentPageNo),
    );

    if (response.isSuccess) {
      _lastPageNo ??= response.responseData['data']['last_page'];
      List<SomeModel> list = [];
      for (Map<String, dynamic> json in response.responseData['data']['results']) {
        list.add(SomeModel.fromJson(json));
      }
      _items.addAll(list);
      _errorMessage = null;
      isSuccess = true;
    } else {
      _errorMessage = response.errorMessage;
    }

    if (_initialLoading) _initialLoading = false;
    else _loadingMoreData = false;
    notifyListeners();
    return isSuccess;
  }

  Future<void> loadInitial() async {
    _currentPageNo = 0;
    _lastPageNo = null;
    await fetchList();
  }
}
```

---

## 5. Screen Scroll Pagination Template (Copy from Crafty Bay)

```dart
class _SomeListScreenState extends State<SomeListScreen> {
  final ScrollController _scrollController = ScrollController();
  final SomeListProvider _provider = SomeListProvider();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _provider.fetchList();
  }

  void _onScroll() {
    if (_scrollController.position.extentBefore < 300) {
      _provider.fetchList();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
```

---

## 6. How to Add a New Feature (Step-by-Step)

```
Step 1: Create data entity    → features/<feature>/data/entities/<entity>.dart
Step 2: Create data model     → features/<feature>/data/models/<model>.dart (extends entity)
Step 3: Create provider       → features/<feature>/providers/<provider>.dart (ChangeNotifier)
Step 4: Create screen         → features/<feature>/presentation/screens/<screen>.dart
Step 5: Create widgets        → features/<feature>/presentation/widgets/<widget>.dart
Step 6: Register route        → app/app_routes.dart (add if/else for setting.name)
Step 7: Add API URL           → app/urls.dart (add constant or method)
Step 8: Register provider     → app/app.dart (if global, add to MultiProvider)
```

---

## 7. Current Build Status

| Feature | Provider API | Screen UI | Pagination | Status |
|---------|:-----------:|:---------:|:----------:|--------|
| Auth (Sign In) | ✅ | ✅ | N/A | **Done** |
| Auth (Sign Up) | ✅ | ✅ | N/A | **Done** |
| Auth (OTP) | ✅ | ✅ | N/A | **Done** |
| Auth (Password Reset) | ✅ | ✅ | N/A | **Done** |
| Google Sign-In | ✅ | ✅ | N/A | **Done** |
| Course List | ❌ Stub | ✅ | ❌ | **Needs API** |
| Course Details | ❌ Stub | ✅ | N/A | **Needs API** |
| Enrolled Course | ❌ Stub | ✅ | ❌ | **Needs API** |
| Course Upload | ✅ | ✅ | N/A | **Done** |
| Manage Module | ✅ | ✅ | N/A | **Done** |
| Video Post | ✅ | ✅ | N/A | **Done** |
| Student Profile | ✅ | ✅ | N/A | **Done** |
| Mentor Profile | ✅ | ✅ | N/A | **Done** |
| Profile Edit | ✅ | ✅ | N/A | **Done** |
| Avatar/Cover Upload | ✅ | ✅ | N/A | **Done** |
| Hub Settings | ✅ | ✅ | N/A | **Done** |
| Password & Security | ✅ | ✅ | N/A | **Done** |
| Mentor Dashboard | ❌ Stub | ✅ | N/A | **Needs API** |
| Payments & Revenue | ❌ | ✅ | N/A | **Needs API** |
| Ads Manager | ❌ | ✅ | N/A | **Needs API** |
| Ads Create | ❌ | ✅ | N/A | **Needs API** |
| Social Feed | ❌ Stub | ❌ Stub | ❌ | **Needs Build** |
| Notifications | ❌ Stub | ❌ Stub | ❌ | **Needs Build** |
| Search | ❌ | ❌ | ❌ | **Needs Build** |
| Payments Gateway | ❌ | ❌ | ❌ | **Needs Build** |
| Push Notifications | ❌ | ❌ | N/A | **Needs Build** |

---

> **Pro Tip:** Always check the Crafty Bay `project.md` for exact pattern reference before building any new file. Every naming convention, folder structure, and code style decision should match.
