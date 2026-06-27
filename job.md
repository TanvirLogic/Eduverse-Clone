# Upload System Overhaul — Technical Job Description

## Problem Summary

Current upload system has **6 sources of truth** (SQLite, FSS, native_uploads.json, WorkManager, Notifications, Flutter memory). After app kill, these desync, causing duplicate uploads, stuck states, endless notifications, and orphaned rows. Single PUT for GB-sized videos is fragile. No heartbeat mechanism, no idempotency keys, no upload resumption.

---

## Phase 1: Single Source of Truth — SQLite Only

**Goal**: Eliminate FlutterSecureStorage and native_uploads.json as independent state stores. SQLite becomes the **sole** authoritative state.

### Task 1.1 — DB Schema Upgrade (v5)
File: `upload_queue_repository.dart`

Add columns:
```sql
ALTER TABLE upload_queue ADD COLUMN uploadId TEXT;          -- UUID (unique per upload attempt)
ALTER TABLE upload_queue ADD COLUMN workerId TEXT;           -- e.g., "foreground_172839"
ALTER TABLE upload_queue ADD COLUMN heartbeatMs INTEGER;    -- last heartbeat from native
ALTER TABLE upload_queue ADD COLUMN retryCount INTEGER DEFAULT 0;
ALTER TABLE upload_queue ADD COLUMN idempotencyKey TEXT;    -- unique per callback attempt
ALTER TABLE upload_queue ADD COLUMN nativeMarkedCompleted INTEGER DEFAULT 0;  -- 0/1
ALTER TABLE upload_queue ADD COLUMN serverCallbackCompleted INTEGER DEFAULT 0; -- 0/1
```

Enable WAL mode on DB open:
```dart
await db.execute('PRAGMA journal_mode=WAL');
await db.execute('PRAGMA busy_timeout=5000');
```

### Task 1.2 — Add `uploadId` (UUID) Generation
File: `upload_queue_repository.dart`

When inserting an item, generate a v4 UUID as `uploadId`. This is the **immutable** identity used everywhere (native state, MethodChannel, dedup, idempotency).

### Task 1.3 — Remove FlutterSecureStorage for Upload Paths
File: `upload_path_storage.dart`

Delete `savePath()`, `removePath()`, `getAllPendingPaths()`, `clearAll()` usage from providers.  
Replace all calls with direct SQLite reads/writes.  
The secure storage is only needed for auth tokens — not upload queue data.

Update `UnifiedUploadQueueProvider`:
- Remove all `UploadPathStorage` calls
- All state flows through SQLite + in-memory `_queue` list

### Task 1.4 — Eliminate `native_uploads.json` as Independent State
File: `UploadStateManager.kt` & `MainActivity.kt`

Change `UploadStateManager` to be a **read-through cache** of SQLite, not an independent store:
- `syncToNative()` writes items to a JSON file, but it's always a snapshot of SQLite
- Native service reads this snapshot, but **never writes back status changes to it**
- Instead, native service writes progress/status via **MethodChannel calls** back to Flutter, which updates SQLite directly
- The native JSON file is deleted after every sync — it's only for crash survival

---

## Phase 2: Heartbeat + Alive Detection

**Goal**: Know definitively whether the native foreground service is alive.

### Task 2.1 — Flutter-Side Heartbeat Poll (replaces current polling)
File: `unified_upload_queue_provider.dart`

Replace the 3-second polling (which reads native state file) with a **heartbeat check**:
- Every 10 seconds, call `NativeUploadBridge.ping()` (new MethodChannel method)
- `ping()` returns `true` if the `:upload` process is alive (service responds)
- If 3 consecutive pings fail → consider native dead → recovery

### Task 2.2 — Android `ping()` Handler
File: `MainActivity.kt`

```kotlin
"ping" -> {
    // Return true if UploadReschedulerService is alive
    // Can check via bound service or a static AtomicBoolean flag
    result.success(isUploadServiceAlive)
}
```

In `UploadReschedulerService`, set a static flag `isAlive = true` in `onCreate()`, `false` in `onDestroy()`.

### Task 2.3 — SQLite Heartbeat Updates
File: `UploadReschedulerService.kt`

During upload, write heartbeat timestamp to SQLite via MethodChannel call every 30 seconds.  
Add method `updateHeartbeat(uploadId)` that updates `heartbeatMs` in the SQLite row.

---

## Phase 3: Idempotent Upload + Recovery Pipeline Fix

**Goal**: No duplicate S3 uploads, no duplicate server callbacks, no stuck states.

### Task 3.1 — State Machine (Strict Transitions)
File: `upload_queue_repository.dart` + providers

Enforce strict state transitions:
```
pending → uploading → completed
pending → uploading → failed → pending (on retry)
pending → cancelled
uploading → completed (only if native confirms)
uploading → failed
```

