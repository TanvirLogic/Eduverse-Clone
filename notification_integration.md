# Notification Integration Flow

## Overview

This document describes three notification strategies for a Flutter app with a custom backend:

1. **Local Notifications** — App triggers its own notifications (foreground + background polling)
2. **FCM Push Notifications** — Backend sends instant notifications via Firebase Cloud Messaging
3. **Progress Notifications** — Shows upload progress in the system notification tray

---

## 1. Local Notification Flow (Already Implemented)

### 1.1 Foreground Timer

```
┌──────────────────────┐
│   Flutter App         │
│   (Foreground)        │
│                       │
│  Timer.periodic(1min) │
│       │               │
│       ▼               │
│  flutter_local_       │
│  notifications.show() │
│       │               │
│       ▼               │
│   System Notification │
│   Tray                │
└──────────────────────┘
```

- Timer fires every 1 minute while app is visible
- Calls `FlutterLocalNotificationsPlugin.show()`
- Notification appears immediately

### 1.2 Background Task (WorkManager)

```
┌─────────────────────────┐       ┌─────────────────┐
│   Flutter App            │       │   Android/iOS   │
│   (Killed / Background)  │       │   OS            │
│                          │       │                 │
│   WorkManager            │◄──────│ Every ~15 min   │
│   callbackDispatcher()   │       │ (Android min)   │
│       │                  │       │                 │
│       ▼                  │       │                 │
│   flutter_local_         │       │                 │
│   notifications.show()   │──────►│  Notification   │
│                          │       │  in Tray        │
└─────────────────────────┘       └─────────────────┘
```

- `Workmanager().registerPeriodicTask()` at app startup
- OS wakes the app at the scheduled interval
- `callbackDispatcher()` runs in a **separate Dart isolate**
- It must re-initialize `FlutterLocalNotificationsPlugin` inside the callback
- It shows the notification, then the isolate is destroyed

### 1.3 Polling Your Backend via WorkManager

```
┌─────────────┐     ┌─────────────────┐     ┌──────────────┐
│ Your Backend│     │   Flutter App    │     │  Device OS   │
│ ─────────── │     │ (WorkManager)    │     │              │
│              │     │                  │     │              │
│  API Endpoint│◄────│ Every ~15 min    │     │              │
│  /notifica-  │     │ GET request      │     │              │
│  tions       │─────│                  │     │              │
│              │ JSON│ Parse response   │     │              │
│              │     │       │          │     │              │
│              │     │       ▼          │     │              │
│              │     │ Show via         │────►│  Notification│
│              │     │ flutter_local_   │     │  in Tray     │
│              │     │ notifications    │     │              │
└─────────────┘     └─────────────────┘     └──────────────┘
```

**Code pattern** (inside `callbackDispatcher`):

```dart
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    final notificationsPlugin = FlutterLocalNotificationsPlugin();
    await notificationsPlugin.initialize(/* ... */);

    // Poll your backend
    final response = await http.get(
      Uri.parse('https://your-backend.com/api/notifications?token=DEVICE_TOKEN'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List;
      for (final item in data) {
        await notificationsPlugin.show(
          item['id'],
          item['title'],
          item['body'],
          /* NotificationDetails */,
        );
      }
      // Tell backend these are delivered
      await http.post(
        Uri.parse('https://your-backend.com/api/notifications/ack'),
        body: {'ids': data.map((e) => e['id']).toList()},
      );
    }
    return Future.value(true);
  });
}
```

**Limitations:**
- Minimum 15 minute interval on Android (enforced by OS)
- iOS timing is unpredictable (managed by BGTaskScheduler)
- Not instant — best effort polling

---

## 2. FCM Push Notification Flow (Recommended for Instant Delivery)

### 2.1 Registration Flow

