# Cross-Device Sync — Implementation Plan

**Status:** Experimental / proposed
**Date:** 2026-05-25
**Supersedes:** Step 13 ("Shielded-USN Synchronization System") of `DEVELOPMENT_PLAN.md`.

This document is the agreed plan for making the Consistency Tracker sync across
devices. It replaces the earlier USN-based proposal, which was dropped for being
too complex and error-prone.

---

## 1. Goal & Constraints

**Goal:** Tick a task on one device, see it on the others in ~1–2s while online.
Work fully offline; reconcile automatically on reconnect. Never lose data.

**Hard constraints:**
- Free — no hosting budget.
- Cross-platform: Linux, Windows, macOS, Android (Linux is "always online").
- Offline writes must be preserved and synced later.
- Open source friendly (optional self-host later, not a v1 feature).
- Solo developer — minimise complexity and moving parts.

**Honest definition of "realtime":** 1–2s propagation when both devices are
online. Not sub-100ms collaborative editing — that is unnecessary here.

---

## 2. Architecture Decision

**Chosen:** Local-first SQLite (full mirror) + a dumb central server (PocketBase)
+ a small hand-rolled sync loop. The client is **pure Dart (HTTP + SSE)** so the
exact same code runs on all four platforms.

**Rejected and why:**
- **Firebase Firestore** — its SDK would handle sync for us, but it has **no Linux
  support** and weak desktop offline support. Linux is a first-class device, so
  this is out.
- **Self-hosting as a v1 feature** — dropped to reduce scope. The server is still
  self-hostable later (PocketBase is a single binary), just not a shipped feature now.
