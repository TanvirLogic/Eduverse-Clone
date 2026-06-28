# Session Summary — Jun 28, 2026

## Goal
Make `manage_module_screen` video upload flow reliable: progress bar updates in real-time, notification survives app kill, upload completes with server callback even after app kill. Also ensure `upload_video_screen` is production-ready with proper error feedback.

## Completed

### Native notification + persistence
- `UploadTask.fromFile` configured with `group: 'upload_queue'` in `BackgroundUploaderService.enqueueUpload`
- `TaskNotificationConfig` for `'upload_queue'` group registered in `UnifiedUploadQueueProvider._init()` — notification survives app kill
- `FileDownloader.configure(runInForeground: Config.always)` in `native_init.dart`

### Proactive native-record checks
- `recordForId()` query in `_loadQueue()` detects native completion immediately on app restart
- `recordForId()` check in `_restorePendingUploads()` skips creating `PendingLesson` if native upload already complete

### Callback retry on failure
- `_handleNativeComplete` does NOT `markFailed()` on callback failure — keeps item `uploading` with `nativeMarkedCompleted=1` for retry
- Queue pump (section 1b) retries items with `isNativeCompleted && !isCallbackCompleted`
- `isNativeCompleted` items skipped in stale reset check (queue pump section 1)

### Progress bar fixes (`_PendingLessonRow` in `module_card.dart`)
- **Before**: `_processNextItem` resets `_activeProgress = 0`; UI showed "Waiting to upload..." text (from `pending.uploadStatus`) with a 0% bar (from `isActiveUpload`) — text/bar mismatch
- **Before**: After upload completed, text stayed "Uploading X%" (from stale `pending.uploadStatus`) until 1s `_pollProgress` caught up
- **Fix**: New text/bar logic:
  - `isActiveUpload && progress > 0` → determinate bar + "Uploading X%"
  - `isActiveUpload && progress == 0` → indeterminate bar + "Preparing..."
  - `!isActiveUpload && pending.uploadStatus == 'uploading'` → indeterminate bar + "Processing..." (transient until `_pollProgress` runs)
  - `pending.uploadStatus == 'completed'` → full bar + "Upload complete"
  - `pending.uploadStatus == 'failed'` → indeterminate bar + "Upload failed"

### Proactive native-status check in queue pump (new)
- Added `recordForId()` check in `_queuePump()` (section 1a, every 15s) for items in `'uploading'` state with `nativeMarkedCompleted=0`
- Detects native uploads that completed (100% in notification tray) but whose `TaskStatus.complete` callback never fired
- Triggers `_handleNativeComplete` immediately when native record shows `status == complete` or `progress >= 1.0`
- Also syncs progress from native DB when the progression callback is missing

### FIFO queue order preserved across app restarts
- **Problem**: After restart, `_isUploading` was `false` even though a native upload was still running, so the queue pump immediately started the next pending item — both uploaded concurrently, breaking FIFO
- **`_loadQueue` fix**: When `recordForId` finds a **running** native task, sets `_isUploading = true`, `_activeItem = item`, and calls `notifyListeners()` — tells the queue engine that an upload is already in progress
- **`_processNextItem` fix**: Added a check for any existing `'uploading'` item with a valid `workerId` — if one exists, defers and releases the lock
- Result: Pending items wait until the running native upload completes, then `_onItemTerminal` starts the next one in FIFO order

### Concurrent callback guard (`_handleNativeComplete`)
- Added `Set<int> _handlingNativeComplete` to prevent duplicate server callbacks
- `_handleNativeComplete` can be triggered from 4 sources (native callback, `_loadQueue`, queue pump 1a, queue pump 1b)
- Without the guard, two concurrent invocations would `POST /course/module/lesson` twice, creating duplicate lessons on the server
- Guard is released in `finally` block

### Polling
- `_pollProgress` interval reduced from 5s → 1s in `_startProgressPolling()`
- `_startProgressPolling()` called from `addVideoLesson()`, `_restorePendingUploads()`, and restore flow (line 355)

### Logging
- `_loadQueue`, `_restorePendingUploads`, `_pollProgress` log percentages and status transitions

### Crash resilience — lost native task recovery
- **Problem**: App crash during upload kills native WorkManager task too. After restart, `recordForId` returns null. The item stayed in `'uploading'` forever (stuck) or until the 10-min stale reset (removed from UI temporarily).
- **Fix in `_loadQueue`**: When `recordForId` returns null for an `'uploading'` item, reset status to `'pending'` and clear `workerId` — the queue picks it up and re-uploads it immediately.
- **Fix in `_queuePump` (section 1a)**: Same check every 15s — if `recordForId` returns null, reset to `'pending'`. This catches the case where the crash happened before `_loadQueue` ran.

### Crash resilience — video navigation while uploading
- **Problem**: Hard-to-reproduce crash when tapping a video lesson to play it while another video is being uploaded. Exact cause unknown (no stack trace), but likely a platform channel interruption, provider race during navigation, or SystemChrome call failure.
- **Fix in `manage_module_screen.dart`**: Wrapped `Navigator.push` in try-catch around `onTapVideo` — navigation failure shows toast instead of crashing the app.
- **Fix in `video_player_screen.dart`**: Wrapped entire `initState` postFrameCallback body in try-catch — any error during fullscreen entry or provider initialization is silently recovered; the video screen shows its built-in error state via `provider.hasError`.

### Crash resilience — resource link opening
- `onTapResource` in `manage_module_screen.dart:293` — `launchUrl` wrapped in try-catch
- `course_details_screen.dart:853` — `launchUrl` wrapped in try-catch
- `social_links_row.dart:43` — `launchUrl` wrapped in try-catch
- `profile_helpers.dart:83` — `launchUrl` wrapped in try-catch

