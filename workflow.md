# Upload System — Operational Workflow

> Version 2.0 — Single Source of Truth architecture
> Applies to: Flutter (Dart) + Android (Kotlin Foreground Service)

---

## 1. Architecture Overview

```
┌──────────────────────────────────────────────────────────────────────┐
│                         Flutter Process                              │
│                                                                      │
│  ┌──────────────┐    ┌─────────────────────────────┐                 │
│  │  UI Screens  │───▶│ UnifiedUploadQueue          │────────┐        │
│  │  (upload_    │    │   Provider                  │        │        │
│  │  video, etc) │    │  - Heartbeat (10s)          │        │        │
│  └──────────────┘    │  - Reads completion manifest│        │        │
│                      └────────┬────────────────────┘        │        │
│                               │                             │        │
│                               ▼                             ▼        │
│                     ┌─────────────────────┐  ┌──────────────────┐    │
│                     │  SQLite (SSoT)      │  │  Heartbeat Poll  │    │
│                     │  upload_queue.db    │  │  ping() + read   │    │
│                     │  + WAL mode         │  │  native_completed│    │
│                     └────────┬────────────┘  │  .json manifest  │    │
│                              │               └────────┬─────────┘    │
│                              │ MethodChannel           │              │
│                              ▼                         ▼              │
│                     ┌────────────────────────────────────────┐        │
│                     │        NativeUploadBridge              │        │
│                     │  (eduverse/upload_bridge)              │        │
│                     │  getCompletedItems()                   │        │
│                     │  acknowledgeCompletedItems()           │        │
│                     └────────────────┬───────────────────────┘        │
└──────────────────────────────────────┼────────────────────────────────┘
                                       │ IPC
┌──────────────────────────────────────┼────────────────────────────────┐
│              Android :upload Process                                  │
│                                     ▼                                │
│  ┌─────────────────────────────────────────────┐                     │
│  │           MainActivity MethodChannel        │                     │
│  │  ping() │ startNativeUpload │ processing    │                     │
│  │  getNativeCompletedItems │ acknowledge      │                     │
│  └────┬──────────────────────────────┬─────────┘                     │
│       │                              │                               │
│       ▼                              ▼                               │
│  ┌──────────────┐           ┌──────────────────┐                     │
│  │ UploadState  │           │UploadRescheduler │                     │
│  │   Manager    │           │   Service        │                     │
│  │              │           │  (Foreground)    │                     │
│  │ native_      │           │  isAlive flag    │                     │
│  │ uploads.json │           │  Heartbeat(30s)  │                     │
│  │ (snapshot)   │           │  Idempotency Key │                     │
│  │              │           │  S3 PUT (65KB    │                     │
│  │ native_      │           │   buffer)        │                     │
│  │ completed    │◄──────────│  Callback POST   │                     │
│  │ .json        │  saves on │  Every completed │                     │
│  │ (manifest)   │  complete │  item → writes   │                     │
│  └──────────────┘           │  to manifest     │                     │
│                             └────────┬─────────┘                     │
│                                      │                               │
│                                      ▼                               │
│                              ┌──────────────┐                        │
│                              │  Amazon S3    │                        │
│                              │  + Server     │                        │
│                              │  Callback     │                        │
│                              └──────────────┘                        │
└──────────────────────────────────────────────────────────────────────┘
```

### Single Source of Truth (SSoT)

**SQLite is the sole authoritative state.** All other stores are derived:
- `native_uploads.json` — crash-only snapshot, deleted after reconcile
- `native_completed.json` — persistent completion manifest (survives `native_uploads.json` cleanup, deleted only after Flutter acknowledges)
- `FlutterSecureStorage` — no longer used for upload queue data
- In-memory `_queue` — cached read of SQLite, refreshed on mutation

---

## 2. Database Schema

### Table: `upload_queue` (v5)

