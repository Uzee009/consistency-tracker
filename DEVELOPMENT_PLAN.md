# Consistency Tracker Development Plan

This document outlines the detailed development plan for the Consistency Tracker application, breaking down the project into manageable phases and steps.

## Phase 1: Setup and Flutter Fundamentals

This phase focuses on setting up the development environment and learning the foundational skills required to build the application.

*   **Step 1: Set up Your Development Environment.**
    *   **Goal:** Have a working local setup where you can create and run a new Flutter project.
    *   **Tasks:**
        *   Install the Flutter SDK.
        *   Install Visual Studio Code (VS Code) as the primary code editor.
        *   Install the Flutter extension for VS Code.
        *   Verify the installation using `flutter doctor`.

*   **Step 2: Learn Dart Language Fundamentals.**
    *   **Goal:** Understand the syntax and core concepts of the Dart programming language.
    *   **Tasks:**
        *   Familiarize yourself with Dart variables, data types, operators.
        *   Learn about control flow (if/else, loops, switch).
        *   Understand functions and object-oriented programming (classes, objects, inheritance, polymorphism).
        *   Explore asynchronous programming with `async`/`await`.

*   **Step 3: Learn Flutter Framework Fundamentals.**
    *   **Goal:** Understand the key concepts of Flutter, like Widgets, layouts, and state management.
    *   **Tasks:**
        *   Understand what a Widget is and the difference between `StatelessWidget` and `StatefulWidget`.
        *   Learn basic layout Widgets (`Column`, `Row`, `Container`, `Padding`, `Center`).
        *   Understand how to manage and update UI state using `setState()`.
        *   Build a simple "Hello World" or counter application to practice.

## Phase 2: Building the Core Logic (The "Engine")

This phase focuses on implementing the application's core business logic and data management. This will primarily involve writing Dart code, independent of the user interface.

*   **Step 4: Model Your Data Structures**
    *   **Goal:** Define the Dart classes that represent the key entities in your application.
    *   **Tasks:**
        *   **4a. `user_model.dart`:** Create a Dart class for `User` with properties like `id` (unique, generated), `name`.
        *   **4b. `task_model.dart`:** Create a Dart class for `Task` with properties like `id`, `name`, `type` (an enum: `daily` or `temporary`), `duration_days`, and `is_active`.
        *   **4c. `day_record_model.dart`:** Create a Dart class for `DayRecord` with properties like `date`, a list of `completedTaskIds`, `cheatUsed` (boolean), `completionScore` (double), and `visualState` (an enum: `empty`, `light_green`, `dark_green`, `star`, `orange`). This will also include methods to convert to/from map for database storage.

*   **Step 5: Implement the Scoring Engine**
    *   **Goal:** Create the logic that calculates a day's performance score and maps it to a visual state.
    *   **Tasks:**
        *   **5a. `scoring_service.dart`:** Create a dedicated Dart file for all scoring-related functions.
        *   **5b. Implement Core Score Calculation:** Write a function, `calculateDailyScore(completedTasksCount, totalExpectedTasksCount)`, that returns a score (0.0-1.0).
        *   **5c. Implement Temporary Task Compensation:** Write a function, `calculateTempTaskCredit(tempTasksCompleted, missingDailyTasksCount)`, that applies the compensation logic (up to 50% of missing daily work).
        *   **5d. Implement Overachievement Logic:** Add logic to determine if a day qualifies for a "star" visual state (all daily tasks + bonus temporary tasks).
        *   **5e. Map Score to Visuals:** Write a function, `mapScoreToVisualState(finalScore, cheatUsed, hasStar)`, that returns the appropriate `visualState` enum based on the calculated score, cheat day status, and star status.

*   **Step 6: Build the Database Service**
    *   **Goal:** Set up and manage the local SQLite database for persistent storage of all application data.
    *   **Tasks:**
        *   **6a. `database_service.dart`:** Create a Dart file for all database interaction logic.
        *   **6b. Initialize Database:** Implement database initialization, including creating tables for `Users`, `Tasks`, and `DayRecords`. Use the `sqflite` package.
        *   **6c. User Management Functions:** Implement `createUser(name)` to create a new user and `getUser(id)` to retrieve user data.
        *   **6d. Task Management Functions:** Implement `addTask(task)`, `updateTask(task)`, `deleteTask(taskId)`, and `getActiveTasksForDate(date)`.
        *   **6e. Day Record Management Functions:** Implement `getOrCreateDayRecord(date)` to retrieve a `DayRecord` or create a default one if none exists for that date. Implement `updateDayRecord(dayRecord)` to save changes.

