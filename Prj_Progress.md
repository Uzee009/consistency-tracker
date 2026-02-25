# Project Progress Log

## Thursday, 19 February 2026 - 10:00 AM

**Summary:**
*   Successfully set up the Flutter development environment on Linux.
*   Flutter SDK installed and configured.
*   Android toolchain validated (Android Studio installed, command-line tools installed, all licenses accepted).
*   Linux desktop development toolchain validated (clang, ninja-build, libgtk-3-dev installed).
*   Confirmed that Android emulators will be skipped due to system limitations, focusing on physical Android devices for testing.
*   The Flutter SDK path has been permanently added to the user's `~/.bashrc` file.

## Thursday, 19 February 2026 - 10:30 AM

**Summary:**
*   Created a new Flutter project named `consistency_tracker_v1` inside the `Tracker App` directory.
*   Successfully ran the Flutter project on the Linux desktop, verifying the development environment.
*   Confirmed that all platforms (Android, iOS, Web, Windows, macOS, Linux) are enabled in the project, respecting future expansion plans.

## Thursday, 19 February 2026 - 11:00 AM

**Summary:**
*   Completed data modeling for the core entities of the application.
*   Defined `user_model.dart` with `User` class (id, name, createdAt).
*   Defined `task_model.dart` with `Task` class (id, name, type, durationDays, createdAt, isActive) and `TaskType` enum.
*   Defined `day_record_model.dart` with `DayRecord` class (date, completedTaskIds, cheatUsed, completionScore, visualState) and `VisualState` enum.
*   Implemented `toMap()` and `fromMap()` methods for easy conversion to/from database-friendly formats for all models.

## Thursday, 19 February 2026 - 11:30 AM

**Summary:**
*   Completed the initial implementation of the Scoring Engine (`scoring_service.dart`).
*   Implemented `calculateCoreDailyScore`, `calculateTempTaskCredit`, `calculateOverallCompletionScore`, `checkForStarStatus`, and `mapScoreToVisualState` methods.
*   Added `sqflite` and `path_provider` dependencies to `pubspec.yaml` and ran `flutter pub get`.

## Thursday, 19 February 2026 - 12:00 PM

**Summary:**
*   Completed the initial implementation of the Database Service (`database_service.dart`).
*   Configured database initialization with `sqflite` and `path_provider`.
*   Implemented table creation for `Users`, `Tasks`, and `DayRecords`.
*   Added basic CRUD operations for `User` (create, get), `Task` (add, update, delete, get active for date), and `DayRecord` (create/update, get, get multiple).
*   Successfully completed Phase 2: Building the Core Logic (The "Engine").

## Thursday, 19 February 2026 - 12:30 PM

**Summary:**
*   Completed the First-Run User Setup UI (`first_run_setup_screen.dart`).
*   Implemented a UI to prompt the user for their name on the first launch.
*   Integrated with `DatabaseService` to create a new `User` entry.
*   Modified `main.dart` to check for existing users and display either `FirstRunSetupScreen` or a placeholder `HomeScreen`.
*   Successfully completed Phase 3, Step 7: First-Run User Setup UI.

## Thursday, 19 February 2026 - 1:00 PM

**Summary:**
*   Successfully ran the application and verified the First-Run User Setup UI.
*   Confirmed that after entering a name, the app navigates to the placeholder `HomeScreen`.
*   Verified that on subsequent runs, the app directly opens to the `HomeScreen`.

## Thursday, 19 February 2026 - 1:30 PM

**Summary:**
*   Implemented the "Add New Task" UI (`task_form_screen.dart`).
*   Enabled navigation to the `TaskFormScreen` via a `FloatingActionButton` on the `HomeScreen`.
*   Verified that clicking the button opens the form, allows task creation (daily/temporary), and shows a confirmation SnackBar.
*   Successfully completed Phase 3, Step 8a (Add functionality).

## Thursday, 19 February 2026 - 2:00 PM

**Summary:**
*   Fixed the "every run is a first run" bug by implementing `hasUser()` in `DatabaseService` and using it in `main.dart` for first-run detection.
*   Removed the debug banner from `MaterialApp` in `main.dart`.

## Thursday, 19 February 2026 - 2:30 PM

**Summary:**
*   Successfully fixed the UI refresh issue on the dashboard. Adding a new task now immediately updates the dashboard list.
*   Corrected the checkbox position to be leading in `CheckboxListTile` on the dashboard.
*   The application is now correctly persisting user data and managing task display on the `HomeScreen`.

## Thursday, 19 February 2026 - 3:00 PM

**Summary:**
*   Implemented the new dashboard layout:
    *   Daily and Temporary task lists now take approximately 30% of screen height.
    *   Individual task items are more compact.
    *   GitHub-style chart placeholder now takes 30% of screen height.
    *   Added a placeholder for Task Streaks at the bottom right.
    *   Temporary tasks now also have checkboxes and mustard yellow text color.
    *   The overall layout is scrollable.

## Thursday, 19 February 2026 - 3:30 PM

