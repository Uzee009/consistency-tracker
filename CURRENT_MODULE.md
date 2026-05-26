# CURRENT_MODULE.md

**Module:** Step 13 — Cross-Device Sync (PocketBase, Local-First)
**Branch:** `experiment`
**State:** IN_PROGRESS
**Current Phase:** Phase 2 — Manual sync (NOT STARTED)
**Last updated:** 2026-05-26

---

## Goal

Tick a task on one device, see it on the others in ~1–2s while online; work fully
offline and reconcile automatically on reconnect; never lose data.

Architecture: Local-first SQLite (full mirror) + dumb central server (PocketBase) +
a small hand-rolled push/pull sync loop. Pure-Dart client (HTTP + SSE) — same code on
Linux/Windows/macOS/Android. Conflict resolution = Last-Write-Wins on a client-set
`updated_at`. Full spec in `DEVELOPMENT_PLAN.md` → "Appendix: Cross-Device Sync".

---

## Phases & Sub-tasks

- **Phase 0 — Local refactor (no network).** `[DONE]` ✅ (2026-05-26, committed)
  - `[DONE]` Task identity migrated from auto-increment `int id` → client-generated UUID `sid TEXT`.
  - `[DONE]` Split `day_records.completed_task_ids` into `task_status` (one row per completion/skip) + `day_meta` (per-day single-value state).
  - `[DONE]` `completion_score` / `visual_state` now derived locally from `task_status` via `ScoringService`.
  - `[DONE]` Added sync columns (`updated_at`, `deleted`, `dirty`) to `tasks`, `task_status`, `day_meta`.
  - `[DONE]` DB migration v7 → v8, automatic on first launch.
  - `[DONE]` Verified: app runs identically on Linux with dev DB; no user-visible change.

- **Phase 1 — PocketBase up + auth.** `[DONE]` ✅
  - `[DONE]` Run PocketBase binary locally (v0.38.2; migration applied via `./pocketbase migrate up`).
  - `[DONE]` Create collections mirroring local tables (JS migration `1748260800_init_sync_collections.js` creates `tasks`, `task_status`, `day_meta` with `owner` relation + owner-scoped rules + unique indexes).
  - `[DONE]` Add a login screen (`lib/screens/login_screen.dart`, reachable from Settings → Sync Account; non-blocking / local-first).
  - `[DONE]` Add a connectivity service (`lib/services/connectivity_service.dart` + `lib/services/pocketbase_service.dart` with AsyncAuthStore token persistence).
  - `[DONE]` End-to-end verify: run server, create shared app account, sign in from the app, confirm token survives restart.
  - `[DONE]` Dev-mode auto-login via gitignored `config/dev.json` (+ tracked `config/dev.json.example`); app silently signs in as the dev account on startup in dev mode, non-blocking.

- **Phase 2 — Manual sync.** `[NOT STARTED]`
  - `[ ]` "Sync now" button running the push/pull loop.
  - `[ ]` Prove correctness across two devices/dev DBs (per A.10 test plan).

- **Phase 3 — Automatic + realtime.** `[NOT STARTED]`
  - `[ ]` dirty-on-write (debounced ~500ms) + SSE subscribe + focus/resume + 60s safety poll.

- **Phase 4 — Deploy + harden.** `[NOT STARTED]`
  - `[ ]` Deploy to free VM (Oracle Cloud Always Free preferred), point app at it.
  - `[ ]` Retry/backoff, tombstone cleanup, multi-device soak test. Optional: E2E encryption (deferred from v1).

---

Phase 1 COMPLETE, code-reviewed (cycle 2 PASS), end-to-end verified by the user, and committed+pushed to origin/experiment as a checkpoint. PocketBase auth + token persistence + connectivity + login screen all working; dev auto-login wired via config/dev.json (gitignored). No sync engine yet. Ready to begin Phase 2 (manual 'Sync now' push/pull loop per DEVELOPMENT_PLAN.md A.5).