```sql
CREATE TABLE upload_queue (
    id                      INTEGER PRIMARY KEY AUTOINCREMENT,
    filePath                TEXT NOT NULL,
    title                   TEXT NOT NULL,
    videoDuration           INTEGER NOT NULL DEFAULT 0,
    fileSize                INTEGER NOT NULL DEFAULT 0,
    uploadUrl               TEXT,               -- presigned S3 PUT URL
    fileUrl                 TEXT,               -- CDN/file URL after upload
    status                  TEXT NOT NULL DEFAULT 'pending',
    bytesUploaded           INTEGER NOT NULL DEFAULT 0,
    errorMessage            TEXT,
    createdAt               TEXT NOT NULL,
    lastUpdated             TEXT NOT NULL,
    uploadType              TEXT NOT NULL DEFAULT 'video_post',
    metadata                TEXT,               -- JSON blob for type-specific data
    uploadId                TEXT,               -- UUID: immutable identity
    workerId                TEXT,               -- e.g. "foreground_172839"
    heartbeatMs             INTEGER,            -- last native heartbeat epoch ms
    retryCount              INTEGER NOT NULL DEFAULT 0,
    idempotencyKey          TEXT,               -- unique per callback attempt
    nativeMarkedCompleted   INTEGER NOT NULL DEFAULT 0,
    serverCallbackCompleted INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX idx_upload_queue_status   ON upload_queue(status);
CREATE INDEX idx_upload_queue_uploadId ON upload_queue(uploadId);

PRAGMA journal_mode = WAL;
PRAGMA busy_timeout = 5000;
```

### Status State Machine

```
                ┌──────────┐
                │  pending │ ◄──────────────┐
                └────┬─────┘                │
                     │                      │
                     ▼                      │
             ┌──────────────┐               │
             │  uploading   │───────────────┤
             └──────┬───────┘  (retry)      │
                    │                       │
           ┌───────┴───────┐               │
           ▼               ▼               │
     ┌──────────┐    ┌────────┐            │
     │completed │    │ failed │────────────┘
     └──────────┘    └────────┘  (retry)
                          │
                          ▼
                    ┌───────────┐
                    │ cancelled │
                    └───────────┘
```

**Valid transitions** (enforced by `_assertValidTransition`):
- `pending → uploading | cancelled`
- `uploading → completed | failed`
- `failed → pending` (retry)
- `completed → ❌` (terminal)
- `cancelled → ❌` (terminal)

---

## 3. Upload Lifecycle

### 3.1 Enqueue (Flutter)

```
User taps Upload
       │
       ▼
UnifiedUploadQueueProvider.addToQueue()
       │
       ├─ SQLite.insert() → generates uploadId (UUID)
       │   Returns {id, uploadId}
       │
       ├─ _fetchAndSyncVideoPost()
       │   ├─ Request presigned URL from server (POST /api/upload-url)
       │   ├─ NativeUploadBridge.startNativeUpload() → persists to native snapshot
       │   └─ NativeUploadBridge.startQueueProcessing() → starts foreground service
       │
       ├─ UI shows item as "pending" in upload queue
       │
       └─ _startHeartbeatPolling() → 10s timer begins
```

### 3.2 Upload Execution (Android :upload Process)

```
UploadReschedulerService.onStartCommand(ACTION_PROCESS_QUEUE)
       │
       ├─ isAlive = true
       ├─ Acquires PARTIAL_WAKE_LOCK + WIFI_LOCK
       ├─ Starts heartbeat executor (30s)
       │
       ├─ processQueue()
       │   ├─ For each pending item (FIFO by id):
       │   │   ├─ Wait for network (up to 5 min)
       │   │   ├─ SQLite status → 'uploading'
       │   │   ├─ Notification: "Uploading... (X/Y)"
       │   │   │
       │   │   ├─ performS3Upload()
       │   │   │   ├─ HttpURLConnection PUT to presigned URL
       │   │   │   ├─ 65KB streaming buffer
       │   │   │   ├─ Progress every 5% → notification + JSON persistence
       │   │   │   ├─ Retry up to 3x with exponential backoff
       │   │   │   └─ Returns success/failure
       │   │   │
       │   │   ├─ If S3 success AND callback provided:
       │   │   │   └─ performServerCallback()
       │   │   │       ├─ POST to callbackUrl with Idempotency-Key header
       │   │   │       ├─ Retry up to 3x (skip on 409 Conflict or 401)
       │   │   │       ├─ On success → markCallbackCompleted in SQLite
       │   │   │       └─ Returns success/failure
       │   │   │
       │   │   ├─ If S3 success + (callback not needed or success):
       │   │   │   ├─ markItemCompleted() → native_uploads.json status='completed'
       │   │   │   └─ Notification: "Upload complete"
       │   │   │
       │   │   └─ If failure:
       │   │       ├─ markItemFailed() → native_uploads.json status='failed'
       │   │       └─ Notification: "Upload failed"
       │   │
       │   └─ Check for newly added pending items → loop
       │
       └─ finally:
           ├─ isProcessing = false
           ├─ removeCompletedAndFailed()
           ├─ If queue empty: clear native state, stopForeground, stopSelf
           └─ isAlive = false
```

