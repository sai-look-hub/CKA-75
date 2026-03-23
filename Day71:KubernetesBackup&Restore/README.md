# Day 71: Kubernetes Backup & Restore

## 📋 Overview

Welcome to Day 71! Master Kubernetes backup and restore - learn etcd backup/restore, disaster recovery strategies, and build automated backup solutions. You'll be prepared to recover from any cluster failure.

### What You'll Learn

- etcd architecture and importance
- Manual etcd backup and restore
- Automated backup strategies
- Disaster recovery planning
- Velero for application backups
- Testing recovery procedures
- Production backup best practices

---

## 🎯 Learning Objectives

1. Understand etcd's role in Kubernetes
2. Perform manual etcd backup/restore
3. Automate backup processes
4. Implement disaster recovery plan
5. Backup application state with Velero
6. Test recovery procedures
7. Build production-ready backup solution

---

## 🗄️ Understanding etcd

### What is etcd?

**etcd** = Distributed key-value store that stores all Kubernetes cluster data.

**Stores:**
- All cluster state
- ConfigMaps, Secrets
- Service definitions
- Pod specs
- RBAC policies
- **Everything!**

**If etcd is lost → Entire cluster state is lost**

### etcd Architecture

```
┌─────────────────────────────────────┐
│         Kubernetes Cluster          │
├─────────────────────────────────────┤
│                                      │
│  kube-apiserver ←→ etcd             │
│                    │                 │
│                    ├─ Pods           │
│                    ├─ Services       │
│                    ├─ ConfigMaps     │
│                    ├─ Secrets        │
│                    ├─ Namespaces     │
│                    └─ Everything!    │
│                                      │
│  etcd = Single source of truth      │
└─────────────────────────────────────┘
```

### Why Backup etcd?

**Scenarios requiring restore:**
1. Hardware failure
2. Data corruption
3. Accidental deletion
4. Security breach
5. Cluster migration
6. Disaster recovery

**Without backup:** Cluster must be rebuilt from scratch.

---

## 💾 etcd Backup

### Backup Methods

**1. Snapshot (Recommended)**
- Fast
- Point-in-time backup
- Small file size
- Easy to restore

**2. Directory Copy**
- Copy entire data directory
- Larger backup
- Slower

### Manual Backup

```bash
ETCDCTL_API=3 etcdctl snapshot save /backup/etcd-snapshot.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
```

**Parameters explained:**
- `snapshot save` - Create snapshot
- `/backup/etcd-snapshot.db` - Output file
- `--endpoints` - etcd server address
- `--cacert` - CA certificate
- `--cert` - Client certificate
- `--key` - Client key

### Verify Backup

```bash
ETCDCTL_API=3 etcdctl snapshot status /backup/etcd-snapshot.db \
  --write-out=table

# Output:
# +----------+----------+------------+------------+
# |   HASH   | REVISION | TOTAL KEYS | TOTAL SIZE |
# +----------+----------+------------+------------+
# | 12345678 |   123456 |       1234 |     5.0 MB |
# +----------+----------+------------+------------+
```

---

## 🔄 etcd Restore

### Restore Process

**1. Stop API server:**
```bash
# Move manifest to stop API server
mv /etc/kubernetes/manifests/kube-apiserver.yaml /tmp/

# Wait for API server to stop
```

**2. Restore snapshot:**
```bash
ETCDCTL_API=3 etcdctl snapshot restore /backup/etcd-snapshot.db \
  --data-dir=/var/lib/etcd-restore \
  --initial-cluster=master=https://127.0.0.1:2380 \
  --initial-advertise-peer-urls=https://127.0.0.1:2380
```

**3. Update etcd manifest:**
```bash
# Edit /etc/kubernetes/manifests/etcd.yaml
# Change data directory:
# volumes:
# - name: etcd-data
#   hostPath:
#     path: /var/lib/etcd-restore  # Changed from /var/lib/etcd
```

**4. Restart API server:**
```bash
mv /tmp/kube-apiserver.yaml /etc/kubernetes/manifests/
```

**5. Verify:**
```bash
kubectl get nodes
kubectl get pods -A
```

