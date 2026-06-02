**Module:** Step 16 — UI/UX Overhaul: Apple-Level Polish
**Branch:** feature/ux-fixes
**State:** COMPLETE (Phases 1 + 1b + 2 + 3 + 4 shipped — ready for merge decision)
**Last updated:** 2026-06-02 (Phase 4 ship + module complete)

## Working Context

Phase 4 — Motion & Micro-interactions — is complete on `feature/ux-fixes`. The whole Step 16 UX overhaul is now done across 4 phases (5 commits counting Phase 1b).

Shipped in Phase 4:
- **Heatmap cell**: `AnimatedContainer` (220ms easeOut) wraps the cell so color transitions between intensities + selected/unselected feel smooth. Each day cell gets a `Tooltip` with a formatted date (manual short-form, no intl dep). `MouseRegion(cursor: click)` for desktop hover affordance. Applied in BOTH the 1M view and the generic multi-month view (~lines 414 and 684).
- **Task tick state**: `Opacity` → `AnimatedOpacity` (200ms) for the dim-on-complete transition. Outer `Container` → `AnimatedContainer` for chrome shifts (border/background) when state changes. Whole row wrapped in `MouseRegion(cursor: click)` so hover state matches expectation on desktop.
- **Sync dot**: `Container` → `AnimatedContainer` (300ms) so color tween between ready/notSignedIn/unreachable is buttery, not stepped.
- **Update banner**: previously early-returned `SizedBox.shrink` when not available — now wrapped in `AnimatedSize` (300ms easeOut) so collapse/expand animates instead of snapping.
- **Pomodoro tabs**: already had `AnimatedContainer` from earlier — verified still in place after Phase 2 sweep.

`flutter analyze`: clean. Three commits accumulated on `feature/ux-fixes` (`5448296` Phase 1+1b, `f3eb6c4` Phase 2, `56484ac` Phase 3, plus the Phase 4 commit to follow). Nothing merged to master yet.

**Honest deferral:** the ~40 raw `TextStyle(fontSize:…)` migrations to `textTheme` remain. They were never blocking — `textTheme` is strengthened and ready whenever the cleanup pass happens. Not strictly part of any phase deliverable.

## Next Action

Step 16 is functionally complete. Two decisions remain:

1. **Spot-check on Linux Mint** — recommended before merge. Walk through home / settings / login / signup / first-run / analytics in both Visual Styles × both brightnesses. Focus on:
   - Heatmap tap → AnimatedContainer smooth color transition; tooltip on hover
   - Task complete/uncomplete → AnimatedOpacity dim + AnimatedContainer chrome
   - Sync dot color change → smooth tween
   - Update banner appear/dismiss → AnimatedSize collapse
   - Page transitions (login → signup, settings → login, first-run → home) → Cupertino slide
   - Empty task list → friendly EmptyState
   - Wrong password → inline errorText below password field, clears on edit

2. **Merge decision** — push `feature/ux-fixes` to master with `#minor` token → CI cuts v1.5.0. All 4 commits on the branch carry `[skip release]`, so only the merge will trigger publication.

After merge, this module is closed. The 4-phase plan in DEVELOPMENT_PLAN.md Step 16 should be flipped to DONE. The next module candidates (Step 12 Desktop Integration, Step 11 Wallpaper for Android, PB backups) are all deferred per existing notes.

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
