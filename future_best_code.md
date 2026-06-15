# Eduverse — Future-Proof Architecture Guide

> **Goal:** Scale to millions of users. Every recommendation here solves a real bottleneck identified in the current codebase.
> **Rule of thumb:** If it adds complexity without solving a concrete bottleneck, don't do it.

---

## 1. Project Structure

### Current (mixed)
```
lib/
  app/           — app.dart, routes, theme, colors, urls, config
  global/core/   — services, models, config, constants, widgets
  features/      — auth, courses, profile, hub, notifications, home
    auth/
      data/models, data/entities, data/services, providers, presentation/screens
    courses/
      models, providers, presentation/screens, presentation/widgets
```

### Recommended
```
lib/
  core/                        ← shared infra (no feature knowledge)
    network/                   ← Dio client, interceptors, api_result
    router/                    ← GoRouter config + route guards
    theme/                     ← colors, text styles, theme data
    utils/                     ← validators, formatters, extensions
    widgets/                   ← truly generic widgets (AppButton, etc.)
    services/                  ← secure_storage, logger, toast
    di/                        ← dependency injection setup
  features/
    auth/
      data/
        datasources/           ← remote (API), local (Hive)
        repositories/          ← impl of domain repo interfaces
        models/                ← JSON serializable DTOs
      domain/
        entities/              ← pure Dart objects
        repositories/          ← abstract interfaces
        usecases/              ← single-responsibility business logic
      presentation/
        providers/             ← or notifiers / cubits
        screens/
        widgets/
    courses/                   ← same structure
    profile/                   ← same structure
    ...
  main.dart
```

**Why:** Current `global/core/` mixes network logic with models and widgets. As the project grows, this becomes a dumping ground. The recommended structure enforces strict dependency rules:

```
features/ ← can depend on core/
core/     ← cannot depend on features/
domain/   ← has ZERO dependencies on Flutter/plugins
```

---

## 2. State Management

### Current: `provider` + `ChangeNotifier`
Every provider is a `ChangeNotifier` registered in `app.dart`'s `MultiProvider`. There are **17 providers** already — this will hit 50+ quickly.

### Problems at scale:
1. `ChangeNotifier` calls `notifyListeners()` for **any** state change → rebuilds all consumers
2. No easy way to dispose providers (they live for the entire app lifetime)
3. `context.read<XxxProvider>()` creates tight coupling between widgets and providers
4. No built-in mechanism for:
   - Debouncing search
   - Cancelling in-flight requests
   - Optimistic UI updates
   - Undo/revert state

### Recommendation: Riverpod

```dart
// ——— No MultiProvider, no context.read ———

// Providers are global, lazy, auto-disposed
final signInProvider = StateNotifierProvider<SignInNotifier, AsyncValue<AuthState>>((ref) {
  return SignInNotifier(ref.read(authRepositoryProvider));
});

// Widgets only know about the provider, not the notifier class
class SignInScreen extends ConsumerWidget {
  Widget build(context, ref) {
    final authState = ref.watch(signInProvider);
    return authState.when(
      data: (state) => /* ... */,
      loading: () => const CircularProgressIndicator(),
      error: (e, _) => Text('$e'),
    );
  }
}
```

**Why Riverpod over Provider:**
| Concern | Provider | Riverpod |
|---------|----------|----------|
| Dispose when unused | ❌ Manual | ✅ `autoDispose` |
| Test without widget tree | ❌ Needs `ProviderScope` | ✅ `ProviderContainer` |
| Compile-time safety | ❌ Runtime `ProviderNotFoundException` | ✅ Compile-time |
| Multiple instances | ❌ Hacky | ✅ `.family` modifier |
| Async state | ❌ Manual `isLoading` flags | ✅ `AsyncValue` built-in |

**Alternative: flutter_bloc** — If you prefer events → states pattern (more boilerplate but clearer traceability). Use Riverpod for simpler features, Bloc for complex flows.

---

## 3. Dependency Injection

### Current: Manual instantiation in `app.dart`
```dart
ChangeNotifierProvider(create: (_) => SignInProvider()),
```

### Problem:
- Adding a new dependency means editing `app.dart`
- No scoping — some providers should only exist while a screen is visible
- Testing requires manual mock wiring

### Recommendation: GetIt (service locator) + injectable (code-gen)

