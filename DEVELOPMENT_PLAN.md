# Consistency Tracker — Development Plan

Living roadmap. Completed phases are kept as one-line pointers; full history lives in `Prj_Progress.md`. The active/next work is detailed at the bottom.

---

## Phase 1 — Flutter & Dart Fundamentals — DONE
Steps 1–3: dev environment, Dart language, Flutter widgets/state. (Setup phase, no app code shipped.)

## Phase 2 — Core Engine — DONE
Steps 4–6: data models (`User`, `Task`, `DayRecord`), scoring service (daily score, temp-task compensation, star/overachievement, score→visual mapping), and SQLite `database_service`.

## Phase 3 — User Interface — DONE
Steps 7–10: first-run setup, task management (add/edit/list, cheat-day allocation), main dashboard with interactive task elements, and the GitHub-style consistency grid (year view, dynamic cell coloring, star overlay).

## Phase 4 — Advanced Features, Sync, Distribution

### Step 11 — Wallpaper Feature — PENDING
Render the consistency grid to an image and set it as the desktop wallpaper on Windows / macOS / Linux. Settings toggle + refresh rate. Not started.

### Step 12 — Desktop Integration — PENDING
Auto-start on login + optional system-tray / menubar icon. Not started.

### Step 13 — Cross-Device Sync (PocketBase, Local-First) — DONE
Local-first SQLite mirror + PocketBase (single Go binary) + hand-rolled push/pull. Pure-Dart HTTP+SSE client (works on Linux/Windows/macOS/Android). Conflict resolution = Last-Write-Wins on a client-set `updated_at`. UUID `sid` task identity, `task_status` + `day_meta` normalised tables, tombstones (`deleted=1`), `dirty` flag, 60s safety poll + 500ms debounce + realtime SSE. Deployed to GCP VM at `consistancy.duckdns.org` (`/home/uzeeslive/pb/`, systemd). Friendly sync-error messages shipped 2026-05-29. Backups still NOT enabled — user to turn on in Admin UI.

### Step 14 — In-App Self-Update & Auto-Release — DONE
CI auto-bumps semver on every master push (`#minor` / `#major` / `[skip release]` tokens in the commit SUBJECT), bakes the version into the binary (`pubspec` rewrite, since `flutter build --build-name` is ignored on desktop), and publishes a real `vX.Y.Z` GitHub release with versioned artifact filenames. App checks GitHub `/releases/latest` on launch, shows a home banner + Settings → Updates section, and supports true one-click "Update & Restart": download → SHA-256 verify → extract → atomic in-place swap → relaunch. Per-OS apply (Linux dir-rename, macOS dmg+quarantine-strip, Windows helper `.cmd`). Shipped v1.3.0.

### Step 15 — Sync Hardening: Apple-Level Seamless Sync — DONE (2026-06-01)
**Outcome:** Comprised of Step 15B (per-account SQLite isolation, landed first because data corruption > bandwidth waste) and Step 15A (the six echo-loop fixes below). All six fixes shipped; PB migration `1780300000_add_device_id.js` deployed live on GCP. Merged to master as `c44d8d9` with `#minor`; CI cut **v1.4.0**. Full narrative in `Prj_Progress.md` (entries dated 2026-06-01). Idle log is quiet, user edits push exactly once, realtime self-echoes are suppressed.

**Goal (original):** the app talks to the network *only* when there is genuinely new work. No echo loops, no idle chatter, no surprises. Edits on device A appear on device B in ~1s; an idle app is silent.

**Symptom motivating this step:** the app currently re-syncs every few seconds even when nothing has changed.

**Root causes diagnosed in `lib/services/sync_service.dart`:**
- **Loop A — realtime self-echo.** `_setupRealtime` subscribes `*` on every collection. After `_push` writes to the server, PocketBase fans the event back to the same client, which calls `requestSync()` → another sync → another push → another echo.
- **Loop B — pull writes re-trigger local-change.** `_pull` → `_applyRemote` → `db.insert/update` bumps `DatabaseService.localChanges`, the same notifier user edits use, so `_onLocalChange` re-fires `requestSync()`.
- **Loop C — wasteful cursor.** `_pull` uses `updated >= cursor`, so every sync re-fetches the most-recent record(s) it already has. `_applyRemote` no-ops them, but it still costs round-trips.
- **Loop D — unconditional 60s poll** on top of everything.

A + B compound: one user edit → push → echo → sync → boundary re-pull → local notifier → sync, capped at one per ~500ms by the debounce. That matches "every few seconds" exactly.

**Fix plan (rollout order = smallest blast radius first):**
1. **Tighten cursor (Loop C).** Change `updated >= cursor` → `updated > cursor` in `_pull`. One-line, zero risk, ~30% drop in noise. Client-only.
2. **Split the local-change notifier (Loop B).** `DatabaseService` exposes `userLocalChanges` (fires only when `dirty=1` is being set by a user-originated write) and a separate internal channel for remote applies. `_onLocalChange` listens to `userLocalChanges` only. Cleaner than a `_isApplyingRemote` flag (no async race).
3. **Trigger-reason instrumentation.** `requestSync({String reason})` with values `'user-edit' | 'realtime' | 'poll' | 'connectivity' | 'auth' | 'manual' | 'pending-flush'`. Plumb through to `_runScheduled` → `sync()`. Keep a 50-entry in-memory ring buffer of `(reason, ts)` exposed on a debug screen — this is what proves the fix held in the wild.
4. **No-op early-exit in `sync()`.** If `dirtyCount == 0` AND realtime is healthy AND `reason == 'user-edit'`, skip entirely (realtime will tell us about peer changes; nothing to push). Pull paths (`'poll' | 'connectivity' | 'manual'`) still run.
5. **Device-id echo suppression (Loop A).** Generate a stable `deviceId` (UUID, stored in SharedPreferences) once per install. Add a `device_id` text field to the three PocketBase collections (`tasks`, `task_status`, `day_meta`) via a new server migration. `_push` writes `body['device_id'] = deviceId`. Realtime callback compares `e.record?.data['device_id']` to our own and returns early if it matches. Loop A dies.
6. **Adaptive poll cadence.** Default 60s; after 3 consecutive empty syncs with realtime healthy, stretch to 5 min then 15 min; snap back to 60s on any non-empty sync or realtime event. Idle app barely talks to the network.

