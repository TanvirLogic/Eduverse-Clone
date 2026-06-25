# Manage Module — Complete Upload Flow

## Overview

This document traces the **entire video lesson upload flow** from the moment a user taps "Add Video" on the Manage Module screen, through every service layer, until the file is uploaded to S3 and the backend is notified. It also covers crash survival, app-kill recovery, and progress polling.

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│  UI Layer (Flutter)                                                 │
│  ManageModuleScreen → ManageModuleAddLessonSheet → ManageModuleProvider │
└──────────────────────────┬──────────────────────────────────────────┘
                           │ calls addVideoLesson()
                           ▼
┌─────────────────────────────────────────────────────────────────────┐
│  Queue Layer (Flutter)                                              │
│  UnifiedUploadQueueProvider.addModuleLessonToQueue()                │
│  ├── UploadPathStorage.savePath()      ← FlutterSecureStorage (FSS) │
│  ├── UploadQueueRepository.insert()    ← SQLite                     │
│  ├── BackgroundUploadService.fetchPresignedUrl()  ← HTTP POST       │
│  ├── NativeUploadBridge.startNativeUpload()       ← MethodChannel   │
│  └── NativeUploadBridge.startQueueProcessing()    ← MethodChannel   │
└──────────────────────────┬──────────────────────────────────────────┘
                           │ MethodChannel("eduverse/upload_bridge")
                           ▼
┌─────────────────────────────────────────────────────────────────────┐
│  Native Layer (Kotlin — separate :upload process)                   │
│  MainActivity → UploadStateManager → UploadReschedulerService       │
│  ├── Persists to native_uploads.json   ← crash survival             │
│  ├── Starts foreground service         ← survives app kill           │
│  ├── HTTP PUT to S3 presigned URL      ← actual file upload          │
│  └── HTTP POST callback to backend     ← notifies server             │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Step-by-Step Flow

### Step 1: User Taps "Add Video"

**File:** `lib/features/manage_module/presentation/screens/manage_module_screen.dart`
**Lines:** 184-196

```dart
onAddVideo: (index) => ManageModuleAddLessonSheet.show(
  context,
  lessonType: LessonType.video,
  moduleId: provider.modules[index].id,
  courseId: provider.courseId,
  onAddLesson: (title, file, _) =>
      provider.addVideoLesson(
        index,
        title,
        file,
        queueProvider: context.read<UnifiedUploadQueueProvider>(),
      ),
),
```

The screen passes a callback `onAddLesson` to the bottom sheet. This callback calls `provider.addVideoLesson()`.

---

### Step 2: Bottom Sheet — File Picking

**File:** `lib/features/manage_module/presentation/widgets/manage_module_add_lesson_sheet.dart`
**Lines:** 72-90, 92-115

The `ManageModuleAddLessonSheet` is a `StatefulWidget` that handles:

1. **File picking** (lines 72-90): Uses `ImagePicker.pickVideo()` for video lessons.
2. **Title input**: A `TextFormField` with 60-char max length.
3. **Upload button** (lines 92-115): Calls `widget.onAddLesson(title, file, (_) {})` which triggers `provider.addVideoLesson()`.

```dart
Future<void> _handleUpload() async {
  if (_selectedFile == null) {
    ToastService.showError('Please select a file first');
    return;
  }
  if (!_formKey.currentState!.validate()) return;
  final title = _titleController.text.trim();

  setState(() => _isUploading = true);

  final success = await widget.onAddLesson(
    title,
    _selectedFile!,
    (_) {},  // progress callback (unused)
  );

  setState(() => _isUploading = false);

  if (success) {
    Navigator.of(context).pop();  // Close the sheet
  }
}
```

---

### Step 3: ManageModuleProvider.addVideoLesson()

**File:** `lib/features/manage_module/providers/manage_module_provider.dart`
**Lines:** 441-484

This is the **orchestrator** that bridges the UI and the upload queue.

