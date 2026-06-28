# Complete Flow of `manage_module_screen`

## Overview

The **Manage Module Screen** lets instructors manage course modules & lessons, upload video/resource files, and track upload progress in real-time — all while the upload survives app kills via Android's WorkManager + a SQLite-backed queue.

**Key layers (bottom → top):**
| Layer | What | File(s) |
|-------|------|---------|
| 1. Native Upload | `background_downloader` (WorkManager) | `background_uploader_service.dart` |
| 2. Presigned URL | Server endpoint → S3 PUT URL | `background_upload_service.dart` |
| 3. Queue Orchestrator | `UnifiedUploadQueueProvider` — state machine | `unified_upload_queue_provider.dart` |
| 4. SQLite Persistence | `UploadQueueRepository` — DB schema v5 | `upload_queue_repository.dart` |
| 5. Foreground Service | `UploadNotificationService` — notifications + background isolate | `upload_notification_service.dart` |
| 6. Progress Polling | `ManageModuleProvider._pollProgress` — 5s timer | `manage_module_provider.dart` |
| 7. UI | `ManageModuleScreen` + `ModuleCard` + `_PendingLessonRow` | `manage_module_screen.dart`, `module_card.dart` |

---

## Step-by-Step Flow

### 1. Screen Entry

**File:** `manage_module_screen.dart:23-35`

```dart
class ManageModuleScreen extends StatelessWidget {
  final int courseId;
  const ManageModuleScreen({super.key, this.courseId = 0});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ManageModuleProvider(courseId: courseId),
      child: const _ManageModuleBody(),
    );
  }
}
```

- Creates a **scoped** `ManageModuleProvider` (ChangeNotifier) with the `courseId`.
- The `_ManageModuleBody` StatefulWidget consumes it via `Consumer<ManageModuleProvider>`.

### 2. Provider Initialization → Load Course

**File:** `manage_module_provider.dart:44-46`

```dart
ManageModuleProvider({this.courseId = 0}) {
  _fetchCourse();
}
```

**`_fetchCourse` (`manage_module_provider.dart:97-195`):**
1. Calls `GET {Urls.updateCourseUrl}?courseID=$courseId` → gets course + modules + lessons + resources.
2. Parses response → populates `_courseTitle`, `_modules` (list of `CourseModule`), etc.
3. Builds `Lesson` objects from `data['lessons']` + `data['resources']`.
4. After parsing, calls `_removeCompletedPendingLessons()` + `notifyListeners()`.
5. Calls `_restorePendingUploads()` — **recovery**: reads the SQLite DB for any `module_lesson` or `resource` items that were in-flight before the screen was opened.

**`_restorePendingUploads` (`manage_module_provider.dart:209-330`):**
- Queries `UploadQueueRepository.getActive()` → filters to `module_lesson` / `resource` types.
- For each item: parses `metadata` → checks if lesson already exists on server → if not, creates a `PendingLesson` object and adds it to `_pendingLessons` map.
- **Critical**: reads real progress from `background_downloader`'s internal DB (`FileDownloader().database.recordForId(workerId)`) — so even if the app was killed, progress is restored.
- If any items found, calls `_startProgressPolling()`.

### 3. User Adds a Video Lesson

**UI:** User taps "Add Video" button in `ModuleCard` → `ManageModuleList` calls `onAddVideo(index)`.

**File:** `manage_module_screen.dart:214-229`

```dart
onAddVideo: (index) =>
    ManageModuleAddLessonSheet.show(
      context,
      lessonType: LessonType.video,
      moduleId: provider.modules[index].id,
      courseId: provider.courseId,
      onAddLesson: (title, file, _) =>
          provider.addVideoLesson(
            index, title, file,
            queueProvider: context.read<UnifiedUploadQueueProvider>(),
          ),
    ),
```

**`ManageModuleAddLessonSheet.show()`** (`manage_module_add_lesson_sheet.dart:26-50`):
- Shows a modal bottom sheet with:
  - An `UploadZone` widget (drag/drop area or tap to pick).
  - A title text field.
  - An "Upload Video" button.
- On "Upload Video" tap → calls `_handleUpload()` → calls the injected `onAddLesson` callback.

### 4. `ManageModuleProvider.addVideoLesson()` — The Queue Entry Point

**File:** `manage_module_provider.dart:628-685`

