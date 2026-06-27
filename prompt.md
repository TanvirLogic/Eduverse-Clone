# Background Video Upload System – Complete Context and Problem Statement

You are a senior Android + Flutter architect. I need you to analyze my existing upload architecture and provide a production-grade solution for large video uploads that survive app kills, process death, device restarts, and network interruptions without duplicate uploads or stuck states.

# Current Stack

* Flutter
* Provider state management
* SQLite
* FlutterSecureStorage
* Native Android upload process (Kotlin)
* Foreground Service + Notifications
* S3 Presigned URL uploads
* Server callback after upload completion

The system currently works perfectly while the app stays open. The issue happens when uploading large videos and the app is killed.

---

# Existing Upload Flow

## UI Entry Point

manage_module_screen.dart

User taps:

```dart
+ Video
```

Calls:

```dart
ManageModuleAddLessonSheet.show(
  lessonType: LessonType.video,
  moduleId: provider.modules[index].id,
  courseId: provider.courseId,
  onAddLesson: provider.addVideoLesson,
)
```

---

# User Picks Video

manage_module_add_lesson_sheet.dart

1. User selects video using:

```dart
ImagePicker.pickVideo()
```

2. User taps Upload.

3. Calls:

```dart
widget.onAddLesson(title, file)
```

which becomes:

```dart
provider.addVideoLesson()
```

---

# ManageModuleProvider.addVideoLesson()

Current flow:

1. `_isQueuing` lock
2. Dedup check
3. Add to UnifiedUploadQueueProvider
4. Create PendingLesson
5. Store in `_pendingLessons`
6. notifyListeners()
7. Start polling
8. Unlock

PendingLesson appears only after:

* SQLite insert succeeds
* Presigned URL succeeds
* Native upload synchronization succeeds

---

# UnifiedUploadQueueProvider Flow

1. Dedup check
2. Create metadata
3. Insert into SQLite
4. Notify UI
5. Notification permission
6. Fetch presigned URL
7. Start native upload
8. Save upload URL + file URL
9. Start queue processing
10. Start completion polling

---

# Native Upload Service

Native side:

* Kotlin service
* Separate :upload process
* Uses MethodChannel
* Uses native_uploads.json
* Survives app kill
* Uploads directly to S3 using presigned URL
* Sends server callback after upload completion.

---

# Current Polling

## ManageModuleProvider Polling

Every 5 seconds:

* Reads native queue.
* Updates PendingLesson.
* Marks completed.
* Removes completed items.
* Silent refresh.

---

## UnifiedUploadQueueProvider Polling

Every 3 seconds:

* Marks SQLite completed.
* Clears completed.
* Clears native state.

---

# Recovery Pipeline

native_init.dart

Phase 1:

Recover FlutterSecureStorage.

Phase 2:

Recover native orphans.

Phase 3:

Reset stale locks.

Phase 4:

Auto resume.

Pseudo:

```dart
if (native empty)
   sync sqlite -> native
```

---

# Current States

```text
pending
uploading
completed
failed
cancelled
```

---

# Dedup

Current dedup:

```dart
same filePath + uploadType
```

---

# Requirements

The upload system must support:

✅ Very large videos (500MB, 1GB, 2GB+)

✅ Upload continues after app kill.

✅ Upload continues after Flutter process death.

✅ Upload survives Android process recreation.

✅ Upload survives device restart.

✅ Upload survives network switching.

✅ No duplicate uploads.

✅ No endless notification loop.

✅ No stuck uploading state.

✅ No orphan SQLite rows.

✅ No orphan native uploads.

✅ No duplicate server callbacks.

✅ No duplicate S3 uploads.

✅ Progress restoration after app restart.

✅ User can retry failed uploads.

✅ User can cancel uploads.

✅ User can re-upload the same file later.

---

# Current Problem

Everything works when the app stays open.

Problem happens when:

1. User uploads a very large video.
2. User kills the app.
3. Native process continues.
4. User reopens app.
5. Recovery pipeline starts.
6. SQLite and native states become inconsistent.
7. Auto-resume starts duplicate uploads.
8. Notification tray continuously shows uploading.
9. Large uploads eventually fail or become stuck.

Sometimes:

* Multiple workers upload the same file.
* Duplicate server callbacks happen.
* SQLite says uploading while native is completed.
* Native says uploading while Flutter thinks upload is dead.
* Endless upload notifications appear.

---

# Existing Storage Sources

Currently there are multiple sources of truth:

1. SQLite
2. Flutter memory
3. FlutterSecureStorage
4. native_uploads.json
5. WorkManager state
6. Notification state

I suspect these become inconsistent after app kill.

---

# What I Need From You

Please redesign this architecture as if it were a production app like:

* YouTube
* Google Drive
* Dropbox
* Udemy

I need recommendations for:

## Architecture

* Single source of truth
* Upload ownership
* State synchronization
* Recovery pipeline
* Process death handling
* Worker recovery
* Notification handling

## Android Side

* Foreground Service
* WorkManager
* Service lifecycle
* Worker IDs
* Unique work policies
* Duplicate prevention
* Process recreation
* Device reboot handling

## Flutter Side

* Provider architecture
* Recovery strategy
* Polling improvements
* State restoration
* Pending lesson management

## Database

Recommended schema:

* uploadId
* workerId
* engine state
* heartbeat
* retry count
* timestamps

## Upload Strategy

Should I:

* Keep single PUT uploads?
* Use S3 Multipart Upload?
* Chunk uploads?
* Resume uploads?

## Edge Cases

Handle all of these:

### App kill during upload

### Device reboot during upload

### Internet lost during upload

### App updated during upload

### Multiple uploads simultaneously

### User cancels upload

### User retries upload

### User uploads same file again

### Native process dies

### SQLite corruption

### Callback failure

### Server timeout

### Notification permission denied

### Upload takes several hours

---

# Deliverables I Need

Please provide:

1. Complete architecture redesign.
2. Production-grade upload flow diagram.
3. State machine diagram.
4. Database schema.
5. Recovery algorithm.
6. Duplicate prevention strategy.
7. Native queue ownership strategy.
8. Retry strategy.
9. Recommended Android APIs.
10. Recommended Flutter changes.
11. Exact code-level changes I should implement.
12. Migration plan from my current architecture.

Think like a senior engineer designing an upload system for millions of users and provide the most robust solution possible.