```dart
// lib/core/di/injection.dart

import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

final getIt = GetIt.instance;

@InjectableInit()
Future<void> configureDependencies() => getIt.init();

// Usage — auto-registered by @injectable annotation
@injectable
class AuthRepository implements IAuthRepository {
  AuthRepository(this._dio, this._storage);
  // ...
}
```

Or use Riverpod's built-in DI which eliminates the need for a separate DI framework:
```dart
final dioProvider = Provider<Dio>((ref) => Dio(BaseOptions(baseUrl: AppConfig.baseUrl)));
final authRepoProvider = Provider<IAuthRepository>((ref) {
  return AuthRepository(ref.read(dioProvider), ref.read(secureStorageProvider));
});
```

---

## 4. Networking

### Current: `http` package + manual retry in `NetworkCaller`
```dart
final response = await getNetworkCaller().postRequest(url: Urls.signInUrl, body: {...});
```

### Problems at scale:
1. **No connection pooling** — `http` creates a new TCP connection per request
2. **No request cancellation** — navigating away doesn't cancel in-flight requests
3. **No interceptors** — logging, auth header injection, retry are all manual
4. **No response caching** — every request hits the network
5. **Content-Type hardcoded** — multipart uploads require manual workarounds (see `_StreamedProgressRequest`)

### Recommendation: Dio

```dart
// lib/core/network/dio_client.dart

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: AppConfig.baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
    sendTimeout: const Duration(seconds: 60),      // uploads
  ));

  dio.interceptors.addAll([
    AuthInterceptor(ref),                            // injects Bearer token, handles 401 → refresh → retry
    LogInterceptor(requestBody: true, responseBody: true),
    RetryInterceptor(dio: dio, retries: 2),          // retry on 5xx
    CacheInterceptor(dio: dio, cache: ref.read(cacheProvider)),
  ]);

  return dio;
});
```

```dart
// ——— Token refresh interceptor ———
class AuthInterceptor extends Interceptor {
  @override
  void onRequest(options, handler) {
    options.headers['Authorization'] = 'Bearer ${AuthController.accessToken}';
    handler.next(options);
  }

  @override
  void onError(err, handler) async {
    if (err.response?.statusCode == 401) {
      final refreshed = await _refreshToken();
      if (refreshed) {
        err.requestOptions.headers['Authorization'] = 'Bearer ${AuthController.accessToken}';
        final retry = await Dio().fetch(err.requestOptions);
        handler.resolve(retry);
        return;
      }
      AuthController.clearUserData();
      GoRouter.of(NavigationKey.key).go('/login');
    }
    handler.next(err);
  }
}
```

```dart
// ——— Unified API result ———
sealed class ApiResult<T> {
  const ApiResult();
  factory ApiResult.success(T data) = ApiSuccess<T>;
  factory ApiResult.failure(ApiFailure failure) = ApiFailureResult<T>;
}

class ApiFailure {
  final String message;
  final int? statusCode;
  final dynamic rawData;
}
```

---

## 5. API Client Generation

### Current: Hardcoded URL strings in `Urls`
```dart
static const String signInUrl = '$_baseUrl/auth/login';
```

### Problem:
- URLs spread across one file — hard to find, no type safety
- Request/response shapes are not documented in code
- Adding an endpoint means writing boilerplate

### Recommendation: OpenAPI + `kiwi` or `dart_openapi_generator`

1. Define your API in OpenAPI 3.0 spec
2. Generate type-safe clients:
```bash
dart run build_runner build
```

Generated code:
```dart
final response = await api.auth.login(body: LoginRequest(email: e, password: p));
final user = response.data.user; // fully typed
```

This eliminates `Map<String, dynamic>` access, runtime casting, and all the `data['field']` pattern.

---

## 6. Error Handling

### Current: Mixed
- `NetworkCaller` returns `NetworkResponse` with `isSuccess` boolean
- Providers catch and set `_errorMessage` strings
- `ToastService` shows errors with hardcoded "friendly" messages

### Problems:
1. `isSuccess` boolean doesn't tell you **what** failed
2. Error messages mixed with business logic in providers
3. No way to distinguish retryable vs fatal errors
4. No error boundaries for UI crashes

### Recommendation: Sealed class results

