# CURRENT_MODULE.md

**Module:** Step 13 — Cross-Device Sync (PocketBase, Local-First)
**Branch:** `experiment`
**State:** IN_PROGRESS
**Current Phase:** Phase 4 — Cleanup pass (IN_PROGRESS), then Deploy
**Last updated:** 2026-05-27 (SESSION CONCLUDED — Phase 4 cleanup + seed removal pushed; deploy guide at deploy/DEPLOYMENT_GUIDE.md; awaiting user infra provisioning)

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

- **Phase 2 — Manual sync.** `[DONE]` ✅
  - `[DONE]` ✅ **Task 0 (prerequisite):** Fix broken Phase-1 PB collections. ✅
  - `[DONE]` ✅ **Task 1:** Sync engine `lib/services/sync_service.dart` (~300 lines) per A.5 —
    push dirty rows (LWW folded into push via natural-key lookup) then pull changed remote rows
    (server `updated` autodate as per-collection cursor in shared_preferences), then full
    chronological recompute of the `day_records` derived cache.
  - `[DONE]` ✅ **Task 2:** "Sync now" button in Settings → Sync Account (spinner + result snackbar;
    disabled when offline or not signed in).
  - `[ ]` **Task 3:** Prove correctness across two dev DBs per A.10 test plan.

- **Phase 3 — Automatic + realtime.** `[DONE]` ✅ (2026-05-27)
  - `[DONE]` dirty-on-write trigger (DatabaseService.localChanges notifier → SyncService debounced 500ms)
  - `[DONE]` PocketBase SSE realtime subscribe on all 3 collections → debounced pull
  - `[DONE]` app focus/resume (WidgetsBindingObserver) + 60s safety poll
  - `[DONE]` connectivity reconnect (offline→online) → re-subscribe realtime + flush dirty
  - `[DONE]` always-on (no settings toggle); efficiency: recompute/dataChanged only when pushed+pulled>0
  - `[DONE]` ghost-task bugfix (Fixes A + C)
  - `[DONE]` race-condition fix: atomic recomputeAllDerived + transactional createOrUpdateDayRecord + WAL + optimistic/debounced UI refresh + write-mutex (synchronized Lock). Code-reviewed PASS.
  - `[DONE]` verified single-device (no random HABITS COMPLETED swings) and two-device (CONVERGED+CONSISTENT at rest). Accepted caveat: ±1 ~1.5s pull-path lag during simultaneous dual-device storms (eventual-consistency, heals at rest) — deferred to Phase 4.

## Session 2026-05-27: Phase 3 ghost-task bugfix

During live two-device realtime verification, ghost tasks (deleted but tombstoned) appeared momentarily with stale completion states ("1 day left") during rapid GUI clicks. Root cause analysis identified two bugs:

**Bug 1 (transient):** Eventual consistency lag on weak connections — deleted task stays visible ~1-2s until tombstone SSE arrives (self-heals).

**Bug 2 (data corruption):** `deleteTaskPermanently()` tombstones task + task_status but NOT day_records cache CSV; next `createOrUpdateDayRecord()` uses stale `completedTaskIds` and resurrects deleted task_status rows with deleted=0, dirty=1.

**Fixes implemented:**

**Fix A (comprehensive cache cleanup):**
- Location: `lib/services/database_service.dart` lines 577-624
- When `deleteTaskPermanently(sid)` tombstones a task, now comprehensively removes the sid from ALL `day_records` cache rows (not just creation date)
- Iterates all day_records, removes sid from both `completed_task_ids` and `skipped_task_ids` CSVs, updates only changed rows
- Code-reviewer: PASS ✅

**Fix C (SharedPreferences namespacing):**
- Locations: database_service.dart (helper), main.dart, pocketbase_service.dart, audio_service.dart, settings_screen.dart, first_run_setup_screen.dart
- All SharedPreferences keys now namespaced by DATABASE_NAME via `DatabaseService.prefixedKey(key)` helper
- Prevents Device A and Device B from cross-contaminating cache state when running on same machine
- Code-reviewer: PASS ✅

**Verification:**
- `flutter analyze`: PASS (0 new errors; 7 pre-existing unrelated warnings)
- App builds and runs without crashes
- Ready for live two-device re-verification

**Next action:** Restart live two-device monitoring to verify the bugfixes prevent ghost-task reappearance.

