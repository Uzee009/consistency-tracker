# Deployment Guide — Consistency Tracker Sync Server

PocketBase (single Go binary) on an Oracle Cloud Always Free VM, TLS via DuckDNS + Let's Encrypt. The server starts **empty** (no data migration).

## Decisions (locked 2026-05-27)
- Host: Oracle Cloud **Always Free**, **Ampere A1 (ARM / aarch64)**, Ubuntu 22.04/24.04.
- TLS: free **DuckDNS** subdomain + PocketBase built-in **Let's Encrypt**.
- Data: server starts **fresh/empty** — existing local history is NOT migrated up (`dirty` defaults to 0, so old rows won't auto-push; acceptable given start-fresh).
- PocketBase version: **v0.38.2** (matches the local dev server + migrations).

---

## Part 1 — Provision the VM (manual)

### 1.1 Instance
- Oracle Console → Compute → Create instance.
- Shape: **Ampere A1 (ARM)**, 1 OCPU / 6 GB is plenty (Always Free allows up to 4 OCPU / 24 GB).
- Image: **Ubuntu 22.04 or 24.04 (aarch64)**.
- Save the SSH private key. Confirm: `ssh ubuntu@<public-ip>`.

### 1.2 Reserve a static public IP
- Convert the instance's ephemeral public IP to **reserved**, so DuckDNS doesn't break on stop/start.

### 1.3 Firewall — TWO layers (classic Oracle trap)
**Layer 1 — Oracle VCN security list / NSG:** add ingress rules allowing **TCP 80** and **TCP 443** from `0.0.0.0/0` (keep 22 for SSH).

**Layer 2 — in-VM iptables:** Oracle's Ubuntu images DROP inbound by default; the security list alone is NOT enough. On the VM:
```
sudo iptables -L INPUT --line-numbers        # find the REJECT line number
sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 80 -j ACCEPT
sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 443 -j ACCEPT
sudo netfilter-persistent save
```
The rules must be inserted ABOVE the `REJECT --reject-with icmp-host-prohibited` line (position 6 is typical, but verify with the `-L` output and adjust).

### 1.4 DuckDNS
- Create a subdomain at https://www.duckdns.org (e.g. `yourname.duckdns.org`).
- Set its IP to the **reserved public IP**. (Static IP → no updater daemon needed.)
- Port 80 must be publicly reachable — Let's Encrypt's ACME challenge uses it.

---

## Part 2 — Install PocketBase (on the VM)

### 2.1 Fetch the arm64 binary
```
cd ~ && mkdir -p ~/pb && cd ~/pb
sudo apt-get update && sudo apt-get install -y unzip
PB=0.38.2
curl -L -o pb.zip https://github.com/pocketbase/pocketbase/releases/download/v${PB}/pocketbase_${PB}_linux_arm64.zip
unzip -o pb.zip && rm pb.zip
./pocketbase --version
```

### 2.2 Bring the migrations
Copy the repo's `pocketbase/pb_migrations/` directory onto the VM into `~/pb/pb_migrations/` (e.g. via `scp -r`). PocketBase auto-applies migrations on serve.

### 2.3 First run (foreground, to issue the cert)
```
cd ~/pb
sudo ./pocketbase serve --http=0.0.0.0:80 --https=0.0.0.0:443
```
PocketBase auto-provisions a Let's Encrypt cert for the domain in incoming HTTPS requests (so DuckDNS must already resolve to this IP). Then open `https://yourname.duckdns.org/_/` to confirm.
NOTE: verify the exact flags for your installed version with `./pocketbase serve --help` — depending on version you may instead pass the domain directly: `sudo ./pocketbase serve yourname.duckdns.org` (binds 80+443, auto-TLS, redirects 80→443).

### 2.4 Run as a systemd service
Create `/etc/systemd/system/pocketbase.service`:
```
[Unit]
Description=PocketBase
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/home/ubuntu/pb
ExecStart=/home/ubuntu/pb/pocketbase serve --http=0.0.0.0:80 --https=0.0.0.0:443
Restart=always
RestartSec=5
LimitNOFILE=4096

[Install]
WantedBy=multi-user.target
```
Then:
```
sudo systemctl daemon-reload
sudo systemctl enable --now pocketbase
sudo systemctl status pocketbase
journalctl -u pocketbase -f      # live logs
```
(Runs as root to bind ports <1024. Alternative: run as `ubuntu` with `AmbientCapabilities=CAP_NET_BIND_SERVICE`.)

### 2.5 Create accounts
- Visit `https://yourname.duckdns.org/_/` → create the **superuser** (first run).
- In the admin UI, create a regular **user record** = the app login account (email + password you chose).

### 2.6 Backups
- Easiest: PocketBase admin → **Settings → Backups** → enable a scheduled (cron) backup and set retention.
- Optionally download backups off-box periodically.

---

## Part 3 — Point the app at the server (code change — do when host is known)
In `lib/services/pocketbase_service.dart`:
- Lines ~14 and ~32: change default `_serverUrl` from `http://127.0.0.1:8090` to `https://yourname.duckdns.org`.
- In `setServerUrl()`: clear the per-device pull cursors (`sync_state` table) so a device that switches servers does a clean FULL pull (prevents stale-cursor skip).
Then on each device: sign in via Settings → Sync Account.
Workflow: code change → code-reviewer → `flutter analyze` clean → commit (only when approved).

---

## Part 4 — Verify (two devices, live server)
- Device A: `flutter run -d linux --dart-define=DATABASE_NAME=consistency_tracker_dev.db`
- Device B: `flutter run -d linux --dart-define=DATABASE_NAME=consistency_tracker_dev2.db`
- Confirm: create/tick/delete converges (~1-2s online); offline→reconnect flushes; app restart persists; no zombie/duplicate tasks.
- Tombstone pruning runs once/day (to test sooner, temporarily lower the retention windows in `sync_service.dart`).

---

## Reference — current sync behavior (already implemented)
- **Conflict resolution:** Last-Write-Wins on client-set `updated_at` (epoch ms).
- **Tombstone pruning:** local prune `deleted=1 AND dirty=0 AND >30d`; server prune `deleted=true AND >90d` (owner-scoped, batched, 404-ignored), guarded once/day via `sync_state['__last_prune__']`. Caveat: a device offline >90d that saw a create-but-not-delete may resurrect that row on next edit.
- **Retry/backoff:** exponential 2s→cap 60s; transient (network / 5xx / 429) retried, permanent (other 4xx) not; manual "Sync Now" never arms a retry.
- **Dev gating:** seed + dev auto-login are compile-time gated on `String.fromEnvironment('DATABASE_NAME')`; a release build (no `--dart-define`) no-ops both.
