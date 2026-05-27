# CURRENT_MODULE.md

**Module:** Step 14 — In-App Updates & Auto-Release
**Branch:** feature/sync-engine
**State:** IN_PROGRESS
**Current Phase:** Part B — Client updater
**Last updated:** 2026-05-28

---

## Goal

The app notifies users when a newer stable release exists and offers a one-click download. CI auto-bumps the version and cuts a real vX.Y.Z GitHub release on every push to master so the app has a clean semver channel to track. 

Note: Prior module (Step 13 sync, Phase 4 deploy) was archived to `.archive/CURRENT_MODULE_2026-05-28_step13-sync.md` and can be resumed from there.

---

## Phases & Sub-tasks

- **Part A — CI:** [DONE]
  - A1 version job (compute next semver tag, handle #major/#minor/[skip release] directives)
  - A2 build_name threading (wire version into flutter build via --build-name)
  - A3 auto-tagged release (replace rolling prerelease with stable vX.Y.Z releases)

- **Part B — Client updater:** [DONE]
  - Dependencies (package_info_plus, url_launcher, http) [DONE]
  - update_service.dart (singleton with checkForUpdate, semver comparison, GitHub API polling) [DONE]
  - Settings UPDATES section (current version, update status, check button, download button) [DONE]
  - Startup hook (main.dart check on init) [DONE]
  - Home banner (show update notification when available) [DONE]

---

## Working Context

The UI wiring for in-app updates is now complete. The client handles background update checks on startup and lifecycle resume, provides a dismissible notification banner on the home screen, and includes a dedicated management section in Settings.

---

## Next Action

Finalize code-review of the update integration and proceed with local verification of the end-to-end update flow.

---

## Review History

(empty — Part A review cycle not yet started)
2026-05-28 — Part A code-reviewer: FAIL→PASS. Cycle 1 fixed: CRITICAL shell-injection (commit msg moved to env var), MAJOR empty --build-name guard, MAJOR tag-push now uses github.ref_name, MINOR idempotent gh release create. Verified by orchestrator.