### 3.3 Heartbeat Protocol

```
Flutter (every 10s)
       │
       ├─ NativeUploadBridge.ping()
       │   └─ MainActivity: returns UploadReschedulerService.isAlive
       │
       ├─ If ping() == true:
       │   └─ _missedHeartbeats = 0
       │
       └─ If ping() == false:
           └─ _missedHeartbeats++
               └─ If >= 3:
                   ├─ resetStaleUploading() → uploading → pending
                   ├─ Read native state for completed/failed
                   ├─ Verify S3 existence via HEAD for uploading items
                   └─ Sync pending items to native, start service

Android (every 30s)
       └─ Heartbeat executor runs (service alive = responds to ping)
```

---

## 4. Recovery Pipeline

On app start (`initPlatformServices`):

```
Phase 1: Heartbeat Check
    ├─ NativeUploadBridge.ping()
    ├─ If alive → resetStaleUploading(), _processCompletedManifest(), return
    └─ If dead → proceed to Phase 2

Phase 2A: Completion Manifest Recovery
    ├─ Read native_completed.json (persistent manifest of finished items)
    ├─ For each itemId in manifest:
    │   ├─ If not already completed/failed in SQLite → markCompleted()
    │   └─ AppLogger: "marked completed from manifest"
    └─ acknowledgeCompletedItems() → deletes manifest

Phase 2B: Native State Recovery (native_uploads.json)
    ├─ If native_uploads.json exists with items:
    │   ├─ For 'completed' items → markCompleted() in SQLite
    │   ├─ For 'failed' items → markFailed() in SQLite
    │   ├─ For 'pending'/'uploading' items:
    │   │   ├─ If file exists locally → recover as 'pending'
    │   │   └─ If file missing → markFailed("File not found")
    │   └─ Clear native_uploads.json
    ├─ If native_uploads.json is empty (already cleared):
    │   └─ For any 'uploading' items in SQLite with both fileUrl+uploadUrl
    │      → markCompleted() (likely uploaded, manifest just missed them)

Phase 3: Reset Stale Locks
    ├─ heartbeatMs is null OR older than 2min → reset to pending
    └─ No heartbeat AND lastUpdated older than 5min → reset to pending

Phase 4: Auto-Resume
    ├─ If pending items exist in SQLite:
    │   ├─ Serialize queue → sync to native
    │   └─ startQueueProcessing() → foreground service
    └─ If no pending items → done
```

---

## 5. Duplicate Prevention

| Scenario | Prevention |
|---|---|
| Same file queued twice | `_hasInFlightFile()` checks for pending/uploading status with same `filePath` |
| Recovery re-queues completed upload | `native_completed.json` manifest — each completed item is recorded before state file cleanup; recovery reads manifest first |
| Server callback fires twice | `Idempotency-Key` header; server drops duplicates (409) |
| Two workers pick same item | Each item has unique `uploadId`; atomic state transitions enforced |
| Native completes but Flutter dead | `saveCompletedItem()` writes to manifest before state cleanup; recovery reads manifest and marks completed |
| App restart during upload | Heartbeat check skips recovery if native alive; manifest read during heartbeat provides live updates |
| Device reboot | `BootReceiver` → WorkManager → foreground service restart |

---

## 6. Retry Strategy

| Layer | Mechanism | Max Retries | Backoff |
|---|---|---|---|
| Presigned URL fetch | HTTP POST with retry | 3 | 2s × attempt |
| S3 PUT upload | `HttpURLConnection` with streaming | 3 | 5s × attempt |
| Server callback | POST with idempotency key | 3 | 3s × attempt |
| User-initiated retry | `incrementRetryCount()` in SQLite | Unlimited | Manual |
| Stale upload recovery | Heartbeat miss detection | Continuous | 10s polling cycle |

---

## 7. Error Handling Matrix

