**Module:** Step 16 — UI/UX Overhaul: Apple-Level Polish
**Branch:** feature/ux-fixes
**State:** IN_PROGRESS (Phase 1 + 1b shipped — Phase 2 next session)
**Last updated:** 2026-06-01 (evening, session-end)

## Working Context

Phase 1 + an unplanned Phase 1b follow-up have shipped to `feature/ux-fixes` (one commit, NOT yet merged to master). All 7 original Phase 1 quick wins landed plus 4 follow-up fixes after the user spot-checked the running app and surfaced things the initial spec missed.

App state is now: pill-button bug killed at the root (global `OutlinedButtonTheme` + `TextButtonTheme` added to `lib/main.dart`); Settings cards span full width via `_buildCard` Container `width: double.infinity`; auth errors render friendly copy via a new `_friendlyAuthError` helper in both login and signup screens (raw exceptions still go to `debugPrint`); Sync & Connectivity signed-in section restructured to a tidy Row layout with themed `colorScheme.error` Sign Out button. `flutter analyze` clean.

Five hard-coded `Colors.orange` instances remain in `settings_screen.dart` (lines around 150, 155, 161, 327, 332) — these are info-icons in PROFILE and CHEAT DAYS cards, intentionally deferred to the Phase 2 color sweep, not Phase 1 scope.

Design decisions remain:
- Brand orange → `colorScheme.tertiary` (themed).
- Settings reached only via PROFILE bottom-nav tab; standalone push route deletion deferred to Phase 3.

## Next Action