Add validation in `updateStatus()`:
```dart
// Reject invalid transitions
if (current == 'completed' && newStatus != 'completed') return;
if (current == 'cancelled' && newStatus != 'cancelled') return;
```

### Task 3.2 — Fix Recovery Phase 2 (native_init.dart)
File: `native_init.dart`

Current problem: `_recoverNativeOrphans()` reads native_uploads.json and writes to SQLite. But native_uploads.json might be stale.

New logic:
1. Check if `:upload` process is alive (heartbeat check)
2. If alive → do nothing (service is managing state)
3. If dead → read native_uploads.json as **last known state**
4. Items marked `completed` in native JSON → mark completed in SQLite
5. Items marked `uploading` in native JSON → check actual S3 file via HEAD request (is the file on S3?)
   - If file exists on S3 → call server callback idempotently, mark completed
   - If file does not exist → reset to `pending`
6. Items marked `pending` → reset to `pending` in SQLite
7. Delete native_uploads.json
8. Reset all `uploading` in SQLite → `pending` (no 30-min wait needed since we have real state)

### Task 3.3 — Idempotency Key for Server Callbacks
File: `UploadReschedulerService.kt`

Before making server callback, generate an idempotency key:
```kotlin
val idempotencyKey = "${item.uploadId}_callback_${System.currentTimeMillis()}"
```

Send as header: `Idempotency-Key: <key>`

The server must reject duplicate idempotency keys (return 409 Conflict).  
If callback succeeds, mark `serverCallbackCompleted = 1` in SQLite.

### Task 3.4 — Native Upload Completion Protocol
File: `UploadReschedulerService.kt` & `MainActivity.kt`

When S3 upload + server callback both succeed:
1. Native marks its in-memory state as completed
2. Native calls **Flutter via MethodChannel** `onNativeUploadCompleted(uploadId, fileUrl)`
3. Flutter marks SQLite as completed
4. **Only then** does native remove the item from its JSON file

If Flutter is dead when native completes:
- Native writes completion to a **new, separate file** `native_completed.json` (instead of modifying main state file)
- On next app start, recovery pipeline reads this file, marks items completed, deletes file

---

## Phase 4: S3 Multipart Upload (for Large Files)

**Goal**: Resume large uploads from where they failed, chunked uploads for GB files.

### Task 4.1 — Server Changes Needed
Coordinate with backend:
- API to initiate multipart upload → returns `{uploadId, uploadUrl}` (PUT URL for single part)
- Better: Use S3 Multipart Upload API directly from native
  - `CreateMultipartUpload` → returns UploadId
  - `UploadPart` for each chunk
  - `CompleteMultipartUpload`
  - `AbortMultipartUpload` on failure/cancel

### Task 4.2 — Multipart Upload in Native Service
File: `UploadReschedulerService.kt`

- Chunk size: 5MB-10MB (S3 minimum 5MB per part except last)
- After each successful part upload, save `{partNumber, ETag}` to local file
- On resume:
  1. Check how many parts were already uploaded
  2. `ListParts` API to verify with S3
  3. Resume from the last unconfirmed part
- On cancel: `AbortMultipartUpload` (clean up S3 parts)

### Task 4.3 — Parallel Part Uploads
File: `UploadReschedulerService.kt`

Use a thread pool (2-4 threads) to upload parts in parallel for speed.  
Maintain ordering — parts must be completed in sequence.

---

## Phase 5: Duplicate Prevention

### Task 5.1 — Dedup by `uploadId` (not filePath)
File: `UnifiedUploadQueueProvider`

Current dedup is `same filePath + uploadType` — this breaks re-upload of same file.  

New dedup:
- Check for `pending`/`uploading` items with same `uploadId` → block
- If same filePath but different `uploadId` → allow (user is re-uploading)
- If same filePath with completed/failed `uploadId` → allow

### Task 5.2 — Worker ID Uniqueness
File: `UploadReschedulerService.kt`

Each foreground service invocation gets a unique `workerId` based on `uploadId`.  
Use `ExistingWorkPolicy.APPEND_OR_REPLACE` in WorkManager.  
Never start two foreground services processing the same `uploadId`.

### Task 5.3 — Cancel Protocol
File: `cancelNativeUpload()` + `cancelTask()`

When user cancels:
1. Set SQLite status to `cancelled` immediately
2. Call native to stop foreground service
3. If mid-S3-upload → abort (for multipart: `AbortMultipartUpload`)
4. Native calls `onNativeUploadCancelled(uploadId)` → Flutter confirms
5. Remove from native JSON

---

## Phase 6: Notification Fixes

### Task 6.1 — Single Notification Source
File: `upload_notification_service.dart` & `UploadReschedulerService.kt`

Notifications should only come from **one place**: either Flutter or native.  
Since native runs in separate process, native should handle all foreground notifications.  
Flutter should not create duplicate notification channels.

### Task 6.2 — Fix Endless Notification Loop
File: `UploadReschedulerService.kt`

