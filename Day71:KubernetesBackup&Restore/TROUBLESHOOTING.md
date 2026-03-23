# 🔧 TROUBLESHOOTING: Backup & Restore - Day 72

## 🚨 ISSUE 1: Backup Creation Fails

**Error:**
```
Error: context deadline exceeded
```

**Diagnosis:**
```bash
# Check if etcd is running
kubectl get pods -n kube-system -l component=etcd

# Check etcd logs
kubectl logs -n kube-system etcd-<node>

# Verify endpoints
ps aux | grep etcd
```

**Solution:**
- Verify etcd is running
- Check certificate paths are correct
- Ensure sufficient disk space

---

## 🚨 ISSUE 2: Restore Breaks Cluster

**Symptoms:** API server won't start after restore

**Diagnosis:**
```bash
# Check API server logs
kubectl logs -n kube-system kube-apiserver-<node>

# Check etcd logs
journalctl -u kubelet | grep etcd

# Verify data directory
ls -la /var/lib/etcd-restore/
```

**Solution:**
```bash
# Restore original etcd manifest
cp /tmp/etcd.yaml.bak /etc/kubernetes/manifests/etcd.yaml

# Or restore original data directory
rm -rf /var/lib/etcd-restore
# Restart cluster
```

---

## 🚨 ISSUE 3: Permission Denied on Backup

**Error:**
```
permission denied: /var/backups/etcd
```

**Solution:**
```bash
# Create directory with correct permissions
sudo mkdir -p /var/backups/etcd
sudo chmod 755 /var/backups/etcd

# Or run as root
sudo ETCDCTL_API=3 etcdctl snapshot save...
```

---

## 🚨 ISSUE 4: Velero Backup Stuck

**Symptoms:** Backup in "InProgress" state

**Diagnosis:**
```bash
# Check Velero logs
kubectl logs -n velero -l component=velero

# Describe backup
velero backup describe <name> --details

# Check for PVC issues
kubectl get pvc -A
```

**Solution:**
- Check storage provisioner
- Verify Velero has access to backup location
- Delete and recreate backup

---

## 📋 Debug Checklist

1. ☑️ etcd pod running
2. ☑️ Certificate paths correct
3. ☑️ Sufficient disk space
4. ☑️ Proper permissions
5. ☑️ Network connectivity
6. ☑️ Backup directory exists
7. ☑️ API server accessible