---

## Review History

- **2026-05-26 — code-reviewer on Phase 0 migration (commit `eef25d1`): FAIL.**
  App compiles (`flutter analyze` clean) and runs on a fresh DB, but the v7→v8
  migration has correctness bugs on real upgrade paths. Findings (prioritized):
  - **[CRITICAL]** `database_service.dart:141-290` — migration not wrapped in a
    transaction; crash mid-migration leaves DB permanently broken.
  - **[CRITICAL]** `database_service.dart:170` — `row['id'] as int` cast fragile;
    use `(row['id'] as num).toInt()`.
  - **[MAJOR]** `database_service.dart:218-289` — `day_records` cache CSV updated but
    `completion_score`/`visual_state` NOT recomputed → stale cached score after
    migration when orphaned (hard-deleted) task ids are silently dropped.
  - **[MAJOR]** `database_service.dart:569-582` — `getTaskHistory` still uses
    `LIKE '%sid%' OR cheat_used = 1`; returns ALL cheat days for any task, inflating
    history/streaks. Should query `task_status` directly.
  - **[MAJOR]** `database_service.dart:487-489` — a sid in both completed+skipped sets
    gets written twice to `task_status` (skipped wins), contradicting the cache row.
  - **[MINOR]** `:221` shadowed `now`; `:141` not idempotent (no `IF NOT EXISTS`);
    `:574` LIKE-on-CSV will false-negative after Phase 1 sync.
  → **User decision (2026-05-26): FIX ALL.** Fix plan below; cycle 1 in progress.

## Fix Plan (Phase 0 review remediation — cycle 1, COMPLETE ✅)

Single file: `lib/services/database_service.dart`.

**Applied all 8 fixes:**

1. ✅ **#1 transaction** — Added comment documenting sqflite's exclusive transaction guarantee.
2. ✅ **#2 cast** — Changed `row['id'] as int` → `(row['id'] as num).toInt()`.
3. ✅ **#3 stale score** — Restructured migration day-loop: process `day_records` in ASC date
   order, maintain chronological `history`, recompute `completion_score`/`visual_state`
   via `ScoringService.calculateDayScore`, write full `finalRecord.toMap()` to cache.
4. ✅ **#4/#8 getTaskHistory** — Rewrote to query `task_status` (DISTINCT dates) then fetch
   `day_records` by `date IN (...)`. Eliminates `LIKE`/CSV-based `cheat_used` false-positives.
5. ✅ **#5 double-write** — In `createOrUpdateDayRecord`, deduped skipped against completed
   (`newSkippedSids..removeAll(record.completedTaskIds)`); completed wins.
6. ✅ **#6 shadow** — Single migration-wide `now` at line 149; removed inner shadowing.
7. ✅ **#7 idempotency** — Added `DROP TABLE IF EXISTS tasks_new` before create; used
   `CREATE TABLE IF NOT EXISTS` for `task_status`/`day_meta`.
8. ✅ **Helper methods** — Added `_remapCsvToSids()` (drop orphaned ids) and
   `_activeTasksFor()` (in-memory date-window filter for score re-derivation).

**Verification:**
- `flutter analyze`: PASS (zero database_service.dart errors; 7 pre-existing unrelated warnings).
- File compiles and all imports/methods resolve correctly.

**Cycle 1 code-reviewer result: FAIL (1 new issue).** All 8 original fixes confirmed
correct. New regression introduced by fix #3: the recompute loads `migratedTasks` via
`db.query(tasksTable)` with NO filter, so archived (`is_active=0`) tasks are passed to
`_activeTasksFor` → inflates the scoring denominator → migrated-day scores lower than the
live path. Live `getActiveTasksForDate` filters `deleted = 0 AND is_active = 1`.

## Fix Plan — cycle 2 (gemini-coder)

- Change the `migratedTasks` load to `db.query(tasksTable, where: 'deleted = 0 AND
  is_active = 1')` so the migration recompute matches the live scoring path. Re-run
  code-reviewer (cycle 2 of max 3).

