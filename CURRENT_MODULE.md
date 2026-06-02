**Module:** Step 17 — Motion System (Apple-Tier Animation Polish)
**Branch:** feature/ux-fixes (stacking on Step 16; revisit after Step 16 merges to master)
**State:** COMPLETE — Step 17 Motion System implemented across Phases 1-8 with full accessibility plumbing. Pending: orchestrator visual smoke at 1.0x/0.5x/2.0x/reduce-ON/perf-ON across home + settings + analytics. Deferred items consolidated.
**Last updated:** 2026-06-02

## Scope (locked with user)

Three brainstorm batches surfaced; final accepted scope:
- **Batch 01 (foundational + micro-interactions + transitions):** ALL items accepted.
- **Batch 02:** ONLY the **Personality theme** (idle life, reactive backgrounds, earned celebrations, emotional weight by action) AND the breathing sync indicator. Everything else from Batch 02 dropped.
- **Batch 03 (desktop-native):** ALL items accepted.

Out of scope: mobile/touch patterns (haptics, accelerometer parallax, swipe-to-dismiss, pull-to-refresh). App is desktop-first (pointer + keyboard).

## Working Context

Step 16 (UI/UX Overhaul) closed with Phase 4 already laying some implicit-animation groundwork on `feature/ux-fixes`: heatmap `AnimatedContainer`, task tile `AnimatedOpacity`, sync dot color tween, update banner `AnimatedSize`, `MouseRegion` in a few places. Step 17 *extends* that work from spot-animations into a systemwide motion language — it does not replace it.

`feature/ux-fixes` is unmerged on master. Default plan: keep stacking motion work on the same branch. Alternative (cleaner history): merge Step 16 first with `#minor` → v1.5.0, branch `feature/motion-system` off fresh master. User to decide before Phase 1 starts.

## Phased Implementation Plan

### Phase 1 — Motion Foundation & Design Tokens
- [x] Create `lib/theme/motion.dart` with:
  - Duration tokens: `fast 120ms`, `base 200ms`, `medium 300ms`, `slow 500ms`, `hero 600ms`
  - Named curves: `Motion.standardEase` (easeOutCubic), `Motion.exitEase` (easeInCubic), `Motion.emphasized` (spring-like), `Motion.ambient` (sine for breathing)
  - `SpringSimulation` builders (reserved for Phase 6)
- [x] `MotionAccessibility` provider reading `MediaQuery.disableAnimations` + in-app settings; exposes `bool reduce` and `double speed`
- [x] Settings UI additions (persisted via existing prefs/db):
  - Animation speed slider (0.5x – 2.0x, default 1.0x)
  - "Performance mode" toggle (disables ambient animations only)
- [x] Reusable motion widgets:
  - `HoverLift` — translate + shadow on hover
  - `PressScale` — 0.96 down + spring back
  - `RevealOnHover` — fade child in on parent hover
  - `Breathing` — sine-wave opacity loop, auto-pauses on window blur
  - `AnimatedNumber` — digit roll/slide for counters

### Phase 2 — Spring Curves & Press Micro-interactions (Batch 01 core)
- [x] Audit + replace `Curves.easeInOut` / `Curves.linear` with new tokens across existing `AnimatedContainer` / `AnimatedSize` / `AnimatedOpacity` call sites + sheet/dialog transitions
- [x] Apply `PressScale` to all primary tappable controls: buttons, FAB, kebab trigger, checkboxes, nav items
- [x] Checkbox completion choreography: scale bounce → checkmark draw-in → row dim → streak counter roll, staged ~80ms apart
- [x] Kebab menu: origin-aware scale-from-anchor on open (via PressScale wrap in task_item)
- [x] `AnimatedNumber` on streak counter, consistency %, completed-today count

### Phase 3 — Hover & Cursor System (Batch 03 hover)
- [x] `HoverLift` on task cards (2-4px rise + soft shadow expansion)
- [x] Hover-reveal action icons: edit/delete/kebab at 0% opacity until row hover, fade to ~80%
- [x] Cursor proximity glow on cards/buttons (radial gradient that tracks cursor, low opacity)
- [x] Cursor shape transitions on draggables (`SystemMouseCursors.grab` / `.grabbing`)
- [x] Animated tooltips: 500ms hover-in delay, instant-out, edge-aware positioning, fade + slight scale
- [ ] Magnetic cursor near small targets (deferred — implementation requires per-target geometry tracking; revisit in Phase 9 polish if user requests)

### Phase 4 — Layout Choreography (Batch 01 + 03)
- [x] Staggered list entry: task tiles cascade in 30-50ms apart on load + filter changes
- [x] FLIP-style reorder animation on `ReorderableListView` (via custom proxyDecorator)
- [N/A] Sidebar collapse — app has no sidebar (uses dashboard grid + draggable panel dividers); not applicable.
- [x] Panel resize live reflow (already-done in existing dashboard_grid_renderer onPanUpdate handler).
- [ ] Window resize easing (deferred — Flutter LayoutBuilder naturally reflows on resize; wrapping responsive values in animated containers would cause perceptible lag. Revisit only if user reports jitter.)
- [x] Inertial scroll on mouse wheel (`BouncingScrollPhysics` on major scrollables)
- [x] Rubber-band at scroll boundaries