**Schema change (server-side):** step 5 needs a new PocketBase migration adding `device_id` (text, optional) to `tasks`, `task_status`, `day_meta`. Deployed via the same `pb_migrations/` mechanism used in Step 13. Coordinate with any other schema changes the user wants to batch in.

**Definition of done:**
- Idle for 10 min → 0 syncs beyond the initial one + the (stretched) poll.
- Edit one task → exactly 1 push, 0 echoes, 0 follow-up pulls on the originating device.
- Edit on device A → device B sees it in ~1s via realtime; device B runs exactly 1 pull; no echo back to A.
- Debug screen ring buffer shows clean per-trigger attribution.

**Keep as-is:** retry/backoff ladder, 500ms debounce, tombstone prune.

### Step 16 — UI/UX Overhaul: Apple-Level Polish — IN PROGRESS

**Goal:** Smooth, simple, thoughtful UI/UX matching Apple-level standards. Eliminate visual fragmentation (14+ ad-hoc spacing values, 7+ border-radius values, 13 icon sizes, ~91 hard-coded color instances across screens/widgets) and UX inconsistencies (error states, empty states, loading states, redundant navigation, weak desktop keyboard support).

**North-star principles:**
1. **One scale, everywhere.** Spacing on a 4/8/12/16/24/32 ladder. Border radius drawn from {8, 12, 16}. Icons from {12, 16, 24}. Anything off-scale must be justified or removed.
2. **Theme is law.** All colors via `Theme.of(context).colorScheme`. No raw `Colors.orange`, `Colors.grey[N]`, hex literals in widget code — semantic roles only (primary, tertiary, error, outline, onSurface, surface, …).
3. **Typography ladder.** ~5 type roles max, all routed through `Theme.of(context).textTheme`. No raw `TextStyle(fontSize: …)` in widgets.
4. **Predictable feedback.** Every async action either shows a spinner or disables — never freezes. Every error renders human copy, never `e.toString()`.
5. **One way to reach each thing.** No duplicate navigation entry points.

**Design decisions baked in (override at exec time only if user disagrees):**
- Brand orange stays as the accent color, mapped to `colorScheme.tertiary` so it is themed (not raw `Colors.orange`).
- Settings reached only via the PROFILE bottom-nav tab; the standalone push route is removed.

**Phase breakdown (each = separate commit on `feature/ux-fixes`):**

- **Phase 1 — Quick Wins** (7 sub-tasks, ~30 min). User-flagged issues + audit highlights. Sync-log deletion, refresh icon-only, top-right user menu removal, Updates card fix, Create Account button de-pill, auth autofocus/Enter-to-submit, tap-target bumps.
- **Phase 2 — Design System Foundation** (~2 hrs). New `lib/theme/app_spacing.dart`, `app_radius.dart`, `app_icon_size.dart`. New reusable `lib/widgets/app_card.dart` extracted from duplicated `_buildCard` helpers. Sweep all screens/widgets to use design-system constants. Replace ~91 hard-coded color instances with `colorScheme.*`. Replace raw `TextStyle(fontSize:…)` with `textTheme.*`. Strengthen `textTheme` definition in `main.dart` if currently thin.
- **Phase 3 — UX Polish** (~3 hrs). Unify form validation on inline `errorText` in `InputDecoration`; stop leaking `e.toString()` (`signup_screen.dart:78`, `login_screen.dart:65`) — map to friendly copy. New `lib/widgets/empty_state.dart` and apply to task list, analytics explorer, filter results. Audit every async action for spinner/disable feedback. First-run setup: live style preview on toggle. Settings nav: remove standalone push (`settings_screen.dart:721-732`), keep PROFILE tab only. Adopt `CupertinoPageRoute` (or themed Material equivalent) for transitions.
- **Phase 4 — Motion & Micro-interactions** (~1-2 hrs). Wrap state-changing widgets in `AnimatedSwitcher` / `AnimatedContainer` / `TweenAnimationBuilder`: heatmap cell color, task tick, sync status dot, update banner. Desktop hover states via `MouseRegion` + cursor change + subtle background shift on tasks, panels, nav tabs. Heatmap cell tap: subtle scale-down feedback + tooltip with date + score.

**Branch:** `feature/ux-fixes`. Merge to master with `#minor` token → CI cuts v1.5.0.

**Definition of done:**
- `flutter analyze` clean after each phase.
- code-reviewer PASS on each phase.
- Manual visual verification on Linux Mint of: home, settings, login, signup, first-run setup, analytics explorer.
- Audit metrics post-Phase-2: zero hard-coded `Colors.*[N]` outside theme files; zero raw `TextStyle(fontSize:…)` in `lib/screens/` and `lib/widgets/`; spacing/radius/icon values all sourced from the design-system constant classes.

Full per-phase task list, sub-task statuses, and review history live in `CURRENT_MODULE.md` while this module is active.

*History note:* the original verbose Step 13 appendix (USN rejection, architecture rationale, hosting options, build-order phases) has been removed now that sync is built and shipped. The decisions it documented are preserved in `Prj_Progress.md`. The current sync code is the source of truth for "how it works"; this plan tracks "what's next."