**Cycle 2 code-reviewer result: PASS ✅ (2026-05-26).** WHERE clause matches the live
`getActiveTasksForDate` path; CSV remap / `task_status` population unaffected (built from
the full `oldIntIdToSid` map, not the filtered list); chronological `history` + recompute
chain intact; `git diff` shows only intended changes; `flutter analyze` clean.

**Status: Phase 0 migration review remediation COMPLETE.** All 8 findings fixed across 2
cycles. Changes are UNCOMMITTED working-tree edits to `lib/services/database_service.dart`
(awaiting user decision to commit). The fixes go *beyond* commit `eef25d1`, so the
"Phase 0 ✅ committed" status above now has follow-up fixes not yet committed.

---

## Session 2026-05-26: Phase 1 Complete

**Deliverables completed:**

1. **`.gitignore`** — Updated to track `pocketbase/pb_migrations/` while ignoring the binary and data.
2. **Dependencies** — Added `pocketbase ^0.24.0` and `connectivity_plus ^7.1.1` via `flutter pub add`.
3. **PocketBase migration** `1748260800_init_sync_collections.js` — Creates `tasks`, `task_status`, `day_meta` base collections with `owner` relation, access rules (list/view/create/update/delete restricted to authenticated owner), and unique indexes.
4. **`PocketBaseService.instance`** — Singleton managing auth state (ValueNotifier), login/logout, server URL persistence, token restoration via PocketBase's default auth store.
5. **`ConnectivityService.instance`** — Singleton tracking online/offline status via `connectivity_plus`, re-checks on connectivity change and on-demand via HTTP GET to `/api/health`.
6. **`LoginScreen`** — StatefulWidget with email, password, optional Advanced server URL field; shows loading spinner, error messages, logs user in and returns to settings.
7. **Settings screen "Sync Account" section** — Displays auth status (signed in/out with email), login/logout buttons, online/offline indicator (green/orange dot).
8. **`main.dart`** — Initializes both services before `runApp()`. App remains fully offline-capable (local-first).

**Verification:**
- `flutter pub get`: All dependencies resolved.
- `flutter analyze`: 7 pre-existing warnings/info (not new); 0 Phase 1 errors.
- `pocketbase migrate up`: Migration applies cleanly (no SQL errors).
- Code compiles: All imports and method calls resolve.

**Status: Phase 1 READY FOR PHASE 2.** The app now has:
- ✅ PocketBase backend configured
- ✅ Auth UI (login screen)
- ✅ Connectivity detection
- ✅ Auth state management
- ❌ Sync engine (Phase 2)

**Next action:** Begin Phase 2 — plan the manual push/pull sync engine (~300 lines, one file) per DEVELOPMENT_PLAN.md A.5, then a 'Sync now' button. Plan with user before coding.

---

## Phase 1 Review Cycle 1 (2026-05-26)

- **2026-05-26 — code-reviewer on Phase 1 (cycle 1): FAIL.** 4 findings:
  - **[CRITICAL]** `pocketbase_service.dart:27` — auth token is never persisted; uses default in-memory AuthStore so token lost on restart.
  - **[MAJOR]** `connectivity_service.dart:31-32` — health check hardcodes `http://127.0.0.1:8090/api/health`; should read live server URL from PocketBaseService.
  - **[MAJOR]** `pocketbase_service.dart:30,74` — `onChange` subscription leaks/goes stale on `setServerUrl()`; new client built without re-subscribing.
  - **[MINOR]** `pocketbase/pb_migrations/1748260800_init_sync_collections.js` — field `id` set equal to field name instead of auto-generated or unique ids.

## Fix Cycle 1 Applied (2026-05-26)

