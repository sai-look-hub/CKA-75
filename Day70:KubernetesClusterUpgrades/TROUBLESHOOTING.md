# 🔧 TROUBLESHOOTING: Cluster Upgrades - Day 71

## 🚨 ISSUE 1: Pod Eviction Timeout During Drain

**Error:**
```
error when evicting pod: pods "app-xxx" eviction is not allowed
```

**Cause:** PodDisruptionBudget (PDB) preventing eviction

**Solution:**
```bash
# Check PDB
kubectl get pdb -A

# Temporarily delete PDB (if safe)
kubectl delete pdb <pdb-name>

# Or force drain
kubectl drain <node> --ignore-daemonsets --delete-emptydir-data --force --grace-period=30
```

---

## 🚨 ISSUE 2: kubelet Won't Start After Upgrade

**Error:**
```
kubelet.service failed
```

**Diagnosis:**
```bash
# Check kubelet logs
journalctl -xeu kubelet

# Check status
systemctl status kubelet
```

**Common Causes:**

**1. Configuration mismatch:**
```bash
# Re-run kubeadm upgrade
sudo kubeadm upgrade node
sudo systemctl restart kubelet
```

**2. Certificate issues:**
```bash
# Check certificates
ls -la /var/lib/kubelet/pki/

# Restart kubelet
sudo systemctl restart kubelet
```

---

## 🚨 ISSUE 3: API Server Not Starting

**Error:**
```
kube-apiserver crashlooping
```

**Diagnosis:**
```bash
# Check API server logs
kubectl logs -n kube-system kube-apiserver-<node>

# Or check on node
sudo journalctl -u kubelet | grep apiserver
```

**Solution:**
```bash
# Check manifest
sudo cat /etc/kubernetes/manifests/kube-apiserver.yaml

# Restore from backup if corrupted
sudo cp /tmp/k8s-config-backup/manifests/kube-apiserver.yaml \
  /etc/kubernetes/manifests/
```

---

## 🚨 ISSUE 4: Version Skew Violation

**Error:**
```
unsupported version skew
```

**Cause:** Trying to skip minor versions

**Solution:**
Upgrade one minor version at a time:
```bash
# Not allowed: v1.27 → v1.29
# Must do: v1.27 → v1.28 → v1.29
```

---

## 🚨 ISSUE 5: etcd Backup Failed

**Error:**
```
failed to save etcd snapshot
```

**Solution:**
```bash
# Check etcd pod running
kubectl get pods -n kube-system -l component=etcd

# Verify endpoints
sudo ls /etc/kubernetes/pki/etcd/

# Retry with correct paths
sudo ETCDCTL_API=3 etcdctl snapshot save /tmp/backup.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
```

---

## 📋 Debug Checklist

1. ☑️ Check kubeadm version matches target
2. ☑️ Verify etcd backup exists
3. ☑️ Ensure sufficient disk space
4. ☑️ Check network connectivity
5. ☑️ Verify all pods drained before upgrade
6. ☑️ Review kubelet logs
7. ☑️ Check API server logs
8. ☑️ Validate certificates not expired