```dart
Future<bool> addVideoLesson(
  int moduleIndex,
  String title,
  XFile videoFile, {
  UnifiedUploadQueueProvider? queueProvider,
}) async {
  final module = _modules[moduleIndex];
  final lessonId = _nextLessonId++;

  // 1. Create a Lesson object with pending status
  final lesson = Lesson(
    id: lessonId,
    title: title,
    duration: '0:00',
    type: LessonType.video,
    uploadProgress: 0.0,
    uploadStatus: 'pending',
  );
  module.lessons.add(lesson);        // Add to UI immediately
  _hasUnsavedChanges = true;
  notifyListeners();                  // Trigger UI rebuild

  try {
    // 2. Delegate to UnifiedUploadQueueProvider
    final queueId = await queueProvider!.addModuleLessonToQueue(
      videoPath: videoFile.path,
      lessonTitle: title,
      moduleId: module.id,
      courseId: courseId,
    );

    // 3. Handle failure
    if (queueId <= 0) {
      lesson.uploadStatus = 'failed';
      notifyListeners();
      return false;
    }

    // 4. Map queue ID → lesson ID for progress tracking
    _queueItemToLesson[queueId] = lessonId;

    // 5. Start polling native state for progress updates
    _startProgressPolling();
    return true;
  } catch (e) {
    AppLogger.e('addVideoLesson queue error: $e');
    lesson.uploadStatus = 'failed';
    notifyListeners();
    ToastService.showError('Failed to queue video lesson');
    return false;
  }
}
```

**Key data structures:**
- `_modules: List<CourseModule>` — the in-memory module list
- `_queueItemToLesson: Map<int, int>` — maps SQLite queue ID → Lesson ID
- `_videoUrlCache: Map<int, String>` — caches video URLs by lesson ID

---

### Step 4: UnifiedUploadQueueProvider.addModuleLessonToQueue()

**File:** `lib/features/courses/providers/unified_upload_queue_provider.dart`
**Lines:** 239-338

This is the **upload queue manager** that persists the upload intent and syncs with the native layer.

#### 4a. Build metadata

```dart
final meta = ModuleLessonMetadata(
  moduleId: moduleId,
  courseId: courseId,
  lessonTitle: lessonTitle,
);
final metadataJson = jsonEncode(meta.toJson());
```

**File:** `lib/features/manage_module/data/manage_module_models.dart` (not shown, but `ModuleLessonMetadata` is a simple JSON-serializable class)

#### 4b. Get file info

```dart
final videoFile = File(videoPath);
final fileSize = await videoFile.length();
final duration = await VideoMetadataHelper.getDurationSeconds(videoPath);
```

**File:** `lib/features/courses/data/helpers/video_metadata_helper.dart` — uses platform channel `eduverse/video_metadata` to call Android's `MediaMetadataRetriever` for duration.

#### 4c. Build queue item

```dart
final item = UploadQueueItem(
  filePath: videoPath,
  title: lessonTitle,
  videoDuration: duration,
  fileSize: fileSize,
  status: 'pending',
  uploadType: 'module_lesson',
  metadata: metadataJson,
);
```

**File:** `lib/features/courses/data/repositories/upload_queue_repository.dart` lines 9-119 — `UploadQueueItem` is a data class with `toMap()`/`fromMap()` for SQLite.

#### 4d. Save to FlutterSecureStorage (crash survival layer 1)

```dart
await UploadPathStorage.savePath(
  filePath: videoPath,
  uploadType: 'module_lesson',
  title: lessonTitle,
  metadata: metadataJson,
);
```

**File:** `lib/global/core/services/upload_path_storage.dart` lines 52-70

```dart
static Future<void> savePath({...}) async {
  final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
  final key = '$_prefix$timestamp';         // e.g. "pending_upload_1719312000000"
  final value = jsonEncode({
    'filePath': filePath,
    'uploadType': uploadType,
    'title': title,
    'metadata': metadata,
    'createdAt': DateTime.now().toIso8601String(),
  });
  await _storage.write(key: key, value: value);
  await _syncToAtomicQueue();   // Updates the single-key atomic queue blob
}
```

**Why FSS?** If the app is killed between SQLite insert and native sync, the recovery system (`native_init.dart` Phase 1) can re-insert the item into SQLite from FSS.

#### 4e. Check notification permission

```dart
final permission = await _ensureNotificationPermission();
if (!permission) {
  await UploadPathStorage.removePathByFilePath(videoPath);
  ToastService.showError('Notification permission required to upload');
  return 0;
}
```

**File:** `lib/features/courses/providers/unified_upload_queue_provider.dart` lines 524-551

The notification permission is required for the Android foreground service. If denied, the FSS entry is cleaned up and `0` is returned (failure).

#### 4f. Insert into SQLite (crash survival layer 2)

```dart
final id = await UploadQueueRepository.insert(item);
```

**File:** `lib/features/courses/data/repositories/upload_queue_repository.dart` lines 196-201