**FIX 1 (CRITICAL) — `pocketbase_service.dart:23-43` (lines changed)**
- Added `import 'dart:async'` for `StreamSubscription`.
- Added `_authSub` field to store the auth change subscription.
- Rewrote `init()`: creates `AsyncAuthStore` with shared_preferences backing (`save` and `initial` callbacks), passes it to `PocketBase(...)`, calls new `_subscribeToAuthChanges()` helper, sets initial auth state.
- Added `_subscribeToAuthChanges()` private method to subscribe and update `authState.value` on token changes.
- **Result:** Auth token now persists across app restarts via shared_preferences; `isAuthenticated` returns true on fresh start if user previously logged in.

**FIX 2 (MAJOR) — `connectivity_service.dart:6,31-34` (lines changed)**
- Added `import 'pocketbase_service.dart'` at top.
- Changed hardcoded `'http://127.0.0.1:8090/api/health'` to `'${PocketBaseService.instance.serverUrl}/api/health'`.
- Added comment documenting dependency on PocketBaseService initialization (guaranteed by main.dart).
- **Result:** Health checks now use live server URL; respects user-set custom server URLs.

**FIX 3 (MAJOR) — `pocketbase_service.dart:82-99` (lines changed)**
- Rewrote `setServerUrl()`: cancels old `_authSub` before URL change, rebuilds client preserving `authStore`, re-subscribes via `_subscribeToAuthChanges()`, updates `authState.value`.
- **Result:** Subscription no longer leaks; auth state updates work correctly after URL change.

**FIX 4 (MINOR) — `pocketbase/pb_migrations/1748260800_init_sync_collections.js:15-29, 41-49, 61-69` (all 3 schemas)**
- Removed all `id:` keys from field definitions in `tasks`, `task_status`, `day_meta` schemas.
- Kept `name` and all other field properties (type, required, presentable, collectionId, maxSelect, cascadeDelete) unchanged.
- Owner relation, indexes, and access rules unchanged.
- **Result:** PocketBase now auto-generates field IDs instead of hardcoding them to field names.

## Validation Results

1. **Migration validation:** Deleted `pb_data/` (dev-only, git-ignored), ran `pocketbase migrate up` from pocketbase/:
   ```
   Applied 1748260800_init_sync_collections.js
   ```
   ✅ Clean apply, no errors.

2. **Flutter analysis:** Ran `flutter pub get` then `flutter analyze`:
   ```
   7 issues found (all pre-existing, unrelated to Phase 1 fixes):
   - 1 warning: missing flutter_lints include
   - 2 info: deprecated window API usage
   - 4 warnings: unused local var, unused param, unused import, unused field
   ```
   ✅ No new Phase 1 errors.

3. **Diff summary:**
   - **pocketbase_service.dart:** Added async/StreamSubscription import; added _authSub field; rewrote init() to use AsyncAuthStore (30-50 loc change); added _subscribeToAuthChanges(); rewrote setServerUrl() to cancel/re-subscribe (82-99 loc).
   - **connectivity_service.dart:** Added pocketbase_service import; updated health check URL read; added dependency comment (6 loc change).
   - **1748260800_init_sync_collections.js:** Removed `id:` from all 28 field definitions across 3 schemas (3 × ~14 lines each).

**Status: Fix Cycle 1 COMPLETE — ALL 4 ISSUES RESOLVED.** Code compiles; migration applies cleanly; no new lint errors. Ready for next code-reviewer cycle or Phase 2 work.

---

## Phase 1 Review Cycle 2 (2026-05-26)

- **2026-05-26 — code-reviewer on Phase 1 (cycle 2): PASS ✅.** All 4 cycle-1 findings fixed (AsyncAuthStore token persistence, connectivity uses live serverUrl, onChange subscription re-wired in setServerUrl, migration field ids auto-generated). flutter analyze clean (7 pre-existing warnings only); app builds + runs on Linux.

---

## Next Action

Begin Phase 2 — plan the manual push/pull sync engine (~300 lines, one file) per DEVELOPMENT_PLAN.md A.5, then a 'Sync now' button. Plan with user before coding.