```dart
// ——— Domain-level result ———
sealed class Result<T> {
  const Result();
  factory Result.success(T data) = Success<T>;
  factory Result.failure(Failure failure) = FailureResult<T>;
}

class Failure {
  final String userMessage;    // shown to user
  final String? logMessage;    // sent to crash reporter
  final int? statusCode;
  final bool isRetryable;
  final Object? originalError;
}
```

```dart
// ——— Usage in repository ———
class AuthRepositoryImpl implements AuthRepository {
  @override
  Future<Result<UserEntity>> login(String email, String password) async {
    try {
      final response = await _dio.post('/auth/login', data: {...});
      return Result.success(UserEntity.fromJson(response.data['data']));
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        return Result.failure(Failure(
          userMessage: e.response?.data['message'] ?? 'Invalid credentials',
          statusCode: 401,
        ));
      }
      return Result.failure(Failure(
        userMessage: 'Unable to connect. Please try again.',
        logMessage: e.toString(),
        statusCode: e.response?.statusCode,
        isRetryable: e.type != DioExceptionType.badResponse,
      ));
    }
  }
}
```

```dart
// ——— UI handling ———
state.when(
  success: (user) => Navigator.pushNamed(context, '/home'),
  failure: (f) => f.isRetryable
    ? _showRetrySnackbar(f.userMessage)
    : _showError(f.userMessage),
);
```

---

## 7. Offline Support & Caching

### Current: Zero
Every request hits the network. No offline support. No local cache.

### Recommendation: Repository pattern with cache-first strategy

```dart
class CourseRepositoryImpl implements CourseRepository {
  final CourseRemoteDataSource _remote;
  final CourseLocalDataSource _local;
  
  Future<Result<List<CourseEntity>>> getCourses() async {
    // 1. Return cached data immediately (UI shows instantly)
    final cached = await _local.getCourses();
    if (cached != null) return Result.success(cached);
    
    // 2. Fetch from network
    try {
      final courses = await _remote.fetchCourses();
      await _local.cacheCourses(courses);  // Hive/Isar
      return Result.success(courses);
    } catch (e) {
      // 3. If network fails AND we have stale cache, return it
      if (cached != null) return Result.success(cached);
      return Result.failure(Failure(...));
    }
  }
}
```

Use **Isar** (fast, no native deps) or **Drift** (SQLite) for local storage.

### Caching strategy table:

| Data Type | Cache Policy | TTL | Storage |
|-----------|-------------|-----|---------|
| Course list | Cache-first | 5 min | Isar |
| Course detail | Cache-first | 10 min | Isar |
| User profile | Stale-while-revalidate | 1 hour | Isar |
| Auth tokens | Persistent | Until revoked | SecureStorage |
| Video metadata | No cache | — | — |
| Dashboard metrics | Network-first | 2 min | Isar |

---

## 8. Routing

### Current: `onGenerateRoute` with switch-case
```dart
static Route<dynamic> onGenerateRoute(RouteSettings settings) {
  switch (settings.name) {
    case splash: return MaterialPageRoute(builder: (_) => const SplashScreen());
    // 20+ cases...
  }
}
```

### Problem:
- 20+ cases in one function — unmaintainable
- No route guards (auth check, role check)
- No deep linking support
- No transition animations per route
- Parameters are untyped `Map` casts

### Recommendation: GoRouter

```dart
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    navigatorKey: NavigationKey.key,
    initialLocation: '/',
    redirect: (ctx, state) {
      final isLoggedIn = authState.isLoggedIn;
      final isOnAuthPage = state.matchedLocation.startsWith('/login');

      if (!isLoggedIn && !isOnAuthPage) return '/login';
      if (isLoggedIn && isOnAuthPage) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const SignInScreen()),
      GoRoute(
        path: '/courses/:id',
        builder: (_, state) => CourseDetailsScreen(courseId: state.pathParameters['id']!),
      ),
      ShellRoute(
        builder: (_, __, child) => MainShell(child: child),  // persistent bottom nav
        routes: [
          GoRoute(path: '/home', builder: (_, __) => const HomeFeed()),
          GoRoute(path: '/search', builder: (_, __) => const SearchScreen()),
        ],
      ),
      // ...
    ],
  );
});
```

---

## 9. Testing

### Current: Zero tests

### Bar for production:
- Every repository → unit tests (mock Dio)
- Every use case → unit tests (mock repository)
- Every screen → widget tests (pump with overrides)
- Critical flows → integration tests

