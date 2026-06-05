# Mobile (Android) — Design Brief

Brief for redesigning Consistency Tracker for Android phones. Intended to be pasted into claude.ai Artifacts alongside screenshots of the current desktop app.

## What the app does

Consistency Tracker is a daily-habit / task app. The user defines tasks they want to do every day. Each day they tick tasks off. A daily score is computed (with cheat-day allocation, temp-task compensation, star/overachievement). A GitHub-style year grid visualises consistency, with cell color reflecting the daily score and stars marking overachievement days. Sync is local-first (SQLite) with a PocketBase backend; the app works offline and reconciles when online.

## Goals for the mobile redesign

- Phone-shaped: portrait-first, one-handed reachable, thumb-friendly.
- Same mental model as desktop (tasks, daily score, year grid, analytics) — do not invent new concepts.
- Speed-of-use: the most common action (ticking today's tasks) is one tap from launch.
- Visual continuity with the desktop app's identity (the design tokens in `lib/theme/`), but layouts re-thought from scratch for a small screen.

## Constraints

- Android only. iOS is out of scope.
- Flutter, same codebase as desktop. Mobile screens will be new `mobile_*.dart` files; shared sync / data / model code is untouched.
- Motion / animation polish is explicitly deferred. Design for static + simple transitions only; "alive" motion comes later.
- Self-update flow is desktop-only — Android updates via Play Store.

## Screens to redesign

The desktop app has six screens. The mobile redesign needs a phone version of each:

1. **First-run setup** — onboarding: pick username, set up initial tasks, choose cheat-day allowance.
2. **Login** — email + password sign-in to PocketBase account.
3. **Signup** — create a PocketBase account.
4. **Home (main dashboard)** — today's tasks (tick/untick), daily score readout, the consistency year-grid, quick add/edit task. This is the screen the user opens 95% of the time.
5. **Settings** — account, sync status, data export, theme, etc.
6. **Analytics explorer** — historical view: drill into past days, streaks, score trends.

## Navigation

Open question for the mockup phase: bottom nav vs. side rail vs. single-screen-with-drawer. Decide during M2 based on which feels most natural for the home-first usage pattern.

## What the mockups must show

For each screen above:
- Portrait layout at typical phone widths (360–420 dp).
- Touch targets ≥ 48 dp.
- Empty / loading / error states for screens that have meaningful ones (home, analytics, login).
- How the year-grid scales down — the desktop version is wide; the mobile version probably needs horizontal scroll or a re-shape (e.g. month chunks).

## Out of scope for the brief

- Specific motion / animation behavior (deferred to M7).
- iOS-specific patterns.
- Tablet / foldable layouts.