Current problem: notification is updated on every 1% progress change. For 2GB files, that's 200 updates.  
Fix: update notification every **5%** and on state transitions (start, complete, fail).  
Also add a notification timeout: if no progress for 5 minutes, show warning notification.

---

## Phase 7: Code-Level Changes (Detailed)

### File: `upload_queue_repository.dart`
- Add `uploadId`, `workerId`, `heartbeatMs`, `retryCount`, `idempotencyKey`, `nativeMarkedCompleted`, `serverCallbackCompleted` fields
- Enable WAL mode + busy timeout
- Add `getByUploadId(uploadId)`, `updateHeartbeat(id, timestamp)`, `markNativeCompleted(id)`, `markCallbackCompleted(id)` methods
- Add `resetStaleUploading()` without 30-min window (just check heartbeat)

### File: `unified_upload_queue_provider.dart`
- Remove all `UploadPathStorage` calls
- Replace dedup by `uploadId` (UUID generated on insert)
- Replace 3-second polling with 10-second heartbeat polling
- Add `onNativeCompleted(uploadId)` handler
- Add `_checkNativeAlive()` method that calls `ping()` and triggers recovery if dead
- Remove `_lastNativeTotal` tracking (flaky)
- Store completed notification IDs to avoid double-toast

### File: `native_init.dart`
- Phase 1: Remove FSS recovery (no longer needed)
- Phase 2: Check heartbeat first; if native alive → skip recovery entirely
- Phase 2: For native-completed items, verify S3 file exists (HEAD request)
- Phase 2: For native-uploading items, check if file exists on S3
- Phase 3: Reset `uploading` items to `pending` immediately (no 30-min wait)
- Phase 4: Only start native if there are `pending` items in SQLite

### File: `MainActivity.kt`
- Add `ping()` method → returns service alive flag
- Add `onNativeUploadCompleted(uploadId, fileUrl)` → calls Flutter side
- Add `updateHeartbeat(uploadId)` → calls Flutter side
- Add `nativeUploadFailed(uploadId, error)` → calls Flutter side

### File: `UploadStateManager.kt`
- Simplify to just read/write snapshot for crash survival
- Add `saveCompleted(uploadId, fileUrl)` → writes to `native_completed.json`
- `clear()` deletes both `native_uploads.json` and `native_completed.json`

### File: `UploadReschedulerService.kt`
- Add heartbeat thread (every 30s → update SQLite via MethodChannel)
- Add `idempotencyKey` to callback requests
- On S3 success + callback success → call `onNativeUploadCompleted()` to Flutter
- On S3 success + callback fail → retry callback (separate from S3 retry)
- Add multipart upload support for files > 100MB
- Fix notification update frequency (every 5% or on state change)
- Add `isAlive` static flag

### File: `manage_module_provider.dart`
- Remove `_restorePendingUploads()` reliance on native state items (use SQLite only)
- In `_startProgressPolling()`, remove the `items.isEmpty` orphan cleanup block (this was the hacky fallback that created duplicates)

### File: `UploadWorker.kt`
- Don't auto-start service if heartbeat shows native is already alive
- Check `nativeMarkedCompleted` flag before restarting uploads

---

## Phase 8: Migration Plan

### Step 1: DB Schema + WAL
Implement schema v5 first. Deploy to prod. No behavior change yet.

### Step 2: Add `uploadId` Generation
Start generating `uploadId` on new inserts. Old rows get `NULL` — handled gracefully.

### Step 3: Remove FSS Dependency
Migrate all FSS reads to SQLite reads. Verify no regressions.

### Step 4: Add Heartbeat
Deploy native heartbeat. Start tracking `heartbeatMs` in SQLite.

### Step 5: Fix Recovery Pipeline
Deploy new recovery logic. Remove 30-min stale lock window.

### Step 6: Multipart Upload
Deploy multipart for files > 100MB. Keep single PUT for smaller files.

### Step 7: Idempotency + Callback Fixes
Deploy idempotency keys. Coordinate with backend.

### Step 8: Remove Legacy Code
Delete `upload_path_storage.dart`, old polling code, FSS recovery from `native_init.dart`.

---

## Success Criteria

- [ ] Upload 500MB+ video, kill app → upload completes, no duplicates
- [ ] Upload 1GB+ video, kill app → upload resumes from last checkpoint
- [ ] Upload 2GB+ video, reboot device → upload resumes
- [ ] Toggle airplane mode during upload → upload auto-resumes
- [ ] Cancel mid-upload → S3 parts cleaned up, no zombie rows
- [ ] Retry failed upload → new `uploadId`, clean slate
- [ ] Re-upload same file → new `uploadId`, no dedup collision
- [ ] 5 simultaneous uploads → all tracked independently
- [ ] App updated during upload → upload continues
- [ ] SQLite crash during write → WAL prevents corruption, recovery works
- [ ] Server callback fails → retried with idempotency key, no duplicate
- [ ] Notification shows accurate progress, no endless updates