```dart
Future<bool> addVideoLesson(int moduleIndex, String title, XFile videoFile, {
  UnifiedUploadQueueProvider? queueProvider,
}) async {
  if (_isQueuing) return false;  // Lock: prevents concurrent queue ops
  _isQueuing = true;
  try {
    // 1. Dedup check: same file already in queue?
    if (!await _checkDedupOrCleanup(videoFile.path)) return false;

    // 2. Generate a local lessonId
    final lessonId = _nextLessonId++;

    // 3. Delegate to UnifiedUploadQueueProvider
    final queueId = await queueProvider.addModuleLessonToQueue(
      videoPath: videoFile.path,
      lessonTitle: title,
      moduleId: module.id,
      courseId: courseId,
      lessonId: lessonId,
    );

    // 4. Track locally as PendingLesson
    _pendingLessons[queueId] = PendingLesson(
      queueId: queueId, lessonId: lessonId, title: title,
      type: LessonType.video, filePath: videoFile.path,
      uploadProgress: 0.0, uploadStatus: 'pending', moduleId: module.id,
    );

    _hasUnsavedChanges = true;
    notifyListeners();
    _startProgressPolling();  // Start 5s timer to poll SQLite for status
    return true;
  } finally {
    _isQueuing = false;
  }
}
```

**`_checkDedupOrCleanup` (`manage_module_provider.dart:797-821`):**
- Queries DB for same `filePath` + `uploadType`.
- If `pending`/`uploading` → block (error toast).
- If `failed`/`cancelled`/`completed` → delete old row + cached file → allow re-upload.

### 5. `UnifiedUploadQueueProvider.addModuleLessonToQueue()` — The Orchestrator

**File:** `unified_upload_queue_provider.dart:1044-1121`

```dart
Future<int> addModuleLessonToQueue({...}) async {
  // 1. Validate file exists
  if (!File(videoPath).existsSync()) return 0;

  // 2. In-flight check (race condition guard)
  if (await _hasInFlightFile(videoPath, uploadType: 'module_lesson')) return 0;

  // 3. Ensure notification permission (required for background upload)
  final permission = await _ensureNotificationPermission();
  if (!permission) return 0;

  // 4. Build metadata JSON (attached to the queue row for later callback)
  final meta = ModuleLessonMetadata(moduleId, courseId, lessonTitle, lessonId: lessonId);
  final metadataJson = jsonEncode(meta.toJson());

  // 5. Get file size + duration
  final fileSize = await videoFile.length();
  final duration = await VideoMetadataHelper.getDurationSeconds(videoPath);

  // 6. Insert into SQLite with status='pending'
  final item = UploadQueueItem(filePath, title, videoDuration: duration,
      fileSize: fileSize, status: 'pending', uploadType: 'module_lesson',
      metadata: metadataJson);
  final insertResult = await UploadQueueRepository.insert(item);
  final id = insertResult['id'] as int;

  _queue = await UploadQueueRepository.getActive();
  notifyListeners();

  // 7. Fetch presigned S3 URL from server
  final urls = await BackgroundUploadService.fetchPresignedUrl(
    filePath: videoPath,
    endpoint: Urls.courseModuleUploadUrl,
    buildPayload: (name) => {
      'videoFilename': name,
      'videoContentType': BackgroundUploadService.inferVideoContentType(name),
    },
    extraFields: {'moduleID': moduleId},
  );

  // 8. Store URLs in SQLite
  await UploadQueueRepository.updateUrls(id: id,
      uploadUrl: urls['uploadUrl']!, fileUrl: urls['fileUrl']!);

  // 9. Kick the upload pipeline
  await _processNextItem();
  return id;
}
```

### 6. `BackgroundUploadService.fetchPresignedUrl()` — Getting S3 Permission

**File:** `background_upload_service.dart:26-87`

```dart
static Future<Map<String, String>?> fetchPresignedUrl({...}) async {
  final token = AuthController.accessToken;
  if (token == null) return null;
  _authToken = token;

  for (int retry = 0; retry < maxRetries; retry++) {
    // POST to server endpoint with filename + contentType + extraFields
    final response = await http.post(Uri.parse(endpoint),
        headers: _authHeaders(), body: jsonEncode(payload))
        .timeout(Duration(seconds: 30));

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = decoded['data'] as Map<String, dynamic>?;
      final uploadUrl = data['uploadUrl'] as String?;  // Presigned PUT URL
      final fileUrl = data['fileUrl'] as String?;       // Public CDN URL
      if (uploadUrl != null && fileUrl != null) return {...};
    }
    // Exponential backoff: 2s, 4s, 6s
  }
  return null;  // All retries failed
}
```

