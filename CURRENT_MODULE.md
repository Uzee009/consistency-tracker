# CURRENT_MODULE.md

**Module:** Step 15A — Sync Echo-Loop Hardening
**Branch:** feature/sync-engine
**State:** IN_PROGRESS (code complete; awaiting code-review + user verification)
**Current Phase:** T1–T6 + T5-migration on disk; code-review pending; user verification pending; commit pending.
**Last updated:** 2026-06-01

Plan: see `DEVELOPMENT_PLAN.md §15A`. Goal: idle app talks to network only when there's genuinely new work; edits on device A appear on device B in ~1s via realtime; originating device runs exactly 1 push + 0 echoes per user edit.

---

## Sub-tasks

- [DONE] T1 — Tighten pull cursor (`>=` → `>`) in `_pull`
- [DONE] T2 — Split local-change notifier (`userLocalChanges` vs `localChanges`); `_applyRemote` wrapped in `runApplyingRemote`
- [DONE] T3 — `requestSync({reason})` + `SyncEvent` ring buffer (50) + debug panel in Settings
- [DONE] T4 — No-op early-exit in `sync()` when `reason=='user-edit' && _realtimeHealthy && dirty==0`
- [DONE] T5 — `DeviceIdService` (new singleton in SharedPreferences key `flutter.device_id`); `_push` writes `device_id`; realtime callback filters own-device echoes; PB migration `pocketbase/pb_migrations/1780300000_add_device_id.js` adds optional text field to all 3 collections.
- [DONE] T6 — Adaptive poll cadence (60s → 5m → 15m on idle, snap back on activity)
- [PENDING] T7 — Code-review (all 6 fixes)
- [PENDING] T8 — User manual verification (DoD scenarios from dev plan)
- [PENDING] T9 — Commit on `feature/sync-engine` + user deploys PB migration on GCP

---

## Working Context

All client-side code lands in this run. `flutter analyze --no-fatal-infos` clean. New `DeviceIdService` singleton initialized in `main()` after `PocketBaseService.init()`. Server-side migration file ready to deploy at `pocketbase/pb_migrations/1780300000_add_device_id.js` — user will SSH to GCP VM `/home/uzeeslive/pb/pb_migrations/` and curl it onto the host, then `sudo systemctl restart pocketbase` (same dance as Day-29 deploy).

---

## Next Action

Hand off to code-reviewer → on PASS, hand to user for manual verification (DoD scenarios) → on all-green, commit and user deploys migration.
