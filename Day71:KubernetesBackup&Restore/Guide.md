# 📖 GUIDEME: Backup & Restore - Day 71

## 🎯 Complete Walkthrough (4-6 hours)

Hands-on etcd backup, restore, and disaster recovery.

---

## Phase 1: Manual etcd Backup (30 min)

### Locate etcd

```bash
# Check if etcd is running
kubectl get pods -n kube-system | grep etcd

# Get etcd pod name
ETCD_POD=$(kubectl get pods -n kube-system -l component=etcd -o jsonpath='{.items[0].metadata.name}')

# Check etcd version
kubectl exec -n kube-system $ETCD_POD -- etcd --version
```

### Create Backup

```bash
# SSH to control plane node
ssh control-plane

# Create backup directory
sudo mkdir -p /var/backups/etcd

# Create snapshot
sudo ETCDCTL_API=3 etcdctl snapshot save /var/backups/etcd/etcd-snapshot-$(date +%Y%m%d-%H%M%S).db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# Verify backup
sudo ETCDCTL_API=3 etcdctl snapshot status /var/backups/etcd/etcd-snapshot-*.db \
  --write-out=table
```

### Test Data Before Restore

```bash
# Create test namespace
kubectl create namespace backup-test

# Create test deployment
kubectl create deployment nginx-test --image=nginx -n backup-test

# Create test configmap
kubectl create configmap test-config --from-literal=key=value -n backup-test

# Verify
kubectl get all -n backup-test
kubectl get configmap -n backup-test
```

**✅ Checkpoint:** Backup created and test data exists.

---

## Phase 2: Restore from Backup (1 hour)

### Prepare for Restore

```bash
# SSH to control plane
ssh control-plane

# Stop kube-apiserver
sudo mv /etc/kubernetes/manifests/kube-apiserver.yaml /tmp/

# Wait 30 seconds for API server to stop
sleep 30

# Verify API server stopped
kubectl get nodes
# Should fail with connection error
```

### Restore Snapshot

```bash
# Restore to new directory
sudo ETCDCTL_API=3 etcdctl snapshot restore /var/backups/etcd/etcd-snapshot-*.db \
  --data-dir=/var/lib/etcd-restore \
  --initial-cluster=control-plane=https://127.0.0.1:2380 \
  --initial-advertise-peer-urls=https://127.0.0.1:2380 \
  --name=control-plane

# Set permissions
sudo chown -R etcd:etcd /var/lib/etcd-restore
```

### Update etcd Configuration

```bash
# Backup original etcd manifest
sudo cp /etc/kubernetes/manifests/etcd.yaml /tmp/etcd.yaml.bak

# Edit etcd manifest
sudo vi /etc/kubernetes/manifests/etcd.yaml

# Change the hostPath in volumes section:
# volumes:
# - hostPath:
#     path: /var/lib/etcd-restore  # Changed from /var/lib/etcd
#     type: DirectoryOrCreate
#   name: etcd-data

# Save and exit
```

### Restart API Server

```bash
# Start API server
sudo mv /tmp/kube-apiserver.yaml /etc/kubernetes/manifests/

# Wait for pods to start
sleep 60

# Check etcd pod
kubectl get pods -n kube-system -l component=etcd

# Check API server
kubectl get pods -n kube-system -l component=kube-apiserver
```

### Verify Restore

```bash
# Check nodes
kubectl get nodes

# Check test namespace (should exist)
kubectl get namespaces

# Check test deployment
kubectl get all -n backup-test

# Check test configmap
kubectl get configmap -n backup-test test-config
```

**✅ Checkpoint:** Cluster restored successfully.

---

## Phase 3: Automated Backup Setup (1.5 hours)

### Create Backup Script

```bash
cat > /usr/local/bin/etcd-backup.sh <<'EOF'
#!/bin/bash
set -e

BACKUP_DIR="/var/backups/etcd"
DATE=$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="$BACKUP_DIR/etcd-$DATE.db"
RETENTION_DAYS=30

mkdir -p $BACKUP_DIR

echo "Creating etcd backup..."
ETCDCTL_API=3 etcdctl snapshot save $BACKUP_FILE \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

echo "Verifying backup..."
ETCDCTL_API=3 etcdctl snapshot status $BACKUP_FILE --write-out=table

echo "Cleaning old backups..."
find $BACKUP_DIR -name "etcd-*.db" -mtime +$RETENTION_DAYS -delete

echo "Backup completed: $BACKUP_FILE"
EOF

sudo chmod +x /usr/local/bin/etcd-backup.sh
```