## Phase 3: Building the User Interface (The "Skin")

This phase involves creating the visual components of the application and connecting them to the backend logic developed in Phase 2.

*   **Step 7: First-Run User Setup UI**
    *   **Goal:** Guide the user through the initial setup process.
    *   **Tasks:**
        *   Create a simple UI screen that displays only on the first launch.
        *   Prompt the user to enter their name.
        *   On submission, call the `database_service.createUser()` function and navigate to the main application dashboard.

*   **Step 8: Task Management UI**
    *   **Goal:** Provide interfaces for users to define and manage their tasks.
    *   **Tasks:**
        *   **8a. Add/Edit Task Screen:** Design a form to create new tasks, specifying name, type (daily/temporary), and duration.
        *   **8b. Cheat Day Allocation:** Implement a UI element (e.g., a simple input field or dropdown) to allow users to specify their maximum cheat days.
        *   **8c. All Tasks View:** Create a screen to list all defined tasks, with options to edit or delete them.

*   **Step 9: The Main Dashboard UI**
    *   **Goal:** Display today's tasks and allow for interaction.
    *   **Tasks:**
        *   **9a. Daily Task Display:** Build the main application screen to show the current date and a list of active tasks for that day.
        *   **9b. Interactive Task Elements:** For each displayed task, add interactive elements (e.g., checkboxes, swipe gestures) to mark tasks as completed, partially completed, or skipped.
        *   **9c. UI Update Logic:** When a task is interacted with, trigger the `database_service.updateDayRecord()` which will internally re-run the scoring logic, and then update the UI instantly to reflect the changes (e.g., changing the appearance of the task).

*   **Step 10: The Consistency Grid (Visual Tracker) UI**
    *   **Goal:** Visualize the user's consistency in a GitHub-style grid format.
    *   **Tasks:**
        *   **10a. Data Fetching:** Retrieve `DayRecord`s for the past year from the `database_service`.
        *   **10b. Grid Widget:** Create a custom Flutter widget (`ConsistencyGrid`) that can display a grid of cells representing days.
        *   **10c. Dynamic Cell Coloring:** For each day, use its `visualState` (from the `DayRecord`) to determine the background color of the corresponding cell in the grid (e.g., `light_green`, `dark_green`, `orange` for cheat days, etc.).
        *   **10d. Star Indicator:** If a day's `visualState` is `star`, overlay a small star icon on its grid cell.
        *   **10e. Placeholder Integration:** Integrate this grid widget into the main dashboard, possibly in a dedicated section or tab.

## Phase 4: Advanced Features and Sync

This phase will focus on implementing the more advanced features and the optional synchronization capabilities.