```dart
// ——— Unit test for AuthRepository ———
void main() {
  late MockDio mockDio;
  late AuthRepository repo;
  
  setUp(() {
    mockDio = MockDio();
    repo = AuthRepository(mockDio, MockSecureStorage());
  });
  
  group('login', () {
    test('returns UserEntity on 200', () async {
      when(() => mockDio.post(any(), data: any(named: 'data')))
          .thenAnswer((_) async => Response(
            data: {'data': {'accessToken': 'abc', 'user': {'_id': '1', 'email': 'a@b.com'}}},
            statusCode: 200,
            requestOptions: RequestOptions(),
          ));
      
      final result = await repo.login('a@b.com', 'pass');
      expect(result, isA<Success<UserEntity>>());
    });
    
    test('returns Failure on 401', () async { /* ... */ });
  });
}
```

### Coverage targets:
| Layer | Coverage | Tool |
|-------|----------|------|
| Domain entities | 100% | `dart test` |
| Repositories | 95% | mocktail/mockito |
| Providers/Notifiers | 90% | Riverpod test |
| Widgets | 80% | `flutter_test` |
| Integration flows | 5 critical paths | `integration_test` |

---

## 10. Performance

### Current bottlenecks:

| Area | Current State | Fix |
|------|--------------|-----|
| **State rebuilds** | `notifyListeners()` on every change | Riverpod's `select()` or `StateNotifier` |
| **Image loading** | Some `Image.network`, some `cached_network_image` | ✅ Already using `cached_network_image` — good |
| **List rendering** | No `builderv` or `ListView.builder` usage checks | Always use `ListView.builder` for dynamic lists |
| **Video player** | `media_kit` Player is heavy | Only initialize when user taps play, dispose on leave |
| **JSON parsing** | Repeated `jsonDecode` in network_caller | Use `freezed` for immutable models + code-gen |
| **Thumbnails** | Not generated | Generate video thumbnails server-side or via `video_thumbnail` |
| **Bundle size** | Current APK size unknown | Enable shrinking, use app bundles, audit unused assets |

### Image optimization:
```dart
// ——— Always ———
CachedNetworkImage(
  imageUrl: '${url}?w=400&q=80',  // server-side resize if supported
  placeholder: (_, __) => ShimmerWidget(...),
  errorWidget: (_, __, ___) => Icon(Icons.error),
  memCacheWidth: 400,              // decode at display size
)
```

### List performance:
```dart
ListView.builder(
  itemCount: items.length,
  itemBuilder: (ctx, i) => ItemCard(key: ValueKey(items[i].id)),
  // If items have images, use:
  addAutomaticKeepAlives: false,  // don't keep off-screen items alive
)
```

---

## 11. Security

### Current:
- ✅ `flutter_secure_storage` for tokens
- ❌ `http://` base URL (not HTTPS)
- ❌ No certificate pinning
- ❌ No biometric lock for sensitive screens

### Must-do:
```dart
// 1. HTTPS only in production
class AppConfig {
  static const String baseUrl = 'https://api.eduverseapp.com/api/v1';
}
```

```dart
// 2. Certificate pinning with Dio
(dio.httpClientAdapter as DefaultHttpClientAdapter).onHttpClientCreate = (client) {
  client.badCertificateCallback = (cert, host, port) => false; // reject all invalid
  return client;
};
```

```dart
// 3. Biometric lock for sensitive screens
final canAuth = await LocalAuthentication().authenticate(
  localizedReason: 'Verify your identity to access this section',
);
if (!canAuth) return;
```

---

## 12. Localization (l10n)

### Current: None — all strings hardcoded in English

### For global scale:
```yaml
# lib/l10n/app_en.arb
{
  "appTitle": "Eduverse",
  "signIn": "Sign In",
  "uploadVideo": "Upload Video",
  "uploadingProgress": "Uploading {percent}%"
}
```

```dart
// Usage
Text(AppLocalizations.of(context)!.uploadingProgress(42));
```

Flutter's built-in `flutter_localizations` + `intl` is sufficient. No need for a third-party package.

---

## 13. Monitoring & Crash Reporting