```
┌──────────────┐          ┌──────────────┐          ┌──────────────┐
│  Flutter App  │          │  FCM Server   │          │ Your Backend │
│              │          │              │          │              │
│  App starts  │          │              │          │              │
│       │      │          │              │          │              │
│       ▼      │          │              │          │              │
│  firebase_   │          │              │          │              │
│  messaging   │          │              │          │              │
│  .getToken() │─────────►│  Return      │          │              │
│              │◄────────│  Device       │          │              │
│              │  Token   │  Token       │          │              │
│       │      │          │              │          │              │
│       ▼      │          │              │          │              │
│  POST /api/  │─────────►│              │─────────►│  Store token │
│  register    │          │              │          │  in DB      │
│  {token}     │          │              │          │              │
└──────────────┘          └──────────────┘          └──────────────┘
```

### 2.2 Push Notification Delivery

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│ Your Backend  │     │  FCM Server   │     │  Device OS    │     │  Flutter App │
│              │     │              │     │              │     │              │
│  Event       │     │              │     │              │     │              │
│  occurs      │     │              │     │              │     │              │
│  (video      │     │              │     │              │     │              │
│   uploaded)  │     │              │     │              │     │              │
│       │      │     │              │     │              │     │              │
│       ▼      │     │              │     │              │     │              │
│  POST https  │     │              │     │              │     │              │
│  ://fcm.     │────►│              │     │              │     │              │
│  googleapis  │     │              │     │              │     │              │
│  .com/send   │     │              │     │              │     │              │
│  {           │     │              │     │              │     │              │
│   token,     │     │              │     │              │     │              │
│   notifica-  │     │              │     │              │     │              │
│   tion,      │     │    Forward   │     │              │     │              │
│   data       │     │──────────────►    │              │     │              │
│  }           │     │              │     │              │     │              │
│              │     │              │     │  OS shows    │     │              │
│              │     │              │     │  notification│     │              │
│              │     │              │     │  in tray     │     │              │
│              │     │              │     │  (even if    │     │              │
│              │     │              │     │  app killed) │     │              │
│              │     │              │     │       │      │     │              │
│              │     │              │     │  If app      │     │              │
│              │     │              │     │  running:    │────►│  onMessage() │
│              │     │              │     │  deliver to  │     │  callback   │
│              │     │              │     │  Dart        │     │              │
│              │     │              │     │  If killed:  │     │              │
│              │     │              │     │  on tap,     │────►│  onMessage  │
│              │     │              │     │  launch app  │     │  OpenedApp()│
└──────────────┘     └──────────────┘     └──────────────┘     └──────────────┘
```

### 2.3 Backend FCM HTTP Request

Your backend sends this POST (no Firebase SDK needed):

```http
POST https://fcm.googleapis.com/v1/projects/YOUR_PROJECT_ID/messages:send
Content-Type: application/json
Authorization: Bearer YOUR_FCM_SERVER_KEY

{
  "message": {
    "token": "DEVICE_TOKEN_FROM_APP",
    "notification": {
      "title": "Video Upload Complete",
      "body": "Your video has been processed"
    },
    "data": {
      "type": "video_complete",
      "videoId": "12345"
    },
    "android": {
      "priority": "high",
      "notification": {
        "channel_id": "high_importance_channel"
      }
    }
  }
}
```

### 2.4 Required Flutter Packages

```yaml
dependencies:
  firebase_core: ^3.0.0
  firebase_messaging: ^15.0.0
  flutter_local_notifications: ^18.0.1
```

### 2.5 Flutter App Registration Code

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  final messaging = FirebaseMessaging.instance;

  // Request permission (iOS)
  await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  // Get device token
  final token = await messaging.getToken();
  // Send token to your backend
  await http.post(
    Uri.parse('https://your-backend.com/api/register-device'),
    body: {'token': token},
  );

  // Handle foreground messages
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    // Show local notification while app is in foreground
    flutterLocalNotificationsPlugin.show(
      message.hashCode,
      message.notification?.title,
      message.notification?.body,
      /* NotificationDetails */,
    );
  });

  // Handle notification tap when app was killed
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    // Navigate to relevant screen
  });

  runApp(const MyApp());
}
```

---

## 3. Progress Notification Flow

Shows upload percentage in the system notification tray and allows user to see progress without opening the app.