The server returns a **time-limited presigned S3 PUT URL** (e.g., 1h for resources, 24h for videos).

### 7. `_processNextItem()` — The Heart of the Queue State Machine

**File:** `unified_upload_queue_provider.dart:299-404`

```dart
Future<void> _processNextItem() async {
  if (_isUploading) return;  // One-at-a-time lock
  _isUploading = true;
  _isUploadingSince = DateTime.now();

  try {
    // 1. Claim next pending item via SQLite transaction (race-safe)
    final candidate = await UploadQueueRepository.claimNextPendingItem();

    // 2. Check if presigned URL is stale (resources: 50 min, videos: 23h)
    if (_isUrlStale(candidate)) {
      final freshUrls = await _fetchFreshUrls(candidate);
      if (freshUrls == null) {
        await UploadQueueRepository.markFailed(candidate.id!, 'URL expired');
        return;
      }
      await UploadQueueRepository.updateUrls(id: candidate.id!, ...);
    }

    // 3. Start foreground service (keeps Dart isolate alive)
    await UploadNotificationService.startService();

    // 4. Mark as 'uploading' in SQLite
    await UploadQueueRepository.updateStatus(id: candidate.id!, status: 'uploading');

    // 5. Enqueue native upload via background_downloader
    final taskId = await BackgroundUploaderService.enqueueUpload(
      itemId: candidate.id!,
      filePath: candidate.filePath,
      uploadUrl: candidate.uploadUrl!,
      contentType: _resolveContentType(candidate),
      displayName: candidate.title,
    );

    // 6. Store workerId (native task ID) in SQLite
    await UploadQueueRepository.updateWorkerId(id: candidate.id!, workerId: taskId);
  } catch (e) {
    _isUploading = false;
    // Mark failed in DB
  }
}
```

**`claimNextPendingItem()` (`upload_queue_repository.dart:452-481`):**
```sql
BEGIN TRANSACTION;
  SELECT * FROM upload_queue WHERE status='pending' 
    AND uploadUrl IS NOT NULL 
    AND (workerId IS NULL OR workerId = '')
    ORDER BY id ASC LIMIT 1;
  UPDATE upload_queue SET status='uploading' WHERE id=? AND status='pending';
COMMIT;
```
The transaction ensures no two isolates can claim the same item.

### 8. `BackgroundUploaderService.enqueueUpload()` — The Native Upload

**File:** `background_uploader_service.dart:15-49`

```dart
static Future<String?> enqueueUpload({...}) async {
  final metaData = jsonEncode({'itemId': itemId});  // Link back to our DB

  final task = UploadTask.fromFile(
    file: File(filePath),
    url: uploadUrl,              // Presigned S3 PUT URL
    httpRequestMethod: 'PUT',    // S3 expects PUT
    post: 'binary',              // Raw binary upload
    mimeType: contentType,       // e.g. 'video/mp4'
    metaData: metaData,          // {itemId: 42}
    retries: 10,                 // Auto-retry on network failure
    updates: Updates.statusAndProgress,
  );

  final ok = await FileDownloader().enqueue(task);  // WorkManager on Android
  return task.taskId;  // Return the native task ID
}
```

- This runs in a **native isolate (WorkManager on Android)** — survives app kill.
- `metaData` carries `itemId` so the global callbacks can map back to our DB row.

### 9. Native Callbacks — How Progress Flows Back

**Registered at init** (`unified_upload_queue_provider.dart:58-85`):

```dart
FileDownloader().registerCallbacks(
  taskStatusCallback: (update) => _onNativeTaskStatus(update),
  taskProgressCallback: (update) => _onNativeTaskProgress(update),
);
await FileDownloader().start(doTrackTasks: true, doRescheduleKilledTasks: true);
```

`start(doTrackTasks: true)` re-delivers any callbacks that fired while the app was dead — this is how uploads that complete while the app is killed still get processed.

#### 9a. `_onNativeTaskProgress()` — Real-time Progress

**File:** `unified_upload_queue_provider.dart:535-593`

