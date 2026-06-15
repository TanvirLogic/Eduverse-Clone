# Crafty Bay — Flutter Ecommerce App: Complete Architecture Guide

> **A deep-dive reference into the project's architecture, design decisions, code conventions, and implementation patterns. Use this as a blueprint for building similar Flutter applications.**

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [High-Level Architecture](#2-high-level-architecture)
3. [Complete Directory Map](#3-complete-directory-map)
4. [App Entry Point & Initialization Flow](#4-app-entry-point--initialization-flow)
5. [State Management Architecture (Provider)](#5-state-management-architecture-provider)
6. [Networking & Data Layer](#6-networking--data-layer)
7. [Routing System](#7-routing-system)
8. [Feature-by-Feature Deep Dive](#8-feature-by-feature-deep-dive)
   - 8.1 [Authentication Feature](#81-authentication-feature)
   - 8.2 [Home Feature](#82-home-feature)
   - 8.3 [Category Feature](#83-category-feature)
   - 8.4 [Product Feature](#84-product-feature)
   - 8.5 [Cart Feature](#85-cart-feature)
   - 8.6 [Wishlist Feature](#86-wishlist-feature)
   - 8.7 [Common/Shared Feature](#87-commonshared-feature)
9. [Localization System](#9-localization-system)
10. [Theme & Styling System](#10-theme--styling-system)
11. [Authentication & Authorization Flow](#11-authentication--authorization-flow)
12. [Pagination Strategy](#12-pagination-strategy)
13. [Error Handling Strategy](#13-error-handling-strategy)
14. [Form Handling Patterns](#14-form-handling-patterns)
15. [Widget Tree Breakdowns](#15-widget-tree-breakdowns)
16. [Code Conventions & Style Guide](#16-code-conventions--style-guide)
17. [Dependencies Reference](#17-dependencies-reference)
18. [Firebase Integration](#18-firebase-integration)
19. [Adding New Features — Step-by-Step Recipe](#19-adding-new-features--step-by-step-recipe)
20. [Known Limitations & TODOs](#20-known-limitations--todos)

---

## 1. Project Overview

| Attribute | Value |
|-----------|-------|
| **Project Name** | Crafty Bay |
| **Package** | `crafty_bay` |
| **SDK** | `^3.10.0` (Dart 3.10+) |
| **Architecture Style** | Feature-first with layered sub-packages |
| **State Management** | Provider (`ChangeNotifier`) |
| **Backend Type** | REST JSON API |
| **Base URL** | `https://ecom-rs8e.onrender.com/api` |
| **Authentication** | JWT token (stored in SharedPreferences) |
| **Backend Services** | Firebase Core, Firebase Crashlytics, Firebase Analytics |
| **Localization** | `flutter_localizations` (English + Bangla) |
| **Target Platforms** | Android, iOS, Web, Windows, macOS, Linux |

---

## 2. High-Level Architecture

### Architectural Philosophy

The project adopts a **Feature-First Architecture** — the codebase is organized by business features (auth, home, product, cart, etc.) rather than by technical layers (models, views, controllers). Within each feature, code is further separated into three conceptual layers:

```
Feature
  ├── data/        → Models (DTOs) and data representations
  ├── providers/   → State management (ChangeNotifier classes)
  └── presentation/
      ├── screens/ → Full-page UI widgets
      └── widgets/ → Reusable UI components
```

### Separation of Concerns

| Layer | Responsibility | Never Does |
|-------|---------------|------------|
| **Screen** | Builds UI layout, handles user gestures, delegates logic to providers | ❌ Never calls APIs directly |
| **Provider** | Holds state, calls NetworkCaller, parses JSON into models, notifies listeners | ❌ Never imports UI packages |
| **NetworkCaller** | Makes HTTP requests, logs, returns raw NetworkResponse | ❌ Never knows about UI or business logic |
| **Model** | Pure data class with `fromJson`/`toJson` | ❌ Never depends on Flutter |

### Unidirectional Data Flow

```
┌─────────────────────────────────────────────────────────┐
│                         SCREEN                          │
│  (Builds UI, shows Consumer<Provider>, handles events)   │
└─────────────┬───────────────────────────────▲────────────┘
              │ User action (tap, submit)      │
              ▼                                │ notifyListeners()
┌──────────────────────────────────────────────┴────────────┐
│                        PROVIDER                           │
│  (ChangeNotifier: _loading, _items, _errorMessage,        │
│   fetchData(), addItem(), etc.)                            │
└─────────────┬─────────────────────────────────────────────┘
              │ Calls method                              Provider parses JSON
              ▼                                            into Model objects
┌──────────────────────────────────────────────┐
│                  NETWORK CALLER               │
│  (http package: GET/POST, logging, status     │
│   code handling, 401 callback)                │
└─────────────┬─────────────────────────────────┘
              │
              ▼ HTTP Request
┌──────────────────────────────────────────────┐
│                  REST API                     │
│  JSON Response → NetworkResponse              │
└──────────────────────────────────────────────┘
```

### Key Architectural Rules

1. **Screens never call `http.get()` or `http.post()` directly** — all API communication is routed through a Provider → NetworkCaller chain.
2. **Providers never import `flutter/material.dart`** — they import only `flutter/foundation.dart` (for ChangeNotifier).
3. **Models are pure Dart classes** — no Flutter dependencies, no business logic, just data mapping.
4. **State is lifted to the nearest common ancestor** — global state in `app.dart` MultiProvider, screen-local state in the screen's State object.
5. **Widgets are stateless where possible** — stateful widgets are only used for ephemeral UI state (e.g., selected color/size, text field controllers).

---

## 3. Complete Directory Map

```
lib/
│
├── main.dart                           # 🔵 APP ENTRY POINT
│   ├── WidgetsFlutterBinding.ensureInitialized()
│   ├── Firebase.initializeApp()
│   ├── FirebaseCrashlytics configuration (global error handlers)
│   └── runApp(CraftyBay())
│
├── firebase_options.dart               # Auto-generated Firebase config per platform
│
├── app/                                # 🟢 APP-LEVEL CONFIGURATION
│   ├── app.dart                        # CraftyBay root widget
│   │   ├── MultiProvider (global providers)
│   │   │   ├── LanguageProvider (locale)
│   │   │   ├── ThemeProvider (theme mode)
│   │   │   ├── MainNavContainerProvider (bottom nav index)
│   │   │   ├── CategoryListProvider (categories)
│   │   │   └── HomeSliderProvider (carousel)
│   │   └── MaterialApp
│   │       ├── onGenerateRoute → AppRoutes.routes
│   │       ├── theme / darkTheme → AppTheme
│   │       ├── themeMode → ThemeProvider
│   │       ├── localizationsDelegates
│   │       ├── supportedLocales [en, bn, de]
│   │       └── locale → LanguageProvider
│   │
│   ├── app_routes.dart                 # 🚦 Route table (onGenerateRoute)
│   │   ├── SplashScreen → /splash-screen
│   │   ├── SignUpScreen → /sign-up
│   │   ├── SignInScreen → /sign-in
│   │   ├── VerifyOTPScreen → /verify-otp-screen
│   │   ├── MainNavHolderScreen → /main-bottom-nav-holder
│   │   ├── HomeScreen → /home-screen
│   │   ├── CategoryListScreen → /category-list-screen
│   │   ├── ProductListByCategoryScreen → /product-list-by-category
│   │   └── ProductDetailsScreen → /product-details
│   │
│   ├── app_colors.dart                 # 🎨 AppColors.themeColor = 0XFF07ADAE
│   │
│   ├── app_theme.dart                  # 📐 ThemeData (light + dark)
│   │   ├── filledButtonTheme (full-width, rounded, teal bg)
│   │   ├── inputDecorationTheme (16px padding, outline border)
│   │   └── brightness: .light / .dark
│   │
│   ├── constants.dart                  # 📌 Constants.takaSign = '৳'
│   │
│   ├── asset_paths.dart                # 🖼️ AssetPaths.logoSvg, shoe_png, etc.
│   │
│   ├── urls.dart                       # 🌐 All API endpoint builders
│   │   ├── signUpUrl, signInOtpUrl, verifyOtpUrl
│   │   ├── homeSlidersUrl
│   │   ├── categoryListUrl(count, page)
│   │   ├── productsByCategoryUrl(size, page, categoryId)
│   │   ├── productDetailsUrl(productId)
│   │   └── addToCartUrl
│   │
│   ├── setup_network_caller.dart       # 🔧 Factory: getNetworkCaller()
│   │   ├── Headers: Content-type + token
│   │   └── onUnauthorize callback (stub)
│   │
│   ├── providers/
│   │   ├── language_provider.dart      # 🌍 Locale management
│   │   │   ├── loadInitialLanguage()   # Reads SharedPreferences
│   │   │   ├── changeLocale(Locale)    # Writes SharedPreferences + notify
│   │   │   └── SharedPreferences keys: 'locale'
│   │   │
│   │   └── theme_provider.dart         # 🎭 ThemeMode management
│   │       ├── loadInitialThemeMode()  # Reads SharedPreferences
│   │       ├── changeTheme(ThemeMode)  # Writes SharedPreferences + notify
│   │       └── SharedPreferences keys: 'themeMode'
│   │
│   └── extensions/
│       └── localization_extension.dart # 🔌 BuildContext → .localizatons
│
├── core/                               # 🟡 SHARED INFRASTRUCTURE
│   ├── services/
│   │   └── network_caller.dart         # 📡 HTTP Client
│   │       ├── getRequest(url)         # GET with auth headers
│   │       ├── postRequest(url, body)  # POST with JSON body
│   │       ├── _logRequest / _logResponse  # Logger
│   │       └── Status codes: 200/201 ✅, 401 🚫 callback, other ❌
│   │
│   └── models/
│       └── network_response.dart       # 📦 Response DTO (part of network_caller)
│           ├── isSuccess: bool
│           ├── responseCode: int
│           ├── responseData: dynamic (parsed JSON)
│           └── errorMessage: String?
│
├── features/                           # 🔵 FEATURE MODULES
│   │
│   ├── auth/                           # 🔐 AUTHENTICATION
│   │   ├── data/models/
│   │   │   ├── user_model.dart         # UserModel (firstName, lastName, email, phone, avatarUrl, city)
│   │   │   ├── sign_up_params.dart     # SignUpParams → toJson()
│   │   │   ├── sign_in_params.dart     # SignInParam → toJson()
│   │   │   └── verify_otp_param.dart   # VerifyOtpParam → toJson()
│   │   │
│   │   ├── providers/
│   │   │   ├── auth_controller.dart    # 🗄️ Static class, SharedPreferences persistence
│   │   │   │   ├── accessToken (static)
│   │   │   │   ├── userModel (static)
│   │   │   │   ├── saveUserData(token, model)
│   │   │   │   ├── getUserData()
│   │   │   │   ├── isLoggedIn()
│   │   │   │   └── clearUserData()
│   │   │   │
│   │   │   ├── sign_in_provider.dart   # ChangeNotifier
│   │   │   │   ├── _isSigninInProgress
│   │   │   │   ├── _errorMessage
│   │   │   │   └── signIn(SignInParam) → bool
│   │   │   │
│   │   │   ├── sign_up_provider.dart   # ChangeNotifier
│   │   │   │   ├── _isSignUpInProgress
│   │   │   │   ├── _errorMessage
│   │   │   │   └── signUp(SignUpParams) → bool
│   │   │   │
│   │   │   └── verify_otp_provider.dart # ChangeNotifier
│   │   │       ├── _isVerifyOTPInProgress
│   │   │       ├── _errorMessage
│   │   │       └── verifyOTP(VerifyOtpParam) → bool
│   │   │
│   │   └── presentation/
│   │       ├── screens/
│   │       │   ├── splash_screen.dart  # 🏁 3s delay → check auth → navigate
│   │       │   ├── sign_in_screen.dart # 🔑 Email + Password + Form + Consumer<SignInProvider>
│   │       │   ├── sign_up_screen.dart # 📝 6 fields + Form + Consumer<SignUpProvider>
│   │       │   ├── verify_otp_screen.dart  # 📱 PinCodeTextField + Consumer<VerifyOTPProvider>
│   │       │   └── verify_email_screen.dart # ⚠️ EMPTY FILE
│   │       │
│   │       └── widgets/
│   │           └── app_logo.dart       # 🖼️ SVG logo (reusable)
│   │
│   ├── home/                           # 🏠 HOME
│   │   ├── data/model/
│   │   │   └── slider_model.dart       # SliderModel (id, photoUrl, description, brand, productId)
│   │   │
│   │   ├── provider/
│   │   │   └── slider_provider.dart    # ChangeNotifier
│   │   │       ├── getHomeSliders() → bool
│   │   │       └── Parses response.responseData['data']['results']
│   │   │
│   │   └── presentation/
│   │       ├── screens/
│   │       │   └── home_screen.dart    # 🏠 THE MAIN DASHBOARD
│   │       │       ├── AppBar (logo + 3 CircleIconButtons)
│   │       │       ├── Drawer (ThemeSelector + LanguageSelector)
│   │       │       ├── ProductSearchField
│   │       │       ├── Consumer<HomeSliderProvider> → Carousel
│   │       │       ├── SectionHeader("Categories") + CategoryCard list
│   │       │       ├── SectionHeader("Popular") + CategoryCard list
│   │       │       ├── SectionHeader("Special") + CategoryCard list
│   │       │       └── SectionHeader("New Arrivals") + CategoryCard list
│   │       │
│   │       └── widgets/
│   │           ├── home_carousel_slider.dart  # 🎠 CarouselSlider + dot indicators
│   │           ├── section_header.dart        # 📰 "Title" + "See All" text button
│   │           ├── product_search_field.dart  # 🔍 Search TextField (no-op)
│   │           └── circle_icon_button.dart    # ⭕ GestureDetector + CircleAvatar
│   │
│   ├── category/                       # 📂 CATEGORIES
│   │   ├── data/models/
│   │   │   ├── category_model.dart     # CategoryModel (id, title, icon)
│   │   │   ├── popular_model.dart      # ⚠️ EMPTY FILE
│   │   │   ├── new_collection_model.dart # ⚠️ EMPTY FILE
│   │   │   └── special_model.dart      # ⚠️ EMPTY FILE
│   │   │
│   │   ├── provider/
│   │   │   └── category_list_provider.dart # ChangeNotifier with PAGINATION
│   │   │       ├── _productCount = 30 (page size)
│   │   │       ├── _currentPageNo / _lastPageNo (pagination tracking)
│   │   │       ├── _initialLoading / _loadingMoreProduct (two loading states)
│   │   │       ├── _categoryList (accumulated list)
│   │   │       ├── fetchCategoryList() → bool
│   │   │       └── loadInitialCategoryList() (resets page counter)
│   │   │
│   │   └── presentation/
│   │       └── screens/
│   │           └── category_list_screen.dart # 📋 GridView (4 cols) + pagination
│   │               ├── ScrollController listener
│   │               ├── PopScope (canPop: false, returns to Home)
│   │               └── Consumer<CategoryListProvider>
│   │
│   ├── product/                        # 📦 PRODUCTS
│   │   ├── data/models/
│   │   │   ├── product_model.dart      # ProductModel (id, title, photo, currentPrice)
│   │   │   └── product_details_model.dart # ProductDetailsModel (id, title, desc, photos[], colors[], sizes[], price, quantity)
│   │   │
│   │   ├── provider/
│   │   │   ├── product_list_by_category_provider.dart # ChangeNotifier with PAGINATION
│   │   │   │   ├── _pageSize = 30
│   │   │   │   ├── _currentPageNo / _lastPageNo
│   │   │   │   ├── _initialLoading / _loadingMoreData
│   │   │   │   ├── _productList (accumulated)
│   │   │   │   ├── fetchProductList(categoryId) → bool
│   │   │   │   └── loadInitialProductList(categoryId)
│   │   │   │
│   │   │   └── prodcut_details_provider.dart # ChangeNotifier
│   │   │       ├── _getProductDetailsInProgress
│   │   │       ├── _productDetailsModel
│   │   │       └── getProductDetails(productId) → bool
│   │   │
│   │   └── presentation/
│   │       ├── screens/
│   │       │   ├── product_list_by_category_screen.dart # 📐 GridView (3 cols) + pagination
│   │       │   │   ├── ScrollController + _loadMoreData
│   │       │   │   └── Consumer<ProductListByCategoryProvider>
│   │       │   │
│   │       │   └── product_details_screen.dart # 🔍 Full product detail view
│   │       │       ├── ProductImageSlider + dot indicators
│   │       │       ├── Title + IncDecButton
│   │       │       ├── RatingView + Reviews + FavouriteButton
│   │       │       ├── ColorPicker + SizePicker
│   │       │       ├── Description section
│   │       │       └── Bottom price bar + AddToCart button
│   │       │           └── Checks AuthController.isLoggedIn() first
│   │       │
│   │       └── widgets/
│   │           ├── color_picker.dart       # 🎨 Wrap of tappable color chips
│   │           ├── size_picker.dart        # 📏 Wrap of tappable size chips
│   │           └── product_image_slider.dart # 🖼️ CarouselSlider + dot indicators
│   │
│   ├── cart/                           # 🛒 SHOPPING CART
│   │   ├── provider/
│   │   │   └── add_to_cart_provider.dart # ChangeNotifier
│   │   │       ├── addToCart(productId) → bool
│   │   │       └── POST to /api/cart
│   │   │
│   │   └── presentation/
│   │       ├── screens/
│   │       │   └── cart_screen.dart    # 🛍️ Cart view (hardcoded items)
│   │       │       ├── ListView of CartItems
│   │       │       └── Bottom bar: total price + Checkout button
│   │       │
│   │       └── widgets/
│   │           ├── cart_item.dart      # 📦 Cart item card (image, title, color/size, delete, IncDecButton)
│   │           └── inc_dec_button.dart # ➕➖ Quantity selector (min 1, max N)
│   │
│   ├── wish_list/                      # ❤️ WISHLIST
│   │   └── presentation/
│   │       └── screens/
│   │           └── wish_list_screen.dart # ⚠️ STUB (uses hardcoded data)
│   │
│   └── common/                         # 🔄 SHARED / CROSS-CUTTING
│       ├── provider/
│       │   └── main_nav_container_provider.dart # 📌 Bottom nav tab index
│       │       ├── changeIndex(int)
│       │       ├── changeToCategory() → index 1
│       │       └── changeToHome() → index 0
│       │
│       ├── screens/
│       │   └── main_nav_holder_screen.dart # 🏗️ APP SHELL (BottomNavigationBar)
│       │       ├── 4 screens: Home, Category, Cart, Wishlist
│       │       ├── Navigation guard: Cart/Wishlist → Auth check
│       │       └── initState: fetch categories + sliders
│       │
│       └── widgets/
│           ├── product_card.dart         # 💳 Product card (image, title, price, rating, fav)
│           ├── category_card.dart        # 📁 Category card (icon, title)
│           ├── rating_view.dart          # ⭐ Star + "4.3" (static)
│           ├── favourite_button.dart     # ❤️ Heart icon button
│           ├── centered_circular_progress.dart # ⌛ Centered spinner
│           ├── theme_selector.dart       # 🎭 DropdownMenu for ThemeMode
│           └── language_selector.dart    # 🌍 DropdownMenu for locale
│
└── l10n/                               # 🌐 LOCALIZATION
    ├── l10n.yaml                       # gen-l10n config
    ├── app_localizations.dart          # Abstract base + delegate
    ├── app_localizations_en.dart       # English translations (80+ strings)
    └── app_localizations_bn.dart       # Bangla translations
```

---

## 4. App Entry Point & Initialization Flow

### `main.dart` — Boot Sequence

```
1. WidgetsFlutterBinding.ensureInitialized()
       │ Ensures platform channels are ready before any async work
       ▼
2. Firebase.initializeApp()
       │ Initializes Firebase services (Core, Crashlytics, Analytics)
       ▼
3. Configure Error Handling
       │ FlutterError.onError → FirebaseCrashlytics (fatal Flutter errors)
       │ PlatformDispatcher.instance.onError → FirebaseCrashlytics (unhandled async errors)
       ▼
4. runApp(CraftyBay())
       │
       ▼
   CraftyBay (StatefulWidget)
       │
       ├── MultiProvider (5 global providers)
       │   │
       │   ├── LanguageProvider → loadInitialLanguage() reads SharedPreferences
       │   ├── ThemeProvider → loadInitialThemeMode() reads SharedPreferences
       │   ├── MainNavContainerProvider
       │   ├── CategoryListProvider
       │   └── HomeSliderProvider
       │   │
       │   ▼
       └── MaterialApp
           ├── initialRoute: SplashScreen.name
           ├── onGenerateRoute: AppRoutes.routes
           ├── theme/darkTheme: AppTheme.lightTheme / darkTheme
           ├── themeMode: ThemeProvider.currentThemeMode
           ├── localizationsDelegates: [AppLocalizations.delegate, ...]
           ├── supportedLocales: [en, bn, de]
           └── locale: LanguageProvider.currentLocale
```

### Why global navigator key?

```dart
static GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
```

The `navigatorKey` is stored as a static field on `CraftyBay` so it can be accessed from anywhere in the app (e.g., from the `onUnauthorize` callback to navigate to login). However, it's currently passed to `MaterialApp` but not actively used in callbacks yet — the `onUnauthorize` in `setup_network_caller.dart` is an empty stub.

---

## 5. State Management Architecture (Provider)

### 5.1 Provider Types

| Type | Registration Location | Lifetime | Examples |
|------|----------------------|----------|----------|
| **Global** | `MultiProvider` in `app.dart` | Entire app lifetime | LanguageProvider, ThemeProvider, MainNavContainerProvider, CategoryListProvider, HomeSliderProvider |
| **Screen-scoped** | `ChangeNotifierProvider` inside screen's `build()` | Screen lifetime (disposed when screen is popped) | SignInProvider, SignUpProvider, VerifyOTPProvider, ProductDetailsProvider, AddToCartProvider, ProductListByCategoryProvider |

### 5.2 The Standard Provider Template

Every provider in the project follows this exact pattern:

```dart
// ⚠️ Note: Imports only foundation.dart (not material.dart)
import 'package:flutter/foundation.dart';

class SomeProvider extends ChangeNotifier {
  // ── Loading state ──
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // ── Data ──
  List<SomeModel> _items = [];
  List<SomeModel> get items => _items;

  // ── Error state ──
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // ── Action method ──
  Future<bool> fetchData() async {
    bool isSuccess = false;

    _isLoading = true;
    notifyListeners();  // 🔔 UI shows loading indicator

    final NetworkResponse response = await getNetworkCaller().getRequest(
      url: Urls.someUrl,
    );

    if (response.isSuccess) {
      // Parse JSON into model objects
      List<SomeModel> list = [];
      for (Map<String, dynamic> item
          in response.responseData['data']['results']) {
        list.add(SomeModel.fromJson(item));
      }
      _items = list;
      _errorMessage = null;
      isSuccess = true;
    } else {
      _errorMessage = response.errorMessage;
    }

    _isLoading = false;
    notifyListeners();  // 🔔 UI shows data or error

    return isSuccess;
  }
}
```

### 5.3 Consumer Patterns in Detail

**Pattern 1: `Consumer<Provider>` — Rebuild subtree on change**
```dart
Consumer<SomeProvider>(
  builder: (context, provider, child) {
    if (provider.isLoading) {
      return CircularProgressIndicator();
    }
    return ListView.builder(
      itemCount: provider.items.length,
      itemBuilder: (context, index) => Text(provider.items[index].title),
    );
  },
)
```

**Pattern 2: `context.read<Provider>()` — Fire-and-forget (no rebuild)**
```dart
// Inside a callback, never inside build()
context.read<SomeProvider>().fetchData();
```

**Pattern 3: `context.watch<Provider>()` — Listen in build**
```dart
// Equivalent to Consumer, used inside build()
final provider = context.watch<SomeProvider>();
```

**Pattern 4: `ValueListenableBuilder` — Lightweight reactive**
```dart
// Used in carousel dot indicators instead of a full Consumer
final ValueNotifier<int> _selectedIndex = ValueNotifier(0);

ValueListenableBuilder(
  valueListenable: _selectedIndex,
  builder: (context, value, child) {
    return Row(children: dots.map((i) => Dot(active: i == value)).toList());
  },
)
```

### 5.4 Provider Lifecycle Diagram

```
App starts
  │
  ▼
MultiProvider (app.dart)
  │  Creates all global providers ONCE
  │  They live until app terminates
  ▼
Screen A (push)
  │  Screen-scoped provider created
  │  in State field
  ▼
Screen A → Screen B (push)
  │  Screen A provider still alive
  │  (A is in navigation stack)
  ▼
Screen B → pop
  │  Screen B provider disposed
  ▼
Screen A → pop
  │  Screen A provider disposed
```

---

## 6. Networking & Data Layer

### 6.1 NetworkCaller — The HTTP Client

**Location:** `lib/core/services/network_caller.dart`

The `NetworkCaller` is a configurable HTTP client that:

1. Accepts custom `headers` (injected via constructor for auth tokens)
2. Accepts an `onUnauthorize` callback for 401 handling
3. Provides two methods: `getRequest(url)` and `postRequest(url, body)`
4. Logs all requests and responses using the `logger` package
5. Returns a `NetworkResponse` object that normalizes success/failure

```dart
class NetworkCaller {
  final Logger _logger = Logger();
  final VoidCallback onUnauthorize;
  final Map<String, String>? headers;

  Future<NetworkResponse> getRequest({required String url}) async { ... }
  Future<NetworkResponse> postRequest({required String url, Map<String, dynamic>? body}) async { ... }
}
```

**Status Code Handling:**

| Code | Behavior |
|------|----------|
| `200` | Success — parse JSON body → `NetworkResponse(isSuccess: true)` |
| `201` | Success (POST) — same as 200 |
| `401` | Unauthorized — call `onUnauthorize()`, return `NetworkResponse(isSuccess: false, errorMessage: 'Un-authorize')` |
| Other 4xx/5xx | Failure — parse JSON body, extract error message from `responseData['msg']` |
| Exception | Network error — return `NetworkResponse(isSuccess: false, responseCode: -1, errorMessage: exception.toString())` |

### 6.2 NetworkResponse — The Response DTO

```dart
class NetworkResponse {
  final bool isSuccess;        // true = 200/201, false = everything else
  final int responseCode;      // HTTP status code or -1 for network errors
  final dynamic responseData;  // Decoded JSON (Map or List)
  final String? errorMessage;  // Human-readable error
}
```

### 6.3 getNetworkCaller() — The Factory

**Location:** `lib/app/setup_network_caller.dart`

```dart
NetworkCaller getNetworkCaller() {
  return NetworkCaller(
    headers: {
      'Content-type': 'application/json',
      'token': AuthController.accessToken ?? '',
    },
    onUnauthorize: () {
      // TODO: Navigate to login screen
    },
  );
}
```

This factory is called by every provider before making an API call. It:
- Injects the JWT token from `AuthController.accessToken` into every request header
- Provides a callback for 401 handling (currently a no-op stub)

### 6.4 API URL Builders

**Location:** `lib/app/urls.dart`

The `Urls` class provides static strings and methods that construct full URLs:

```dart
class Urls {
  static const String _baseUrl = 'https://ecom-rs8e.onrender.com/api';

  // Simple endpoints (constants)
  static const String signUpUrl = '$_baseUrl/auth/signup';
  static const String verifyOtpUrl = '$_baseUrl/auth/verify-otp';
  static const String signInOtpUrl = '$_baseUrl/auth/login';
  static const String homeSlidersUrl = '$_baseUrl/slides';
  static const String addToCartUrl = '$_baseUrl/cart';

  // Parameterized endpoints (methods)
  static String categoryListUrl(int productCount, int pageNo) =>
      '$_baseUrl/categories?count=$productCount&page=$pageNo';

  static String productsByCategoryUrl(int pageSize, int pageNo, String categoryId) =>
      '$_baseUrl/products?count=$pageSize&page=$pageNo&category=$categoryId';

  static String productDetailsUrl(String productId) =>
      '$_baseUrl/products/id/$productId';
}
```

---

## 7. Routing System

### 7.1 Architecture

The project uses **named routes with `onGenerateRoute`** — a centralized routing approach where all route definitions live in a single file (`app_routes.dart`). Each screen defines a `static const String name` for its route.

**Why `onGenerateRoute` instead of `routes` map?**
- Allows passing typed arguments (`setting.arguments`)
- Supports dynamic route creation
- Single place to manage all navigation logic

### 7.2 Route Table

```dart
class AppRoutes {
  static Route<dynamic> routes(RouteSettings setting) {
    Widget widget = SizedBox();  // Default fallback (empty)

    if (setting.name == SplashScreen.name) {
      widget = SplashScreen();
    } else if (setting.name == SignUpScreen.name) {
      widget = SignUpScreen();
    } else if (setting.name == SignInScreen.name) {
      widget = SignInScreen();
    } else if (setting.name == VerifyOTPScreen.name) {
      widget = VerifyOTPScreen(email: setting.arguments as String);
    } else if (setting.name == MainNavHolderScreen.name) {
      widget = MainNavHolderScreen();
    } else if (setting.name == HomeScreen.name) {
      widget = HomeScreen();
    } else if (setting.name == CategoryListScreen.name) {
      widget = CategoryListScreen();
    } else if (setting.name == ProductListByCategoryScreen.name) {
      widget = ProductListByCategoryScreen(
        categoryModel: setting.arguments as CategoryModel,
      );
    } else if (setting.name == ProductDetailsScreen.name) {
      widget = ProductDetailsScreen(productId: setting.arguments as String);
    }

    return MaterialPageRoute(builder: (context) => widget);
  }
}
```

### 7.3 Navigation Patterns

| Pattern | When to Use | Example |
|---------|-------------|---------|
| `Navigator.pushNamed()` | Go to next screen (back allowed) | SignUp → VerifyOTP |
| `Navigator.pushReplacementNamed()` | Replace current screen | SignIn → SignUp (swap) |
| `Navigator.pushNamedAndRemoveUntil(_, _, (route) => false)` | Clear stack and set root | Splash → MainNav, SignIn → Home |
| `Navigator.pop()` | Go back | System back button |
| `PopScope(canPop: false)` | Intercept back (e.g., tab screens) | CategoryScreen returns to Home tab |

### 7.4 Navigation Guard Pattern

In `MainNavHolderScreen`, cart and wishlist tabs check authentication:

```dart
if (index == 2 || index == 3) {
  if (await AuthController.isLoggedIn() == false) {
    Navigator.pushNamed(context, SignUpScreen.name);
    return;  // Don't switch tab
  }
}
mainNavContainerProvider.changeIndex(index);
```

---

## 8. Feature-by-Feature Deep Dive

### 8.1 Authentication Feature

#### 8.1.1 Data Models

**`UserModel`** — The authenticated user profile:
```dart
class UserModel {
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String? avatarUrl;
  final String city;
}
```

**`SignUpParams`** — Request body for registration POST:
```dart
class SignUpParams {
  // firstName, lastName, email, password, phone, city
  Map<String, dynamic> toJson() => { /* snake_case keys */ };
}
```

**`SignInParam`** — Request body for login POST:
```dart
class SignInParam {
  // email, password
  Map<String, dynamic> toJson() => { "email": email, "password": password };
}
```

**`VerifyOtpParam`** — Request body for OTP verification POST:
```dart
class VerifyOtpParam {
  // email, otp
  Map<String, dynamic> toJson() => { "email": email, "otp": otp };
}
```

#### 8.1.2 AuthController (Token Persistence)

`AuthController` is a **static class** (not a ChangeNotifier) that manages JWT token and user data persistence via `SharedPreferences`.

```dart
class AuthController {
  static const _tokenKey = 'access-token';
  static const _userKey = 'user-data';

  static UserModel? userModel;
  static String? accessToken;

  static Future<void> saveUserData(String token, UserModel model) async {
    // Write token and JSON-encoded user model to SharedPreferences
  }

  static Future<void> getUserData() async {
    // Read token and user model from SharedPreferences
  }

  static Future<bool> isLoggedIn() async {
    // Check if token exists in SharedPreferences
  }

  static Future<void> clearUserData() async {
    // Clear all SharedPreferences
  }
}
```

**Why static?** Token and user data need to be accessible from anywhere without context — the `getNetworkCaller()` factory uses `AuthController.accessToken` to build request headers.

#### 8.1.3 Provider Pattern (Auth)

All three auth providers (`SignInProvider`, `SignUpProvider`, `VerifyOTPProvider`) follow the exact same pattern:

```dart
class SignInProvider extends ChangeNotifier {
  bool _isSigninInProgress = false;   // Loading flag
  String? _errorMessage;              // Error message

  Future<bool> signIn(SignInParam params) async {
    _isSigninInProgress = true;
    notifyListeners();                // → UI shows spinner

    final response = await getNetworkCaller().postRequest(
      url: Urls.signInOtpUrl,
      body: params.toJson(),
    );

    if (response.isSuccess) {
      // Save token + user model
      await AuthController.saveUserData(token, userModel);
      _errorMessage = null;
      isSuccess = true;
    } else {
      _errorMessage = response.errorMessage;
    }

    _isSigninInProgress = false;
    notifyListeners();                // → UI hides spinner, shows data/error
    return isSuccess;
  }
}
```

#### 8.1.4 Screen Patterns (Auth)

All auth screens share these structural characteristics:

1. **GestureDetector wrapper** — dismisses keyboard on tap outside
2. **SingleChildScrollView + SafeArea** — handles keyboard overlap
3. **Form + GlobalKey<FormState>** — form validation
4. **TextEditingController per field** — controlled inputs
5. **Consumer<Provider> wrapping the submit button** — shows spinner while loading
6. **LanguageSelector + ThemeSelector in top-right row** — settings access
7. **RichText with TextSpan** — navigation links (e.g., "Don't have an account? Sign Up")
8. **SnackBar on error** — user feedback
9. **dispose() override** — clean up all controllers

**Sign In Screen Flow:**
```
User enters email + password
  → Form validates
  → _signIn()
    → SignInProvider.signIn(SignInParam)
      → POST /api/auth/login
      → On success: save token + UserModel → navigate to HomeScreen (clear stack)
      → On failure: show SnackBar with errorMessage
```

**Sign Up Screen Flow:**
```
User enters 6 fields (first name, last name, email, password, phone, address)
  → Form validates
  → _signUp()
    → SignUpProvider.signUp(SignUpParams)
      → POST /api/auth/signup
      → On success: navigate to VerifyOTPScreen (with email arg)
      → On failure: show SnackBar with errorMessage
```

**Verify OTP Screen Flow:**
```
User enters 4-digit OTP (PinCodeTextField)
  → Form validates
  → _verifyOTP()
    → VerifyOTPProvider.verifyOTP(VerifyOtpParam)
      → POST /api/auth/verify-otp
      → On success: navigate to SignInScreen (clear stack)
      → On failure: show SnackBar with errorMessage
```

### 8.2 Home Feature

#### 8.2.1 HomeScreen — The Main Dashboard

`HomeScreen` is the primary landing page after login/splash. It's a large widget composed of multiple sections:

```
┌─ AppBar ──────────────────────────────────────────────┐
│ [≡]  [Logo]                    [👤] [📞] [🔔]       │
├─ Drawer ──────────────────────────────────────────────┤
│  ThemeSelector                                        │
│  LanguageSelector                                     │
├─ Body ────────────────────────────────────────────────┤
│  🔍 ProductSearchField                                │
│                                                        │
│  🎠 HomeCarouselSlider (from HomeSliderProvider)       │
│    ● ● ○ ○ ● (dot indicators)                         │
│                                                        │
│  📰 SectionHeader: "Categories"       [See All]       │
│  [Cat1] [Cat2] [Cat3] [Cat4] ... (horizontal list)   │
│                                                        │
│  📰 SectionHeader: "Popular"          [See All]       │
│  [Cat1] [Cat2] [Cat3] [Cat4] ... (horizontal list)   │
│                                                        │
│  📰 SectionHeader: "Special"          [See All]       │
│  [Cat1] [Cat2] [Cat3] [Cat4] ... (horizontal list)   │
│                                                        │
│  📰 SectionHeader: "New Arrivals"     [See All]       │
│  [Cat1] [Cat2] [Cat3] [Cat4] ... (horizontal list)   │
└────────────────────────────────────────────────────────┘
```

**Important observation:** All four category sections (Categories, Popular, Special, New Arrivals) use the **same** `CategoryListProvider` and render the **same** data. The Popular, Special, and New Collection model files are empty stubs — their dedicated providers (`PopularProvider`, `SpecialProvider`, `NewCollectionProvider`) exist but are not used in `HomeScreen`. Only `CategoryListProvider` is consumed. This is a work-in-progress state.

#### 8.2.2 Home Widgets

**`HomeCarouselSlider`**
- Uses `carousel_slider` package
- `ValueNotifier<int>` tracks selected page index
- `ValueListenableBuilder` renders dot indicators
- Each slide is a `Container` with `NetworkImage` background

**`SectionHeader`**
- Row: `title` (Text) + Spacer + "See All" (TextButton)
- `onTapSeeAll` callback navigates to category tab

**`ProductSearchField`**
- `TextField` with search icon prefix
- Filled grey background, no border
- 🚫 Currently no-op (no search logic)

**`CircleIconButton`**
- `GestureDetector` wrapping `CircleAvatar`
- Used in AppBar for person, phone, notification icons

### 8.3 Category Feature

#### 8.3.1 CategoryModel

```dart
class CategoryModel {
  final String id;
  final String title;
  final String icon;    // URL to category icon image
}
```

#### 8.3.2 CategoryListProvider — Paginated Data Loading

This is one of the most important providers in the project as it demonstrates the **pagination pattern** used throughout:

```dart
class CategoryListProvider extends ChangeNotifier {
  final int _productCount = 30;
  int _currentPageNo = 0;         // Start at 0 (first fetch increments to 1)
  int? _lastPageNo;               // Set from API response
  bool _initialLoading = false;   // First load
  bool _loadingMoreProduct = false; // Subsequent loads
  List<CategoryModel> _categoryList = [];
  String? _errorMessage;

  Future<bool> fetchCategoryList() async {
    bool isSuccess = false;

    if (_currentPageNo == 0) {
      _categoryList.clear();
      _initialLoading = true;
    } else if (_currentPageNo < _lastPageNo!) {
      _loadingMoreProduct = true;
    } else {
      return false;  // Already on last page
    }
    notifyListeners();

    _currentPageNo++;
    final response = await getNetworkCaller().getRequest(
      url: Urls.categoryListUrl(_productCount, _currentPageNo),
    );

    if (response.isSuccess) {
      _lastPageNo ??= response.responseData['data']['last_page'];
      List<CategoryModel> list = [];
      for (Map<String, dynamic> json in response.responseData['data']['results']) {
        list.add(CategoryModel.fromJson(json));
      }
      _categoryList.addAll(list);
      isSuccess = true;
    } else {
      _errorMessage = response.errorMessage;
    }

    if (_initialLoading) {
      _initialLoading = false;
    } else {
      _loadingMoreProduct = false;
    }
    notifyListeners();
    return isSuccess;
  }

  Future<void> loadInitialCategoryList() async {
    _currentPageNo = 0;
    _lastPageNo = null;
    await fetchCategoryList();  // Will clear and re-fetch
  }
}
```

**Pagination Logic:**
1. `_currentPageNo` starts at 0
2. First call: detects `_currentPageNo == 0`, sets `_initialLoading = true`, clears list
3. Subsequent calls: checks `_currentPageNo < _lastPageNo` before fetching
4. `_currentPageNo` increments before the API call
5. `_lastPageNo` is set once from the first response (`??=`)
6. On reaching last page, `fetchCategoryList()` returns `false`

#### 8.3.3 CategoryListScreen

```
┌─ AppBar ──────────────────────────────────────────────┐
│ [←]  Categories                                        │
├─ Body ────────────────────────────────────────────────┤
│                                                        │
│ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐                  │
│ │Icon  │ │Icon  │ │Icon  │ │Icon  │  (GridView 4 cols)│
│ │Title │ │Title │ │Title │ │Title │                  │
│ └──────┘ └──────┘ └──────┘ └──────┘                  │
│ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐                  │
│ │Icon  │ │Icon  │ │Icon  │ │Icon  │                  │
│ │Title │ │Title │ │Title │ │Title │                  │
│ └──────┘ └──────┘ └──────┘ └──────┘                  │
│ ... (infinite scroll with pagination)                  │
│                                                        │
│ On scroll near bottom → fetchCategoryList()            │
│ While loading more → CenterCircularProgress            │
└────────────────────────────────────────────────────────┘
```

Key features:
- `PopScope(canPop: false)` — back button returns to Home tab (not pops screen)
- `ScrollController` listener triggers pagination when `_scrollController.position.extentBefore < 300`
- `Consumer<CategoryListProvider>` for reactive UI

### 8.4 Product Feature

#### 8.4.1 Data Models

**`ProductModel`** — Used in list views:
```dart
class ProductModel {
  final String id;
  final String title;
  final String photo;
  final int currentPrice;

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['_id'],
      title: json['title'],
      photo: json['photos'][0],  // ⚠️ Takes first photo (TODO: null-safety)
      currentPrice: json['current_price'],
    );
  }
}
```

**`ProductDetailsModel`** — Detailed view with all attributes:
```dart
class ProductDetailsModel {
  final String id;
  final String title;
  final String description;
  final List<String> photos;
  final List<String> colors;
  final List<String> sizes;
  final double price;
  final int quantity;
}
```

#### 8.4.2 ProductListByCategoryProvider — Paginated Products

Same pagination pattern as `CategoryListProvider`:
- `_pageSize = 30`, `_currentPageNo`, `_lastPageNo`
- `_initialLoading` / `_loadingMoreData`
- Accumulated `_productList`
- `fetchProductList(categoryId)` + `loadInitialProductList(categoryId)`

#### 8.4.3 ProductDetailsProvider — Single Product Fetch

Simpler provider (no pagination):
```dart
class ProductDetailsProvider extends ChangeNotifier {
  ProductDetailsModel? _productDetailsModel;
  bool _getProductDetailsInProgress = false;

  Future<bool> getProductDetails(String productId) async {
    // GET /products/id/{productId}
    // Parse response.responseData['data'] into ProductDetailsModel
  }
}
```

#### 8.4.4 Product Screens

**ProductListByCategoryScreen:**
```
┌─ AppBar ──────────────────────────────────────────────┐
│ [←]  {Category Title}                                  │
├─ Body ────────────────────────────────────────────────┤
│                                                        │
│ ┌──────┐ ┌──────┐ ┌──────┐                            │
│ │📷    │ │📷    │ │📷    │  (GridView 3 cols)         │
│ │Title │ │Title │ │Title │                            │
│ │$price│ │$price│ │$price│                            │
│ └──────┘ └──────┘ └──────┘                            │
│                                                        │
│ ... infinite scroll pagination                          │
└────────────────────────────────────────────────────────┘
```

Each card is a `ProductCard` wrapped in `FittedBox` for sizing.

**ProductDetailsScreen:**
```
┌─ AppBar ──────────────────────────────────────────────┐
│ [←]  Product Details                                   │
├─ Body ────────────────────────────────────────────────┤
│                                                        │
│ 🖼️ ProductImageSlider (carousel with dot indicators) │
│                                                        │
│ Product Title                          [➕ 1 ➖]       │
│ ⭐ 4.3    [Reviews]                    [❤️]           │
│                                                        │
│ Color                                                  │
│ [Red] [Blue] [Green] (color chips)                     │
│                                                        │
│ Size                                                   │
│ [S] [M] [L] [XL] (size chips)                          │
│                                                        │
│ Description                                            │
│ Lorem ipsum dolor sit amet...                          │
│                                                        │
├─ Bottom Bar ──────────────────────────────────────────┤
│ Price: ৳75,000                    [Add to Cart]       │
│ ─────────────────────────────────────────────────────  │
│ 🔒 Checks auth before adding to cart                   │
└────────────────────────────────────────────────────────┘
```

#### 8.4.5 Product Widgets

**`ColorPicker`** — StatefulWidget:
- List of color strings rendered as `Wrap` of `GestureDetector` chips
- Selected chip gets `AppColors.themeColor` background
- Calls `onchange(String)` callback on selection
- Uses local `setState()` for UI update (ephemeral state)

**`SizePicker`** — Identical pattern to `ColorPicker`:
- List of size strings rendered as chips
- Selected chip highlighted with theme color
- `onchange(String)` callback

**`ProductImageSlider`** — Same pattern as `HomeCarouselSlider`:
- `CarouselSlider` with `NetworkImage` items
- `ValueNotifier<int>` for selected index
- `Positioned` dot indicators at bottom

### 8.5 Cart Feature

#### 8.5.1 AddToCartProvider

```dart
class AddToCartProvider extends ChangeNotifier {
  bool _addToCartInProgress = false;
  String? _errorMessage;

  Future<bool> addToCart(String productId) async {
    // POST /api/cart with body: { "product": productId }
    // Returns isSuccess
  }
}
```

#### 8.5.2 CartScreen

Currently uses **hardcoded data** (item count hardcoded to 3, prices hardcoded):

```
┌─ AppBar ──────────────────────────────────────────────┐
│ [←]  Cart                                              │
├─ Body ────────────────────────────────────────────────┤
│                                                        │
│ ┌─────────────────────────────────────────────────┐   │
│ │ [📷]  Nike KH3434 - new arrival shoe     [🗑️]  │   │
│ │       Color: Black Size: XL                       │   │
│ │       ৳100                           [➕ 1 ➖]   │   │
│ └─────────────────────────────────────────────────┘   │
│                                                        │
│ ┌─────────────────────────────────────────────────┐   │
│ │ [📷]  ... (more items)                         │   │
│ └─────────────────────────────────────────────────┘   │
│                                                        │
├─ Bottom Bar ──────────────────────────────────────────┤
│ Total: ৳500                          [Checkout]       │
└────────────────────────────────────────────────────────┘
```

#### 8.5.3 Cart Widgets

**`CartItem`** — Stateless widget:
- `Card` with `Row`: image + details + delete button
- Details: title, color/size, price, `IncDecButton`
- Uses hardcoded data (no model binding yet)

**`IncDecButton`** — StatefulWidget:
- `_currentValue` starts at 1
- Min = 1, Max = `widget.maxValue`
- `-` button decrements, `+` button increments
- Calls `onChange(int)` callback on each change
- Uses local `setState()` for counter display

### 8.6 Wishlist Feature

**Status: ⚠️ Stub/Incomplete**

`WishListScreen` exists but:
- Uses hardcoded item count (10)
- Item builder returns `null` (no actual widgets rendered)
- No provider or model layer exists
- No API integration

### 8.7 Common/Shared Feature

#### 8.7.1 MainNavContainerProvider

```dart
class MainNavContainerProvider extends ChangeNotifier {
  int _selectedIndex = 0;       // 0=Home, 1=Category, 2=Cart, 3=Wishlist

  void changeIndex(int index) {
    if (_selectedIndex == index) return;  // No-op if same tab
    _selectedIndex = index;
    notifyListeners();
  }

  void changeToCategory() => changeIndex(1);  // Used by HomeScreen "See All"
  void changeToHome() => changeIndex(0);       // Used by back buttons
}
```

#### 8.7.2 MainNavHolderScreen — The App Shell

This is the root scaffold after authentication. It manages the `BottomNavigationBar` and hosts all 4 major screens:

```dart
class _MainNavHolderScreenState extends State<MainNavHolderScreen> {
  final List<Widget> _screens = [
    HomeScreen(),          // index 0
    CategoryListScreen(),  // index 1
    CartScreen(),          // index 2
    WishListScreen(),      // index 3
  ];

  @override
  void initState() {
    super.initState();
    // Pre-fetch data on app start
    context.read<CategoryListProvider>().fetchCategoryList();
    context.read<HomeSliderProvider>().getHomeSliders();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MainNavContainerProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          body: _screens[provider.selectedIndex],
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: provider.selectedIndex,
            onTap: (index) async {
              if (index == 2 || index == 3) {
                if (!await AuthController.isLoggedIn()) {
                  Navigator.pushNamed(context, SignUpScreen.name);
                  return;
                }
              }
              provider.changeIndex(index);
            },
            items: [Home, Categories, Cart, Wishlist],
          ),
        );
      },
    );
  }
}
```

#### 8.7.3 Common Widgets

**`ProductCard`** — Reusable product card:
```dart
class ProductCard extends StatelessWidget {
  final ProductModel productModel;

  // GestureDetector → onTap → Navigator.pushNamed(ProductDetailsScreen)
  // Shows: NetworkImage, title, price (৳), RatingView, FavouriteButton
}
```

**`CategoryCard`** — Reusable category card:
```dart
class CategoryCard extends StatelessWidget {
  final CategoryModel categoryModel;

  // GestureDetector → onTap → Navigator.pushNamed(ProductListByCategoryScreen)
  // Shows: Card with NetworkImage icon, Text title
  // Has errorBuilder for missing icons (shows error icon)
}
```

**`RatingView`** — Static star rating (hardcoded to 4.3):
```dart
// Wrap: star icon + Text("4.3")
```

**`FavouriteButton`** — Heart icon in a theme-colored card:
```dart
// Card with theme color bg + white heart icon
// ⚠️ No state — always shows "not favourited" icon
```

**`CenteredCircularProgress`** — Simple reusable spinner:
```dart
Center(child: CircularProgressIndicator())
```

**`ThemeSelector`** — DropdownMenu with 3 options (Light/Dark/System):
```dart
// Uses context.read<ThemeProvider>().changeTheme(theme!)
// Initial selection from ThemeProvider.currentThemeMode
```

**`LanguageSelector`** — DropdownMenu with 2 options (English/Bangla):
```dart
// Uses context.read<LanguageProvider>().changeLocale(Locale(language!))
// Initial selection from LanguageProvider.currentLocale.languageCode
```

---

## 9. Localization System

### 9.1 Architecture

- **Config file:** `lib/l10n/l10n.yaml`
  - `arb-dir: lib/l10n`
  - `template-arb-file: app_en.arb`
  - `output-localization-file: app_localizations.dart`
- **Supported locales:** `en` (English), `bn` (Bangla), `de` (German — declared in MaterialApp but no ARB file found)
- **Base class:** `AppLocalizations` (abstract, generated/manual)
- **Implementations:** `AppLocalizationsEn`, `AppLocalizationsBn`

### 9.2 How to Use

```dart
// Via extension (preferred)
import 'package:crafty_bay/app/extensions/localization_extension.dart';

Text(context.localizatons.login);
Text(context.localizatons.categories);
Text(context.localizatons.addToCart);

// Equivalent direct access
AppLocalizations.of(context)!.login;
```

### 9.3 Available String Keys (80+)

| Category | Keys |
|----------|------|
| General | `appTitle`, `ok`, `cancel`, `save`, `delete`, `edit`, `add`, `search`, `loading`, `error`, `retry`, `success` |
| Auth | `login`, `logout`, `register`, `signUp`, `email`, `password`, `forgotPassword`, `firstName`, `lastName`, `phoneNumber`, `address` |
| Navigation | `home`, `categories`, `cart`, `wishlist`, `profile`, `settings`, `notifications` |
| Product | `addToCart`, `buyNow`, `productDetails`, `description`, `price`, `quantity`, `rating`, `reviews` |
| Cart | `total`, `subtotal`, `deliveryFee`, `discount`, `checkout`, `cartEmpty` |
| Home | `searchProduct`, `featuredProducts`, `newArrivals`, `popular`, `special`, `seeAll` |
| Validation | `validationRequired`, `validationEmail`, `validationPhone`, `validationPasswordLength` |

### 9.4 LanguageProvider

```dart
class LanguageProvider extends ChangeNotifier {
  Locale _currentLocale = Locale("en");

  Future<void> loadInitialLanguage() async {
    _currentLocale = await _getLocale();  // Read SharedPreferences
    notifyListeners();
  }

  void changeLocale(Locale newLocale) {
    if (_currentLocale == newLocale) return;
    _currentLocale = newLocale;
    _saveLocale(_currentLocale.languageCode);  // Write SharedPreferences
    notifyListeners();
  }
}
```

---

## 10. Theme & Styling System

### 10.1 AppColors

Single file that defines the brand color:
```dart
class AppColors {
  static Color themeColor = Color(0XFF07ADAE);  // Teal
}
```

This color is used throughout the app for:
- Primary color in ThemeData
- Button backgrounds
- Active tab indicators
- Price text
- Favourite buttons
- Selected state in pickers
- Section header "See All" links
- Bottom price bars

### 10.2 AppTheme

Two theme modes with consistent configurations:

```dart
class AppTheme {
  static ThemeData get lightTheme => ThemeData(
    brightness: Brightness.light,
    primaryColor: AppColors.themeColor,
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        fixedSize: Size.fromWidth(double.maxFinite),  // Full-width buttons
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        backgroundColor: Colors.teal,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      hintStyle: TextStyle(color: Colors.grey),
      contentPadding: EdgeInsets.all(16),
      border: OutlineInputBorder(borderSide: BorderSide()),
      errorBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.red)),
    ),
  );

  static ThemeData get darkTheme => ThemeData(
    brightness: Brightness.dark,  // Everything else same as light
    // Same filledButtonTheme, same inputDecorationTheme
  );
}
```

### 10.3 ThemeProvider

```dart
class ThemeProvider extends ChangeNotifier {
  ThemeMode _currentThemeMode = ThemeMode.system;

  Future<void> loadInitialThemeMode() async {
    _currentThemeMode = await _getThemeMode();  // Read SharedPreferences
    notifyListeners();
  }

  Future<void> changeTheme(ThemeMode mode) async {
    if (currentThemeMode == ThemeMode.system && _currentThemeMode == mode) {
      // Toggle to system removes saved preference
      SharedPreferences pref = await SharedPreferences.getInstance();
      pref.remove(_themeKey);
      return;
    }
    _currentThemeMode = mode;
    _saveThemeMode(mode.name);  // Write 'light', 'dark', or 'system'
    notifyListeners();
  }
}
```

---

## 11. Authentication & Authorization Flow

### 11.1 Complete Auth Flow Diagram

```
App Launch
    │
    ▼
SplashScreen (3s delay)
    │
    ├── AuthController.getUserData()  ← reads SharedPreferences
    │
    ├── Token exists? ──yes──► MainNavHolderScreen (authenticated)
    │
    └── No token ──► MainNavHolderScreen still loads
                      (but cart/wishlist tabs show auth guard)

    ┌──────────────────────────────────────────────┐
    │           INSIDE MAIN NAV HOLDER              │
    │                                                │
    │  HomeScreen ──► "Add to Cart" ───►            │
    │    │            AuthController.isLoggedIn()?   │
    │    │              ├── yes → Add to cart        │
    │    │              └── no  → SignUpScreen       │
    │    │                                           │
    │  CartTab ──► AuthController.isLoggedIn()?     │
    │    │          ├── yes → Show cart              │
    │    │          └── no  → SignUpScreen           │
    │    │                                           │
    │  WishlistTab ──► same guard as Cart           │
    └──────────────────────────────────────────────┘

    ┌──────────────────────────────────────────────┐
    │           REGISTRATION FLOW                   │
    │                                                │
    │  SignUpScreen (6 fields)                      │
    │    │                                           │
    │    ├── POST /auth/signup                       │
    │    │    ├── success → VerifyOTPScreen(email)   │
    │    │    └── fail    → SnackBar(error)          │
    │    │                                           │
    │    ▼                                           │
    │  VerifyOTPScreen (4-digit OTP)                 │
    │    │                                           │
    │    ├── POST /auth/verify-otp                   │
    │    │    ├── success → SignInScreen             │
    │    │    └── fail    → SnackBar(error)          │
    │    │                                           │
    │    ▼                                           │
    │  SignInScreen (email + password)               │
    │    │                                           │
    │    ├── POST /auth/login                        │
    │    │    ├── success → save token + user        │
    │    │    │          → navigate to HomeScreen    │
    │    │    └── fail    → SnackBar(error)          │
    └──────────────────────────────────────────────┘
```

### 11.2 Token Management

| Action | What happens |
|--------|-------------|
| **Sign in success** | `AuthController.saveUserData(token, userModel)` → writes to `SharedPreferences['access-token']` + `SharedPreferences['user-data']` |
| **App restart** | `AuthController.getUserData()` (in SplashScreen) → reads from SharedPreferences → restores `accessToken` + `userModel` |
| **Every API call** | `getNetworkCaller()` reads `AuthController.accessToken` → includes in request header |
| **Logout** | `AuthController.clearUserData()` → clears all SharedPreferences |

### 11.3 API Request Headers

Every request carries:
```json
{
  "Content-type": "application/json",
  "token": "eyJhbGciOiJIUzI1NiIs..."
}
```

---

## 12. Pagination Strategy

### 12.1 How Pagination Works

The project uses **cursor-based pagination** via page numbers (1-based) with configurable page size. Two providers implement this: `CategoryListProvider` and `ProductListByCategoryProvider`.

```
Initial State:
  _currentPageNo = 0
  _lastPageNo = null
  _categoryList = []

First fetch:
  _currentPageNo = 0 → detected as first load
    → set _initialLoading = true
    → _currentPageNo becomes 1
    → GET /api/categories?count=30&page=1
    → _lastPageNo = response.data.last_page (e.g., 5)
    → _categoryList = [items from page 1]
    → _initialLoading = false

Scroll near bottom (extentBefore < 300):
    → check _currentPageNo (1) < _lastPageNo (5) → true
    → set _loadingMoreProduct = true
    → _currentPageNo becomes 2
    → GET /api/categories?count=30&page=2
    → _categoryList.addAll([items from page 2])
    → _loadingMoreProduct = false

... continues until _currentPageNo >= _lastPageNo

Last page:
    → _currentPageNo (5) >= _lastPageNo (5) → return false (no more data)
```

### 12.2 Scroll Detection

```dart
void _loadMoreData() {
  if (provider.moreLoading) return;  // Already loading

  if (_scrollController.position.extentBefore < 300) {
    // User is near the bottom (300px threshold)
    provider.fetchCategoryList();  // or fetchProductList()
  }
}
```

### 12.3 Reset Pattern

```dart
Future<void> loadInitialCategoryList() async {
  _currentPageNo = 0;    // Reset to initial state
  _lastPageNo = null;     // Clear last page info
  await fetchCategoryList();  // Will start fresh
}
```

---

## 13. Error Handling Strategy

### 13.1 Network Errors

| Error Source | Handling |
|-------------|----------|
| HTTP 4xx/5xx | Parsed in `NetworkCaller`, returned as `NetworkResponse(errorMessage: decodedData['msg'])` |
| HTTP 401 | `onUnauthorize()` callback invoked + error response returned (callback is currently empty) |
| Network timeout/exception | Caught in `NetworkCaller`, returns `NetworkResponse(isSuccess: false, responseCode: -1, errorMessage: exception.toString())` |
| API success but bad JSON | Exception propagates to Flutter error handlers (Crashlytics) |

### 13.2 UI Error Handling

```dart
// In provider:
if (response.isSuccess) {
  // parse data, set _errorMessage = null
} else {
  _errorMessage = response.errorMessage;  // Store for UI
}

// In screen (callback):
Future<void> _someAction() async {
  final bool isSuccess = await _provider.someMethod();
  if (isSuccess) {
    Navigator.pushNamed(context, NextScreen.name);
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_provider.errorMessage!)),
    );
  }
}
```

### 13.3 Global Error Handling (main.dart)

```dart
// Flutter framework errors (widget build failures)
FlutterError.onError = (errorDetails) {
  FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
};

// Unhandled async errors (platform channel errors, etc.)
PlatformDispatcher.instance.onError = (error, stack) {
  FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  return true;  // Don't crash the app
};
```

---

## 14. Form Handling Patterns

### 14.1 Standard Form Structure

Every form in the app follows this exact pattern:

```dart
class SomeScreen extends StatefulWidget { ... }

class _SomeScreenState extends State<SomeScreen> {
  // 1. Controllers for each field
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // 2. Form key for validation
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // 3. Provider instance (screen-scoped)
  final SignInProvider _provider = SignInProvider();  // or any other provider

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),  // Dismiss keyboard
      child: ChangeNotifierProvider(                   // Provide to subtree
        create: (context) => _provider,
        child: Scaffold(
          body: SingleChildScrollView(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    spacing: 10,
                    children: [
                      // ... form fields ...

                      // Submit button with loading state
                      Consumer<SignInProvider>(
                        builder: (context, provider, _) {
                          return Visibility(
                            visible: !provider.isLoading,
                            replacement: CircularProgressIndicator(),
                            child: FilledButton(
                              onPressed: _onSubmit,
                              child: Text(context.localizatons.submit),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 4. Submit handler
  void _onSubmit() {
    if (_formKey.currentState!.validate()) {
      _performAction();
    }
  }

  Future<void> _performAction() async {
    final bool isSuccess = await _provider.someMethod(/* params */);
    if (isSuccess) {
      Navigator.pushNamed(context, NextScreen.name);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_provider.errorMessage!)),
      );
    }
  }

  // 5. Cleanup
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
```

### 14.2 Form Validation

```dart
TextFormField(
  controller: _emailController,
  decoration: InputDecoration(
    hintText: context.localizatons.emailHint,
  ),
  validator: (String? value) {
    if (value?.trim().isEmpty ?? true) {
      return context.localizatons.emailHint;  // Error message
    }
    return null;  // Valid
  },
)
```

---

## 15. Widget Tree Breakdowns

### 15.1 MainNavHolderScreen (Full App Shell)

```
MaterialApp
  └── MultiProvider (5 global providers)
      └── Consumer<LanguageProvider>
          └── Consumer<ThemeProvider>
              └── Navigator
                  └── SplashScreen (initial route)
                  └── MainNavHolderScreen
                      └── Consumer<MainNavContainerProvider>
                          └── Scaffold
                              ├── body: IndexedStack or list[_selectedIndex]
                              │   ├── [0] HomeScreen
                              │   │   └── Scaffold
                              │   │       ├── AppBar
                              │   │       └── SingleChildScrollView
                              │   │           ├── ProductSearchField
                              │   │           ├── Consumer<HomeSliderProvider>
                              │   │           │   └── HomeCarouselSlider
                              │   │           ├── SectionHeader("Categories")
                              │   │           │   └── Consumer<CategoryListProvider>
                              │   │           │       └── ListView.builder → CategoryCard[]
                              │   │           ├── SectionHeader("Popular")
                              │   │           ├── SectionHeader("Special")
                              │   │           └── SectionHeader("New Arrivals")
                              │   │
                              │   ├── [1] CategoryListScreen
                              │   │   └── Consumer<CategoryListProvider>
                              │   │       └── GridView.builder → CategoryCard[]
                              │   │
                              │   ├── [2] CartScreen
                              │   │   └── Column
                              │   │       ├── Expanded → ListView → CartItem[]
                              │   │       └── Bottom price bar
                              │   │
                              │   └── [3] WishListScreen (stub)
                              │
                              └── BottomNavigationBar (4 items)
```

### 15.2 ProductDetailsScreen

```
Scaffold
  ├── AppBar("Product Details")
  └── MultiProvider
      ├── ChangeNotifierProvider(ProductDetailsProvider)
      └── ChangeNotifierProvider(AddToCartProvider)
      └── Consumer<ProductDetailsProvider>
          └── Column
              ├── Expanded
              │   └── SingleChildScrollView
              │       └── Column
              │           ├── ProductImageSlider
              │           │   └── Stack
              │           │       ├── CarouselSlider → Container[].NetworkImage
              │           │       └── Positioned → ValueListenableBuilder → dot indicators
              │           │
              │           └── Padding
              │               └── Column
              │                   ├── Row: Title + IncDecButton
              │                   ├── Row: RatingView + Reviews + FavouriteButton
              │                   ├── Text("Color") + ColorPicker
              │                   ├── Text("Size") + SizePicker
              │                   └── Text("Description") + description text
              │
              └── Container (bottom bar)
                  └── Row
                      ├── Column: "Price" text + taka amount
                      └── Consumer<AddToCartProvider>
                          └── FilledButton("Add to Cart")
```

---

## 16. Code Conventions & Style Guide

### 16.1 Naming Conventions

| Element | Convention | Example |
|---------|-----------|---------|
| Files | `snake_case` | `product_details_screen.dart` |
| Classes | `PascalCase` | `ProductDetailsScreen` |
| Methods/Functions | `camelCase` | `fetchCategoryList()` |
| Private fields | `_camelCase` | `_isLoading` |
| Private methods | `_camelCase` | `_logRequest()` |
| Constants | `camelCase` (static) | `static const takaSign` |
| Enums/static route names | `camelCase` | `static const name = '/product-details'` |
| Type aliases | `PascalCase` | `NetworkResponse` |

### 16.2 Import Order

```
1. dart: imports (dart:convert, dart:ui)
2. package: imports (flutter, provider, http)
3. package:crafty_bay imports (app/, core/, features/)
   (ordered by proximity: same feature → common → app → core)
```

### 16.3 File Structure per Dart File

```dart
// 1. Imports (grouped)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../provider/my_provider.dart';

// 2. Class definitions (one main class per file)
class MyScreen extends StatefulWidget { ... }
class _MyScreenState extends State<MyScreen> { ... }

// 3. Private helper classes at bottom if needed
```

### 16.4 Widget Conventions

- **StatelessWidget** preferred unless local ephemeral state is needed
- **`const` constructors** for widgets when possible
- **`super.key`** parameter in all widget constructors
- **Named parameters** with `required` for non-optional data
- **`final`** for all constructor parameters
- **Callbacks** typed as `Function(ParamType)` or `VoidCallback`

```dart
class MyWidget extends StatelessWidget {
  const MyWidget({super.key, required this.title, this.onTap});

  final String title;
  final VoidCallback? onTap;
}
```

### 16.5 Provider Conventions

- Private fields with public getters (read-only from outside)
- `bool _loading` → `bool get loading`
- `List<T> _items` → `List<T> get items`
- `String? _errorMessage` → `String? get errorMessage`
- `notifyListeners()` called before and after async work
- Returns `Future<bool>` for success/failure

---

## 17. Dependencies Reference

### 17.1 Production Dependencies

| Package | Version | Purpose | Where Used |
|---------|---------|---------|------------|
| `flutter` | SDK | UI framework | Everywhere |
| `flutter_localizations` | SDK | i18n | `app.dart` delegates |
| `cupertino_icons` | ^1.0.8 | iOS icons | Optional |
| `firebase_core` | ^4.3.0 | Firebase init | `main.dart` |
| `firebase_crashlytics` | ^5.0.6 | Error reporting | `main.dart` crash handlers |
| `firebase_analytics` | ^12.1.0 | Analytics | Firebase setup |
| `intl` | ^0.20.2 | Internationalization | Localization files |
| `provider` | ^6.1.5+1 | State management | Every screen + provider |
| `shared_preferences` | ^2.5.4 | Local storage | Auth, Theme, Language persistence |
| `flutter_svg` | ^2.2.3 | SVG rendering | `AppLogoWidget`, nav logo |
| `pin_code_fields` | ^8.0.1 | OTP input | `VerifyOTPScreen` |
| `carousel_slider` | ^5.1.1 | Image carousel | `HomeCarouselSlider`, `ProductImageSlider` |
| `http` | ^1.5.0 | HTTP client | `NetworkCaller` |
| `logger` | ^2.6.1 | Logging | `NetworkCaller` request/response logging |

### 17.2 Dev Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| `flutter_test` | SDK | Unit/widget testing |
| `flutter_lints` | ^6.0.0 | Lint rules |

---

## 18. Firebase Integration

### 18.1 Initialization

```dart
await Firebase.initializeApp();  // Uses DefaultFirebaseOptions.currentPlatform
```

The `firebase_options.dart` provides platform-specific configuration for:
- Web
- Android
- iOS
- macOS
- Windows
- Linux

### 18.2 Crashlytics — Two Levels of Error Capture

```dart
// Level 1: Flutter framework errors (widget build failures, assert failures)
FlutterError.onError = (errorDetails) {
  FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
};

// Level 2: Unhandled async errors (platform channel errors, timer callbacks)
PlatformDispatcher.instance.onError = (error, stack) {
  FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  return true;  // Prevents the Dart runtime from killing the isolate
};
```

---

## 19. Adding New Features — Step-by-Step Recipe

### 19.1 New Screen with API Data

```
Step 1: Create data model
  └── features/<feature>/data/models/<model>.dart
  └── class + fromJson() + toJson()

Step 2: Create provider
  └── features/<feature>/providers/<provider>.dart
  └── extends ChangeNotifier
  └── loading state, data list, error message
  └── fetchData() → NetworkCaller → parse → notifyListeners

Step 3: Create screen
  └── features/<feature>/presentation/screens/<screen>.dart
  └── StatefulWidget + static const name
  └── Provider instance + ChangeNotifierProvider wrapper
  └── Consumer<Provider> + Form/ListView/etc.
  └── dispose() controllers

Step 4: Register route
  └── app/app_routes.dart → add if/else for setting.name
  └── Extract arguments, pass to screen constructor

Step 5: Add API URL
  └── app/urls.dart → add constant or method

Step 6: Register provider (if global)
  └── app/app.dart → add to MultiProvider list
```

### 19.2 New Reusable Widget

```
  └── If shared across features → features/common/presentation/widgets/
  └── If feature-specific → features/<feature>/presentation/widgets/
  └── Prefer StatelessWidget
  └── Accept data via required constructor params
  └── Expose callbacks via Function params
```

### 19.3 New Provider

```
Global (app-wide state):
  └── Add ChangeNotifierProvider to MultiProvider in app/app.dart
  └── Example: LanguageProvider, ThemeProvider

Screen-scoped (local state):
  └── Create instance in StatefulWidget State as field
  └── Wrap build tree in ChangeNotifierProvider(create: (_) => _provider)
  └── Example: SignInProvider, ProductDetailsProvider
```

### 19.4 New Localized String

```
1. Add getter to AppLocalizations (app_localizations.dart)
2. Add override to AppLocalizationsEn (app_localizations_en.dart)
3. Add override to AppLocalizationsBn (app_localizations_bn.dart)
4. Use in code: context.localizatons.yourKey
```

---

## 20. Known Limitations & TODOs

### 20.1 Code TODOs

| Location | Issue |
|----------|-------|
| `lib/app/setup_network_caller.dart:12` | `onUnauthorize` callback is empty — should navigate to SignInScreen |
| `lib/app/urls.dart` | `homeSlidersUrl` has a commented-out line with a different URL pattern |
| `lib/features/product/data/models/product_model.dart:19` | `photos[0]` — no null-safety if photos list is empty |
| `lib/core/services/network_caller.dart:57` | `decodedErrorMSGKey` — propose a solution to make component independent |

### 20.2 Incomplete Features

| Feature | Status |
|---------|--------|
| `PopularModel`, `SpecialModel`, `NewCollectionModel` | Empty files — not implemented |
| `PopularProvider`, `SpecialProvider`, `NewCollectionProvider` | Files exist but separate providers not used in HomeScreen |
| `VerifyEmailScreen` | Empty file |
| `WishListScreen` | Stub with hardcoded data, no items rendered |
| `CartScreen` | Uses hardcoded data (3 items, ৳500 total) |
| `CartItem` | Uses hardcoded data, no model binding |
| `ProductSearchField` | No search logic — visual only |
| `ForgotPassword` button | No-op (empty callback) |
| Backend 401 handling | `onUnauthorize` → no navigation to login |
| `RatingView` | Hardcoded to 4.3 stars |
| `FavouriteButton` | No toggle state — always shows unfilled heart |

### 20.3 Architectural Observations

| Observation | Detail |
|-------------|--------|
| **Duplicate provider instances** | `CategoryListProvider` is registered twice in `app.dart` (lines 33-34) |
| **Shared data for different sections** | HomeScreen's Popular, Special, New Arrivals all use the same `CategoryListProvider` data instead of dedicated providers/models |
| **German locale declared but no ARB** | `supportedLocales` includes `de` but no `app_localizations_de.dart` |
| **Screen-scoped vs global inconsistency** | `CategoryListProvider` is global (registered in MultiProvider) but `ProductListByCategoryProvider` is screen-scoped — both fetch similar paginated data |
| **Typo in folder name** | `cart/presentaton/` should be `presentation/` (missing 'i') |
| **Typo in filename** | `prodcut_details_provider.dart` should be `product_details_provider.dart` |

---

> **End of Architecture Guide**
>
> This document covers 100% of the project's source files. Use it as a reference for
> understanding the existing codebase or as a blueprint for building similar Flutter
> applications following the same patterns and conventions.