### Test Backup Script

```bash
# Run script
sudo /usr/local/bin/etcd-backup.sh

# Verify backup created
ls -lh /var/backups/etcd/
```

### Schedule with Cron

```bash
# Add to crontab
sudo crontab -e

# Add this line (daily at 2 AM):
0 2 * * * /usr/local/bin/etcd-backup.sh >> /var/log/etcd-backup.log 2>&1

# Verify cron job
sudo crontab -l
```

**✅ Checkpoint:** Automated backups configured.

---

## Phase 4: Velero Setup (Optional, 2 hours)

### Install Velero CLI

```bash
# Download Velero
wget https://github.com/vmware-tanzu/velero/releases/download/v1.12.0/velero-v1.12.0-linux-amd64.tar.gz

# Extract
tar -xzf velero-v1.12.0-linux-amd64.tar.gz

# Install
sudo mv velero-v1.12.0-linux-amd64/velero /usr/local/bin/

# Verify
velero version --client-only
```

### Install Velero Server (Local Storage)

```bash
# Create credentials file
cat > /tmp/credentials-velero <<EOF
[default]
aws_access_key_id = minio
aws_secret_access_key = minio123
EOF

# Install Velero with MinIO (for testing)
velero install \
  --provider aws \
  --plugins velero/velero-plugin-for-aws:v1.8.0 \
  --bucket velero \
  --secret-file /tmp/credentials-velero \
  --use-volume-snapshots=false \
  --backup-location-config region=minio,s3ForcePathStyle="true",s3Url=http://minio.velero.svc:9000

# Verify installation
kubectl get pods -n velero
```

### Create Test Backup

```bash
# Create test application
kubectl create namespace velero-test
kubectl create deployment nginx --image=nginx -n velero-test
kubectl create configmap app-config --from-literal=key=value -n velero-test

# Create backup
velero backup create test-backup --include-namespaces velero-test

# Check backup
velero backup describe test-backup
velero backup get
```

### Test Restore

```bash
# Delete namespace
kubectl delete namespace velero-test

# Verify deleted
kubectl get namespace velero-test
# Should show "not found"

# Restore from backup
velero restore create --from-backup test-backup

# Verify restored
kubectl get all -n velero-test
kubectl get configmap -n velero-test
```

**✅ Checkpoint:** Velero backup/restore working.

---

## Phase 5: Disaster Recovery Testing (1 hour)

### Create DR Scenario

```bash
# Create production-like namespace
kubectl create namespace production

# Deploy application
kubectl create deployment app --image=nginx --replicas=3 -n production
kubectl expose deployment app --port=80 -n production

# Create data
kubectl create configmap app-config --from-literal=version=v1.0 -n production
kubectl create secret generic app-secret --from-literal=password=secret123 -n production

# Verify running
kubectl get all,configmap,secret -n production
```

### Perform Backup

```bash
# etcd backup
sudo /usr/local/bin/etcd-backup.sh

# Velero backup (if installed)
velero backup create production-backup --include-namespaces production

# Verify backups
ls -lh /var/backups/etcd/
velero backup get
```

### Simulate Disaster

```bash
# Delete production namespace
kubectl delete namespace production --force --grace-period=0

# Delete test namespace
kubectl delete namespace backup-test --force --grace-period=0

# Verify data lost
kubectl get namespace production
kubectl get namespace backup-test
```

### Execute Recovery

```bash
# Method 1: etcd restore (restores everything)
# [Follow Phase 2 restore steps]

# Method 2: Velero restore (restores specific namespace)
velero restore create prod-restore --from-backup production-backup

# Verify recovery
kubectl get all -n production
kubectl get configmap,secret -n production
```

**✅ Checkpoint:** Successfully recovered from disaster.

---

## ✅ Final Validation

### Backup Checklist
- [ ] etcd manual backup works
- [ ] etcd restore tested
- [ ] Automated backup script created
- [ ] Cron job scheduled
- [ ] Backup retention configured
- [ ] Velero installed (optional)
- [ ] DR test successful

### Test Commands

```bash
# Check latest backup age
ls -lht /var/backups/etcd/ | head -5

# Verify backup can be read
sudo ETCDCTL_API=3 etcdctl snapshot status $(ls -t /var/backups/etcd/etcd-*.db | head -1)

# Check cron job
sudo crontab -l | grep etcd

# Check Velero (if installed)
velero backup get
```

---

**Congratulations! You've mastered Kubernetes backup & restore! 💾🚀**
