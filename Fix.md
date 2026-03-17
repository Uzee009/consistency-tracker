# Consistency Tracker - Logic & Bug Fix Log

This file tracks potential logical errors, dead code, and architectural inconsistencies identified during the codebase audit.

## Initial Audit Findings

### 1. Inaccurate Consistency Rate for New Tasks (Fixed)
*   **Issue:** The `consistencyRate` was calculated against the global start date, regardless of task creation.
*   **Fix:** Updated `calculateAnalytics` to accept `taskCreatedAt`. The denominator now correctly clamps to the task's lifetime and ignores "neutral" days (skips/cheats).
*   **Location:** `ScoringService.calculateAnalytics`.
*   **Status:** Fixed

### 2. Global Streak Fragility (Fixed)
*   **Issue:** Individual task streaks supported skips, but global ones did not.
*   **Fix:** Updated global analytics logic to treat any day with a "skipped" task as neutrally skipped, preserving the global streak.
*   **Location:** `ScoringService.calculateAnalytics`.
*   **Status:** Fixed

### 3. Misaligned Heatmap "Jump" Logic (Fixed)
*   **Issue:** `_jumpToDateMultiMonth` used a hardcoded offset of `120.0` pixels per month.
*   **Fix:** Updated to use a dynamic week-based calculation for scroll offsets, ensuring accurate jumps for months of varying lengths.
*   **Location:** `ConsistencyHeatmap._jumpToDateMultiMonth`.
*   **Status:** Fixed

### 4. Zero-Benchmark Error on All-Skip Days (Fixed)
*   **Issue:** If all daily tasks were skipped, the benchmark clamped to 1, causing a 0% "failure" state.
*   **Fix:** Added logic to return `VisualState.empty` (or `cheat` if applied) when all tasks are skipped and none were completed. This correctly visualizes "Excused" days.
*   **Location:** `ScoringService.calculateDayScore`.
*   **Status:** Fixed

### 5. Heatmap "Normal Mode" vs. User Intent (Fixed)
*   **Issue:** Default multi-month views focused on the future.
*   **Fix:** Defaulted `_isReportMode` to `true`, focusing multi-month views on history (recent progress).
*   **Location:** `ConsistencyHeatmap._ConsistencyHeatmapState`.
*   **Status:** Fixed

### 6. Dead & Flawed Code: `getTaskHistory` (Fixed)
*   **Issue:** `DatabaseService.getTaskHistory` filtered out everything except completions in Dart.
*   **Fix:** Updated to return all relevant records (completions, skips, cheats) via SQL filtering, making it useful for streak calculations.
*   **Location:** `DatabaseService.getTaskHistory`.
*   **Status:** Fixed

### 7. Redundant Data Fetching (Fixed)
*   **Issue:** `AnalyticsExplorerScreen` called `getDayRecords` twice during initialization.
*   **Fix:** Updated `_refreshAnalytics` to use the primary `_allRecordsForCache`, reducing disk I/O.
*   **Location:** `AnalyticsExplorerScreen._refreshAnalytics`.
*   **Status:** Fixed

## Second Audit Findings (Deeper Scan)

### 8. Pomodoro Timer State Loss (Fixed)
*   **Issue:** `DashboardLayoutController` returned new widget instances on every call, resetting state.
*   **Fix:** Implemented a `_widgetCache` in `DashboardLayoutController` and wrapped content in `ValueListenableBuilder<BoxConstraints>`. Widgets are now persisted across dashboard rebuilds.
*   **Location:** `DashboardLayoutController.getWidgetForId`.
*   **Status:** Fixed

### 9. Lack of Pomodoro Session Persistence (Fixed)
*   **Issue:** Completed Pomodoro sessions were not saved to the database.
*   **Fix:** Updated `DayRecord` model and database schema to include `pomodoro_sessions` and `pomodoro_goal`. `PomodoroTimer` now persists data via `DashboardController` on session completion or goal changes.
*   **Location:** `PomodoroTimer`, `DayRecord`, `DatabaseService`.
*   **Status:** Fixed

### 10. Unnecessary `UniqueKey()` causing Heatmap Resets (Fixed)
*   **Issue:** `CalendarPanel` used `UniqueKey()` for its `ConsistencyHeatmap` child, causing scroll/view resets on every update.
*   **Fix:** Replaced `UniqueKey()` with a stable `ValueKey('calendar_heatmap_stable')`.
*   **Location:** `CalendarPanel._CalendarPanelState.build`.
*   **Status:** Fixed

### 11. `DashboardController` Initialization Race Condition (Fixed)
*   **Issue:** `initialize` was `async` without protection, causing potential data mismatches if multiple calls occurred rapidly.
*   **Fix:** Added `_lastRequestId` to ensure only the result of the most recent `initialize` call is applied to the state.
*   **Location:** `DashboardController.initialize`.
*   **Status:** Fixed

### 12. Inefficient `getTaskHistory` Query (Fixed)
*   **Issue:** `DatabaseService.getTaskHistory` fetched all records from the database and filtered them in Dart.
*   **Fix:** Implemented SQL `LIKE` filtering for more efficient data retrieval.
*   **Location:** `DatabaseService.getTaskHistory`.
*   **Status:** Fixed

## Third Audit Findings (UI & Redundancy)

### 13. Redundant Mockup: `HomePremiumMockup` (Fixed)
*   **Issue:** A legacy/mockup file that is not part of the active application flow.
*   **Fix:** Deleted the file `lib/screens/home_premium_mockup.dart`.
*   **Status:** Fixed

### 14. Redundant Logic: `TaskFormScreen` vs. `AddTaskBottomSheet` (Fixed)
*   **Issue:** Two separate implementations for adding/editing tasks.
*   **Fix:** Deleted `TaskFormScreen` and `TasksListScreen`. Consolidated all task management into `AddTaskBottomSheet` and the main dashboard.
*   **Status:** Fixed

### 15. Dead Widget: `StreakBoard` (Fixed)
*   **Issue:** The widget is no longer used, superseded by `AnalyticsKPIs`.
*   **Fix:** Deleted the file `lib/widgets/streak_board.dart`.
*   **Status:** Fixed

### 16. Inconsistent Text Formatting (Title Case) (Fixed)
*   **Issue:** Sidebar habits used Title Case, but dashboard tasks were inconsistent.
*   **Fix:** Verified that `TaskItem` and `AnalyticsExplorerScreen` consistently apply `_toTitleCase` to habit names.
*   **Location:** `lib/widgets/task_item.dart`, `lib/screens/analytics_explorer_screen.dart`.
*   **Status:** Fixed