| Error | Detection | Recovery |
|---|---|---|
| Network lost mid-upload | `isNetworkAvailable()` returns false | Wait up to 5 min via `ConnectivityManager` callback; fail after timeout |
| S3 returns 5xx | Response code check | 3 retries with backoff; mark failed after exhaustion |
| Server callback fails | Timeout or non-2xx | 3 retries; 401 = immediate fail |
| SQLite write fails | Exception caught | WAL mode prevents corruption; retry on next write |
| Notification denied | `SecurityException` on `startForeground` | Mark all items failed; `stopSelf()` |
| File deleted before upload | `File.exists()` check | `markFailed("File not found")` |
| App update during upload | Process restart → recovery pipeline | Heartbeat check → stale reset → auto-resume |
| Multiple uploads same file | `_hasInFlightFile()` by filePath | Reject with "already in queue" toast |

---

## 8. MethodChannel API

### Flutter → Android

| Method | Params | Returns | Purpose |
|---|---|---|---|
| `scheduleWorkManager` | — | void | Initialize periodic orphan checker |
| `syncQueueToNative` | `itemsJson` (String) | bool | Persist full queue snapshot |
| `startQueueProcessing` | — | bool | Start foreground upload service |
| `startNativeUpload` | `filePath`, `uploadUrl`, `fileUrl`, `title`, `contentType`, `uploadType`, `authToken`, `callbackUrl`, `callbackBody`, `metadata`, `itemId`, `uploadId` | bool | Add single item to native state |
| `getNativeQueueStatus` | — | JSON `{totalItems, pending, uploading, completed, failed}` | Aggregate queue progress |
| `getNativePendingUploads` | — | JSON array of items | Full state from crash snapshot |
| `getQueueItems` | — | `{items: [...], isUploading: bool}` | Full items with progress |
| `clearState` | — | void | Delete native_uploads.json |
| `cancelNativeUpload` | — | void | Stop service + clear state |
| `ping` | — | bool | Is :upload process alive? |
| `onNativeUploadCompleted` | `itemId`, `fileUrl` | void | Native → Flutter: upload done |
| `onNativeUploadFailed` | `itemId`, `error` | void | Native → Flutter: upload failed |
| `getNativeCompletedItems` | — | JSON array of `{id, fileUrl}` | Read completion manifest (items that finished while Flutter was away) |
| `acknowledgeCompletedItems` | — | void | Delete completion manifest after Flutter processes it |
| `openNotificationSettings` | — | void | OS-level notification settings |

---

## 9. Key Files Reference

### Flutter (Dart)
| File | Responsibility |
|---|---|
| `lib/features/courses/data/repositories/upload_queue_repository.dart` | SQLite CRUD, schema v5, state machine enforcement, WAL |
| `lib/features/courses/providers/unified_upload_queue_provider.dart` | Central upload state, heartbeat polling, native sync |
| `lib/app/native_init.dart` | 4-phase recovery pipeline |
| `lib/global/core/services/native_upload_bridge.dart` | MethodChannel IPC bridge |
| `lib/features/courses/services/background_upload_service.dart` | Presigned URL fetch, S3 HEAD verification |

### Android (Kotlin)
| File | Responsibility |
|---|---|
| `MainActivity.kt` | MethodChannel dispatch, ping, native→Flutter events |
| `UploadReschedulerService.kt` | Foreground service, S3 PUT, callback with idempotency, heartbeat |
| `UploadStateManager.kt` | native_uploads.json crash snapshot |
| `UploadWorker.kt` | WorkManager periodic orphan check |
| `BootReceiver.kt` | Device boot → WorkManager enqueue |

---

## 10. Migration Checklist (v1 → v2)

- [ ] Deploy DB schema v5 (WAL, new columns, indexes)
- [ ] Verify all `insert()` calls use new return type `{id, uploadId}`
- [ ] Remove `UploadPathStorage` (FSS) calls from providers
- [ ] Deploy Android `ping()`, `onNativeUploadCompleted`, `onNativeUploadFailed` handlers
- [ ] Deploy `isAlive` flag + heartbeat executor in native service
- [ ] Deploy idempotency key header in server callbacks
- [ ] Deploy 5% notification throttle (was 1%)
- [ ] Deploy recovery pipeline v2 (heartbeat check, S3 HEAD, no 30-min wait)
- [ ] Update `ManageModuleProvider` orphan cleanup (removed FSS-based dedup)
- [ ] Remove legacy `video_queue_upload_provider.dart` if no longer used
- [ ] Remove `upload_path_storage.dart` after full migration