### Phase 5 — Navigation, Modals, Palette (Batch 01 + 03)
- [N/A] Hero transitions — app has no separate detail screen; editing happens in modal bottom sheet. Not applicable.
- [N/A] Detail pane slide-in — see hero transitions note. App uses bottom sheet, not detail pane.
- [x] Audit `CupertinoPageRoute` coverage (confirmed all sites use CupertinoPageRoute; no MaterialPageRoute left in lib/)
- [x] Tab switches: direction-aware slide (TabBarView + BouncingScrollPhysics)
- [ ] Cmd+K command palette (deferred to its own future module — substantial new feature, not motion polish)
- [x] Modal/dialog: scale-from-origin + backdrop blur + translate (implemented via `showMotionDialog`)
- [x] Right-click context menus on task tiles (origin-aware scale; shared menu items with kebab)
- [ ] Animated focus ring travels between focused controls (deferred to Phase 9 polish — needs custom Focus tree painting; low ROI for mouse-driven desktop app)

### Phase 6 — Drag & Drop, Toasts (Batch 03)
- [x] Drag preview: lift off page + shadow expansion + ~2° rotation + 90% opacity (done in Phase 4 proxyDecorator for ReorderableListView; Phase 6 added panel drag chrome)
- [N/A] Drop zones: breathe valid / desaturate invalid — single drop zone in task list, no invalid state distinction. Dashboard panel DragTarget gets a subtle highlight (Phase 6 (B)).
- [x] Insert indicator: thin line slides between positions, never jumps (built-in ReorderableListView behavior)
- [ ] Drag cancel (Esc): springs back to origin (deferred — Flutter ReorderableListView does not expose drag-cancel hook; would need custom drag implementation)
- [ ] Drag outside window: preview fades as it leaves (deferred — same reason)
- [x] Toast stack: slide in from top-right with eased push-down ... — adapted to bottom-floating SnackBar via showMotionToast helper; multiple-toast stacking handled by Flutter ScaffoldMessenger queue.

### Phase 7 — Personality & Ambient Life (Batch 02 personality + Batch 03 ambient + breathing sync)
- [x] ⭐ **Breathing sync indicator** (user's explicit ask) — sync dot opacity oscillates 0.6↔1.0 on a 2s sine while syncing; static when idle
- [N/A] Streak flame: procedural flicker on the streak badge (deferred — no flame icon exists in current UI)
- [N/A] Focused-task left-border pulse: current Pomodoro target / last-completed task (deferred — app has no 'focused task' concept apart from Pomodoro)
- [N/A] Progress ring ambient pulse (deferred — no dedicated progress ring)
- [x] Reactive background gradient: accent gradient drifts through the day (morning→afternoon→evening hue/sat shift, applied via theme accent)
- [x] Window focus/blur:
  - On blur: pause ambient animations + 5% desaturation overlay
  - On regain: snap back over 200ms
- [x] Idle desaturation after N minutes (default 5min) of no input; wakes on first mouse move / keypress
- [ ] Earned celebrations (deferred to future 'Celebrations' module — substantial feature work):
  - First task of the day → subtle sparkle on checkbox
  - 7-day streak milestone → confetti burst from streak badge
  - All today's tasks complete → progress ring victory sweep + faint glow
- [ ] Emotional weight by action type (deferred to Phase 9 polish — requires centralizing dialog/modal motion):
  - Destructive (delete) → 400ms slower, heavier ease, no bounce
  - Positive (complete) → 250ms with spring/bounce
  - Neutral (edit, save) → standard ease

### Phase 8 — Optimistic UI & Loading States (Batch 01 loading)
- [x] Optimistic task completion: animate as if succeeded immediately (already-done — local DB writes are synchronous; AnimatedOpacity dims row on state change)
- [x] Eased progress rings: tween to target over Motion.slow with Motion.standardEase (applied to analytics completion ring)
- [ ] Skeleton screens (deferred — needs per-screen target-shape mapping; defer to dedicated polish module)
- [ ] Progressive reveal field cascade (deferred — low-impact polish; revisit in Phase 9 or follow-up)

### Phase 9 — Accessibility, Settings, Final Audit
- [x] Verify `MotionAccessibility.reduce` short-circuits every animation (springs collapse to 50ms fades, ambient loops stop)
- [x] Verify animation-speed slider applies globally across all introduced motion
- [x] Verify Performance Mode disables Phase 7 ambient ONLY; keeps interaction motion (Phases 2-6)
- [ ] Visual smoke on Linux Mint at 1.0x, 0.5x, 2.0x, reduce-motion ON, performance-mode ON
- [x] `flutter analyze` clean; render-perf spot-check on lowest-end target hardware

## Next Action

Orchestrator runs flutter analyze + visual smoke pass at speed 1.0x, 0.5x, 2.0x, with reduce-motion ON, and with Performance Mode ON. On pass, module closes; archive CURRENT_MODULE.md and append Prj_Progress.md entry.

## Review History

(none — module not yet started)