```dart
Future<void> _onNativeTaskProgress(TaskProgressUpdate update) async {
  final itemId = _extractItemId(update.task);
  final pct = max(0, (update.progress * 100).round());

  // 1. Update in-memory state → immediate UI refresh (via notifyListeners)
  if (_activeItem?.id == itemId) {
    _activeProgress = pct;
    notifyListeners();
  }

  // 2. Persist to SQLite (throttled to whole-percent boundaries)
  if (pct != currentStoredPct) {
    await UploadQueueRepository.updateProgress(id: itemId, bytesUploaded: bytes);
  }

  // 3. Update foreground notification
  await UploadNotificationService.showQueueProgress(
    queueIndex: queueIdx + 1, queueTotal: total,
    itemProgress: bytes, itemTotal: item.fileSize,
    itemTitle: item.title, uploadType: item.uploadType,
  );

  // 4. Periodic WAL checkpoint every 200 ticks
  if (_progressUpdateCount % 200 == 0) {
    await UploadQueueRepository.checkpointWal();
  }
}
```

#### 9b. `_onNativeTaskStatus()` — Terminal Events

**File:** `unified_upload_queue_provider.dart:495-533`

```dart
switch (update.status) {
  case TaskStatus.complete:
    await _handleNativeComplete(itemId, update.task.taskId);
    break;
  case TaskStatus.failed:
    await UploadQueueRepository.markFailed(itemId, 'Native upload failed');
    await _onItemTerminal(itemId);
    break;
  case TaskStatus.canceled:
    await UploadQueueRepository.updateStatus(id: itemId, status: 'cancelled');
    await _onItemTerminal(itemId);
    break;
}
```

### 10. `_handleNativeComplete()` — Server Callback After S3 Upload

**File:** `unified_upload_queue_provider.dart:607-638`

```dart
Future<void> _handleNativeComplete(int itemId, String taskId) async {
  // 1. Mark native upload as complete in SQLite
  await UploadQueueRepository.markNativeCompleted(itemId);

  // 2. Get the full item from DB
  final item = (await UploadQueueRepository.getAll()).firstWhere((i) => i.id == itemId);

  // 3. Send server callback (PUT/POST to your API)
  final callbackSent = await _sendCallbackForItem(item);
  if (!callbackSent) {
    await UploadQueueRepository.markFailed(itemId, 'Server callback failed');
    return;
  }

  // 4. Mark callback complete + final 'completed' status
  await UploadQueueRepository.markCallbackCompleted(itemId);
  await UploadQueueRepository.markCompleted(itemId);

  // 5. Delete cached temp file
  await _cleanupCachedFile(item.filePath);

  // 6. Release queue lock → process next item
  await _onItemTerminal(itemId);
}
```

**`_sendCallbackForItem()` → `_buildCallbackDetails()` (`unified_upload_queue_provider.dart:642-731`):**

For `module_lesson`:
```dart
url: Urls.courseModuleLessonUrl,
body: {
  'title': meta.lessonTitle,
  'moduleId': meta.moduleId,
  'videoUrl': item.fileUrl,     // The public CDN URL
  'duration': item.videoDuration,
  'fileSize': item.fileSize,
}
```

Sent via `BackgroundUploaderService.sendServerCallback()` with an **Idempotency-Key** header to prevent duplicate lessons on retry.

### 11. ManageModuleProvider Progress Polling

**File:** `manage_module_provider.dart:687-791`

```dart
void _startProgressPolling() {
  _progressTimer?.cancel();
  _pollProgress();  // Run immediately
  _progressTimer = Timer.periodic(const Duration(seconds: 5), (_) {
    _pollProgress();
  });
}
```

**`_pollProgress`:**
1. Reads ALL items from `UploadQueueRepository.getAll()`.
2. For each `_pendingLessons` entry:
   - If DB item is gone → remove from pending.
   - **Read real progress from `background_downloader` DB** — `FileDownloader().database.recordForId(workerId)` — gives progress even if Dart callbacks failed.
   - Sync status + progress to in-memory `PendingLesson`.
   - If `completed` → remove from `_pendingLessons`, show toast, call `_silentRefresh()`.
   - If `failed` → update UI to show error state.
3. If `_pendingLessons` becomes empty → cancel timer.

### 12. UI Rendering of Pending Lessons

**File:** `module_card.dart:172-183`

```dart
if (pendingLessons.isNotEmpty) ...[
  ...pendingLessons.map((pending) =>
    _PendingLessonRow(
      pending: pending,
      onDelete: () => onDeletePendingLesson(pending.queueId),
    )),
]
```

**`_PendingLessonRow` (`module_card.dart:195-335`):**
```dart
// Reads live progress from UnifiedUploadQueueProvider for real-time %:
final queueProvider = context.watch<UnifiedUploadQueueProvider>();
final isActiveUpload = queueProvider.activeItem?.id == pending.queueId;
final liveProgress = isActiveUpload
    ? queueProvider.activeProgress / 100.0   // Immediate from callbacks
    : pending.uploadProgress;                 // From 5s polling

final progress = isUploading ? liveProgress : pending.uploadProgress;
```

