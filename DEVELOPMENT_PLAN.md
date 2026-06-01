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

### Step 15 — Sync Hardening: Apple-Level Seamless Sync — NEXT
**Goal:** the app talks to the network *only* when there is genuinely new work. No echo loops, no idle chatter, no surprises. Edits on device A appear on device B in ~1s; an idle app is silent.

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

---

*History note:* the original verbose Step 13 appendix (USN rejection, architecture rationale, hosting options, build-order phases) has been removed now that sync is built and shipped. The decisions it documented are preserved in `Prj_Progress.md`. The current sync code is the source of truth for "how it works"; this plan tracks "what's next."
