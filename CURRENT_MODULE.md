**Module:** Step 16 — UI/UX Overhaul: Apple-Level Polish
**Branch:** feature/ux-fixes
**State:** IN_PROGRESS (Phase 1 + 1b + 2 shipped — Phase 3 next session)
**Last updated:** 2026-06-02 (Phase 2 ship)

## Working Context

Phase 2 — Design System Foundation — is complete on `feature/ux-fixes`. The design system primitives are now centralized:

- **`lib/theme/app_spacing.dart`** — 8 spacing tokens (xxs=4 … xxxl=40)
- **`lib/theme/app_radius.dart`** — 6 radius tokens (xs=4 … xxl=24)
- **`lib/theme/app_icon_size.dart`** — 6 icon-size tokens (xs=12 … xxl=24)
- **`lib/widgets/app_card.dart`** — single reusable card chrome, extracted from the duplicated `_buildCard` helpers
- **`lib/main.dart`** — strengthened `textTheme` (9 explicit roles) via new `_buildAppTextTheme(Brightness)` helper; `colorScheme.tertiary` (brand orange `#EA580C` light / `#FB923C` dark) and `colorScheme.error` (red `#DC2626` light / `#F87171` dark) now drive what used to be hard-coded `Colors.orange`/`Colors.red` references

Sweep results across `lib/screens/` and `lib/widgets/`:
- **Zero** raw `Colors.red|orange|grey|blue|green|yellow|amber|purple` references remaining (verified via grep)
- All `BorderRadius.circular(N)` on the standard scale (4/6/8/12/16/24) now go through `AppRadius.*`; non-token values (1/2/3/10/20) intentionally left inline
- All `Icon(size: N)` on the standard scale (12/14/16/18/20/24) now go through `AppIconSize.*`
- `_buildCard` removed from `settings_screen.dart` (6 call sites swapped to `AppCard`); `_section` helper in `analytics_explorer_screen.dart` now wraps `AppCard`
- `syncStatusColor` signature changed to take `ColorScheme`; both call sites (home + settings) updated
- `StyleService` (the dynamic VisualStyle palette) was left untouched as planned
- Semantic gradient colors in `analytics_kpis._getConsistencyColor` and pomodoro mode accents kept as hex constants (with explanatory comments) — they encode meaning, not theme

`flutter analyze`: clean.

**Honest deferral:** ~40 `TextStyle(fontSize:…)` instantiations remain in `lib/screens/` and `lib/widgets/`. The plan's full goal of zero raw TextStyles wasn't met this phase — `textTheme` is strengthened and ready, but the call-site migration of all 40 instances was deferred to keep Phase 2's scope honest and the sweep mechanical. Migrating those to `Theme.of(context).textTheme.X.copyWith(...)` can be folded into Phase 3 polish or done as a follow-up pass.

## Next Action

Resume by reading this file + the latest `Prj_Progress.md` entry. Two paths forward:

1. **Merge Phase 1+1b+2 to master with `#minor` token → CI cuts v1.5.0**, then start Phase 3 on the same branch. The system is structurally healthier and ready for users to see.
2. **Continue stacking on `feature/ux-fixes`** through Phase 3 + 4, ship as one larger release.

Recommendation: option 2 if user is comfortable continuing without a release; option 1 if a checkpoint feels valuable.

If starting **Phase 3 — UX Polish**:
- Unify form validation on inline `errorText` across login/signup/first-run/task creation
- New `lib/widgets/empty_state.dart` and apply to task list / analytics-explorer-no-records / filter results
- Audit every async action for spinner-or-disable feedback
- First-run setup: live theme preview on toggle
- Remove standalone Settings push route at `settings_screen.dart:721-732` — PROFILE tab only
- Adopt `CupertinoPageRoute` (or themed Material variant) for nav transitions
- (Optional cleanup) Migrate remaining raw `TextStyle(fontSize:…)` instances to `textTheme.*`

---

## Phase 2 — Design System Foundation [DONE]

**P2.1 [DONE] Create token files + AppCard**
- New: `lib/theme/app_spacing.dart`, `app_radius.dart`, `app_icon_size.dart`, `lib/widgets/app_card.dart`
_Verified: 4 files exist; analyze clean._