Shows:
- **Pending**: "Waiting to upload..." + indeterminate bar.
- **Uploading**: "Uploading 45%" + determinate `LinearProgressIndicator`.
- **Failed**: "Upload failed" + red error icon.
- **Completed**: auto-removed from `_pendingLessons` via polling.

### 13. Heartbeat & Safety Net (`_startQueuePump`)

**File:** `unified_upload_queue_provider.dart:92-151`

Runs every **15 seconds**:
1. **Stale native task recovery**: If an item has `status='uploading'` but `lastUpdated` > 10 min ago → reset to `pending` (native WorkManager task was lost).
2. **Stuck Dart lock recovery**: If `_isUploading` is true for > 5 min with no `uploading` item in DB → release lock.
3. **Stuck pending kicker**: If pending items have no `workerId` but should be enqueued → call `_processNextItem()`.

### 14. App Restart Recovery

**On `UnifiedUploadQueueProvider._init()` (`unified_upload_queue_provider.dart:58-85`)**

1. `FileDownloader().registerCallbacks(...)` — re-registers to receive missed callbacks.
2. `FileDownloader().start(doTrackTasks: true, doRescheduleKilledTasks: true)` — re-delivers callbacks for tasks that ran while app was dead.
3. `_loadQueue()` (`unified_upload_queue_provider.dart:153-234`):
   - Finds items where `nativeMarkedCompleted=1` but `serverCallbackCompleted=0` → retries the server callback.
   - Resets stale `uploading` items (no workerId or >30 min) back to `pending`.
   - Removes stale `pending` items (>30 min, no uploadUrl).
   - Calls `_processNextItem()` to re-enqueue pending items.

**On `ManageModuleProvider._restorePendingUploads()` (`manage_module_provider.dart:209-330`)**:
- Reads active items from SQLite, matches them to modules, creates `PendingLesson` objects, reads live progress from `background_downloader` DB.

### 15. Foreground Service & Notifications

**File:** `upload_notification_service.dart`

| Method | When | What it shows |
|--------|------|---------------|
| `startService()` | Before each upload | Keeps Dart isolate alive (Android foreground service) |
| `showQueueProgress()` | Every progress callback | "Uploading 1/3 • My Video... 45%" with progress bar |
| `showQueueItemComplete()` | Each item done | "Uploading 1/3 • Video uploaded" |
| `showQueueAllComplete()` | Queue empty | "All Uploads Complete" |
| `stopService()` | Queue empty | Stops the foreground service |

### 16. SQLite Schema (v5)

**File:** `upload_queue_repository.dart:208-232`

```sql
CREATE TABLE upload_queue (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  filePath TEXT NOT NULL,          -- Local file path
  title TEXT NOT NULL,             -- Display title
  videoDuration INTEGER DEFAULT 0,
  fileSize INTEGER DEFAULT 0,
  uploadUrl TEXT,                  -- Presigned S3 PUT URL
  fileUrl TEXT,                    -- Public CDN URL (after upload)
  status TEXT DEFAULT 'pending',   -- pending|uploading|completed|failed|cancelled
  bytesUploaded INTEGER DEFAULT 0,
  errorMessage TEXT,
  createdAt TEXT NOT NULL,
  lastUpdated TEXT NOT NULL,
  uploadType TEXT DEFAULT 'video_post',  -- module_lesson|resource|course|course_intro|video_post
  metadata TEXT,                   -- JSON: ModuleLessonMetadata or CourseUploadMetadata
  uploadId TEXT,                   -- Unique upload identifier
  workerId TEXT,                   -- Native WorkManager task ID
  heartbeatMs INTEGER,             -- Last heartbeat timestamp (ms)
  retryCount INTEGER DEFAULT 0,
  idempotencyKey TEXT,             -- For server callback dedup
  nativeMarkedCompleted INTEGER DEFAULT 0,
  serverCallbackCompleted INTEGER DEFAULT 0
);
```

---

## Visual Flow Diagram