### Must-have for production:
```dart
// ——— Firebase Crashlytics ———
await Firebase.initializeApp();
FlutterError.onError = (details) {
  FirebaseCrashlytics.instance.recordFlutterFatalError(details);
};
PlatformDispatcher.instance.onError = (error, stack) {
  FirebaseCrashlytics.instance.recordError(error, stack);
  return true;
};

// ——— Performance tracking ———
final trace = FirebasePerformance.instance.newTrace('video_upload');
trace.start();
await uploadVideo();
trace.stop();
```

### Minimum viable:
1. **Crashlytics** (Firebase or Sentry)
2. **Analytics** (Firebase Analytics or Mixpanel)
3. **Logging** → current `AppLogger` is good, but add remote log shipping

---

## 14. CI/CD

### Minimum:
```yaml
# .github/workflows/ci.yaml
name: CI
on: [push, pull_request]
jobs:
  analyze:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
      - run: flutter pub get
      - run: flutter analyze
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
      - run: flutter test --coverage
      - uses: codecov/codecov-action@v3
  build-android:
    needs: [analyze, test]
    runs-on: ubuntu-latest
    steps:
      - run: flutter build appbundle --release
      - uses: actions/upload-artifact@v4
        with:
          name: release.aab
          path: build/app/outputs/bundle/release/app-release.aab
```

---

## 15. Recommended Package Stack

| Category | Package | Why |
|----------|---------|-----|
| **State** | `flutter_riverpod` | Zero-boilerplate DI + state |
| **Network** | `dio` | Interceptors, cancellation, multipart |
| **API gen** | `openapi_generator` | Type-safe clients from OpenAPI spec |
| **Router** | `go_router` | Deep links, guards, shell routes |
| **Models** | `freezed` + `json_serializable` | Immutable models, copyWith, union types |
| **Local DB** | `isar` or `drift` | Offline cache |
| **Notifications** | `firebase_messaging` | Push notifications (required for millions) |
| **Crash** | `firebase_crashlytics` | Error monitoring |
| **Analytics** | `firebase_analytics` | User behavior |
| **CI** | GitHub Actions | Free for public repos |

---

## 16. Migration Roadmap

### Phase 1 (Week 1-2) — Foundation
```
[ ] Add GoRouter → replace onGenerateRoute
[ ] Add Dio → replace http calls in ONE feature (auth)
[ ] Add Riverpod → migrate ONE provider (SignInProvider)
[ ] Write first tests for the migrated code
[ ] Verify everything still works
```

### Phase 2 (Week 3-4) — Data Layer
```
[ ] Model code-gen with freezed + json_serializable
[ ] Isar setup for offline cache
[ ] Repository pattern for courses + profile
[ ] API client generation
```

### Phase 3 (Week 5-6) — Production Readiness
```
[ ] Firebase Crashlytics + Analytics
[ ] CI/CD pipeline
[ ] L10n setup
[ ] Performance audit
[ ] Security audit (HTTPS, cert pinning)
```

### Phase 4 (Ongoing)
```
[ ] Migrate remaining features one by one
[ ] Increase test coverage
[ ] Add integration tests for critical flows
[ ] Performance monitoring with Firebase Performance
```

---

## 17. Quick Wins (Do Today)

These take < 1 hour each and immediately improve quality:

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 1 | Enforce HTTPS in `AppConfig.baseUrl` | 2 min | 🔴 Security |
| 2 | Add `ListView.builder` check to all lists | 15 min | 🟡 Performance |
| 3 | Add `mounted` check before `Navigator` calls | 10 min | 🟡 Stability |
| 4 | Replace `http` with Dio for ONE endpoint | 30 min | 🟢 Developer experience |
| 5 | Add `flutter test` to CI | 20 min | 🟢 Reliability |
| 6 | Add `const` constructors to all widgets | 15 min | 🟡 Performance |
| 7 | Remove unused assets from `pubspec.yaml` | 5 min | 🟢 Bundle size |
| 8 | Add error boundary widget (`FlutterError.onError`) | 10 min | 🟡 UX |

---

## 18. Key Principles

```
1.  Fail fast → crash with a clear message rather than silently swallowing errors
2.  Every file has ≤ 200 lines → if longer, split
3.  Every class has one responsibility
4.  No `Map<String, dynamic>` in UI code → typed models always
5.  No `BuildContext` outside widget layer → never in providers/services
6.  Test every repository independently
7.  CI must pass before merge
8.  Zero warnings in `flutter analyze`
9.  All API calls go through repositories, never directly from widgets
10. Data flows down; events flow up
```
