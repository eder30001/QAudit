---
phase: 15-photos-per-item
reviewed: 2026-05-07T23:37:44Z
depth: standard
files_reviewed: 8
files_reviewed_list:
  - primeaudit/supabase/migrations/20260510_create_checklist_item_images.sql
  - primeaudit/lib/models/checklist_item_image.dart
  - primeaudit/lib/services/checklist_image_service.dart
  - primeaudit/lib/screens/checklist/checklist_execution_screen.dart
  - primeaudit/test/checklist_item_image_test.dart
  - primeaudit/test/checklist_image_service_test.dart
  - primeaudit/test/checklist_photo_isolation_test.dart
  - primeaudit/test/checklist_photo_strip_test.dart
findings:
  critical: 5
  warning: 5
  info: 3
  total: 13
status: issues_found
---

# Phase 15: Code Review Report

**Reviewed:** 2026-05-07T23:37:44Z
**Depth:** standard
**Files Reviewed:** 8
**Status:** issues_found

## Summary

Phase 15 adds photo-per-item support to the checklist execution flow. The overall
architecture — isolated `_failedSaves` state, parallel bulk-image loading, and
fire-and-forget upload with snackbar feedback — is well-designed. However, five
BLOCKER-level defects were found spanning security (RLS bypass, Storage policy
scope creep, dangling Storage objects), correctness (null crash, backoff
off-by-one), and a missing file-type validation layer. Five additional warnings
and three info items round out the findings.

---

## Critical Issues

### CR-01: Storage RLS policies scope all authenticated users — any company can read/write another company's photos

**File:** `primeaudit/supabase/migrations/20260510_create_checklist_item_images.sql:113-137`

**Issue:** The three `storage.objects` policies (`authenticated_upload_checklist_images`,
`authenticated_read_checklist_images`, `authenticated_delete_checklist_images`) are
declared with `TO authenticated` — every logged-in user of the platform, across all
companies — not scoped to the `checklist-images` bucket guard. The only isolation is
that `(storage.foldername(name))[1] = get_my_company_id()::text`, which means a user
can upload, read, or delete any file whose top-level folder happens to match their own
company UUID. The critical gap: these are **blanket policies on `storage.objects`**.
`DROP POLICY IF EXISTS` on `storage.objects` will silently drop any same-named policy
that exists from a prior migration (e.g., `audit-images` bucket), and the new policy
covers all buckets that pass the `bucket_id` check. More dangerously, if
`get_my_company_id()` ever returns `NULL` (e.g., superuser with no active company set),
`NULL = NULL` evaluates to `NULL` (false), but the `IS NULL` case is never explicitly
handled — the behaviour is undefined. The table-level policies correctly scope by
`company_id`, but the Storage-level policies are weaker than they should be.

Additionally, the `authenticated_delete_checklist_images` Storage policy lets **any**
authenticated user in the same company delete *any* object in the company folder —
including photos belonging to other users' executions. The table-level `auditor`
DELETE policy correctly requires `created_by = auth.uid()`, but Storage delete can
bypass the table check entirely since you can delete the object without touching
the table row.

**Fix:**
```sql
-- Scope upload to the uploader's own company AND require role check
CREATE POLICY "authenticated_upload_checklist_images" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'checklist-images'
    AND get_my_company_id() IS NOT NULL
    AND (storage.foldername(name))[1] = get_my_company_id()::text
    -- Optional: also verify segment 2 is a valid execution owned by caller
  );

-- Scope delete: caller must own the row in checklist_item_images
CREATE POLICY "authenticated_delete_checklist_images" ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'checklist-images'
    AND get_my_company_id() IS NOT NULL
    AND (storage.foldername(name))[1] = get_my_company_id()::text
    AND EXISTS (
      SELECT 1 FROM checklist_item_images cii
      WHERE cii.storage_path = name
        AND cii.created_by = auth.uid()
    )
  );
```

---

### CR-02: `get_my_company_id()` returning NULL causes silent auth bypass in Storage policies

**File:** `primeaudit/supabase/migrations/20260510_create_checklist_item_images.sql:118,127,135`