- **Anki-style USN protocol** (Gemini's Step 13) — over-engineered. We keep only
  its unavoidable skeleton (UUIDs, tombstones, timestamps, LWW, push/pull) and
  delete the parts that caused the pain:
  - ❌ `usn` Update Sequence Numbers + "Finalize" handshake → replaced by a plain
    `updated_at` timestamp cursor.
  - ❌ `session_id` idempotency tokens → upsert-by-`sid` + LWW is naturally idempotent.
  - ❌ `sync_meta` global state table + Dart "state machine" → it's just one function.
  - ❌ Zero-knowledge crypto (Argon2id / AES-GCM / 24-word mnemonic) → deferred to
    optional v2; HTTPS + auth is enough for v1.
  - ❌ ">90-day zombie reconciliation" + WAL-for-sync → non-problems with
    tombstones + a timestamp cursor.

**Why it works on every OS:** no native platform SDK. It's `package:http` + SSE,
identical on Linux/Windows/macOS/Android.

---

## 3. Data Model Changes (Phase 0 — local only, no network)

These fix two latent bugs that would break *any* sync design, and are testable
entirely offline with zero user-visible change.

### 3.1 Task identity → UUID/ULID strings
Auto-increment `INTEGER PRIMARY KEY` collides across devices (two devices both
create `id=6`). Switch the sync identity to a client-generated `sid TEXT` (UUID).

### 3.2 Normalise day completions
Today `day_records.completed_task_ids` is a comma-joined string (`"3,5,7"`). Row-level
LWW on this loses concurrent ticks. Split into:

- **`task_status`** — one row per completion/skip:
  `(date TEXT, task_sid TEXT, status TEXT,  -- 'completed' | 'skipped'
    updated_at INTEGER, deleted INTEGER, dirty INTEGER, PRIMARY KEY(date, task_sid))`
  → ticking *different* tasks on two devices = different rows = **no conflict**.
  → ticking the *same* (date, task) = LWW by `updated_at` = correct answer.

- **`day_meta`** — single-value per-day state:
  `(date TEXT PRIMARY KEY, cheat_used INTEGER, pomodoro_sessions INTEGER,
    pomodoro_goal INTEGER, updated_at INTEGER, deleted INTEGER, dirty INTEGER)`

### 3.3 Derived, not synced
`completion_score` and `visual_state` are recomputed locally from `task_status`
via `ScoringService`. `monthly_usage` is derived by counting `cheat_used` per
month. None of these sync — they can't conflict.

### 3.4 Sync columns on every synced table
`updated_at` (epoch ms, **client-set**), `deleted` (tombstone — never hard-delete),
`dirty` (locally changed, needs push). Applies to `tasks`, `task_status`, `day_meta`.

---

## 4. Backend — PocketBase

- Single Go binary, SQLite backend, built-in auth + realtime (SSE), admin UI.
- Collections mirror the local tables: `tasks`, `task_status`, `day_meta`.
- **Auth:** one PocketBase account; all your devices log in with it. Every synced
  row belongs to that user (add an `owner` field for multi-user later).
- Run the binary locally during development before deploying anywhere.

---

## 5. Sync Engine (~300 lines, one file)

```
sync():
  if offline: return
  for each collection in [tasks, task_status, day_meta]:
    # PUSH
    for row in localRows(where dirty = 1):
        server.upsert(collection, row keyed by sid)
        row.dirty = 0
    # PULL
    cursor = prefs.lastCursor[collection]
    for r in server.list(collection, filter "updated > cursor", sort "updated"):
        local = localGet(r.sid)
        if local == null or r.updated_at > local.updated_at:   # LWW
            localUpsert(r)        # deleted = 1 → hide row
        cursor = max(cursor, r.updated)
    prefs.lastCursor[collection] = cursor
  recomputeDerived()   # score + visual_state from task_status
```

- **LWW** resolves on the **client-set `updated_at`** (so a stale offline edit can't
  clobber a newer online one). PocketBase's server `updated` is used only as the
  pull cursor.
- Retries are naturally idempotent (re-pushing the same row is a no-op).

---

## 6. Realtime + Offline Behaviour

**Triggers for sync:**
- On any local write → set `dirty`, debounce ~500ms, run `sync()`.
- Subscribe to PocketBase realtime (SSE) → on a remote event, run a pull.
- On app focus/resume and a 60s safety poll → pull.
- Connectivity listener → on reconnect, flush queued `dirty` rows.

**Offline:** writes just set `dirty`; `sync()` early-returns. App stays fully
usable (reads are always local). Flushes on reconnect.

---

## 7. Hosting (free)

- **Oracle Cloud Always Free** ARM VM (free forever, never pauses) — preferred.
- Or **PocketHost** (managed free PocketBase).
- TLS via PocketBase built-in / Caddy. App stores the server URL in settings.

---

## 8. Build Order (each phase shippable)

- **Phase 0 — Local refactor (no network).** UUID `sid`, `task_status` + `day_meta`
  split, derive score/visual_state, add sync columns. No user-visible change.
- **Phase 1 — PocketBase up + auth.** Run binary locally, create collections, add
  login screen + connectivity service.
- **Phase 2 — Manual sync.** "Sync now" button running push/pull. Prove correctness
  on two devices.
- **Phase 3 — Automatic + realtime.** dirty-on-write + SSE subscribe + focus/poll.
- **Phase 4 — Deploy + harden.** Deploy to free VM, point app at it, retry/backoff,
  tombstone cleanup, multi-device soak test. Optional: E2E encryption.

---

## 9. Known Caveats (being honest)

- **Clock skew** between devices can mis-order LWW for genuinely concurrent edits
  to the *same* field. Rare for a single user; acceptable for v1. Upgrade to a
  hybrid logical clock only if it ever bites.
- **First-write conflict** on the very first sync of two pre-existing local DBs
  needs a one-time reconciliation pass (match by `sid`; for legacy int-id data,
  match `tasks` by name).
- **Heatmap needs all data local** — confirms full local mirror over partial caching.

---

## 10. Experiment Test Plan

1. Phase 0 refactor; verify the app runs identically offline (existing data intact).
2. Run PocketBase locally; create collections; log in.
3. Manual "Sync now" between two local app instances (e.g. two dev DBs):
   - Tick different tasks on each → both appear on both. (no data loss)
   - Tick the same task on both → newer `updated_at` wins.
   - Delete a task on one → tombstone hides it on the other.
   - Edit offline on both, then reconnect → LWW resolves predictably.
4. Enable realtime; confirm ~1–2s propagation.