**Summary:**
*   Applied final dashboard UI refinements:
    *   Removed AppBar title (`Consistency Tracker Dashboard`).
    *   Implemented background styling for Daily Tasks (sky-blueish) and Temporary Tasks (sticky-note yellow) with borders.
    *   Replaced the global FloatingActionButton with individual "Add" buttons (IconButton) in the headers of Daily and Temporary task sections.
    *   Refactored the bottom section to display the GitHub-style chart placeholder (75% width) and Task Streaks placeholder (25% width) side-by-side.
    *   Modified `task_form_screen.dart` to accept an `initialTaskType` for pre-selection when adding tasks from individual buttons.

## Saturday, 21 February 2026

**Summary:**
*   **Resolved Critical UI Errors:** Fixed a major malformed widget tree in `home_screen.dart` that was causing persistent compiler errors.
*   **Version Control Implementation:** Initialized a Git repository and made an initial commit to establish a baseline for safe development and easy rollbacks.
*   **UI Layout Refinements:**
    *   Removed the top `AppBar` to maximize screen space.
    *   Adjusted the height distribution to a 50/50 split between the task management section and the consistency chart/streaks area.
*   **Enhanced Task Management:**
    *   **Edit Task:** Added functionality to edit existing tasks directly from the home screen.
    *   **Remove Task:** Implemented a secure delete function with a confirmation dialog.
    *   **Skip Task:** Introduced a "Skip" feature allowing users to mark a task as intentionally skipped for the day.
*   **Database & Model Updates:**
    *   Updated `DayRecord` model to track skipped task IDs.
    *   Performed a database migration (Version 2) to add the `skipped_task_ids` column to the `day_records` table.
    *   Updated `DatabaseService` to handle the new schema and migration logic.
*   **Verified Build:** Confirmed that the application compiles and runs successfully on Linux with no critical errors.

## Monday, 23 February 2026

**Summary:**
*   **Feature: Personalized Cheat Day System:**
    *   Updated `User` model and performed database migrations (v4 & v5) to support user-defined monthly cheat day allowances.
    *   Implemented "Cheat Day Tokens" logic: users can declare a cheat day from the dashboard, which uses a token and prevents streak breaks.
    *   Added a `SettingsScreen` allowing users to update their name and cheat day allowance.
    *   Integrated remaining token display in the `HomeScreen` AppBar.
*   **Feature: Custom Git-like Heatmap Grid:**
    *   Implemented a fully custom, responsive heatmap grid from scratch using core Flutter widgets (replacing third-party packages for better control).
    *   The grid displays the full current calendar year (2026) with 7 rows (days) and variable columns (weeks).
    *   Added dynamic month labels (Jan, Feb, etc.) and full day labels (Sun, Mon, etc.) with custom `#2f0035` coloring.
    *   Implemented visual gaps between months to match the `uhabits`/GitHub aesthetic.
    *   Applied custom styling: Background `#f6b4ff`, Empty cells `#cb5dda`.
    *   Added day numbers inside every heatmap cell with auto-contrasting text color.
    *   Integrated `ScoringService` to drive cell colors based on task performance (Greens), Cheat Days (Orange), and Star Days (Amber).
*   **UI/UX Refinements:**
    *   Standardized the task addition flow using a modal bottom sheet for both Daily and Temporary tasks.
    *   Centered the `HomeScreen` title and refined the user profile menu to include a "Copy ID" feature.
*   **Stability & Process:**
    *   Resolved multiple layout overflow and compilation issues.
    *   Established a rigorous pre-flight build check (Clean -> Get -> Analyze -> Run) to ensure code quality.

## Wednesday, 25 February 2026

**Summary:**
*   **Global Refactoring:** Performed a project-wide spelling correction, renaming all instances of "consistancy" to "consistency" in source code, file paths, documentation, and project configuration.
*   **UI/UX Modernization (Shadcn-inspired):**
    *   Redesigned task sections and items with a flat, minimalist aesthetic, removing drop shadows and elevations for a cleaner look.
    *   Updated the global theme to **Deep Purple** as the primary color.
    *   Refined the `FirstRunSetupScreen` and `AddTaskBottomSheet` with modern typography and styled components.
    *   Improved contrast in task sections by using darker blue and yellow shades.
*   **Feature Enhancements & Bug Fixes:**
    *   **Dynamic Heatmap Scaling:** Expanded the green color scale to five distinct levels (Level 1 to Level 5) with a more granular scoring breakdown.
    *   **Legacy Mapping:** Implemented logic to ensure old visual states map correctly to the new 5-level system.
    *   **Smooth UI Refresh:** Fixed a bug where task sections would reload and lose scroll position; refactored rendering to use `List<Task>` instead of `FutureBuilder`.
    *   **Score Recalculation:** Implemented `_refreshTodayRecord` to ensure the heatmap and scores update immediately when tasks are added, edited, or removed.
    *   **Enhanced Controls:** Added a "Cheat Day" label to the header button for better clarity.
*   **Version Control:** Committed all changes to the repository, establishing a new stable baseline for the modernized application.
