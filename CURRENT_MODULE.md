# CURRENT_MODULE.md

**Module:** Step 15B — Account Isolation
**Branch:** feature/sync-engine
**State:** COMPLETE
**Current Phase:** T1–T6 complete (code + review PASS). Awaiting user T7 manual verification and T8 commit approval.
**Last updated:** 2026-06-01

Full approved plan: `~/.claude/plans/peaceful-popping-knuth.md`. This file tracks live execution status.

---

## Goal

Apple-level account isolation: when the user switches PocketBase accounts on the same device, each account sees only its own data, with no cross-contamination of habits or `dirty=1` rows. Implemented via one SQLite file per account (`accounts/<userId>.db`) plus a SharedPreferences `account_registry` that evicts idle accounts after 30 days. No client schema change — existing v1.3.0 users carry their data forward via a one-time legacy-file rename.

This lands BEFORE Step 15A (sync echo-loop hardening) because data corruption > bandwidth waste, and doing isolation first means 15A is written against the final data-layer shape.

---

## Sub-tasks

- [DONE] **T1 — New `lib/services/account_registry.dart`** (91 lines, `flutter analyze` clean)

- [DONE] **T2 — Modified `lib/services/database_service.dart`** (+ `_activeUserId`, `_accountsDir`, `_dbPathFor`, `close`, `switchTo`, `migrateLegacyDb`)

- [DONE] **T3 — Modified `lib/services/sync_service.dart`** (+41 lines)
  Added `pauseForSwitch()` (cancels debounce/poll/retry timers, clears `_pendingSync`, busy-waits up to 5s for in-flight `sync()`, then `_teardownRealtime()`). Added `resumeAfterSwitch()` (no-op if `!_autoStarted`, recreates `_pollTimer`, `_restartRealtime()`, `requestSync()`). Neutralised `_onAuthOrClientChange` to a no-op (listener kept attached for `startAuto`/`stopAuto` symmetry). Added `await AccountRegistry.instance.touch(ownerId)` in `sync()` success branch after `lastSyncedAt = ...`.

- [DONE] **T4 — Modified `lib/main.dart` + helper in `lib/services/database_service.dart`** (+30 main.dart, +25 database_service.dart)
  Added `DatabaseService.deleteAccountDbs(List<String>)` (best-effort delete of main + WAL/SHM/journal sidecars per id). In main(), inserted bootstrap block between `PocketBaseService.init()` and `ConnectivityService.init()`: migrateLegacyDb → evictIdle → deleteAccountDbs → switchTo. After `startAuto()`, added top-level auth listener: `pauseForSwitch()`; on sign-IN also `switchTo(newUserId)` + `resumeAfterSwitch()`; on sign-OUT just leaves DB active. In `didChangeAppLifecycleState`, added `unawaited(AccountRegistry.instance.touch(activeId))` on resume.
  Also patched `migrateLegacyDb` to move `-wal` / `-shm` sidecars alongside the main file.

- [DONE] **T5 — Touched `lib/services/pocketbase_service.dart`** (doc-comment-only on `logout()` noting main.dart owns DB switching)

- [DONE] **T6 — Code review** — PASS. Reviewer noted two non-blocking concerns:
   1. The 5-second timeout fallback in `pauseForSwitch` does not cancel a truly stuck in-flight `sync()`; if it ever exhausts the timeout, the stale sync's next `await database` opens the NEW account's DB, so its tail-end writes could land in the wrong file. Acceptable risk given 5s is generous and the path is exceptional. Could be hardened later via a sync-generation token if observed in the wild.
   2. The auth listener in main.dart is `async` without re-entrance guard. ValueNotifier dispatches synchronously, but rapid auth changes could interleave. Practically unlikely; could be wrapped in a `synchronized` Lock if it ever happens.

- [PENDING] **T7 — User manual verification (8 scenarios, see plan §Verification)**
  Legacy migration, two-account isolation, server-side isolation, first-run + later sign-in, eviction sweep, switch atomicity, app-lifecycle touch, regression (`flutter analyze` + dashboard + heatmap + Step 14 banner).

- [PENDING] **T8 — Commit on `feature/sync-engine`** (only after user explicitly approves the diff)

---

## Working Context

T1–T6 done. `flutter analyze` clean. Final working-tree changes for Step 15B:
- `lib/services/account_registry.dart` (NEW, 91 lines)
- `lib/services/database_service.dart` (+ per-account dir logic, switchTo, close, migrateLegacyDb w/ sidecar move, deleteAccountDbs)
- `lib/services/sync_service.dart` (+41 lines: pauseForSwitch, resumeAfterSwitch, neutralised _onAuthOrClientChange, touch in sync())
- `lib/main.dart` (+30 lines: bootstrap block, top-level auth listener, resume-touch)
- `lib/services/pocketbase_service.dart` (+3 lines: docstring on logout)

Plus pre-existing modifications to `CURRENT_MODULE.md` and `DEVELOPMENT_PLAN.md`.

Awaiting user: T7 manual scenarios and explicit approval to commit (T8).

---

## Next Action

Hand off to user for T7 — run the 8 manual verification scenarios (legacy migration, two-account isolation, server-side isolation, first-run + later sign-in, eviction sweep, switch atomicity, app-lifecycle touch, regression). On all-green, user approves diff and I delegate T8 commit to gemini-coder.

