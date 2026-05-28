# CURRENT_MODULE.md

**Module:** Step 14 — In-App Updates & Auto-Release
**Branch:** feature/sync-engine
**State:** COMPLETE
**Current Phase:** Part B — Client updater
**Last updated:** 2026-05-28

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

Step 14 self-update complete; shipping v1.3.0 to master with in-app Download & Restart (GitHub artifact download, SHA-256 verification, per-OS atomic install swap), versioned release filenames, and three verified bug fixes (pubspec injection, commit-subject-only token parsing, ConnectivityService gate removal).

---

## Next Action

Monitor v1.3.0 CI; future work as needed. (Step 14 module complete.)

---

## Review History

(empty — Part A review cycle not yet started)
2026-05-28 — Part A code-reviewer: FAIL→PASS. Cycle 1 fixed: CRITICAL shell-injection (commit msg moved to env var), MAJOR empty --build-name guard, MAJOR tag-push now uses github.ref_name, MINOR idempotent gh release create. Verified by orchestrator.
