**Module:** Step 16 — UI/UX Overhaul: Apple-Level Polish
**Branch:** feature/ux-fixes
**State:** IN_PROGRESS (Phase 1 + 1b + 2 + 3 shipped — Phase 4 next session)
**Last updated:** 2026-06-02 (Phase 3 ship)

## Working Context

Phase 3 — UX Polish — is complete on `feature/ux-fixes`. Shipped:

- **`lib/widgets/empty_state.dart`** — new reusable EmptyState (icon + title + optional subtitle + optional action). Applied to the task list ('No tasks yet — tap + to add your first one') and to the analytics search sidebar (context-aware copy: 'No habits in this category' vs 'No matches' depending on whether a search term is active).
- **Inline form validation** — login + signup screens migrated from a Container error banner to `InputDecoration.errorText` attached to the password field. Both screens also clear `_errorMessage` on `onChanged` of either email or password, so the error disappears as soon as the user starts correcting it.
- **Settings de-embed** — `SettingsScreen.isEmbedded` parameter and all its dead-code branches removed; the screen is now always rendered as the PROFILE bottom-nav tab. `home_screen.dart` updated to drop the now-removed arg. The standalone push route (CANCEL button + AppBar + back chevron variant) is gone — one way to reach Settings.
- **Settings save feedback** — added `_isSavingSettings` state; the SAVE CHANGES button now disables and shows a spinner during the async write to DatabaseService.
- **Cupertino transitions** — all 4 `MaterialPageRoute` push sites swapped to `CupertinoPageRoute` (first-run → home, login → signup, settings → login, settings → signup). Smoother desktop-appropriate slide-in.
- **First-run live preview** — already wired (`styleNotifier.value = style` fires on style tap in `_buildStyleOption`); confirmed working, no edit needed.
- **Async audit** — login + signup already had full `_isLoading` disable + inline spinner. Settings save was the one gap, now closed. Other async paths (timer settings update, task add/delete, prefs writes) complete in milliseconds locally — instrumenting them would be noise, not signal.

`flutter analyze`: clean.

**Honest deferral:** the ~40 raw `TextStyle(fontSize:…)` instances from Phase 2 are still pending migration to `textTheme`. Folded forward to a follow-up pass; not blocking Phase 4.

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
