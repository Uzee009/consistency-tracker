**Module:** Task Row UX — Kebab Menu + Manual Ordering
**Branch:** feature/ux-fixes
**State:** READY FOR TESTING — Phase A + Phase B implemented, not yet verified live
**Last updated:** 2026-06-02

## Working Context

Phase A (kebab menu replacing Skip/Edit/Delete trio in task_item.dart) was implemented and visually confirmed by the user. Phase B (this cycle) adds persisted manual ordering and drag-to-reorder, and rips out the auto-sort.

Changes in Phase B:
- task_model.dart: new `sortOrder` int field, plumbed through toMap/fromMap/copyWith.
- database_service.dart: schema v9 → v10. New `sort_order` column on tasks. Backfilled from created_at ascending so legacy data preserves insertion order. addTask now auto-assigns `max(sort_order)+1`. New `reorderTasks(sids, values)` method that bumps dirty/updated_at so sync will pick up the change.
- dashboard_controller.dart: bucketed + alphabetical sort REMOVED. Replaced with pure `sort_order` ascending. New `reorderTasksWithinType(type, oldIndex, newIndex)` that rotates only that type's sort_order pool.
- task_section.dart: ListView.builder → ReorderableListView.builder. Drag handle (`Icons.drag_indicator`) added left of the checkbox via `ReorderableDragStartListener`. buildDefaultDragHandles: false.
- task_panel.dart: wires onReorder through to controller.

SYNC CAVEAT (follow-up): PocketBase `tasks` collection needs a `sort_order` numeric field added so reorders sync across devices. Until that's done, dirty rows will push but the field may be silently dropped or rejected by PB depending on collection schema mode. Local UX works regardless.

## Next Action

User: hot-restart the app (existing per-account DBs will run the v9→v10 migration in place). Verify:
1. Task rows now have a drag handle (⋮⋮) on the left of the checkbox.
2. Drag-and-drop reorders persist across restart.
3. New tasks added via + button append at the bottom.
4. No alphabetical reshuffle. Completing a task does NOT move it.
5. Kebab menu (Phase A) still works on each row.

After verification: commit Phase A + B together on feature/ux-fixes with [skip release].

## Review History

- Cycle 1 (Phase A): gemini-coder swapped 3 trailing buttons in task_item.dart for a PopupMenuButton. flutter analyze clean (one expected unused-element warning for _buildActionButton retained for Phase B). Claude inline review: PASS. User visually confirmed.
- Cycle 2 (Phase B): gemini-coder added sort_order field + migration + ReorderableListView + reorder controller method. flutter analyze: [TO BE FILLED]