Resume by reading this file + the latest entry in `Prj_Progress.md`. Then start **Phase 2 — Design System Foundation** on the SAME branch `feature/ux-fixes` (we have not merged Phase 1 to master; the whole UX overhaul will merge as one release once Phases 1-4 are done, OR we may decide to merge Phase 1+1b first as an early ship — that's a session-start decision for tomorrow).

First Phase 2 step: create the three new constant files (`lib/theme/app_spacing.dart`, `lib/theme/app_radius.dart`, `lib/theme/app_icon_size.dart`) and the new `lib/widgets/app_card.dart` extracted from the duplicated `_buildCard` helpers (one in `settings_screen.dart:756`, one in `analytics_explorer_screen.dart:356`). Then begin the screen/widget sweep replacing magic numbers and hard-coded colors.

---

## Phase 1 — Quick Wins (current commit)

**P1.1 [DONE] Delete Sync Log panel**
- File: `lib/screens/settings_screen.dart:495-524`
- Action: Remove the entire `if (kDebugMode) ...[ … ]` block. Remove the `kDebugMode` import on line 1 if it has no other usages in the file. Remove the `_formatAge` helper if it becomes orphaned.
_Verified: Sync Log block, kDebugMode import, and _formatAge helper all removed; flutter analyze clean._

**P1.2 [DONE] Strip REFRESH text label from header refresh button**
- File: `lib/screens/home_screen.dart:402-416`
- Action: Replace the `TextButton.icon(icon: Icon(Icons.refresh, size: 18), label: Text('REFRESH', …), …)` with an `IconButton(icon: Icon(Icons.refresh, size: 18), tooltip: 'Refresh', onPressed: <same onPressed>)`. Preserve the theme-aware `foregroundColor` (or its IconButton equivalent).
_Verified: TextButton.icon replaced by IconButton with tooltip 'Refresh' at home_screen.dart:400; REFRESH text gone._

**P1.3 [DONE] Remove redundant top-right UserMenu**
- File: `lib/screens/home_screen.dart:417-429`
- Action: Delete the `SizedBox(width: 8)` separator at line 417 and the `SizedBox(width: 40, child: Align(…, child: UserMenu(…)))` block at 418-429. After removal, grep the project for remaining `UserMenu` references; if none, also delete `lib/widgets/user_menu.dart` and remove the import line from `home_screen.dart`. NOTE: SettingsScreen has Sign Out at line 392, and the PROFILE bottom-nav tab already routes to embedded SettingsScreen (line 273-274), so there is no functional regression.
_Verified: UserMenu block deleted from home_screen.dart, lib/widgets/user_menu.dart removed (137 lines), zero remaining UserMenu references in lib/._

**P1.4 [DONE] Fix Settings → UPDATES card**
- Files: `lib/screens/settings_screen.dart:527-691`, plus `_buildSectionHeader` body around line 736-755
- Actions:
  - Audit visually: launch app on Linux Mint, screenshot the Settings screen, compare the UPDATES card against sibling cards (PROFILE, APPEARANCE, SOUND). Confirm whether the user's "square / not full-width / off-theme" complaint is about the section header, the hard-coded oranges, the card padding, or something else.
  - Replace hard-coded `Colors.orange[700]` / `Colors.orange.withValues(…)` at lines around 545-550, 549, 622, and home-screen banner colors at `home_screen.dart:103,107,144,159,186` with `Theme.of(context).colorScheme.tertiary`.
  - Replace hard-coded `Colors.red[700]` at 622 and similar with `Theme.of(context).colorScheme.error`.
  - If the section header uses `colorScheme.primary` differently from siblings, align it.
  - Re-screenshot after fix; both screenshots in the review report.
_Verified: hard-coded Colors.orange[700]/Colors.red[700] in UPDATES card and home banner replaced with colorScheme.tertiary / colorScheme.error. NOTE: 5 unrelated Colors.orange instances remain elsewhere in settings_screen.dart (PROFILE/CHEAT DAYS info icons) — deferred to Phase 2 color sweep._

**P1.5 [DONE] De-pill Create Account button (verify visually first)**
- File: `lib/screens/signup_screen.dart:208-222`
- Action: The global `ElevatedButtonTheme` in `lib/main.dart` (lines ~284-415) defines `RoundedRectangleBorder(borderRadius: 4)`, so the button SHOULDN'T be pill-shaped. Hypotheses for the user's report:
  - (A) The `SizedBox(width: double.infinity)` wrapping makes the wide-but-short button visually read as a pill.
  - (B) A local `shape:` override or M3 default is overriding the global theme. Grep for `StadiumBorder` and any local `style: ElevatedButton.styleFrom(...)` in this file.
- Steps:
  1. Launch app, navigate to Sign Up screen, take a screenshot of the Create Account button.
  2. Diagnose root cause.
  - Fix so the button matches the rectangular look of the `SAVE CHANGES` button at `settings_screen.dart:703-710` — same shape, same padding scale. (Global theme not changed in Phase 1.)
  - Re-screenshot to confirm.
  _Verified-and-extended: local RoundedRectangleBorder(4) override added to signup_screen.dart:219 and login_screen.dart:196. INSUFFICIENT — the Settings "Create Account" OutlinedButton at settings_screen.dart:350 was still pill because OutlinedButtonTheme was never defined globally. Fixed root cause in Phase 1b (see below)._

**P1.6 [DONE] Auth UX: autofocus + Enter-to-submit**
- Files: `lib/screens/login_screen.dart`, `lib/screens/signup_screen.dart`
- Actions:
  - Email TextField in both files: add `autofocus: true`.
  - Password TextField in both files: add `textInputAction: TextInputAction.done` and `onSubmitted: (_) => _handleSignIn()` (login) or `(_) => _handleSignUp()` (signup).
_Verified: autofocus:true on email field, textInputAction.next on email, textInputAction.done + onSubmitted on password, in both login and signup screens._

**P1.7 [DONE] Tap-target bumps to ≥44×44 logical pixels**
- Files: `lib/widgets/task_item.dart` (action buttons, currently `EdgeInsets.all(8)`), `lib/widgets/pomodoro_timer.dart:139-157` (mode toggles, currently h10/v6).
- Action: Increase padding/sizing so each interactive widget meets a 44×44 minimum. Use Material's standard `IconButton` defaults (which give 48×48) where it fits, otherwise pad manually.
_Verified: task_item.dart EdgeInsets.all(8.0) → all(12.0) at line 207. pomodoro_timer.dart EdgeInsets.symmetric(h:10,v:6) → (h:14,v:10) at line 141._

## Review History

**Phase 1 (initial batch)** — gemini-coder executed all 7 quick wins on 2026-06-01. Code-reviewer subagent not registered in current harness, so the orchestrator (Claude) performed an inline review by reading the unified diff. Diff was minimal and on-spec; no collateral damage; flutter analyze zero issues. PASS.

**Phase 1b (user spot-check follow-up)** — user ran the app and reported via screenshots:
1. Settings "Create Account" OutlinedButton STILL pill-shaped (root cause: missing OutlinedButtonTheme globally).
2. Settings → UPDATES card was narrow, not full-width (root cause: _buildCard Container had no width constraint, sized to its short content).
3. Wrong-password attempt showed raw `ClientException: ...` blob (root cause: `_errorMessage = e.toString()` at login_screen.dart:65 and signup_screen.dart:78 — was meant for Phase 3 but pulled forward).
4. Signed-in Sync & Connectivity layout cramped and Sign Out button used hard-coded red.

Four fixes shipped in same session:
- A: added `OutlinedButtonTheme` + `TextButtonTheme` to BOTH light and dark themes in `lib/main.dart` (radius=4, matching ElevatedButtonTheme). This kills pills app-wide as a Phase 2 down-payment.
- B: `_buildCard` Container in `settings_screen.dart:756` now has `width: double.infinity`.
- C: new `_friendlyAuthError(Object e, {required bool isSignUp})` helper at top of `login_screen.dart` and `signup_screen.dart`, mapping common errors (400/401/403/network/5xx) to human copy. Raw error still logged via `debugPrint`.
- D: signed-in Sync card section restructured from Column to Row with `Icons.check_circle_outline` + "Signed in" label + email left, themed `colorScheme.error` OutlinedButton "Sign Out" right.

Inline review by orchestrator after Phase 1b: PASS. flutter analyze clean.

## Acceptance for Phase 1
- All 7 sub-tasks marked [DONE] in this file. ✓
- `flutter analyze` produces zero issues. ✓
- code-reviewer PASS verdict (orchestrator-inline, subagent not available). ✓
- Manual verification on Linux Mint: user spot-checked the running app post-Phase-1, surfaced 4 additional issues, all fixed in Phase 1b (see Review History). User has NOT yet spot-checked Phase 1b results — that's the first thing for next session.

**Phase 1+1b status: implementation complete, committed but not merged. Next session will start by user re-running the app to confirm Phase 1b fixes look right, then either merge or iterate further before starting Phase 2.**

---

## Phases 2–4 (queued, do AFTER Phase 1 ships)

**Phase 2 — Design System Foundation** (~2 hrs):
- New files: `lib/theme/app_spacing.dart` (xs=4, sm=8, md=12, lg=16, xl=24, xxl=32), `lib/theme/app_radius.dart` (sm=8, md=12, lg=16), `lib/theme/app_icon_size.dart` (sm=12, md=16, lg=24).
- New file: `lib/widgets/app_card.dart` extracted from `_buildCard` (currently duplicated in `settings_screen.dart:756` and `analytics_explorer_screen.dart:356`).
- Sweep all `lib/screens/*.dart` and `lib/widgets/**/*.dart` to:
  - Replace `EdgeInsets`, `SizedBox` magic numbers with `AppSpacing.*`.
  - Replace `BorderRadius.circular(N)` with `AppRadius.*`.
  - Replace `Icon(size: N)` with `AppIconSize.*`.
  - Replace hard-coded `Colors.*` / `Color(0xFF…)` with `Theme.of(context).colorScheme.*`. Use `colorScheme.tertiary` for the brand orange accent.
  - Replace raw `TextStyle(fontSize: …, fontWeight: …)` with `Theme.of(context).textTheme.*` styles. If the existing textTheme in `main.dart` doesn't have enough roles, expand it (target ~5 roles).

**Phase 3 — UX Polish** (~3 hrs):
- Form validation: unify on inline `errorText` in `InputDecoration` across login, signup, first-run, task creation. Stop leaking raw exception strings — map PocketBase errors to friendly copy at `signup_screen.dart:78` and `login_screen.dart:65`.
- New `lib/widgets/empty_state.dart` (icon + title + subtitle + optional CTA). Apply to: task list empty day, analytics explorer with no records for selected task, filter results yielding nothing.
- Audit every async action (sync, update check, signup, login, task save, settings save) for spinner-or-disable feedback. No silent freezes.
- First-run setup: live theme/style preview as the user toggles options (currently jumpy).
- Settings nav consolidation: remove the standalone push entry point at `settings_screen.dart:721-732` (the `widget.isEmbedded ? Scaffold(...) : Scaffold(appBar: ...)` branch). PROFILE bottom-nav tab becomes the only path.
- Page transitions: adopt `CupertinoPageRoute` for navigation (or a themed Material variant with smoother curves) — desktop-appropriate.

**Phase 4 — Motion & Micro-interactions** (~1-2 hrs):
- Wrap state-changing widgets in implicit animation containers:
  - Heatmap cell color (`lib/widgets/consistency_heatmap.dart`) → `AnimatedContainer` for color transitions.
  - Task tick state (`lib/widgets/task_item.dart`) → `AnimatedSwitcher` for the checkmark and `TweenAnimationBuilder` for any score-bar fill animation.
  - Sync status dot (`lib/widgets/sync_status.dart`) → `AnimatedContainer` for color.
  - Update banner (`lib/screens/home_screen.dart:92-234`) → `AnimatedSize` for collapse/expand.
- Desktop hover states: wrap interactive elements (task rows, panels, nav tabs, buttons) in `MouseRegion` + `AnimatedContainer` for subtle background-shift on hover + cursor change to `SystemMouseCursors.click`.
- Heatmap cell: subtle scale-down (`AnimatedScale`) on tap-down, plus a tooltip with the formatted date and score.

---

## Out of Scope (explicitly deferred)

- Step 12 — Desktop Integration (auto-start + tray) — DEFERRED to its own branch after this module ships.
- Step 11 — Wallpaper feature — DEFERRED to the Android phase.
- PocketBase server backups — non-code, user to enable in Admin UI.