- **Phase 4 — Deploy + harden.** `[IN_PROGRESS]` (cleanup pass order A→C→B→D)

  ### Phase 4 Cleanup (Dev Mode, order A→C→B→D)

  - `[DONE] A — Lint hygiene: make flutter analyze green (remove dangling flutter_lints include, fix 2 deprecated window uses, remove 4 unused symbols).`
  - `[ ] C — Pre-deploy safety audit: confirm dev gating is compile-time only (no code change expected).`
  - `[DONE] B — Tombstone pruning: local prune deleted=1 AND dirty=0 older than 30d; server prune deleted tombstones older than 90d; daily-guarded; documented resurrection caveat. Code-reviewed PASS (2026-05-27).`
  - `[DONE] D — Retry/backoff: exponential backoff (2s→cap 60s) in SyncService: _isTransient classifies ClientException (0/5xx/429=transient, other 4xx=permanent), _runScheduled schedules retry only on transient error, _cancelRetry on success/offline/permanent, retry timer cancelled in stopAuto. — code-reviewer PASS (7 axes incl. in-flight-retry chain survival via _pendingSync), flutter analyze clean.`

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

- **2026-05-26 — code-reviewer on Phase 2 Task 1 (sync engine), cycle 1: FAIL → fixed.**
  5 findings addressed: (1) recomputeAllDerived now does a FULL rebuild (clears day_records
  first) so tombstoned dates leave no phantom cache rows; (2) pull cursor uses `>=` (LWW makes
  boundary re-apply idempotent) so equal-timestamp rows are never skipped; (3) _applyRemote insert
  uses ConflictAlgorithm.replace; (4) _push counts only actual create/update writes (dirty still
  cleared for every row); (5) PB filter values now escape embedded double-quotes. Re-review pending.

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

- **2026-05-26 — Phase 2 Task 1 cycle 2: PASS ✅.** All 5 cycle-1 fixes verified correct, no
  regressions. recomputeAllDerived now does a FULL rebuild (clears day_records
  first) so tombstoned dates leave no phantom cache rows;
  `>=` cursor cannot skip or infinite-loop (LWW idempotent); ConflictAlgorithm.replace on insert;
  push counts only real writes; filter values escaped.
- **2026-05-26 — Phase 2 Task 2 ("Sync Now" button): verified.** flutter analyze clean (whole
  project: only the 7 pre-existing warnings). Button wired in Settings → SYNC & CONNECTIVITY:
  disabled while syncing or signed out, inline spinner, snackbar via captured ScaffoldMessenger,
  last-synced timestamp shown.
- **2026-05-26 — Task 0 follow-up bug found during live API testing + FIXED.** PocketBase treats a
  `required: true` NUMBER field value of 0 as "blank", so creating a task with `duration_days: 0`
  (valid for daily/perpetual tasks) failed with `validation_required`. Removed `required` from all
  NUMBER fields (`tasks.duration_days`, and `updated_at` in tasks/task_status/day_meta); text fields
  and the owner relation stay required. Migration re-applied (field counts still 16/10/11; users
  preserved).
- **2026-05-26 — Server-side end-to-end smoke test (headless curl, regular dev user): PASS ✅.**
  Against the running PocketBase as dev@local.com (a non-superuser): owner-scoped create with
  duration_days=0 → 200; owner-scoped list returns the row; LWW PATCH → 200; duplicate (owner,sid)
  → 400 (unique index enforced); task_status + day_meta creates → 200; deletes → 204; unauthenticated
  list returns 200 with 0 items (rule filters, no leak). Confirms the corrected collections accept
  the exact wire format SyncService._push builds.