```
┌──────────────┐          ┌──────────────┐
│  Flutter App  │          │  Notification │
│              │          │  Tray         │
│              │          │               │
│  User taps   │          │               │
│  "Upload     │          │               │
│  Video"      │          │               │
│       │      │          │               │
│       ▼      │          │               │
│  Show        │──────1──►│ [=====     ]  │
│  notification│          │ Uploading: 50%│
│  with        │          │               │
│  progress=0  │          │               │
│       │      │          │               │
│       ▼      │          │               │
│  Upload to   │          │               │
│  backend     │          │               │
│  (HTTP)      │          │               │
│       │      │          │               │
│  On progress │          │               │
│  callback:   │──────2──►│ [========  ]  │
│  update      │          │ Uploading: 80%│
│  notification│          │               │
│  with new %  │          │               │
│       │      │          │               │
│       ▼      │          │               │
│  On complete │          │               │
│  update to   │──────3──►│ ✅ Upload     │
│  "Complete"  │          │    Complete    │
│  + auto-     │          │ (auto-dismiss) │
│  dismiss     │          │               │
└──────────────┘          └──────────────┘
```

### 3.1 Flutter Code for Progress Notifications

```dart
const String progressChannelId = 'upload_channel';
const String progressChannelName = 'Upload Progress';

/// Start upload and show progress notification
Future<void> startUpload(String filePath) async {
  final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;

  // Show initial notification with progress = 0
  await flutterLocalNotificationsPlugin.show(
    notificationId,
    'Uploading Video',
    'Starting upload...',
    NotificationDetails(
      android: AndroidNotificationDetails(
        progressChannelId,
        progressChannelName,
        channelDescription: 'Video upload progress',
        importance: Importance.low,
        priority: Priority.defaultPriority,
        showProgress: true,        // Enable progress bar
        maxProgress: 100,          // Total = 100%
        progress: 0,               // Current progress
        indeterminate: false,      // Determinate progress
        onlyAlertOnce: true,       // Don't re-alert on update
      ),
    ),
  );

  // Upload with progress tracking
  final httpClient = http.Client();
  final request = http.MultipartRequest('POST',
    Uri.parse('https://your-backend.com/api/upload'));

  request.files.add(await http.MultipartFile.fromPath('video', filePath));

  // Track bytes sent
  final totalBytes = File(filePath).lengthSync();
  int sentBytes = 0;

  final response = await httpClient.send(request);
  final stream = response.stream.transform(
    StreamTransformer.fromHandlers(handleData: (data, sink) {
      sentBytes += data.length;
      final progress = ((sentBytes / totalBytes) * 100).round();

      // Update notification with progress
      flutterLocalNotificationsPlugin.show(
        notificationId,
        'Uploading Video',
        '$progress%',
        NotificationDetails(
          android: AndroidNotificationDetails(
            progressChannelId,
            progressChannelName,
            showProgress: true,
            maxProgress: 100,
            progress: progress,
            indeterminate: false,
            onlyAlertOnce: true,
          ),
        ),
      );

      sink.add(data);
    }),
  ).toList();

  // Upload complete — show "Done" notification and dismiss after 2s
  await flutterLocalNotificationsPlugin.show(
    notificationId,
    'Upload Complete',
    '✅ Video uploaded successfully',
    NotificationDetails(
      android: AndroidNotificationDetails(
        progressChannelId,
        progressChannelName,
        importance: Importance.high,
        priority: Priority.high,
        onlyAlertOnce: true,
      ),
    ),
  );

  // Auto-dismiss after 2 seconds
  Future.delayed(const Duration(seconds: 2), () {
    flutterLocalNotificationsPlugin.cancel(notificationId);
  });
}
```

---

## 4. Combined Architecture (Recommended)

