# 📋 Command Cheatsheet: Backup & Restore - Day 71

## 💾 etcd Backup Commands

```bash
# Create snapshot
ETCDCTL_API=3 etcdctl snapshot save /backup/etcd-snapshot.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# Verify snapshot
ETCDCTL_API=3 etcdctl snapshot status /backup/etcd-snapshot.db \
  --write-out=table

# List backups
ls -lht /var/backups/etcd/

# Check backup size
du -sh /var/backups/etcd/*
```

## 🔄 etcd Restore Commands

```bash
# Restore snapshot
ETCDCTL_API=3 etcdctl snapshot restore /backup/etcd-snapshot.db \
  --data-dir=/var/lib/etcd-restore \
  --initial-cluster=master=https://127.0.0.1:2380 \
  --initial-advertise-peer-urls=https://127.0.0.1:2380

# Stop API server
mv /etc/kubernetes/manifests/kube-apiserver.yaml /tmp/

# Update etcd data directory
vi /etc/kubernetes/manifests/etcd.yaml
# Change: path: /var/lib/etcd-restore

# Restart API server
mv /tmp/kube-apiserver.yaml /etc/kubernetes/manifests/
```

## 📦 Velero Commands

```bash
# Create backup
velero backup create <name> --include-namespaces <ns>

# List backups
velero backup get
velero backup describe <name>

# Restore backup
velero restore create --from-backup <name>

# Schedule automatic backups
velero schedule create daily \
  --schedule="@daily" \
  --include-namespaces production

# Delete backup
velero backup delete <name>
```

## 🔍 Validation Commands

```bash
# Check etcd health
ETCDCTL_API=3 etcdctl endpoint health \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# Get etcd members
ETCDCTL_API=3 etcdctl member list \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
```

## 💡 Useful One-Liners

```bash
# Check latest backup age
ls -lt /var/backups/etcd/etcd-*.db | head -1

# Count backups
ls -1 /var/backups/etcd/etcd-*.db | wc -l

# Delete old backups (>30 days)
find /var/backups/etcd -name "etcd-*.db" -mtime +30 -delete

# Backup with timestamp
ETCDCTL_API=3 etcdctl snapshot save \
  /backup/etcd-$(date +%Y%m%d-%H%M%S).db \
  [other options...]
```
