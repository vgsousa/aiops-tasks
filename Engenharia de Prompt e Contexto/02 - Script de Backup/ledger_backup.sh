#!/usr/bin/env bash
set -euo pipefail

DB_HOST="ledger-db.internal.hvt.io"
DB_PORT="5432"
DB_NAME="ledger_prod"
DB_USER="backup_user"
S3_BUCKET="hvt-ledger-backups"
AWS_REGION="us-east-1"
BACKUP_DIR="/var/backups/ledger"
LOG_FILE="/var/log/ledger-backup.log"
RETENTION_DAYS=30
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="${BACKUP_DIR}/ledger_${TIMESTAMP}.dump.gz"
S3_KEY="ledger_${TIMESTAMP}.dump.gz"

log()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }
fail() { log "ERROR: $*"; exit 1; }

log "=== Backup started ==="

[[ -z "${PGPASSWORD:-}" ]] && fail "PGPASSWORD not set"

AVAIL_GB=$(df -BG "$BACKUP_DIR" | awk 'NR==2 {gsub("G",""); print $4}')
[[ "$AVAIL_GB" -lt 15 ]] && fail "Insufficient disk: ${AVAIL_GB} GB available, 15 GB required"

log "Dumping database..."
if ! pg_dump \
      --host="$DB_HOST" \
      --port="$DB_PORT" \
      --username="$DB_USER" \
      --no-password \
      "$DB_NAME" \
    | gzip > "$BACKUP_FILE"; then
  rm -f "$BACKUP_FILE"
  fail "pg_dump failed"
fi

log "Backup size: $(du -sh "$BACKUP_FILE" | cut -f1)"

log "Uploading to S3..."
if ! aws s3 cp "$BACKUP_FILE" "s3://${S3_BUCKET}/${S3_KEY}" --region "$AWS_REGION"; then
  rm -f "$BACKUP_FILE"
  fail "S3 upload failed"
fi

rm -f "$BACKUP_FILE"
log "Upload complete"

log "Enforcing 30-day retention..."
CUTOFF=$(date -d "30 days ago" --utc +"%Y-%m-%dT%H:%M:%SZ")
DELETED=0

aws s3api list-objects-v2 \
  --bucket "$S3_BUCKET" \
  --query "Contents[?LastModified<='${CUTOFF}'].Key" \
  --region "$AWS_REGION" \
  --output text 2>/dev/null \
  | while read -r key; do
    [[ -z "$key" ]] && continue
    aws s3 rm "s3://${S3_BUCKET}/${key}" --region "$AWS_REGION" && ((DELETED++)) || true
  done

log "Retention cleanup done"
log "=== Backup completed successfully ==="
