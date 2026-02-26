# Operational Mandates

1.  **Operational Modes:**
    *   **Consult Mode (Default/Inquiry):** Focused on analysis, strategy, and brainstorming. You MUST NOT modify any files (except logs during conclusion) or run implementation commands.
    *   **Dev Mode (Directive):** Focused on implementation and execution.
    *   **Switching:** You will stay in the current mode unless specifically asked to switch. If the mode is ambiguous or not specified at the start of a task, you MUST ask: "Which mode are we using: Dev or Consult?"
2.  **Session Logging:**
    *   Do NOT log changes after every tool call or task.
    *   You will ONLY append entries to `Prj_Progress.md` when the user says "conclude session here".
3.  **Source Control:**
    *   NEVER commit changes or merge branches (e.g., merging to `master`) unless explicitly and specifically instructed to do so for that specific action.

# Directory Overview

* **`My Role`** : I am a senior developer with decades of experience I make highly scalable apps with clean code modern UIs and Flow less UX. I made no syntax error and follows best industry practices and write highly readable code.

This directory contains the planning, ideation, and specification documents for a new software project called the **Consistency Tracker**. The project's goal is to create a cross-platform (Windows, macOS, Linux) desktop application with future mobile support, designed to help users track their daily habits and consistency in a visually engaging way, similar to a GitHub contribution graph.

The application is intended to be offline-first, with a robust, Anki-style synchronization mechanism for future multi-device support. It emphasizes user privacy and a frictionless experience.

# Key Files

*   **`Initial draft.txt`**: The first document outlining the core ideas for the application. It describes the initial concept, key functionalities like task allocation (daily and temporary), cheat days, reminders, and the GitHub-style tracker visualization.

*   **`Consistency Tracker - Consistency Tracker Plan.pdf`**: A detailed and refined planning document. It provides a deep dive into the project's philosophy, architecture, and technology stack. Key concepts include:
    *   **Engine-first, Surface-agnostic** design.
    *   **Desktop-primary, Phone-secondary** interaction model.
    *   A precise, multi-step **scoring algorithm** for daily consistency.
    *   The **recommended tech stack**: Flutter for the UI, Dart for the logic, and SQLite for the local database.
    *   A plan for an **Anki-style, "dumb server" sync model**.

*   **`DEVELOPMENT_PLAN.md`**: The actionable, step-by-step development roadmap for building the application. It breaks down the project into four main phases:
    1.  **Phase 1: Setup and Flutter Fundamentals**: Covers environment setup and learning the basics of Dart and Flutter.
    2.  **Phase 2: Building the Core Logic ("Engine")**: Focuses on creating the data models, scoring engine, and database service.
    3.  **Phase 3: Building the User Interface ("Skin")**: Covers the development of all UI components, from the first-run experience to the main dashboard and the visual consistency grid.
    4.  **Phase 4: Advanced Features and Sync**: Outlines the implementation of advanced features like wallpaper integration and the optional sync client.

# Usage

The contents of this directory should be used as the primary source of truth and context for the development of the Consistency Tracker application. Before beginning any coding task, these documents should be consulted to understand the project's goals, architecture, feature specifications, and the agreed-upon development plan.

# Project Progress Tracking

To maintain a clear and chronological record of our development efforts, a `Prj_Progress.md` file is used. This file serves as a session log, detailing the work accomplished.

**Workflow for `Prj_Progress.md`:**

*   **Beginning of Session:** Review `Prj_Progress.md` to quickly recap what was done in the previous session and to set the context for current tasks.
*   **End of Session:** Append a new entry to `Prj_Progress.md` with the following format:
    *   **Timestamp:** Include the current date and time.
    *   **Summary:** Briefly describe the tasks completed, decisions made, and any significant outcomes or issues encountered during the session.

This practice ensures continuous tracking and easy reference for our development journey.