```
User taps "Add Video"
       │
       ▼
ManageModuleAddLessonSheet.show()     ← Bottom sheet: pick file, enter title
       │
       ▼
ManageModuleProvider.addVideoLesson()
  ├── _checkDedupOrCleanup()          ← Same file already queued?
  ├── queueProvider.addModuleLessonToQueue()
  │     ├── Validate file exists
  │     ├── _ensureNotificationPermission()
  │     ├── UploadQueueRepository.insert()    ← INSERT INTO SQLite (pending)
  │     ├── BackgroundUploadService.fetchPresignedUrl()  ← GET S3 PUT URL
  │     └── UploadQueueRepository.updateUrls() ← Store URLs in SQLite
  ├── _pendingLessons[queueId] = PendingLesson(...)  ← In-memory tracking
  └── _startProgressPolling()          ← 5s timer
                                           │
                                           ▼
UnifiedUploadQueueProvider._processNextItem()   ← called from addModuleLessonToQueue
  ├── claimNextPendingItem()           ← SQLite transaction: pending→uploading
  ├── _isUrlStale()? _fetchFreshUrls() ← Refresh expired presigned URLs
  ├── UploadNotificationService.startService()  ← Start foreground service
  ├── BackgroundUploaderService.enqueueUpload() ← WorkManager native upload
  └── UploadQueueRepository.updateWorkerId()    ← Store native task ID
                                           │
                                           ▼
                              ┌──────────────────────────┐
                              │  Native Isolate           │
                              │  (survives app kill)      │
                              │                           │
                              │  PUT file → S3 via        │
                              │  presigned URL            │
                              └──────────┬───────────────┘
                                         │
              Callbacks (re-fired on restart)
              ┌──────────────┐
              │ TaskProgress │──→ _onNativeTaskProgress()
              │  (realtime)  │      ├── _activeProgress = pct
              │              │      ├── UploadQueueRepository.updateProgress()
              │              │      └── UploadNotificationService.showQueueProgress()
              └──────────────┘
                                         │
              ┌──────────────┐
              │ TaskStatus   │──→ _onNativeTaskStatus()
              │  "complete"  │      └── _handleNativeComplete()
              │              │           ├── markNativeCompleted(id)
              │              │           ├── _sendCallbackForItem()  ← POST to server API
              │              │           │     └── BackgroundUploaderService.sendServerCallback()
              │              │           ├── markCallbackCompleted(id)
              │              │           ├── markCompleted(id)
              │              │           ├── _cleanupCachedFile()
              │              │           └── _onItemTerminal(id)
              │              │                └── _processNextItem()  ← Next in queue
              └──────────────┘
                                         │
                              ManageModuleProvider._pollProgress()  ← Every 5s
                                ├── Reads SQLite + background_downloader DB
                                ├── Syncs _pendingLessons status/progress
                                ├── Completed items → _silentRefresh() + remove
                                └── Empty → cancel timer
                                         │
                                     ModuleCard / _PendingLessonRow
                                └── context.watch<UnifiedUploadQueueProvider>()
                                    → liveProgress from callbacks or polling
```

---

## File Index

| File | Role | Key Functions/Classes |
|------|------|----------------------|
| `manage_module_screen.dart` | UI entry point | `ManageModuleScreen`, `_ManageModuleBody` |
| `manage_module_provider.dart` | State mgmt for screen | `_fetchCourse`, `addVideoLesson`, `_restorePendingUploads`, `_pollProgress`, `_checkDedupOrCleanup` |
| `manage_module_models.dart` | Data models | `Lesson`, `CourseModule`, `PendingLesson`, `LessonType` |
| `manage_module_add_lesson_sheet.dart` | File picker UI | `_pickFile`, `_handleUpload` |
| `module_card.dart` | Module expandable card | `_PendingLessonRow` (shows progress bar) |
| `unified_upload_queue_provider.dart` | Queue orchestrator | `_init`, `_processNextItem`, `addModuleLessonToQueue`, `_onNativeTaskStatus`, `_onNativeTaskProgress`, `_handleNativeComplete`, `_sendCallbackForItem`, `_startQueuePump` |
| `upload_queue_repository.dart` | SQLite CRUD | `insert`, `claimNextPendingItem`, `updateProgress`, `markCompleted`, `resetStaleUploading` |
| `background_upload_service.dart` | Presigned URL fetcher | `fetchPresignedUrl`, `fetchCoursePresignedUrls`, `verifyFileExists` |
| `background_uploader_service.dart` | Native upload | `enqueueUpload`, `sendServerCallback`, `cancelUploadByWorkerId` |
| `upload_notification_service.dart` | Foreground notifications | `startService`, `showQueueProgress`, `showQueueAllComplete` |
| `upload_task.dart` | Queue metadata models | `UploadTaskType`, `CourseUploadMetadata`, `ModuleLessonMetadata` |