**P2.2 [DONE] Strengthen `textTheme` + add `tertiary` / `error` to colorScheme**
- `lib/main.dart`: new `_buildAppTextTheme(Brightness)` helper covering 9 type roles; light/dark colorScheme override for tertiary (brand orange) and error (red).
_Verified: grep confirms `_buildAppTextTheme` in both light/dark blocks; tertiary/error overrides present; analyze clean._

**P2.3 [DONE] Sweep small widgets (sync_status, panels/*)**
- `sync_status.dart`: `syncStatusColor` now takes `ColorScheme`; callers in home + settings updated. Semantic-success green kept as `Color(0xFF10B981)`.
- Panels (`focus_panel`, `calendar_panel`, `graph_panel`, `task_panel`, `add_panel_placeholder`): tokenized.
_Verified: zero Colors.\* in panels; analyze clean._

**P2.4 [DONE] Sweep mid widgets (pomodoro_timer, task_item, task_section, analytics_kpis, add_task_bottom_sheet)**
- All color/radius/icon tokens applied. `analytics_kpis._getConsistencyColor` semantic gradient documented as hex constants (intentional).
_Verified: only Colors.\* matches are in comments referencing the gradient origin; analyze clean._

**P2.5 [DONE] Sweep consistency_heatmap (788 lines)**
- All Colors.grey/orange replaced with theme tokens; chevron icons de-consted where they now reference Theme.of(context).
_Verified: zero Colors.\* remaining; analyze clean._

**P2.6 [DONE] Sweep auth + first-run screens**
- Error border/text in login + signup now use `colorScheme.error`; first-run radius + icon tokenized.
_Verified: analyze clean._

**P2.7 [DONE] Sweep home_screen (623 lines)**
- 4 grey refs → `onSurfaceVariant`; radius/icon-size tokens applied.
_Verified: analyze clean._

**P2.8 [DONE] Sweep settings_screen + `_buildCard` → `AppCard` (891 lines)**
- 6 call sites of `_buildCard` replaced with `AppCard(child: Column(...))`; helper method deleted.
- All 5 remaining `Colors.orange` info-icons (PROFILE + CHEAT DAYS) → `colorScheme.tertiary`.
_Verified: zero Colors.\* in file; zero `_buildCard` references; analyze clean._

**P2.9 [DONE] Sweep analytics_explorer_screen + AppCard (560 lines)**
- `_section` helper refactored to wrap `AppCard(padding: EdgeInsets.zero, ...)`.
- 18+ color references swept (greys → `onSurfaceVariant`, oranges → `tertiary`, semantic green kept as hex).
_Verified: zero Colors.\* in file; analyze clean._

**P2.10 [DONE] Cleanup pass (analytics_carousel, dashboard_grid_renderer, add_task_bottom_sheet:93, pomodoro_timer:239)**
- These were not in the original file list but surfaced in the final audit. All tokenized.
_Verified: final `grep -rn 'Colors.(red|orange|grey|blue|green|yellow|amber|purple)' lib/screens lib/widgets` returns ONLY comment lines in analytics_kpis._

## Review History

**Phase 2** — Gemini (invoked via Bash --yolo per memory `subagents-not-registered`) executed the sweep in 8 batched specs (token files, theme strengthen, small widgets, mid widgets, heatmap, auth, home, settings, analytics, cleanup). The orchestrator (Claude) verified each batch with `flutter analyze` + targeted greps. A few transient gemini issues self-resolved on retry (one mid-batch tool-call corruption was recovered via full file rewrite). One `const` violation on `Theme.of(context)` substitution was caught and fixed mid-stream. Inline orchestrator review: PASS. Final analyze: clean.

## Acceptance for Phase 2

- 3 new token classes + AppCard widget created and used ✓
- `textTheme` strengthened with 9 roles ✓
- `colorScheme.tertiary` + `colorScheme.error` defined explicitly ✓
- Zero hard-coded `Colors.<material color>` outside theme/comments ✓
- `_buildCard` duplication eliminated; both screens use `AppCard` ✓
- `flutter analyze` clean ✓
- Inline orchestrator code review PASS ✓
- Manual visual smoke (Linux Mint dual-style/dual-brightness walkthrough): **PENDING** — user to verify before merge

---

## Out of Scope (explicitly deferred — unchanged)

- Step 12 — Desktop Integration (auto-start + tray) — separate branch
- Step 11 — Wallpaper feature — Android phase
- PocketBase backups — non-code
- Full TextStyle → textTheme migration of remaining ~40 instances — folded into Phase 3 or follow-up
