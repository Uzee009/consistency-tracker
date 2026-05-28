# CURRENT_MODULE.md

**Module:** Step 14 — In-App Updates & Auto-Release
**Branch:** feature/sync-engine
**State:** COMPLETE
**Current Phase:** Part B — Client updater
**Last updated:** 2026-05-29

---

## Goal

The app notifies users when a newer stable release exists and offers a one-click download. CI auto-bumps the version and cuts a real vX.Y.Z GitHub release on every push to master so the app has a clean semver channel to track. 

Note: Prior module (Step 13 sync, Phase 4 deploy) was archived to `.archive/CURRENT_MODULE_2026-05-28_step13-sync.md` and can be resumed from there.

---

## Phases & Sub-tasks

**Previously completed modules (Steps 13-14 Parts A–B) archived in `.archive/`. See CURRENT_MODULE_* files for history.**

---

## Step 14 cont. — True Self-Update (Update & Restart)

- Part A — versioned release filenames [DONE]
- Part B — in-app download+apply+relaunch (deps archive/crypto; UpdateService.downloadAndApply; Linux/macOS/Windows apply; main.dart cleanup; banner + settings UI) [DONE]

---

## Working Context

Step 14 self-update shipped (v1.3.0). Most recent work was an out-of-band incident fix (2026-05-28/29): the live PocketBase server was missing its three sync collections (`404 Missing collection context`) because `pb_migrations/` was never deployed next to the binary on the GCP VM (`/home/uzeeslive/pb/`, user `uzeeslive` — NOT the Oracle host the old guide described). Fixed server-side via curl-from-repo + restart; sync verified live. Two UNCOMMITTED changes remain on `feature/sync-engine`: friendly sync-error messages in `lib/services/sync_service.dart` and GCP corrections in `deploy/DEPLOYMENT_GUIDE.md` (both reviewed/analyze-clean).

---

## Next Action

(1) Commit the two uncommitted changes if/when the user approves. (2) User to enable PocketBase backups (Admin UI → Settings → Backups) — server currently has no backup protection. (3) BUG TO FIX NEXT SESSION: the app re-syncs every few seconds even when nothing changed (wasteful). Hypothesis (unconfirmed): the realtime subscription in `lib/services/sync_service.dart` re-triggers `sync()` on the server's own writes, and/or the 60s poll + debounce keep firing; investigate skipping sync when no local rows are dirty and there is no genuine remote change. Step 14 module remains COMPLETE.

---

## Review History

(empty — Part A review cycle not yet started)
2026-05-28 — Part A code-reviewer: FAIL→PASS. Cycle 1 fixed: CRITICAL shell-injection (commit msg moved to env var), MAJOR empty --build-name guard, MAJOR tag-push now uses github.ref_name, MINOR idempotent gh release create. Verified by orchestrator.
