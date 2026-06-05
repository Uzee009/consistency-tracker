# PocketBase Backup Runbook

## 1. Setup GCS Bucket
Create a bucket in GCP and apply the 14-day lifecycle rule:
```bash
# Replace <bucket-name> with your desired bucket name
gsutil mb gs://<bucket-name>
gsutil lifecycle set lifecycle.json gs://<bucket-name>
```

## 2. Deploy Scripts to Server
Upload the scripts to the server. Note: the `pb-backup.service` assumes they live in `/home/uzeeslive/pb/scripts/`.

```bash
# From local repo root
gcloud compute scp pocketbase/scripts/* uzeeslive@<instance-name>:/home/uzeeslive/pb/scripts/
```

## 3. Configure Credentials
On the server, create `/home/uzeeslive/pb/scripts/.env` with your PB admin credentials and bucket name:
```bash
PB_ADMIN_EMAIL="admin@example.com"
PB_ADMIN_PASSWORD="secure-password"
GCS_BUCKET="your-bucket-name"
```
Restrict permissions to the `.env` file:
```bash
chmod 600 /home/uzeeslive/pb/scripts/.env
```

## 4. Install Systemd Units
On the server, copy units to `/etc/systemd/system/` and enable the timer:
```bash
sudo cp /home/uzeeslive/pb/scripts/pb-backup.service /etc/systemd/system/
sudo cp /home/uzeeslive/pb/scripts/pb-backup.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now pb-backup.timer
```

## 5. Verification
Check timer status:
```bash
systemctl status pb-backup.timer
```
Trigger a manual backup to verify it works:
```bash
sudo systemctl start pb-backup.service
# Watch logs
journalctl -u pb-backup.service -f
```
Verify the file lands in GCS:
```bash
gsutil ls gs://<bucket-name>/
```

## 6. Restore Procedure
1. Identify the backup to restore and download it:
   ```bash
   gsutil cp gs://<bucket-name>/pb-YYYY-MM-DD.zip .
   ```
2. **Stop PocketBase** service.
3. Move current `pb_data` out of the way:
   ```bash
   mv pb_data pb_data_pre_restore_bak
   ```
4. Restore from zip:
   ```bash
   unzip pb-YYYY-MM-DD.zip -d pb_data
   ```
5. **Start PocketBase** and verify data.