```dart
static Future<int> insert(UploadQueueItem item) async {
  final db = await database;
  final id = await db.insert('upload_queue', item.toMap());
  AppLogger.i('UploadQueueRepository: inserted item id=$id, ...');
  return id;
}
```

SQLite is the **source of truth** for the upload queue. The `id` returned is the auto-increment primary key used to track this item across all layers.

#### 4g. Fetch presigned S3 URL

```dart
final urls = await BackgroundUploadService.fetchPresignedUrl(
  filePath: videoPath,
  endpoint: Urls.courseModuleUploadUrl,
  buildPayload: (name) => {
    'videoFilename': name,
    'videoContentType': BackgroundUploadService.inferVideoContentType(name),
  },
  extraFields: {'moduleID': moduleId},
);
```

**File:** `lib/features/courses/services/background_upload_service.dart` lines 27-72

```dart
static Future<Map<String, String>?> fetchPresignedUrl({...}) async {
  final token = AuthController.accessToken;
  // ... retry loop (max 3 attempts) ...
  final response = await http.post(
    Uri.parse(endpoint),
    headers: _authHeaders(),
    body: jsonEncode(payload),
  ).timeout(const Duration(seconds: 30));

  // Returns {uploadUrl: "https://s3...?presigned...", fileUrl: "https://s3.../file.mp4"}
  return {'uploadUrl': uploadUrl, 'fileUrl': fileUrl};
}
```

The server returns:
- `uploadUrl` — S3 presigned PUT URL (used to upload the file)
- `fileUrl` — Final S3 URL (used in the callback to the backend)

If this fails, `_cleanupFailedUpload(id, videoPath)` is called which marks SQLite as `'failed'` and removes the FSS entry.

#### 4h. Sync to native layer via MethodChannel

```dart
final syncOk = await NativeUploadBridge.startNativeUpload(
  filePath: videoPath,
  uploadUrl: urls['uploadUrl']!,
  fileUrl: urls['fileUrl'],
  title: lessonTitle,
  contentType: BackgroundUploadService.inferVideoContentType(videoPath),
  uploadType: 'module_lesson',
  authToken: authToken,
  callbackUrl: Urls.courseModuleLessonUrl,
  callbackBody: callbackBody,
  metadata: metadataJson,
  itemId: id,
);
```

**File:** `lib/global/core/services/native_upload_bridge.dart` lines 70-101

```dart
static Future<bool> startNativeUpload({...}) async {
  await _channel.invokeMethod('startNativeUpload', {
    'filePath': filePath,
    'uploadUrl': uploadUrl,
    'fileUrl': fileUrl,
    'title': title,
    'contentType': contentType,
    'uploadType': uploadType,
    'authToken': authToken,
    'callbackUrl': callbackUrl,
    'callbackBody': callbackBody,
    'metadata': metadata,
    'itemId': itemId,
  });
  return true;
}
```

This sends the upload info to **Kotlin** via `MethodChannel("eduverse/upload_bridge")`.

**Kotlin handler:** `android/app/src/main/kotlin/net/eduverseapp/platform/MainActivity.kt` lines 77-118

```kotlin
"startNativeUpload" -> {
    val state = UploadStateManager.load(this)
    val existingItems = state?.items?.toMutableList() ?: mutableListOf()
    val newItem = PendingUpload(
        id = itemId,
        filePath = filePath,
        title = title ?: "Upload",
        uploadUrl = uploadUrl,
        fileUrl = fileUrl,
        contentType = contentType,
        uploadType = uploadType,
        authToken = authToken,
        callbackUrl = callbackUrl,
        callbackBody = callbackBody,
        metadata = metadata,
        status = UploadConstants.STATUS_PENDING,
    )
    existingItems.removeAll { it.id == itemId }
    existingItems.add(0, newItem)
    UploadStateManager.save(this, existingItems, 0, true)
    result.success(true)
}
```

The native layer **persists** the upload item to `native_uploads.json` via `UploadStateManager`. This is crash survival layer 3 — if the app is killed, the `:upload` process can read this file and continue.

#### 4i. Update SQLite with presigned URLs

```dart
await UploadQueueRepository.updateUrls(
  id: id,
  uploadUrl: urls['uploadUrl']!,
  fileUrl: urls['fileUrl']!,
);
```

**File:** `lib/features/courses/data/repositories/upload_queue_repository.dart` lines 247-263