---

## 🤖 Automated Backup

### Backup Automation Strategy

**Requirements:**
- Daily backups (minimum)
- Off-cluster storage
- Retention policy (30 days)
- Monitoring/alerts
- Tested restore

### CronJob Backup Script

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: etcd-backup
  namespace: kube-system
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          hostNetwork: true
          containers:
          - name: backup
            image: registry.k8s.io/etcd:3.5.9-0
            command:
            - /bin/sh
            - -c
            - |
              BACKUP_FILE=/backup/etcd-$(date +%Y%m%d-%H%M%S).db
              etcdctl snapshot save $BACKUP_FILE \
                --endpoints=https://127.0.0.1:2379 \
                --cacert=/etc/kubernetes/pki/etcd/ca.crt \
                --cert=/etc/kubernetes/pki/etcd/server.crt \
                --key=/etc/kubernetes/pki/etcd/server.key
              
              # Upload to S3 (optional)
              aws s3 cp $BACKUP_FILE s3://my-bucket/etcd-backups/
              
              # Clean old backups (keep 30 days)
              find /backup -name "etcd-*.db" -mtime +30 -delete
            volumeMounts:
            - name: etcd-certs
              mountPath: /etc/kubernetes/pki/etcd
            - name: backup
              mountPath: /backup
          volumes:
          - name: etcd-certs
            hostPath:
              path: /etc/kubernetes/pki/etcd
          - name: backup
            hostPath:
              path: /var/backups/etcd
          restartPolicy: OnFailure
```

### Bash Backup Script

```bash
#!/bin/bash
# etcd-backup.sh

set -e

BACKUP_DIR="/var/backups/etcd"
DATE=$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="$BACKUP_DIR/etcd-$DATE.db"
RETENTION_DAYS=30

# Create backup directory
mkdir -p $BACKUP_DIR

# Create snapshot
ETCDCTL_API=3 etcdctl snapshot save $BACKUP_FILE \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# Verify backup
ETCDCTL_API=3 etcdctl snapshot status $BACKUP_FILE

# Upload to S3 (optional)
if command -v aws &> /dev/null; then
  aws s3 cp $BACKUP_FILE s3://my-bucket/etcd-backups/
fi

# Clean old backups
find $BACKUP_DIR -name "etcd-*.db" -mtime +$RETENTION_DAYS -delete

echo "Backup completed: $BACKUP_FILE"
```

---

## 📦 Application Backup with Velero

### What is Velero?

**Velero** = Backup and restore Kubernetes resources and persistent volumes.

**Features:**
- Backup namespaces, resources
- Backup persistent volumes
- Schedule automatic backups
- Disaster recovery
- Cluster migration

### Install Velero

```bash
# Download Velero
wget https://github.com/vmware-tanzu/velero/releases/download/v1.12.0/velero-v1.12.0-linux-amd64.tar.gz
tar -xzf velero-v1.12.0-linux-amd64.tar.gz
sudo mv velero-v1.12.0-linux-amd64/velero /usr/local/bin/

# Install Velero server (with S3)
velero install \
  --provider aws \
  --bucket my-backup-bucket \
  --backup-location-config region=us-east-1 \
  --snapshot-location-config region=us-east-1 \
  --secret-file ./credentials-velero
```

### Backup with Velero

```bash
# Backup entire namespace
velero backup create production-backup --include-namespaces production

# Backup with label selector
velero backup create app-backup --selector app=myapp

# Schedule automatic backups
velero schedule create daily-backup \
  --schedule="@daily" \
  --include-namespaces production

# Check backups
velero backup get
```

### Restore with Velero

```bash
# Restore backup
velero restore create --from-backup production-backup

# Restore to different namespace
velero restore create --from-backup production-backup \
  --namespace-mappings production:production-restore

