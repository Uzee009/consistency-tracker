# Mobile (Android) — Development Plan

Separate roadmap for the Android build of Consistency Tracker. Desktop roadmap lives in `DEVELOPMENT_PLAN.md`. iOS is OUT OF SCOPE (no MacBook, no Apple Dev account).

Same Flutter project — mobile-only Dart files use the `mobile_` prefix (e.g. `lib/screens/mobile_home_screen.dart`). Shared code (sync, data, models, services) stays as-is.

---

## M1 — Design Brief & Screen Inventory — IN_PROGRESS
Produce `mobile_DESIGN_BRIEF.md` with goals, constraints, current screen list, and what each screen must do on a phone. User pastes brief + desktop screenshots into claude.ai Artifacts.

## M2 — External Mockup Phase (claude.ai Artifacts) — PENDING
User iterates on clickable React/HTML mockups in claude.ai. No work happens in this repo during this phase. Exits when user has an approved mockup set for every screen.

## M3 — Mobile Design Tokens — PENDING
Translate approved mockups into spacing / sizing / touch-target / typography tokens added to `lib/theme/`. Reuse desktop tokens where possible; add mobile-only ones where they diverge.

## M4 — Mobile Shell & Navigation — PENDING
`mobile_app_shell.dart` + bottom nav (or side rail — decided during M2). Wire the mobile shell as the entry point when the app runs on Android. Desktop path untouched.

## M5 — Core Screens — PENDING
Port the six screens to mobile, one at a time, against approved mockups:
- `mobile_first_run_setup_screen.dart`
- `mobile_login_screen.dart` / `mobile_signup_screen.dart`
- `mobile_home_screen.dart`
- `mobile_settings_screen.dart`
- `mobile_analytics_explorer_screen.dart`

## M6 — Android Release — PENDING
APK signing + Play Store internal track. Self-update flow (Step 14 on desktop) does NOT apply on Android — Play Store handles updates.

## M7 — Motion Polish — PENDING (deferred)
Apple-tier motion on mobile (spring physics, choreography). Deferred until app is stable end-to-end on Android.
