# CURRENT_MODULE.md

**Module:** Step 13 — Cross-Device Sync (PocketBase, Local-First)
**Branch:** `experiment`
**State:** IN_PROGRESS
**Current Phase:** Phase 1 — PocketBase up + auth (NOT STARTED)
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

- **Phase 1 — PocketBase up + auth.** `[NOT STARTED]` ← **NEXT**
  - `[ ]` Run PocketBase binary locally (validated v0.38.2 in the spike).
  - `[ ]` Create collections mirroring local tables: `tasks`, `task_status`, `day_meta` (with `owner` field for future multi-user).
  - `[ ]` Add a login screen (single PocketBase account; all devices share it).
  - `[ ]` Add a connectivity service (online/offline detection).

- **Phase 2 — Manual sync.** `[NOT STARTED]`
  - `[ ]` "Sync now" button running the push/pull loop.
  - `[ ]` Prove correctness across two devices/dev DBs (per A.10 test plan).

- **Phase 3 — Automatic + realtime.** `[NOT STARTED]`
  - `[ ]` dirty-on-write (debounced ~500ms) + SSE subscribe + focus/resume + 60s safety poll.

- **Phase 4 — Deploy + harden.** `[NOT STARTED]`
  - `[ ]` Deploy to free VM (Oracle Cloud Always Free preferred), point app at it.
  - `[ ]` Retry/backoff, tombstone cleanup, multi-device soak test. Optional: E2E encryption (deferred from v1).

---

## Working Context

Phase 0 (the local data-model refactor) is complete AND its code-review remediation is
done — all pushed to `origin/experiment`. Commits: `eef25d1` (migration) + `c1b7441`
(docs) + `6643693` (the review-hardening fix). The v7→v8 migration is now crash-safe
(sqflite wraps onUpgrade in a transaction), recomputes derived scores chronologically,
and `getTaskHistory` reads `task_status` instead of the old CSV-LIKE hack. The app
behaves identically to before and is verified on Linux with the dev DB.

A throwaway spike (`sync_spike/`, git-ignored) already validated the whole approach
against real PocketBase v0.38.2: 73 ms realtime propagation, correct LWW, and correct
offline reconcile. So the strategy is de-risked; what remains is wiring a real PocketBase
backend + sync engine into the actual app.

No network/sync code exists in the app yet — **Phase 1 has not been started.** The
workflow files (`CLAUDE.md`, `CURRENT_MODULE.md`, `.claude/agents/*`) are now tracked in
git; `.claude/settings.local.json` is gitignored (per-machine).

## Next Action

Begin **Phase 1**. Suggested first step: stand up the PocketBase binary locally and
create the three collections (`tasks`, `task_status`, `day_meta`) mirroring the local
schema (including an `owner` field). Then, with the user, plan the login screen +
connectivity service before writing any code (per the Coding Workflow: plan → approve →
gemini-coder → code-reviewer). Confirm Dev vs. Consult mode with the user at session start.

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