```dart
static Future<void> updateUrls({...}) async {
  await db.update('upload_queue', {
    'uploadUrl': uploadUrl,
    'fileUrl': fileUrl,
    'status': 'uploading',   // Status changes from 'pending' → 'uploading'
  }, where: 'id = ?', whereArgs: [id]);
}
```

#### 4j. Start the native upload service

```dart
final started = await NativeUploadBridge.startQueueProcessing();
```

**File:** `lib/global/core/services/native_upload_bridge.dart` lines 36-44

```dart
static Future<bool> startQueueProcessing() async {
  await _channel.invokeMethod('startQueueProcessing');
  return true;
}
```

**Kotlin handler:** `MainActivity.kt` lines 120-134

```kotlin
"startQueueProcessing" -> {
    val state = UploadStateManager.load(this)
    if (state != null && state.items.isNotEmpty()) {
        val intent = Intent(this, UploadReschedulerService::class.java).apply {
            action = UploadReschedulerService.ACTION_PROCESS_QUEUE
        }
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }
    result.success(true)
}
```

This starts `UploadReschedulerService` as a **foreground service** in a separate `:upload` process. The service:
1. Reads the queue from `native_uploads.json`
2. Processes items sequentially (S3 PUT → callback POST)
3. Updates status in `native_uploads.json`
4. Deletes the state file when all items are done

**File:** `android/app/src/main/kotlin/net/eduverseapp/platform/UploadReschedulerService.kt`

#### 4k. Return queue ID

```dart
ToastService.showSuccess('Video lesson queued');
return id;   // SQLite auto-increment ID
```

Back in `ManageModuleProvider.addVideoLesson()` (line 474):

```dart
_queueItemToLesson[queueId] = lessonId;   // Map SQLite ID → Lesson ID
_startProgressPolling();                    // Start 2-second timer
```

---

### Step 5: Progress Polling

**File:** `lib/features/manage_module/providers/manage_module_provider.dart`
**Lines:** 486-561

```dart
void _startProgressPolling() {
  _progressTimer?.cancel();
  int emptyNativeReads = 0;

  _progressTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
    try {
      final data = await NativeUploadBridge.getQueueItems();
      final items = data['items'] as List<dynamic>? ?? [];
      bool updated = false;

      // CASE 1: Native state empty but we still have queued lessons
      if (items.isEmpty && _queueItemToLesson.isNotEmpty) {
        emptyNativeReads++;
        // Wait 2 cycles (4 seconds) to confirm native is truly gone
        if (emptyNativeReads >= 2) {
          for (final entry in _queueItemToLesson.entries) {
            final lesson = _findLessonById(entry.value);
            if (lesson != null && lesson.uploadStatus != 'completed') {
              lesson.uploadStatus = 'completed';
              updated = true;
            }
          }
          _queueItemToLesson.clear();
        }
      }
      // CASE 2: Native has items — update progress
      else if (items.isNotEmpty) {
        emptyNativeReads = 0;

        for (final raw in items) {
          final item = raw as Map<String, dynamic>;
          final queueId = item['id'] as int;
          final lessonId = _queueItemToLesson[queueId];
          if (lessonId == null) continue;

          final lesson = _findLessonById(lessonId);
          if (lesson == null) {
            _queueItemToLesson.remove(queueId);
            continue;
          }

          final status = item['status'] as String? ?? 'pending';
          final progress =
              ((item['progress'] as num?)?.toDouble() ?? 0.0) / 100.0;

          if (lesson.uploadStatus != status || lesson.uploadProgress != progress) {
            lesson.uploadStatus = status;
            lesson.uploadProgress = progress;
            updated = true;
          }

          if (status == 'completed') {
            final fileUrl = item['fileUrl'] as String?;
            if (fileUrl != null && fileUrl.isNotEmpty) {
              lesson.videoUrl ??= fileUrl;
            }
            _queueItemToLesson.remove(queueId);
          } else if (status == 'failed') {
            _queueItemToLesson.remove(queueId);
          }
        }
      }

      if (updated) notifyListeners();

      // Stop polling when all items are done
      if (_queueItemToLesson.isEmpty) {
        _progressTimer?.cancel();
        _progressTimer = null;
      }
    } catch (e) {
      AppLogger.e('_startProgressPolling error: $e');
    }
  });
}
```

**How progress flows:**
1. Polling calls `NativeUploadBridge.getQueueItems()` every 2 seconds
2. This reads `native_uploads.json` via the Kotlin MethodChannel
3. The native service updates `progress` (0-100) and `status` in this file during upload
4. Flutter maps `queueId → lessonId` and updates the `Lesson` object
5. `notifyListeners()` triggers UI rebuild with new progress bar