*   **Step 11: Implement the Wallpaper Feature.**
    *   **Goal:** Allow users to optionally display their consistency grid as a desktop wallpaper.
    *   **Tasks:**
        *   **11a. Render Grid to Image:** Develop functionality to render the `ConsistencyGrid` widget into an image file (e.g., PNG).
        *   **11b. OS-Specific Wallpaper Setter:** Implement platform-specific code (using Flutter's platform channels or existing packages) to set the generated image as the desktop wallpaper on Windows, macOS, and Linux.
        *   **11c. UI Toggle:** Add a toggle in the app's settings to enable/disable this feature and control its refresh rate.

*   **Step 12: Desktop Integration.**
    *   **Goal:** Enhance the desktop user experience.
    *   **Tasks:**
        *   **12a. Auto-Start on Login:** Implement functionality for the app to launch automatically when the user logs into their operating system.
        *   **12b. System Tray/Menubar Icon:** Add an optional system tray or menubar icon for quick access or status display.

*   **Step 13: Implement Cross-Device Sync (PocketBase, Local-First).**
    *   **Goal:** Tick a task on one device, see it on the others in ~1–2s while online; work fully offline and reconcile automatically on reconnect; never lose data.
    *   **Architecture:** Local-first SQLite (full mirror) + a dumb central server (PocketBase) + a small hand-rolled push/pull sync loop. The client is pure Dart (HTTP + SSE), so the exact same code runs on Linux, Windows, macOS, and Android. Conflict resolution is Last-Write-Wins on a **client-set `updated_at`**. This supersedes the earlier USN-based proposal, which was dropped as over-engineered and error-prone.
    *   **Build Order (each phase shippable):**
        *   **Phase 0 — Local refactor (no network).** Switch task identity to a client-generated UUID (`sid`); split `day_records.completed_task_ids` into a `task_status` table (one row per completion/skip) + a `day_meta` table (per-day single-value state); derive `completion_score`/`visual_state` locally (never synced); add sync columns (`updated_at`, `deleted`, `dirty`) to `tasks`, `task_status`, `day_meta`. No user-visible change.
        *   **Phase 1 — PocketBase up + auth.** Run the binary locally, create collections mirroring the local tables, add a login screen + connectivity service.
        *   **Phase 2 — Manual sync.** A "Sync now" button running push/pull; prove correctness across two devices.
        *   **Phase 3 — Automatic + realtime.** dirty-on-write (debounced ~500ms) + SSE subscribe + focus/resume + 60s safety poll.
        *   **Phase 4 — Deploy + harden.** Deploy to a free VM (Oracle Cloud Always Free preferred), point the app at it, add retry/backoff, tombstone cleanup, and a multi-device soak test. Optional: E2E encryption (deferred from v1).
    *   **Validation:** A throwaway PocketBase spike (`sync_spike/`, git-ignored) confirmed the approach — **73 ms** realtime propagation, correct LWW (newer write wins, older rejected), and correct offline reconcile (stale offline edits rejected).
    *   **Detailed specification:** See "Appendix: Cross-Device Sync — Implementation Plan" at the end of this document.

---

# Appendix: Cross-Device Sync — Implementation Plan

**Status:** Experimental / proposed
**Date:** 2026-05-25
**Supersedes:** The original Step 13 ("Shielded-USN Synchronization System").

This is the agreed plan for making the Consistency Tracker sync across devices. It
replaces the earlier USN-based proposal, which was dropped for being too complex
and error-prone.

## A.1 Goal & Constraints

**Goal:** Tick a task on one device, see it on the others in ~1–2s while online.
Work fully offline; reconcile automatically on reconnect. Never lose data.

**Hard constraints:**
- Free — no hosting budget.
- Cross-platform: Linux, Windows, macOS, Android (Linux is "always online").
- Offline writes must be preserved and synced later.
- Open source friendly (optional self-host later, not a v1 feature).
- Solo developer — minimise complexity and moving parts.

**Honest definition of "realtime":** 1–2s propagation when both devices are
online. Not sub-100ms collaborative editing — that is unnecessary here.

## A.2 Architecture Decision

**Chosen:** Local-first SQLite (full mirror) + a dumb central server (PocketBase)
+ a small hand-rolled sync loop. The client is **pure Dart (HTTP + SSE)** so the
exact same code runs on all four platforms.

**Rejected and why:**
- **Firebase Firestore** — its SDK would handle sync for us, but it has **no Linux
  support** and weak desktop offline support. Linux is a first-class device, so
  this is out.
- **Self-hosting as a v1 feature** — dropped to reduce scope. The server is still
  self-hostable later (PocketBase is a single binary), just not a shipped feature now.
- **Anki-style USN protocol** (Gemini's Step 13) — over-engineered. We keep only
  its unavoidable skeleton (UUIDs, tombstones, timestamps, LWW, push/pull) and
  delete the parts that caused the pain:
  - ❌ `usn` Update Sequence Numbers + "Finalize" handshake → replaced by a plain
    `updated_at` timestamp cursor.
  - ❌ `session_id` idempotency tokens → upsert-by-`sid` + LWW is naturally idempotent.
  - ❌ `sync_meta` global state table + Dart "state machine" → it's just one function.
  - ❌ Zero-knowledge crypto (Argon2id / AES-GCM / 24-word mnemonic) → deferred to
    optional v2; HTTPS + auth is enough for v1.
  - ❌ ">90-day zombie reconciliation" + WAL-for-sync → non-problems with
    tombstones + a timestamp cursor.

**Why it works on every OS:** no native platform SDK. It's `package:http` + SSE,
identical on Linux/Windows/macOS/Android.

## A.3 Data Model Changes (Phase 0 — local only, no network)

These fix two latent bugs that would break *any* sync design, and are testable
entirely offline with zero user-visible change.

### A.3.1 Task identity → UUID/ULID strings
Auto-increment `INTEGER PRIMARY KEY` collides across devices (two devices both
create `id=6`). Switch the sync identity to a client-generated `sid TEXT` (UUID).

### A.3.2 Normalise day completions
Today `day_records.completed_task_ids` is a comma-joined string (`"3,5,7"`). Row-level
LWW on this loses concurrent ticks. Split into:

- **`task_status`** — one row per completion/skip:
  `(date TEXT, task_sid TEXT, status TEXT,  -- 'completed' | 'skipped'
    updated_at INTEGER, deleted INTEGER, dirty INTEGER, PRIMARY KEY(date, task_sid))`
  → ticking *different* tasks on two devices = different rows = **no conflict**.
  → ticking the *same* (date, task) = LWW by `updated_at` = correct answer.

- **`day_meta`** — single-value per-day state:
  `(date TEXT PRIMARY KEY, cheat_used INTEGER, pomodoro_sessions INTEGER,
    pomodoro_goal INTEGER, updated_at INTEGER, deleted INTEGER, dirty INTEGER)`

### A.3.3 Derived, not synced
`completion_score` and `visual_state` are recomputed locally from `task_status`
via `ScoringService`. `monthly_usage` is derived by counting `cheat_used` per
month. None of these sync — they can't conflict.

### A.3.4 Sync columns on every synced table
`updated_at` (epoch ms, **client-set**), `deleted` (tombstone — never hard-delete),
`dirty` (locally changed, needs push). Applies to `tasks`, `task_status`, `day_meta`.

## A.4 Backend — PocketBase

- Single Go binary, SQLite backend, built-in auth + realtime (SSE), admin UI.
- Collections mirror the local tables: `tasks`, `task_status`, `day_meta`.
- **Auth:** one PocketBase account; all your devices log in with it. Every synced
  row belongs to that user (add an `owner` field for multi-user later).
- Run the binary locally during development before deploying anywhere.

## A.5 Sync Engine (~300 lines, one file)

```
sync():
  if offline: return
  for each collection in [tasks, task_status, day_meta]:
    # PUSH
    for row in localRows(where dirty = 1):
        server.upsert(collection, row keyed by sid)
        row.dirty = 0
    # PULL
    cursor = prefs.lastCursor[collection]
    for r in server.list(collection, filter "updated > cursor", sort "updated"):
        local = localGet(r.sid)
        if local == null or r.updated_at > local.updated_at:   # LWW
            localUpsert(r)        # deleted = 1 → hide row
        cursor = max(cursor, r.updated)
    prefs.lastCursor[collection] = cursor
  recomputeDerived()   # score + visual_state from task_status
```

- **LWW** resolves on the **client-set `updated_at`** (so a stale offline edit can't
  clobber a newer online one). PocketBase's server `updated` is used only as the
  pull cursor.
- Retries are naturally idempotent (re-pushing the same row is a no-op).

## A.6 Realtime + Offline Behaviour

**Triggers for sync:**
- On any local write → set `dirty`, debounce ~500ms, run `sync()`.
- Subscribe to PocketBase realtime (SSE) → on a remote event, run a pull.
- On app focus/resume and a 60s safety poll → pull.
- Connectivity listener → on reconnect, flush queued `dirty` rows.

**Offline:** writes just set `dirty`; `sync()` early-returns. App stays fully
usable (reads are always local). Flushes on reconnect.

## A.7 Hosting (free)

- **Oracle Cloud Always Free** ARM VM (free forever, never pauses) — preferred.
- Or **PocketHost** (managed free PocketBase).
- TLS via PocketBase built-in / Caddy. App stores the server URL in settings.

## A.8 Build Order (each phase shippable)

- **Phase 0 — Local refactor (no network).** UUID `sid`, `task_status` + `day_meta`
  split, derive score/visual_state, add sync columns. No user-visible change.
- **Phase 1 — PocketBase up + auth.** Run binary locally, create collections, add
  login screen + connectivity service.
- **Phase 2 — Manual sync.** "Sync now" button running push/pull. Prove correctness
  on two devices.
- **Phase 3 — Automatic + realtime.** dirty-on-write + SSE subscribe + focus/poll.
- **Phase 4 — Deploy + harden.** Deploy to free VM, point app at it, retry/backoff,
  tombstone cleanup, multi-device soak test. Optional: E2E encryption.

## A.9 Known Caveats (being honest)

- **Clock skew** between devices can mis-order LWW for genuinely concurrent edits
  to the *same* field. Rare for a single user; acceptable for v1. Upgrade to a
  hybrid logical clock only if it ever bites.
- **First-write conflict** on the very first sync of two pre-existing local DBs
  needs a one-time reconciliation pass (match by `sid`; for legacy int-id data,
  match `tasks` by name).
- **Heatmap needs all data local** — confirms full local mirror over partial caching.

## A.10 Experiment Test Plan

1. Phase 0 refactor; verify the app runs identically offline (existing data intact).
2. Run PocketBase locally; create collections; log in.
3. Manual "Sync now" between two local app instances (e.g. two dev DBs):
   - Tick different tasks on each → both appear on both. (no data loss)
   - Tick the same task on both → newer `updated_at` wins.
   - Delete a task on one → tombstone hides it on the other.
   - Edit offline on both, then reconnect → LWW resolves predictably.
4. Enable realtime; confirm ~1–2s propagation.