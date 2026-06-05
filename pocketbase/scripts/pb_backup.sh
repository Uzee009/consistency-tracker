#!/bin/bash
set -e

# Targets PocketBase v0.23+ (superusers auth endpoint)

# Configuration
PB_URL="${PB_URL:-http://127.0.0.1:8090}"
# These should be set in the environment or a .env file (loaded via systemd)
# PB_ADMIN_EMAIL
# PB_ADMIN_PASSWORD
# GCS_BUCKET

BACKUP_NAME="pb-$(date +%Y-%m-%d).zip"
TEMP_FILE="/tmp/${BACKUP_NAME}"

if [ -z "$PB_ADMIN_EMAIL" ] || [ -z "$PB_ADMIN_PASSWORD" ] || [ -z "$GCS_BUCKET" ]; then
    echo "Error: PB_ADMIN_EMAIL, PB_ADMIN_PASSWORD, and GCS_BUCKET must be set."
    exit 1
fi

echo "Authenticating as admin..."
AUTH_RES=$(curl -s -X POST "${PB_URL}/api/collections/_superusers/auth-with-password" \
    -H "Content-Type: application/json" \
    -d "{\"identity\":\"${PB_ADMIN_EMAIL}\",\"password\":\"${PB_ADMIN_PASSWORD}\"}")

TOKEN=$(echo "$AUTH_RES" | grep -o '"token":"[^"]*' | cut -d'"' -f4)

if [ -z "$TOKEN" ]; then
    echo "Error: Failed to authenticate. Response: $AUTH_RES"
    exit 1
fi

echo "Triggering backup: ${BACKUP_NAME}..."
# Note: This call is synchronous in PocketBase; it returns when the zip is ready.
curl -s -X POST "${PB_URL}/api/backups" \
    -H "Authorization: ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"name\":\"${BACKUP_NAME}\"}"

echo "Downloading backup..."
FILE_TOKEN=$(curl -s -X POST -H "Authorization: ${TOKEN}" "${PB_URL}/api/files/token" | grep -o '"token":"[^"]*' | cut -d'"' -f4)
curl -s -L -o "${TEMP_FILE}" "${PB_URL}/api/backups/${BACKUP_NAME}?token=${FILE_TOKEN}"

if [ ! -s "${TEMP_FILE}" ] || ! head -c2 "${TEMP_FILE}" | grep -q 'PK'; then
    echo "Error: downloaded backup is missing or not a zip file"
    exit 1
fi

echo "Uploading to GCS: gs://${GCS_BUCKET}/${BACKUP_NAME}..."
gcloud storage cp "${TEMP_FILE}" "gs://${GCS_BUCKET}/${BACKUP_NAME}"

echo "Cleaning up local temp file..."
rm "${TEMP_FILE}"

# Delete from PB internal storage to keep pb_data small
echo "Deleting backup from PB internal storage..."
curl -s -X DELETE "${PB_URL}/api/backups/${BACKUP_NAME}" \
    -H "Authorization: ${TOKEN}"

echo "Backup complete: ${BACKUP_NAME}"