**Completion detection:**
- The native service's `finally` block calls `removeCompletedAndFailed()` then `clear()` (deletes `native_uploads.json`)
- When Flutter reads an empty native state, it waits 2 cycles (4s) then marks all queued lessons as `'completed'`
- The timer stops when `_queueItemToLesson` is empty

---

### Step 6: Native Upload Process (Kotlin)

**File:** `android/app/src/main/kotlin/net/eduverseapp/platform/UploadReschedulerService.kt`

The `:upload` process runs independently from the Flutter UI:

1. **Reads** `native_uploads.json` for pending items
2. **Uploads** each file via HTTP PUT to the S3 presigned URL
3. **Updates** progress in `native_uploads.json` (Flutter reads this via polling)
4. **Calls back** to the backend via HTTP POST with the callback URL and body
5. **Marks** the item as `'completed'` or `'failed'`
6. **Cleans up** by deleting completed/failed items from the state file
7. **Deletes** `native_uploads.json` when the queue is empty (signals completion to Flutter)

**Crash survival:** If the app is killed, the `:upload` process continues because it's a separate Android process. The state file (`native_uploads.json`) persists the upload info.

---

### Step 7: App Kill Recovery

**File:** `lib/app/native_init.dart`

On every app start, `initPlatformServices()` runs a 5-phase recovery pipeline:

#### Phase 1: Recover from FSS (lines 41-85)

```dart
Future<void> _recoverPendingUploads() async {
  await UploadQueueRepository.resetStaleUploading();
  final pendingPaths = await UploadPathStorage.getAllPendingPaths();
  for (final entry in pendingPaths) {
    if (!entry.fileExists) {
      await UploadPathStorage.removePath(entry.key);
      continue;
    }
    // Skip if already in SQLite
    final activeItems = await UploadQueueRepository.getActive();
    final alreadyQueued = activeItems.any(
      (item) => item.filePath == entry.filePath &&
          item.status != 'completed' && item.status != 'failed',
    );
    if (alreadyQueued) {
      await UploadPathStorage.removePath(entry.key);
      continue;
    }
    // Re-insert into SQLite
    final item = UploadQueueItem(...);
    await UploadQueueRepository.insert(item);
    await UploadPathStorage.removePath(entry.key);
  }
}
```

This handles the case where the app was killed **after** FSS save but **before** SQLite insert.

#### Phase 2: Sync from native state (lines 96-191)

```dart
Future<void> _recoverNativeOrphans() async {
  final nativeItems = await NativeUploadBridge.getPendingUploads();
  for (final item in nativeItems) {
    if (status == 'completed') {
      await UploadQueueRepository.markCompleted(itemId);  // Prevent re-upload
    } else if (status == 'failed') {
      await UploadQueueRepository.markFailed(itemId, ...);
    } else {
      // Re-insert as pending if not already in SQLite
    }
  }
  if (!hasStillUploading) {
    await NativeUploadBridge.clearState();
  }
}
```

This handles the case where the native service completed while the app was killed. It marks items as completed in SQLite to prevent re-upload.

#### Phase 3: Clear stale locks (lines 194-201)

```dart
Future<void> _clearStaleLocks() async {
  await UploadQueueRepository.resetStaleUploading(
    olderThan: const Duration(minutes: 30),
  );
}
```

Items stuck in `'uploading'` for >30 minutes are reset to `'pending'` so they can be retried.

#### Phase 4: Auto-resume (lines 208-238)

```dart
Future<void> _autoResumeIfNeeded() async {
  final pendingCount = await UploadQueueRepository.countPending();
  if (pendingCount == 0) return;

  // Build native queue from SQLite (correct IDs + uploadUrls)
  final pendingItems = await UploadQueueRepository.getByStatus('pending');
  final nativeQueueJson = jsonEncode(pendingItems.map((item) => {
    'id': item.id,
    'filePath': item.filePath,
    'title': item.title,
    'uploadUrl': item.uploadUrl,
    'fileUrl': item.fileUrl,
    'contentType': _inferContentType(item.filePath),
    'uploadType': item.uploadType,
    'metadata': item.metadata,
  }).toList());

  await NativeUploadBridge.syncQueueToNative(nativeQueueJson);
  await NativeUploadBridge.startQueueProcessing();
}
```

This rebuilds the native queue from SQLite (which has correct IDs and presigned URLs) and restarts the native service.

