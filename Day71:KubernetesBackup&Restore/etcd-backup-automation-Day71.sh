#!/bin/bash
# etcd-backup-automation-Day71.sh
# Automated etcd backup script with S3 upload and monitoring

set -e

# Configuration
BACKUP_DIR="/var/backups/etcd"
DATE=$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="$BACKUP_DIR/etcd-$DATE.db"
RETENTION_DAYS=30
S3_BUCKET="s3://my-k8s-backups/etcd"
SLACK_WEBHOOK=""  # Optional: Add Slack webhook for notifications

# etcd connection details
ETCD_ENDPOINTS="https://127.0.0.1:2379"
ETCD_CACERT="/etc/kubernetes/pki/etcd/ca.crt"
ETCD_CERT="/etc/kubernetes/pki/etcd/server.crt"
ETCD_KEY="/etc/kubernetes/pki/etcd/server.key"

# Functions
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

notify_slack() {
    if [ -n "$SLACK_WEBHOOK" ]; then
        curl -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"$1\"}" "$SLACK_WEBHOOK" || true
    fi
}

# Create backup directory
mkdir -p $BACKUP_DIR

log "Starting etcd backup..."

# Create snapshot
if ETCDCTL_API=3 etcdctl snapshot save $BACKUP_FILE \
    --endpoints=$ETCD_ENDPOINTS \
    --cacert=$ETCD_CACERT \
    --cert=$ETCD_CERT \
    --key=$ETCD_KEY; then
    
    log "Snapshot created successfully"
    
    # Verify backup
    if ETCDCTL_API=3 etcdctl snapshot status $BACKUP_FILE --write-out=table; then
        log "Backup verified"
        
        # Get backup size
        BACKUP_SIZE=$(du -h $BACKUP_FILE | cut -f1)
        log "Backup size: $BACKUP_SIZE"
        
        # Upload to S3 (if AWS CLI available)
        if command -v aws &> /dev/null; then
            log "Uploading to S3..."
            if aws s3 cp $BACKUP_FILE $S3_BUCKET/; then
                log "Successfully uploaded to S3"
                notify_slack "✅ etcd backup successful: $BACKUP_FILE ($BACKUP_SIZE)"
            else
                log "ERROR: Failed to upload to S3"
                notify_slack "⚠️ etcd backup created but S3 upload failed"
            fi
        fi
        
        # Clean old backups
        log "Cleaning old backups (older than $RETENTION_DAYS days)..."
        DELETED=$(find $BACKUP_DIR -name "etcd-*.db" -mtime +$RETENTION_DAYS -delete -print | wc -l)
        log "Deleted $DELETED old backup(s)"
        
        # Success
        log "Backup completed successfully: $BACKUP_FILE"
        exit 0
    else
        log "ERROR: Backup verification failed"
        notify_slack "❌ etcd backup verification failed"
        exit 1
    fi
else
    log "ERROR: Snapshot creation failed"
    notify_slack "❌ etcd snapshot creation failed"
    exit 1
fi