### Single notification service
- **Problem**: Two notifications appeared during upload — one from `background_downloader` native (via `configureNotificationForGroup`) and one from Dart `UploadNotificationService.showQueueProgress`
- **Fix**: Removed `UploadNotificationService.showQueueProgress` from `_onNativeTaskProgress` and `showQueueAllComplete`/`stopService` from `_onItemTerminal` in `unified_upload_queue_provider.dart`. Now only the native `background_downloader` notification shows — it survives app kills and has progress bar.

### Native upload buffer size increased (8KB → 64KB)
- **Problem**: `background_downloader` native Kotlin code reads file in 8KB chunks (`2 shl 12`) — too small for multi-GB videos, causing excessive I/O overhead
- **Fix**: Changed `bufferSize` in `TaskRunner.kt:110` and `TaskWorker.kt:31` from `2 shl 12` to `64 * 1024` (64KB). Uploads now read 64KB per chunk instead of 8KB, reducing read/write cycles by 8×.
- **Permanent solution**: Copied the package to `packages/background_downloader` and added `dependency_overrides` in `pubspec.yaml` — survives `pub upgrade` and `pub cache repair`.
- **Also fixed**: Custom `filterNotNull()` extension returned `Map<K, V>` with nullable `K` type — downstream `mapKeys { it.key.lowercase() }` failed because `it.key` was still `String?`. Changed to `mapKeys { it.key!!.lowercase() }`.
- **⚠️**: If the original package has breaking API changes in a future version, the local fork must be manually updated to match.

### Notification double %% fix
- **Problem**: Native Kotlin code (`Notifications.kt:1023`) appends `%` to the progress value (`"45%"` for 0.45), and the Dart template also had `%` after `{progress}` → resulted in `"45%% completed"` in the tray.
- **Fix**: Changed template from `'{progress}% completed'` to `'{progress} completed'` — native already adds the `%`.
- Reviewed the standalone video upload screen against the queue integration
- **Fix**: Added `ToastService.showError('Failed to queue video. Please try again.')` in the `addToQueue` catch block of `UnifiedUploadQueueProvider` — previously, unexpected exceptions during queuing silently logged with no user feedback
- Screen correctly handles: file selection, form validation, file-exists check, mounted guards, queuing via `UnifiedUploadQueueProvider.addToQueue`, and navigation pop on success
- No changes needed in the screen itself — all feedback paths (permission denied, duplicate file, upload URL failure, generic exception) now display a toast

## Known Issues / Open
- The navigation-to-video crash (while upload is in progress) is guarded by try-catch but root cause is unknown. A `FlutterError.onError` or platform-level handler could provide a stack trace if it reproduces in a release build with crash reporting (Sentry/Firebase Crashlytics).
- Queue pump retries server callback forever (every 15s) — no max-retry limit. Harmless if the server eventually responds, but could drain battery if the server endpoint is permanently broken. Consider adding a max-retry cap and dead-letter state.
- No file size validation when queuing uploads. The upload streams in chunks so OOM is avoided, but a 24-hour S3 timeout means files over ~2GB (depending on network speed) will fail. Add a warning if this is a concern.
- Callback thread (`_handleNativeComplete`) and queue pump are not wrapped in top-level try-catch. Dart's async timer swallows exceptions so no crash risk, but errors won't appear in logs. Add a try-catch if log visibility is needed.

## Relevant Files
- `lib/features/manage_module/presentation/widgets/module_card.dart` — `_PendingLessonRow`, text/bar logic at lines 212-240; `progress` takes `max(nativeProgress, dbProgress)` so `_pollProgress` (via `recordForId`) serves as fallback when `_onNativeTaskProgress` isn't firing
- `lib/features/courses/providers/unified_upload_queue_provider.dart` — `_handleNativeComplete`, `_onItemTerminal`, `_loadQueue`, queue pump, `addToQueue`
- `lib/features/manage_module/providers/manage_module_provider.dart` — `_pollProgress`, `_startProgressPolling`
- `lib/features/courses/services/background_uploader_service.dart` — `enqueueUpload`, group config
- `lib/features/courses/services/background_upload_service.dart` — `fetchPresignedUrl`, `sendServerCallback`; `uploadFileToS3` timeout increased 30 min → 24 hours
- `lib/global/core/services/upload_notification_service.dart` — `showQueueProgress`, `startService`, `stopService`
- `pubspec.yaml` — `dependency_overrides` for local `packages/background_downloader`
- `packages/background_downloader/android/.../TaskRunner.kt` — `bufferSize` 8KB → 64KB
- `packages/background_downloader/android/.../TaskWorker.kt` — `bufferSize` 8KB → 64KB
- `lib/features/courses/data/repositories/upload_queue_repository.dart` — SQLite CRUD
- `lib/app/native_init.dart` — `FileDownloader.configure(runInForeground: Config.always)`
- `lib/features/manage_module/presentation/screens/manage_module_screen.dart` — `onTapVideo` wrapped in try-catch, `onTapResource` wrapped in try-catch
- `lib/features/profile/student/presentation/widgets/video_player_screen.dart` — `initState` postFrameCallback wrapped in try-catch; `provider.restart()` → `seek(Duration.zero) + play()`
- `lib/features/course_details/presentation/screens/course_details_screen.dart` — `launchUrl` wrapped in try-catch
- `lib/features/profile/student/presentation/widgets/social_links_row.dart` — `launchUrl` wrapped in try-catch
- `lib/features/profile/shared/helpers/profile_helpers.dart` — `launchUrl` wrapped in try-catch
- `lib/features/courses/services/background_upload_service.dart` — `uploadFileToS3` timeout increased 30 min → 24 hours