# Check restore status
velero restore get
velero restore describe <restore-name>
```

---

## 🎯 Disaster Recovery Plan

### DR Levels

**RTO (Recovery Time Objective):** How long to recover?
**RPO (Recovery Point Objective):** How much data can be lost?

| Tier | RTO | RPO | Strategy |
|------|-----|-----|----------|
| Critical | < 1 hour | < 5 min | HA cluster + continuous backup |
| Important | < 4 hours | < 1 hour | Daily backups + off-site storage |
| Standard | < 24 hours | < 24 hours | Weekly backups |

### DR Checklist

**1. Backup Strategy**
- [ ] Daily etcd snapshots
- [ ] Application backups (Velero)
- [ ] PV snapshots
- [ ] Configuration backups

**2. Off-site Storage**
- [ ] S3/Cloud storage
- [ ] Different region
- [ ] Encrypted backups

**3. Testing**
- [ ] Monthly restore tests
- [ ] DR drill quarterly
- [ ] Document procedures

**4. Monitoring**
- [ ] Backup success/failure alerts
- [ ] Storage capacity monitoring
- [ ] Retention policy enforcement

---

## 📊 Backup Best Practices

### 1. Multiple Backup Types

```
etcd Snapshots      → Cluster state
Velero Backups      → Applications + PVs
Configuration       → YAML manifests
Secrets             → Encrypted separately
```

### 2. 3-2-1 Backup Rule

```
3 copies of data
2 different media types
1 copy off-site
```

### 3. Encryption

```bash
# Encrypt backup
gpg --encrypt --recipient ops@company.com etcd-snapshot.db

# Decrypt
gpg --decrypt etcd-snapshot.db.gpg > etcd-snapshot.db
```

### 4. Testing

```bash
# Test restore monthly
# Document time to recover
# Update procedures based on lessons learned
```

### 5. Retention Policy

```
Daily:   Keep 7 days
Weekly:  Keep 4 weeks
Monthly: Keep 12 months
Yearly:  Keep 7 years (compliance)
```

---

## 🔧 Monitoring Backups

### Check Backup Age

```bash
#!/bin/bash
# check-backup-age.sh

BACKUP_DIR="/var/backups/etcd"
MAX_AGE_HOURS=24

LATEST_BACKUP=$(ls -t $BACKUP_DIR/etcd-*.db | head -1)
BACKUP_AGE_SECONDS=$(( $(date +%s) - $(stat -c %Y "$LATEST_BACKUP") ))
BACKUP_AGE_HOURS=$(( $BACKUP_AGE_SECONDS / 3600 ))

if [ $BACKUP_AGE_HOURS -gt $MAX_AGE_HOURS ]; then
  echo "CRITICAL: Latest backup is $BACKUP_AGE_HOURS hours old"
  exit 2
else
  echo "OK: Latest backup is $BACKUP_AGE_HOURS hours old"
  exit 0
fi
```

### Prometheus Metrics

```yaml
# ServiceMonitor for backup monitoring
apiVersion: v1
kind: ConfigMap
metadata:
  name: backup-metrics
data:
  metrics.sh: |
    #!/bin/bash
    echo "# HELP etcd_backup_age_seconds Age of latest backup"
    echo "# TYPE etcd_backup_age_seconds gauge"
    
    LATEST=$(ls -t /backup/etcd-*.db | head -1)
    AGE=$(( $(date +%s) - $(stat -c %Y "$LATEST") ))
    
    echo "etcd_backup_age_seconds $AGE"
```

---

## 📖 Key Takeaways

✅ etcd stores ALL cluster state
✅ Backup etcd regularly (daily minimum)
✅ Test restores monthly
✅ Store backups off-cluster
✅ Automate backup process
✅ Use Velero for application backups
✅ Encrypt backups
✅ Monitor backup success
✅ Document DR procedures
✅ Follow 3-2-1 backup rule

---

## 🔗 Resources

- [etcd Documentation](https://etcd.io/docs/)
- [Velero Documentation](https://velero.io/docs/)
- [Kubernetes Backup Best Practices](https://kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/#backing-up-an-etcd-cluster)

---

## 🚀 Next Steps

1. Complete GUIDEME.md exercises
2. Set up automated backups
3. Test restore procedure
4. Document DR plan
5. Implement monitoring
6. Schedule regular DR drills

**Happy Backing Up! 💾**