**Issue:** `(storage.foldername(name))[1] = get_my_company_id()::text` — when
`get_my_company_id()` returns `NULL` (superuser with no company context, or any user
whose profile lacks `company_id`), the comparison becomes `<text> = NULL`, which
evaluates to `NULL` (falsy in a `WITH CHECK` context). This means a superuser/dev
with no active company context **cannot upload at all** via the Storage policy, even
though the table-level RLS grants them full access. The Storage block happens silently —
the upload call will return a permission-denied error with no clear explanation, leading
to confusing "Upload falhou" snackbars for legitimate admin users.

**Fix:**
```sql
-- Add explicit NULL guard:
AND get_my_company_id() IS NOT NULL
AND (storage.foldername(name))[1] = get_my_company_id()::text

-- OR use a separate superuser/dev policy on storage.objects:
CREATE POLICY "superuser_dev_storage_checklist_images" ON storage.objects
  FOR ALL TO authenticated
  USING (
    bucket_id = 'checklist-images'
    AND get_my_role() IN ('superuser', 'dev')
  )
  WITH CHECK (
    bucket_id = 'checklist-images'
    AND get_my_role() IN ('superuser', 'dev')
  );
```

---

### CR-03: `CompanyContextService.instance.activeCompanyId!` — null-bang crash in `_pickPhoto` and `_retryPhoto`

**File:** `primeaudit/lib/screens/checklist/checklist_execution_screen.dart:198,245`

