**Module:** Step 18 — PocketBase Infra Debt (sort_order field + GCS daily backups)
**Branch:** feature/pb-infra-debt
**State:** IN_PROGRESS
**Last updated:** 2026-06-05

## Working Context

Tackling two pieces of infra debt in one module. (A) The client already writes `sort_order` locally (DB schema v10, addTask + reorderTasks) and bumps dirty=1, but the PB `tasks` collection has no `sort_order` field, so manual ordering doesn't sync across devices. (B) The PB server on GCP (`/home/uzeeslive/pb`) has no backups. Plan: GCS bucket, PB built-in /api/backups endpoint, daily systemd timer, 14-day retention via GCS lifecycle rule. User runs deploy commands via gcloud/ssh; orchestrator gives short paste-safe commands (SSH terminal mangles long pastes — see memory).

## Sub-tasks

### A. sort_order field
- [x] A1. Write `pocketbase/pb_migrations/<ts>_add_sort_order.js` — adds `sort_order` (number, optional) to `tasks` collection only; mirrors `1780300000_add_device_id.js` pattern; includes reverse migration.
- [x] A2. Edit `lib/services/sync_service.dart` — add `'sort_order'` to the `tasks` `_Col.intCols` list so the sync push payload includes the field. Model toMap/fromMap already handle it.
- [x] A3. `flutter analyze` clean.
- [ ] A4. Deploy: scp migration to GCP, restart pb, verify field exists.

### B. GCS daily backups
- [x] B1. Write `pocketbase/scripts/pb_backup.sh` — POSTs to PB admin `/api/backups` to create a consistent zip, downloads it, `gsutil cp` to `gs://<bucket>/pb-YYYY-MM-DD.zip`. No pruning logic in script.
- [x] B2. Write `pocketbase/scripts/pb-backup.service` + `pocketbase/scripts/pb-backup.timer` — systemd unit + daily timer (03:00 UTC).
- [x] B3. Write `pocketbase/scripts/lifecycle.json` — 14-day GCS lifecycle delete rule.
- [x] B4. Write `pocketbase/scripts/README.md` — runbook: bucket create, lifecycle apply, systemd install, manual test, RESTORE procedure.
- [ ] B5. Deploy: user runs gcloud + scp + systemctl commands; verify timer active and a manual test backup lands in GCS.

### C. Release
- [ ] C1. Commit, merge to master with `#minor` token (sort_order is user-visible).
- [ ] C2. Close out: append Prj_Progress.md entry, mark Step 18 done in DEVELOPMENT_PLAN.md (or note it as 'Infra debt cleared'), archive CURRENT_MODULE.md.

## Next Action

A4/B5 — User deployment on GCP. See README.md in pocketbase/scripts for backup setup. For A4: scp migration and restart PB.

## Review History
(none)