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

*   **Step 13 (Future Goal): Implement Anki-style Sync Client.**
    *   **Goal:** Provide optional, seamless, and private data synchronization across devices.
    *   **Tasks:**
        *   **13a. Data Encryption/Decryption:** Implement strong encryption for `DayRecord` data before uploading and decryption after downloading.
        *   **13b. Sync Service Client:** Create a service to communicate with a "dumb blob storage" backend (e.g., Firebase Storage, Supabase, or a custom minimal API).
        *   **13c. Sync Logic:** Implement the "last-write-wins" logic per `DayRecord` based on timestamps and device IDs.
        *   **13d. Automated Triggers:** Set up automatic sync on app launch, close, or periodically in the background.