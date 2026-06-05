# Consistency Tracker — Development Plan

Living roadmap. Completed phases are kept as one-line pointers; full history lives in `Prj_Progress.md`. The active/next work is detailed at the bottom.

**Mobile (Android) track:** separate plan in `mobile_DEVELOPMENT_PLAN.md`.

---

## Phase 1 — Flutter & Dart Fundamentals — DONE
Steps 1–3: dev environment, Dart language, Flutter widgets/state.

## Phase 2 — Core Engine — DONE
Steps 4–6: data models (`User`, `Task`, `DayRecord`), scoring service, SQLite `database_service`.

## Phase 3 — User Interface — DONE
Steps 7–10: first-run setup, task management, main dashboard, GitHub-style consistency grid.

## Phase 4 — Advanced Features, Sync, Distribution

### Step 11 — Wallpaper Feature — PENDING
Render the consistency grid to an image and set it as the desktop wallpaper on Windows / macOS / Linux. Settings toggle + refresh rate. Not started.

### Step 12 — Desktop Integration — PENDING
Auto-start on login + optional system-tray / menubar icon. Not started.

### Step 13 — Cross-Device Sync (PocketBase, Local-First) — DONE
Local-first SQLite + PocketBase on GCP VM (`consistancy.duckdns.org`, `/home/uzeeslive/pb/`). Pure-Dart HTTP+SSE. LWW on `updated_at`. UUID `sid`, `task_status` + `day_meta` tables, tombstones, dirty flag, debounce + realtime.

### Step 14 — In-App Self-Update & Auto-Release — DONE
CI auto-bumps semver on master push (`#minor`/`#major`/`[skip release]` tokens). One-click update & restart in app. Shipped v1.3.0.

### Step 15 — Sync Hardening: Apple-Level Seamless Sync — DONE (2026-06-01)
Per-account SQLite isolation + six echo-loop fixes (device_id suppression, cursor strict-gt, split notifier, no-op early-exit, adaptive poll, trigger instrumentation). PB migration `1780300000_add_device_id.js` deployed. Shipped v1.4.0.

### Step 16 — UI/UX Overhaul: Apple-Level Polish — DONE (2026-06-02)
Design system tokens in `lib/theme/`. Visual + state consistency pass.

### Step 17 — Motion System (Apple-Tier Polish) — DONE (2026-06-02)
Motion tokens + 11 reusable motion widgets, hover/cursor/drag/modal polish, breathing sync indicator, focus/idle states, accessibility. Deferred follow-ups: Cmd+K palette, Celebrations, Skeleton screens.

### Step 18 — PocketBase Infra Debt — DONE (2026-06-05)
PB `tasks.sort_order` field for cross-device manual ordering. Daily PB backups to GCS bucket `ct-pb-backups-acd35fdb` at 03:00 UTC, 14-day retention. Shipped v1.2.0.

---

## Next up (desktop)

Open candidates, no commitment yet:
- Step 11 (Wallpaper) or Step 12 (Desktop Integration) — the original Phase 4 leftovers.
- Step 17 follow-ups: Cmd+K palette, Celebrations, Skeleton screens.

Mobile work is tracked separately — see `mobile_DEVELOPMENT_PLAN.md`.