```
┌──────────────────────────────────────────────────────────────┐
│                   YOUR BACKEND                                │
│                                                              │
│  ┌─────────────┐  ┌──────────────┐  ┌───────────────────┐   │
│  │ Push via FCM │  │ Polling API  │  │ Upload Endpoint   │   │
│  │ (instant)    │  │ /api/        │  │ /api/upload       │   │
│  │              │  │ notifications│  │ (returns progress)│   │
│  └──────┬───────┘  └──────┬───────┘  └────────┬──────────┘   │
│         │                 │                    │              │
└─────────┼─────────────────┼────────────────────┼──────────────┘
          │                 │                    │
          ▼                 ▼                    ▼
┌──────────────────────────────────────────────────────────────┐
│                    FLUTTER APP                                │
│                                                              │
│  ┌─────────────────┐  ┌──────────────┐  ┌───────────────┐   │
│  │ firebase_        │  │ WorkManager  │  │ flutter_local_ │   │
│  │ messaging        │  │ (fallback)   │  │ notifications  │   │
│  │ (instant push)   │  │ ~15 min      │  │ (display)      │   │
│  └────────┬────────┘  └──────┬───────┘  └───────┬────────┘   │
│           │                  │                   │           │
└───────────┼──────────────────┼───────────────────┼───────────┘
            │                  │                   │
            ▼                  ▼                   ▼
┌──────────────────────────────────────────────────────────────┐
│                    DEVICE OS                                  │
│                                                              │
│  ┌──────────────────────────────────────────────────┐        │
│  │              SYSTEM NOTIFICATION TRAY             │        │
│  │                                                   │        │
│  │  ┌──────────────────────────────────────┐         │        │
│  │  │ 🔔 Upload Progress  [========  ] 80% │         │        │
│  │  │ 🔔 Video Complete                     │         │        │
│  │  │ 🔔 New Message from Server            │         │        │
│  │  └──────────────────────────────────────┘         │        │
│  └──────────────────────────────────────────────────┘        │
└──────────────────────────────────────────────────────────────┘
```

### 4.1 Decision Flow

```
                  ┌──────────────┐
                  │  Event       │
                  │  Occurs      │
                  └──────┬───────┘
                         │
              ┌──────────▼──────────┐
              │  App is running?    │
              └──────┬──────┬───────┘
                  Yes│      │No
                     │      │
              ┌──────▼┐  ┌─▼──────────┐
              │ Show   │  │ App is     │
              │ local  │  │ killed?    │
              │ notif  │  └──┬────┬────┘
              └───────┘  Yes│    │No
                           │    │
                    ┌──────▼┐ ┌─▼────────┐
                    │ FCM   │ │ WorkMgr  │
                    │ Push  │ │ Polling  │
                    │──► OS │ │──► Check │
                    │ shows │ │  backend │
                    │ notif │ │  API     │
                    └───────┘ └──────────┘
```

---

## 5. Summary Table

| Requirement | Local Timer | WorkManager Poll | FCM Push |
|-------------|:-----------:|:----------------:|:--------:|
| Instant notification (foreground) | ✅ 1 min | ❌ | ✅ |
| Instant notification (background) | ❌ | ❌ (~15 min) | ✅ |
| Instant notification (killed) | ❌ | ❌ (~15 min) | ✅ |
| Progress bar in tray | ✅ | ❌ | ❌ |
| Works when app killed | ❌ | ✅ (~15 min) | ✅ |
| Backend triggers delivery | ❌ | ✅ (via polling) | ✅ |
| No Firebase dependency | ✅ | ✅ | ❌ needs FCM |

---

## 6. Recommended Implementation Path

### Phase 1 (Current App — Already Done)
- ✅ Local notifications via `flutter_local_notifications`
- ✅ Foreground timer (1 min interval)
- ✅ Background WorkManager polling pattern

### Phase 2 (Add FCM Push)
- Add `firebase_core`, `firebase_messaging`
- Create Firebase project
- Add `google-services.json` / `GoogleService-Info.plist`
- Register device token with your backend
- Backend calls FCM HTTP API

### Phase 3 (Add Progress Notifications)
- Add progress notification channel
- Show notification with `showProgress: true`
- Update notification on upload progress callback
- Dismiss on completion

### Phase 4 (Hybrid: Push + Polling)
- FCM for instant delivery when app is alive or recently killed
- WorkManager polling as fallback for devices that missed FCM
- Progress notifications during foreground uploads