---

## Data Flow Summary

```
User picks video (XFile)
  │
  ▼
ManageModuleAddLessonSheet._handleUpload()
  │
  ▼
ManageModuleProvider.addVideoLesson()
  ├── Creates Lesson(status='pending') → adds to module.lessons
  ├── notifyListeners() → UI shows lesson with 0% progress
  │
  ▼
UnifiedUploadQueueProvider.addModuleLessonToQueue()
  ├── UploadPathStorage.savePath()           → FSS: pending_upload_<ts>
  ├── UploadQueueRepository.insert()         → SQLite: id=42, status='pending'
  ├── _ensureNotificationPermission()        → Android notification check
  ├── BackgroundUploadService.fetchPresignedUrl() → HTTP POST → {uploadUrl, fileUrl}
  │   └── On failure: _cleanupFailedUpload(42, videoPath) → SQLite='failed', FSS deleted
  ├── NativeUploadBridge.startNativeUpload() → MethodChannel → Kotlin writes native_uploads.json
  │   └── On failure: _cleanupFailedUpload(42, videoPath) → SQLite='failed', FSS deleted
  ├── UploadQueueRepository.updateUrls()     → SQLite: status='uploading', uploadUrl, fileUrl
  ├── NativeUploadBridge.startQueueProcessing() → MethodChannel → starts :upload foreground service
  │   └── On failure: _cleanupFailedUpload(42, videoPath) → SQLite='failed', FSS deleted
  └── returns queueId=42
  │
  ▼
ManageModuleProvider (continued)
  ├── _queueItemToLesson[42] = lessonId      → maps queue ID → lesson ID
  └── _startProgressPolling()                → starts 2-second Timer
  │
  ▼
Progress Polling (every 2s)
  ├── NativeUploadBridge.getQueueItems()     → reads native_uploads.json
  ├── Maps queueId=42 → lessonId → Lesson object
  ├── Updates lesson.uploadProgress and lesson.uploadStatus
  ├── notifyListeners() → UI rebuilds with new progress bar
  └── When native state empty for 2 cycles → marks lesson 'completed'
  │
  ▼
Native :upload process (separate Android process)
  ├── Reads native_uploads.json
  ├── HTTP PUT file to S3 presigned URL
  ├── Updates progress in native_uploads.json (Flutter polls this)
  ├── HTTP POST callback to backend (creates lesson in DB)
  ├── Marks item 'completed' in native_uploads.json
  └── Deletes native_uploads.json when queue empty
```

---

## Crash Survival Layers

| Layer | Storage | When Written | When Read |
|-------|---------|--------------|-----------|
| **FSS** | FlutterSecureStorage | Before SQLite insert | Recovery Phase 1 |
| **SQLite** | upload_queue.db | After FSS save | Recovery Phases 2-4, Progress polling |
| **Native JSON** | native_uploads.json | After MethodChannel call | Recovery Phase 2, Progress polling |

If the app is killed at any point, at least one layer has the data needed to recover.

---

## Key Files Reference

| File | Purpose |
|------|---------|
| `lib/features/manage_module/presentation/screens/manage_module_screen.dart` | Screen with module list, triggers add video |
| `lib/features/manage_module/presentation/widgets/manage_module_add_lesson_sheet.dart` | Bottom sheet for file picking + title input |
| `lib/features/manage_module/providers/manage_module_provider.dart` | Orchestrator: creates Lesson, delegates to queue, polls progress |
| `lib/features/courses/providers/unified_upload_queue_provider.dart` | Queue manager: FSS, SQLite, presigned URL, native sync |
| `lib/features/courses/data/repositories/upload_queue_repository.dart` | SQLite CRUD for upload queue items |
| `lib/global/core/services/upload_path_storage.dart` | FlutterSecureStorage wrapper for crash survival |
| `lib/global/core/services/native_upload_bridge.dart` | Flutter↔Kotlin MethodChannel bridge |
| `lib/features/courses/services/background_upload_service.dart` | Presigned URL fetch with retry logic |
| `lib/app/native_init.dart` | 5-phase recovery pipeline on app start |
| `lib/features/manage_module/data/manage_module_models.dart` | Lesson, CourseModule data models |
| `android/.../MainActivity.kt` | Kotlin MethodChannel handlers |
| `android/.../UploadReschedulerService.kt` | Android foreground service for S3 upload |
| `android/.../UploadStateManager.kt` | Native state file read/write |