**Issue:** Both `_pickPhoto` (line 198) and `_retryPhoto` (line 245) call
`CompanyContextService.instance.activeCompanyId!` with a hard `!` (null-bang). Per
`company_context_service.dart`, `activeCompanyId` is typed `String?` and can legitimately
be `null` for a superuser/dev user who has not selected an active company yet. If
the user reaches the checklist execution screen in this state (possible given the
service is a singleton that persists across navigation), the app will throw a
`Null check operator used on a null value` error and crash — losing the photo
attempt silently with no recoverable state. This violates the Core Value ("nenhum
dado preenchido em campo deve ser perdido").

**Fix:**
```dart
Future<void> _pickPhoto(String itemId) async {
  final messenger = ScaffoldMessenger.of(context);
  final companyId = CompanyContextService.instance.activeCompanyId;
  if (companyId == null) {
    messenger.showSnackBar(const SnackBar(
      content: Text('Contexto de empresa não definido. Selecione uma empresa.'),
      behavior: SnackBarBehavior.floating,
    ));
    return;
  }
  // ... rest of the method, replacing activeCompanyId! with companyId
}
```
Apply the same guard in `_retryPhoto` at line 245.

---

### CR-04: No file-type validation before upload — non-JPEG files are uploaded with forced `content-type: image/jpeg`

**File:** `primeaudit/lib/services/checklist_image_service.dart:47-54`

**Issue:** The storage path is always suffixed `.jpg` and `contentType` is hardcoded
to `'image/jpeg'`, but there is no validation that the `XFile` actually contains JPEG
data. `ImagePicker` with `imageQuality` set will re-encode the image on Android/iOS,
but the XFile extension is platform-dependent (may be `.png`, `.heic`, `.webp`, etc.,
on various devices). The content-type mismatch can cause browsers/`Image.network`
to fail to render the image, and on some platforms the raw bytes may be a PNG header
with a `.jpg` path, corrupting the storage object. Additionally, there is no max-size
check on `bytes` — a user could pick a very large file before `imageQuality`
compression, and `readAsBytes()` loads the full content into memory synchronously.

**Fix:**
```dart
Future<ChecklistItemImage> uploadImage({
  required String companyId,
  required String executionId,
  required String itemId,
  required XFile file,
}) async {
  final bytes = await file.readAsBytes();

  // Validate JPEG magic bytes (FF D8 FF)
  if (bytes.length < 3 ||
      bytes[0] != 0xFF || bytes[1] != 0xD8 || bytes[2] != 0xFF) {
    throw Exception(
        'Arquivo não é uma imagem JPEG válida. '
        'Selecione uma foto JPEG.');
  }

  // Optional size guard (e.g., 10 MB)
  const maxBytes = 10 * 1024 * 1024;
  if (bytes.length > maxBytes) {
    throw Exception('Imagem muito grande (máx 10 MB).');
  }

  final uuid = _uuid();
  final path = '$companyId/$executionId/$itemId/$uuid.jpg';
  // ... rest unchanged
}
```

---

### CR-05: Backoff `pow(2, attemptCount)` starts at 1s for attempt 0 but comment says "tentativa 0 = 1s" — actual first delay is `2^0 = 1s` but `attemptCount` is incremented **after** the delay, causing retries with stale data

**File:** `primeaudit/lib/screens/checklist/checklist_execution_screen.dart:354-378`

**Issue:** The retry loop reads `pending = _failedSaves[itemId]!` at the top of each
iteration and then computes `delaySeconds = pow(2, pending.attemptCount).toInt()`.
After a failed retry, it calls `setState(() { _failedSaves[itemId] = pending.copyWithAttempt(); })`.
On the **next** iteration, `pending` is re-read from `_failedSaves[itemId]!`, which
now has `attemptCount + 1`. This part is correct.

However, there is a race condition: `_saveAnswer` can be called independently (e.g.,
user taps an item again), which also calls `_scheduleRetry`. The guard
`if (_retrying.contains(itemId)) return` prevents a **second loop**, but the first
loop is already running and using a snapshot of `pending` captured before the
`await Future.delayed` gap. If the user manually retries via the snackbar action
(which calls `_saveAnswer` directly, bypassing the retry loop), the loop may
still be running with a stale `pending` and will clobber the result:

1. Loop iteration N reads `pending` at `attemptCount=2`.
2. User taps "Tentar novamente" — `_saveAnswer` succeeds and removes `itemId` from `_failedSaves`.
3. Loop wakes from `Future.delayed`, checks `_failedSaves.containsKey(itemId)` — now false — and breaks. Safe.

Actually this specific race is handled by the `containsKey` check after the delay. The
**real** bug is: when a retry **fails**, the loop does `setState(() { _failedSaves[itemId] = pending.copyWithAttempt(); })` — but `pending` was captured before `Future.delayed`. If `_saveAnswer` updated `_failedSaves[itemId]` with a newer response during the delay (user changed their answer), the loop now **overwrites** that newer response with the stale `pending.response`.

**Fix:** Re-read from `_failedSaves` after the delay instead of using the pre-delay snapshot:
```dart
while (_failedSaves.containsKey(itemId)) {
  // Re-read AFTER each delay, not once at the top
  final pending = _failedSaves[itemId]!;
  if (pending.attemptCount >= _maxAutoRetryAttempts) break;

  final delaySeconds = pow(2, pending.attemptCount).toInt();
  await Future.delayed(Duration(seconds: delaySeconds));

  if (!mounted || !_failedSaves.containsKey(itemId)) break;

  // Re-read again after the await — the user may have updated the answer
  final current = _failedSaves[itemId];
  if (current == null) break;

  try {
    await _answerService.upsertAnswer(
      executionId: widget.execution.id,
      itemId: itemId,
      response: current.response,       // use current, not stale pending
      observation: current.observation,
    );
    // ...
  } catch (_) {
    if (mounted) {
      setState(() {
        _failedSaves[itemId] = current.copyWithAttempt();
      });
    }
  }
}
```

---

## Warnings

### WR-01: `_scheduleRetry` calls `ScaffoldMessenger.of(context)` after `await` without prior capture

**File:** `primeaudit/lib/screens/checklist/checklist_execution_screen.dart:371`

**Issue:** Line 371 calls `ScaffoldMessenger.of(context).clearSnackBars()` inside the
retry loop, directly after `await _answerService.upsertAnswer(...)`. Unlike `_pickPhoto`
(which correctly captures `messenger` before any `await`), this call uses
`context` across an async gap. Flutter's `use_build_context_synchronously` lint will
flag this. Although the code guards with `if (mounted)` first, `mounted` does not
guarantee that `ScaffoldMessenger.of(context)` is safe — the context's `ScaffoldMessenger`
lookup can deactivate between the `mounted` check and the call if the widget is
being disposed.

**Fix:**
```dart
// At the top of _scheduleRetry, before the while loop:
if (!mounted) return;
final messenger = ScaffoldMessenger.of(context);

// Then inside the success branch:
if (mounted) {
  setState(() => _failedSaves.remove(itemId));
  messenger.clearSnackBars();
}
```

---

### WR-02: `deleteImage` leaves a dangling table row if Storage delete fails and the exception is swallowed, then DB delete also fails

**File:** `primeaudit/lib/services/checklist_image_service.dart:105-116`

**Issue:** `deleteImage` swallows Storage delete errors (correct — best-effort) and
then calls `_client.from('checklist_item_images').delete().eq('id', imageId)` without
`await`-ing a result check. More importantly, `_removePhoto` in the screen at line
283-287 wraps the entire `deleteImage` call in an empty `catch (_) {}`. This means:
if the DB delete fails (network error), the table row persists but the UI entry has
already been removed via `setState(() => photos.removeWhere(...))` at line 281 — the
photo disappears from the UI but the row stays in the DB. On next `_load()`, the
orphaned DB row will re-appear in the UI with no backing file (Storage object was
already deleted), causing `getSignedUrl` to fail and rendering an error thumbnail
permanently.

**Fix:** Do not remove the UI entry optimistically before confirming the DB delete:
```dart
Future<void> _removePhoto(String itemId, String key) async {
  final photos = _photosPerItem[itemId];
  if (photos == null) return;
  final idx = photos.indexWhere((p) => p.key == key);
  if (idx < 0) return;
  final entry = photos[idx];
  if (entry.image != null) {
    try {
      await _imageService.deleteImage(
          imageId: entry.image!.id, storagePath: entry.image!.storagePath);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Erro ao remover foto: $e'),
        behavior: SnackBarBehavior.floating,
      ));
      return; // Do NOT remove from UI if DB delete failed
    }
  }
  // Only remove from UI after confirmed delete
  if (mounted) setState(() => photos.removeWhere((p) => p.key == key));
}
```

---

### WR-03: `_pickPhoto` does not guard against `_finalizing = true` — photo upload can race with finalization

**File:** `primeaudit/lib/screens/checklist/checklist_execution_screen.dart:174,604-606`

**Issue:** `_onAnswer` guards against `_finalizing` with `if (_finalizing) return` at
line 159. But `_pickPhoto` has no such guard. The photo strip is rendered with
`readOnly: _finalizing` (line 601), which correctly disables the strip button in the
UI — but `_pickPhoto` is still callable programmatically, and more importantly:
between the time the user taps the camera button and the time `_pickPhoto`'s first
`await` completes, `_finalizing` could become true (user opened the confirmation
dialog from a different tap). The upload then runs concurrently with finalization,
and `setState` mutations on `_photosPerItem` after finalization could hit a disposed
state if `Navigator.pop` was already called.

**Fix:**
```dart
Future<void> _pickPhoto(String itemId) async {
  if (_finalizing) return;  // Guard added here
  final messenger = ScaffoldMessenger.of(context);
  // ...
}
```

---

### WR-04: `ChecklistItemImage.fromMap` casts every field with `as String` / `as String?` — no null safety on unexpected DB responses

**File:** `primeaudit/lib/models/checklist_item_image.dart:29-37`

**Issue:** Every field uses a hard cast (`map['id'] as String`, etc.). If Supabase
returns a row where any non-nullable field is `null` (e.g., a migration left the
column nullable, or a future migration adds a column with a default that is null for
old rows), the cast throws a `TypeError` at runtime, crashing the load and triggering
the full error screen — potentially losing the in-flight `_answers` state on refresh.
`DateTime.parse(map['created_at'] as String)` is doubly unsafe: if `created_at` is
null, the `as String` cast throws, and if it is a non-ISO8601 string, `parse` throws
`FormatException` without a descriptive message.

**Fix:**
```dart
factory ChecklistItemImage.fromMap(Map<String, dynamic> map) {
  return ChecklistItemImage(
    id: map['id']?.toString() ?? '',
    executionId: map['execution_id']?.toString() ?? '',
    itemId: map['item_id']?.toString() ?? '',
    companyId: map['company_id']?.toString() ?? '',
    storagePath: map['storage_path']?.toString() ?? '',
    createdBy: map['created_by']?.toString() ?? '',
    createdAt: map['created_at'] != null
        ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
        : DateTime.now(),
  );
}
```

---

### WR-05: `_load()` re-renders `_photosPerItem` by calling `addAll(photosMap)` — stale uploading/error entries from previous session are overwritten but in-progress uploads from the current session are not preserved

**File:** `primeaudit/lib/screens/checklist/checklist_execution_screen.dart:127-132`

**Issue:** On `_load()` (called on `initState` and on pull-to-refresh), the method
builds a fresh `photosMap` from DB rows and calls `_photosPerItem.addAll(photosMap)`.
Because `addAll` overwrites existing keys, any in-memory entries for `itemId`s that
are currently `uploading` or `error` state (added by a concurrent `_pickPhoto`) are
silently replaced by the DB snapshot. This means:

1. User taps camera → entry added with state `uploading`.
2. User pulls to refresh while upload is pending.
3. `_load()` runs, `photosMap` does not contain the in-progress entry (not yet in DB).
4. `addAll` does nothing for that itemId if there was no previous DB row, or overwrites
   if there was one.
5. The `uploading` entry disappears from the UI even though the upload continues.

The upload future is still running and will eventually call `setState` looking for
`photos.indexWhere((p) => p.key == key)` — that entry no longer exists, so `i = -1`
and the `if (i >= 0)` guard prevents an update. The upload orphans silently.

**Fix:** In `_load()`, merge photosMap into `_photosPerItem` preserving any entries
in `uploading` state:
```dart
// After building photosMap from DB rows:
for (final entry in photosMap.entries) {
  final existing = _photosPerItem[entry.key];
  if (existing != null) {
    // Preserve uploading/error entries not yet in DB
    final dbIds = entry.value.map((e) => e.image?.id).toSet();
    final pending = existing.where(
      (e) => e.image == null || !dbIds.contains(e.image!.id)
    ).toList();
    _photosPerItem[entry.key] = [...entry.value, ...pending];
  } else {
    _photosPerItem[entry.key] = entry.value;
  }
}
```

---

## Info

### IN-01: `_uuid()` in `ChecklistImageService` uses `dart:math` — not a standard UUID library

**File:** `primeaudit/lib/services/checklist_image_service.dart:19-32`

**Issue:** The UUID v4 implementation is hand-rolled. While `Random.secure()` provides
cryptographically secure bytes, the bit manipulation for the version nibble (`bytes[6]`)
and variant bits (`bytes[8]`) is correct per RFC 4122. However, the implementation
produces lowercase hex without the standard grouping `xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx`
check — the format is correct, but should be audited against `uuid` package output if
there are format-sensitive consumers (e.g., Storage path regex matching). The comment
says "sem dependência externa" which is a valid design choice, but it should be noted
that the `uuid` package is already a transitive dependency of `supabase_flutter`.

**Fix:** Consider using `const Uuid().v4()` from the already-available `uuid` package
transitively imported via `supabase_flutter`, rather than maintaining a custom
implementation.

---

### IN-02: Test suite uses placeholder/no-op tests that document rather than verify

**File:** `primeaudit/test/checklist_image_service_test.dart:30-34`

**Issue:** The test "upload failure does not touch _failedSaves — contract documented"
contains only `expect(true, isTrue)` — a placeholder that always passes and provides
zero coverage. It explicitly defers to `checklist_photo_isolation_test.dart`, but
the isolation test itself is also mock-only (no real service or widget under test).
Neither test would catch a regression where `_pickPhoto` was accidentally modified
to write to `_failedSaves`.

**Fix:** Replace the placeholder with a real contract assertion or delete it entirely.
A comment explaining the contract is sufficient documentation without a false-green test.

---

### IN-03: `_ChecklistPhotoStrip` is `StatelessWidget` but `_buildThumb` uses `File(p.file!.path)` — breaks on web platform

**File:** `primeaudit/lib/screens/checklist/checklist_execution_screen.dart:1467`

**Issue:** `Image.file(File(p.file!.path), fit: BoxFit.cover)` uses `dart:io`'s `File`
class which is not available on Web. The file `checklist_execution_screen.dart` already
imports `dart:io` (line 1). If the project ever targets Web (the scaffold is present in
`primeaudit/web/`), this will fail to compile. Additionally, `image_picker` on web
returns an XFile whose `path` is an object URL, not a filesystem path — `File(path)`
will construct an invalid File object that throws on any read. The correct cross-platform
approach for displaying a picked image is `Image.memory(await file.readAsBytes())` or
`XFileImage` if available.

**Fix:** Limit platform-specific code with a conditional, or store bytes in
`_ChecklistPhotoEntry` for cross-platform display:
```dart
// In _buildThumb, replace:
Image.file(File(p.file!.path), fit: BoxFit.cover)
// With:
kIsWeb
    ? Image.network(p.file!.path, fit: BoxFit.cover)
    : Image.file(File(p.file!.path), fit: BoxFit.cover)
// (requires import 'package:flutter/foundation.dart' show kIsWeb;)
```

---

_Reviewed: 2026-05-07T23:37:44Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