- **2026-05-26 — Two-device test (Task 3) surfaced a real sync bug → diagnosed + FIXED + reviewed.**
  Symptom: tasks synced but task COMPLETIONS did not (both directions), and after deleting dev2.db
  sync stopped entirely. Root cause: the pull cursor lived in shared_preferences, which is SHARED by
  two same-machine instances (same app id) while their SQLite DBs are separate — so each instance
  poisoned the other's cursor (`updated >= cursor` then skips everything ≤ a cursor advanced by the
  other instance). Fix: moved the cursor into a per-device DB table `sync_state(collection PK, cursor)`
  (DB bumped v8→v9; helpers getSyncCursor/setSyncCursor; _pull now reads/writes the DB, shared_preferences
  import removed). Empty cursor → full pull, so a NEW instance pulls ALL data (user's stated goal); deleting
  a DB now also resets its cursor (self-healing). code-reviewer: PASS. (The Atk-CRITICAL / Gdk cursor-theme
  console lines and "Syncing files to device" were benign GTK/hot-reload noise, not sync errors.)
- **2026-05-26 — Two-device retest surfaced duplicate/"zombie" tasks + stale UI → root-caused, FIXED, reviewed.**
  Root cause of duplicates was NOT the sync engine: main.dart ran seedData() on EVERY launch of the
  dev DB, and seedData() hard-deletes all rows (no tombstone) and regenerates tasks with NEW uuid sids.
  So each launch pushed a fresh generation to the server while old sids stayed there forever → 3×/4×
  duplicates + zombies; also explained the "indefinite sync" (each reseed re-pushed ~180 days, server
  kept growing). Fixes: (1) main.dart now seeds ONLY when the dev DB is empty (`!hasUser()`); reseed by
  deleting the DB file. (2) Post-sync UI refresh: SyncService.dataChanged ValueNotifier bumped on success;
  HomeScreen listens → reloads DashboardController; added a manual Refresh button in the global header.
  code-reviewer: PASS (one cosmetic header-spacing note, fixed). Also fixed earlier: PB number fields
  marked required rejected 0 (duration_days), and the pull cursor moved into per-device DB sync_state.
- **2026-05-26 — One-time test cleanup performed.** Server records cleared (tasks/task_status/day_meta →
  0; schema, rules, indexes, users, superuser preserved). Deleted ~/Documents/consistency_tracker_dev.db
  and consistency_tracker_dev2.db so Device A reseeds ONE clean generation and Device B pulls clean.

Known limitations (deferred, documented): push is O(N) round-trips (fine for v1; batch later if needed);
name-based reconciliation for genuinely-divergent offline DBs is the A.9 caveat (not triggered here).
Nothing committed this session (awaiting explicit user instruction).

---

## Session 2026-05-27: Phase 3 implementation

Implemented automatic and realtime sync triggers by:
1. Adding a `localChanges` notifier to `DatabaseService` triggered by every local write.
2. Adding a `clientRevision` notifier to `PocketBaseService` to handle client/auth changes.
3. Implementing a coordinator in `SyncService` that listens to local changes, connectivity, auth, and PocketBase realtime SSE (SSE subscriptions for tasks, task_status, and day_meta).
4. Adding `WidgetsBindingObserver` to `lib/main.dart` to trigger sync on app resume, and starting the auto-sync engine on startup.
5. Optimized `SyncService.sync()` to skip expensive cache recomputes when no data has changed.

---

## Session 2026-05-27 (cont.): Phase 3 sync race-condition fix

**Real root cause found.** The "ghost task (Gym Workout, 1 day left)" reported earlier was NOT a
product bug — it was a broken test harness: two app instances were launched with bare `flutter run`
(no `--dart-define`), so BOTH opened the DEFAULT production DB `consistency_tracker.db` and raced
each other, producing `database is locked (code 5)` errors. "Gym Workout" is a legitimate active
task in production and does not appear when production runs alone.

**The actual reproducible bug:** rapidly toggling a single task makes the dashboard "HABITS
COMPLETED" stat jump to random values (122 → 27 → 1072 → 372 → 142…), even in a single instance.

Cause: `DatabaseService.recomputeAllDerived()` did `db.delete(dayRecordsTable)` then rebuilt ~180
rows one await at a time, NOT in a transaction. Each toggle marks rows dirty → Phase-3 sync fires
(500ms debounce) → runs recompute, while each toggle ALSO ran a full `initialize()` that reads all
366 day_records to compute the stat. Reads landing mid-rebuild saw a partially-populated cache.

**Fixes (full hardening, all code-reviewed PASS 2026-05-27):**
- **Fix 1:** `recomputeAllDerived()` wrapped in a single `db.transaction` (atomic delete+rebuild).
  `lib/services/database_service.dart`.
- **Fix 2:** `createOrUpdateDayRecord()` STEP 1–3 wrapped in one `db.transaction`;
  `_notifyLocalChange()` moved to after commit; return semantics preserved.
- **Fix 3:** WAL mode enabled via `onConfigure` (`PRAGMA journal_mode=WAL; busy_timeout=5000;`) in
  `_initDatabase()`.
- **Fix 4:** `lib/controllers/dashboard_controller.dart` — `toggleTaskCompletion`/`toggleTaskSkip`
  now do an optimistic in-memory `todayRecord` update + `notifyListeners()` for instant feedback,
  then a 280ms DEBOUNCED `initialize()` (`_scheduleRefresh()`) instead of a full re-read on every
  click. `dispose()` cancels the debounce timer.

Verification: `flutter analyze` clean (7 pre-existing warnings only); `flutter build linux` OK;
code-reviewer confirmed no nested-transaction deadlock and DayRecord field preservation in the
optimistic update.

**Test harness correction:** DB selection is COMPILE-TIME via
`--dart-define=DATABASE_NAME=...` (database_service.dart:14), NOT an env var. Correct launch:
- Device A: `flutter run -d linux --dart-define=DATABASE_NAME=consistency_tracker_dev.db`
- Device B: `flutter run -d linux --dart-define=DATABASE_NAME=consistency_tracker_dev2.db`
Bare `flutter run` uses production — never use it for two-device testing.

---

## Next Action

Phase 4 cleanup COMPLETE — all four items code-reviewed PASS, flutter analyze clean:
- A (lint hygiene): analyzer now zero issues (removed dangling flutter_lints include, fixed 2 deprecated window uses, removed 4 unused symbols).
- C (pre-deploy safety): audit PASS, NO code change — dev seed + dev auto-login are compile-time gated on String.fromEnvironment('DATABASE_NAME'); a release build with no --dart-define gets '' so both no-op; dev creds only in gitignored config/dev.json.
- B (tombstone pruning): DatabaseService.pruneLocalTombstones (deleted=1 AND dirty=0 AND >30d) + SyncService._maybePrune (server prune deleted=true AND >90d, owner-scoped, getFullList batched, 404-ignored) guarded once/day via sync_state '__last_prune__'; errors swallowed so sync never fails from pruning. Documented caveat: a device offline >90d that saw create-but-not-delete can resurrect that row on next edit.
- D (retry/backoff): SyncService exponential backoff 2s→cap60s; _isTransient classifies ClientException (statusCode 0 / >=500 / 429 = transient, other 4xx = permanent), non-ClientException = transient; _runScheduled schedules retry only on transient error, _cancelRetry on success/offline/notSignedIn/permanent; retry timer cancelled in stopAuto; manual 'Sync Now' never arms a retry.

ALL CHANGES UNCOMMITTED (awaiting user approval to commit). NEXT: plan deployment — deploy PocketBase to a free VM (Oracle Cloud Always Free preferred) and repoint the app's default server URL from 127.0.0.1:8090 to the deployed host. Deferred: pull→recompute ±1 ~1.5s lag fix.

PRE-DEPLOY DECISIONS (2026-05-27): (1) Removed all dev data-seeding logic (DatabaseService.seedData + main.dart seed gate) — a fresh dev DB now goes through normal first-run setup, no fake 'Test Pilot'/180-day data. (2) TLS via free DuckDNS subdomain + PocketBase built-in Let's Encrypt. (3) Server starts FRESH/EMPTY — existing local history is NOT migrated up; the server fills naturally from new edits. (Implication: because dirty defaults to 0, pre-existing local rows won't auto-push; that's acceptable given the start-fresh decision.) Still TODO before/at deploy: repoint default _serverUrl from 127.0.0.1:8090 to the DuckDNS https URL, and reset the per-device pull cursor in setServerUrl() so switching servers does a clean full pull.

SESSION PAUSE (2026-05-27): Phase 4 cleanup (A/B/C/D) committed as 765cb58; dev seed removal committed as b55e0fa. Both LOCAL on branch experiment, NOT pushed (2 commits ahead of origin). Deployment decisions: Oracle Cloud Always Free Ampere A1 (ARM/aarch64) Ubuntu; TLS via DuckDNS + PocketBase built-in Let's Encrypt; server starts FRESH/EMPTY (no data migration). User is provisioning infra themselves first. WHEN USER RETURNS they will bring: DuckDNS hostname, reserved public IP, confirmation ports 80/443 open (both Oracle security list AND in-VM iptables — Oracle Ubuntu images DROP inbound by default), and CPU arch. THEN do: (1) gemini-coder creates deploy/ kit — systemd unit for PocketBase, setup script (fetch PB v0.38.2 linux/arm64 binary + pb_migrations/, serve --http=0.0.0.0:80 --https=0.0.0.0:443 for Let's Encrypt on the DuckDNS host), backup cron, deploy/README.md runbook (incl. exact iptables commands for 80/443). (2) Code: repoint default _serverUrl in lib/services/pocketbase_service.dart (lines 14 & 32) from http://127.0.0.1:8090 to https://<duckdns-host>; and reset the per-device pull cursor inside setServerUrl() (clear sync_state rows) so switching servers does a clean full pull. (3) PB admin: create superuser + app login account. (4) Verify two-device against live server. Workflow reminder: each code change → code-reviewer → flutter analyze clean; all writes via gemini-coder; commit only when user says so; --yolo on headless gemini.