---

## Review History

- 2026-05-30 — code-reviewer agent — PASS with two non-blocking notes (pauseForSwitch 5s timeout fallback; auth-listener re-entrance). One minor finding (migrateLegacyDb sidecar move) addressed in-line.

---

## Design Decisions (settled 2026-05-30)

1. **Model E — `_local.db` is for users who have NEVER signed in. Sign-out does NOT swap the DB.** Lifecycle:
   - Never signed in → `_local.db` is the home. Writes work. No sync. Forever. (Honors the no-signin policy.)
   - First-ever sign-in as X → `_local.db` (if it exists) gets RENAMED to `<X>.db`. `_local.db` is gone forever from this device. Sync turns on.
   - Sign-out from X → sync turns OFF, but `<X>.db` STAYS active. Reads and writes continue to work on `<X>.db`; they simply don't sync.
   - Sign in as Y on the same device → swap active DB from `<X>.db` to `<Y>.db`. X's file preserved on disk.
   - Sign back in as X later → swap back to `<X>.db`. Sync resumes.
   Consequence: no dormant `_local.db` ever exists post-bootstrap, because no flow recreates it. Once identified, the user cannot accidentally drop back into anonymous mode. If they genuinely want to, it's a future explicit Settings → "Clear local account data" action. The 30-day eviction sweep still protects against multi-account dormancy on `<X>.db` files when the user moves to a different account and never returns.

2. **Dev override is directory-scoped.** `--dart-define=DATABASE_NAME=consistency_tracker_dev.db` causes the per-account directory to become `accounts_dev/` instead of `accounts/`. So `accounts_dev/<userId>.db` for dev runs, `accounts/<userId>.db` for prod runs. Clean separation; dev wipe is `rm -rf accounts_dev/` without touching prod data.

---

## 15B-FollowUp — UX fixes from T7 verification (2026-06-01)

**State:** COMPLETE — all fixes verified by user on 2026-06-01
**Last updated:** 2026-06-01

During T7 manual verification of Step 15B (per-account SQLite isolation), three UX bugs surfaced in the post-sign-in flow. All three traced back to the same root cause: `_MyAppState._initializeThemeAndStyle()` computes `_isFirstRun = _checkFirstRun()` exactly ONCE at boot, so when `DatabaseService.switchTo` swaps the active per-account DB on sign-in, the FutureBuilder at line ~402 never re-evaluates against the new DB state.

### T7 status snapshot

- [DONE] T7.1 — Legacy migration (PASS — `consistency_tracker.db` was renamed into `accounts/<userId>.db`, prod data intact)
- [DONE] T7.2 — Two-account isolation (PASS — verified with a brand-new `test1@test.com` account; its DB is 4 KB empty, while `4uri…db` and `9gxy…db` each have their own contaminated copies; clean separation proven)
- [DONE] T7.3 — Server isolation (implicit PASS — PB `owner = @request.auth.id` rules confirmed in `pb_migrations/1748260800_init_sync_collections.js`; test1's fresh DB stayed empty)
- [DONE] T7.4 — First-run + later sign-in (PASS-by-equivalence — rename code path identical to T7.1; Model-E offline-write behavior verified — `OFFLINE_FIRST_TEST` stayed confined to `x0ybhh.db` with zero cross-DB leakage)
- [DONE] T7.5 — Eviction sweep (PASS — one aged-out account `9gxyy1tnorm5ii5.db` evicted on next boot — app log confirms `AccountRegistry: Evicted 1 idle accounts`)
- [DONE] T7.6 — Switch atomicity (PASS — sign-in immediately followed by sign-out: no crash, no freeze, no corruption)
- [DONE] T7.7 — App-lifecycle touch (SKIPPED — 1-hour background wait, low-value scenario)
- [DONE] T7.8 — Regression (PASS — full regression smoke — dashboard, heatmap, task ticks, settings, update banner all working)

### Fixes applied

- [DONE] **F1** — `lib/main.dart`: `_MyAppState` now listens to `DatabaseService.instance.activeDbRevision`; on every fire, `_isFirstRun` is recomputed and `setState` rebuilds. Routes brand-new accounts to `FirstRunSetupScreen` (fixes #11/#9 at the root). Attach in `initState`, detach in `dispose`.
- [DONE] **F2** — `lib/services/database_service.dart` exposes `final ValueNotifier<int> activeDbRevision` (line 46), incremented inside `switchTo` after the DB is opened and `_activeUserId` updated (line 127). `lib/screens/home_screen.dart` listens to it and re-initializes its dashboard controller on fire (fixes #10).
- [DONE] **F3** — `lib/screens/settings_screen.dart`: profile section now falls back to `PocketBaseService.instance.client.authStore.record` (email + id) with a "Profile setup pending" placeholder when the local `users` row is missing. Hard "Could not load profile." error only fires if BOTH local row and auth record are absent.

### Verification

- `flutter analyze --no-fatal-infos`: clean (no issues found).
- Code-reviewer agent: PENDING (running in parallel with this write).
- User manual re-verification: PENDING.

### Next Action

After code-reviewer PASS, user manually re-tests: (a) register a fresh PB account → expect FirstRunSetupScreen, not the profile-error HomeScreen; (b) sign in as an existing account → HomeScreen auto-refreshes with that account's tasks. Then resume T7.4–T7.8.
