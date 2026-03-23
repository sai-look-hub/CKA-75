# Day 70: Kubernetes Cluster Upgrades

## 📋 Overview

Welcome to Day 71! Master Kubernetes cluster upgrades - learn to safely upgrade control plane, worker nodes, and understand version skew policies. You'll perform hands-on cluster upgrades without downtime.

### What You'll Learn

- Kubernetes versioning and release cycle
- Version skew policy
- Control plane upgrade process
- Worker node upgrade strategies
- Rolling updates for zero downtime
- Backup and rollback procedures
- Best practices for production upgrades

---

## 🎯 Learning Objectives

1. Understand Kubernetes version skew policy
2. Upgrade control plane components
3. Upgrade worker nodes safely
4. Implement zero-downtime upgrades
5. Handle upgrade failures
6. Validate cluster health post-upgrade
7. Plan upgrade strategies for production

---

## 📚 Kubernetes Versioning

### Version Format

```
v1.28.3
│ │  │
│ │  └─ Patch version (bug fixes, security patches)
│ └──── Minor version (new features, deprecations)
└────── Major version (breaking changes)
```

### Release Cycle

- **New minor version:** Every ~4 months
- **Support window:** Latest 3 minor versions
- **Patch releases:** As needed (security, critical bugs)

**Example (as of 2026):**
- Latest: v1.30.x
- Supported: v1.30.x, v1.29.x, v1.28.x
- Deprecated: v1.27.x and older

---

## 📐 Version Skew Policy

### What is Version Skew?

**Version skew** = Difference in versions between cluster components.

### Supported Skew

**1. kube-apiserver**
- Most recent component
- All others reference it

**2. kubelet**
- Can be up to 2 minor versions older than apiserver
- Example: apiserver v1.30 → kubelet v1.28 ✅

**3. kube-controller-manager, kube-scheduler, cloud-controller-manager**
- Can be 1 minor version older than apiserver
- Example: apiserver v1.30 → controller-manager v1.29 ✅

**4. kubectl**
- Within 1 minor version of apiserver
- Example: apiserver v1.30 → kubectl v1.29, v1.30, v1.31 ✅

**5. kube-proxy**
- Same version as kubelet or 1 minor version newer
- Example: kubelet v1.28 → kube-proxy v1.28 or v1.29 ✅

### Version Skew Example

```
Control Plane (v1.30):
├── kube-apiserver: v1.30.0
├── kube-controller-manager: v1.29.0 (1 version older ✅)
└── kube-scheduler: v1.29.0 (1 version older ✅)

Worker Nodes:
├── kubelet: v1.28.0 (2 versions older ✅)
└── kube-proxy: v1.28.0 (matches kubelet ✅)

Client:
└── kubectl: v1.29.0 to v1.31.0 (±1 version ✅)
```

### Upgrade Path

**Rule:** Upgrade one minor version at a time.

**Example:**
```
v1.28.x → v1.29.x → v1.30.x ✅

v1.28.x → v1.30.x ❌ (skip not allowed)
```

---

## 🔄 Upgrade Process Overview

### High-Level Steps

```
1. Backup etcd
   ↓
2. Upgrade control plane components
   - kube-apiserver
   - kube-controller-manager
   - kube-scheduler
   - etcd
   ↓
3. Upgrade worker nodes
   - Drain node
   - Upgrade kubelet & kube-proxy
   - Uncordon node
   ↓
4. Validate cluster
   ↓
5. Update kubectl
```

---

## 🎛️ Control Plane Upgrade

### Prerequisites

1. **Backup etcd:**
```bash
ETCDCTL_API=3 etcdctl snapshot save backup.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
```

2. **Check current version:**
```bash
kubectl version --short
kubectl get nodes
```

3. **Review release notes**

### Upgrade Steps (kubeadm)

**1. Upgrade kubeadm:**
```bash
# Find available versions
apt update
apt-cache madison kubeadm | grep 1.29

# Upgrade kubeadm
apt-mark unhold kubeadm
apt-get update && apt-get install -y kubeadm=1.29.0-00
apt-mark hold kubeadm

# Verify
kubeadm version
```

**2. Plan upgrade:**
```bash
kubeadm upgrade plan
```

**3. Apply upgrade:**
```bash
# First control plane node
kubeadm upgrade apply v1.29.0

# Additional control plane nodes (if HA)
kubeadm upgrade node
```

**4. Drain control plane node:**
```bash
kubectl drain <control-plane-node> --ignore-daemonsets
```

**5. Upgrade kubelet and kubectl:**
```bash
apt-mark unhold kubelet kubectl
apt-get update && apt-get install -y kubelet=1.29.0-00 kubectl=1.29.0-00
apt-mark hold kubelet kubectl

systemctl daemon-reload
systemctl restart kubelet
```

**6. Uncordon node:**
```bash
kubectl uncordon <control-plane-node>
```

---

## 💻 Worker Node Upgrade

### Strategy 1: Rolling Update (Recommended)

**One node at a time:**

```bash
# 1. Drain node (move pods to other nodes)
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data

# 2. SSH to node and upgrade
ssh <node>
apt-mark unhold kubeadm kubelet kubectl
apt-get update && apt-get install -y \
  kubeadm=1.29.0-00 \
  kubelet=1.29.0-00 \
  kubectl=1.29.0-00
apt-mark hold kubeadm kubelet kubectl

# 3. Upgrade node config
kubeadm upgrade node

# 4. Restart kubelet
systemctl daemon-reload
systemctl restart kubelet

# 5. From control plane: Uncordon
kubectl uncordon <node-name>

# 6. Verify node ready
kubectl get nodes
```

**Repeat for each worker node.**

### Strategy 2: Blue-Green Deployment

**For cloud environments:**

```
1. Create new node pool (v1.29)
2. Migrate workloads
3. Delete old node pool (v1.28)
```

**Pros:**
- Fast rollback
- No drain needed

**Cons:**
- Requires extra capacity
- More complex

---

## ⚠️ Common Issues

### Issue 1: Pod Eviction Timeout

```bash
# Pod won't evict (PDB too restrictive)
kubectl drain node1 --ignore-daemonsets --delete-emptydir-data --force --grace-period=30
```

### Issue 2: Version Incompatibility

```
Error: unsupported version skew
```

**Fix:** Upgrade one minor version at a time.

### Issue 3: etcd Upgrade Failure

**Solution:** Restore from backup:
```bash
ETCDCTL_API=3 etcdctl snapshot restore backup.db \
  --data-dir /var/lib/etcd-restore
```

---

## ✅ Post-Upgrade Validation

### Check Cluster Health

```bash
# 1. Verify component versions
kubectl version --short
kubectl get nodes

# 2. Check component status
kubectl get componentstatuses

# 3. Check all pods running
kubectl get pods -A

# 4. Verify workload functionality
kubectl run test --image=nginx --rm -it -- curl http://service

# 5. Check cluster-info
kubectl cluster-info

# 6. Verify API resources
kubectl api-resources
```

---

## 📋 Best Practices

### 1. Plan Ahead

- Review release notes
- Check deprecations
- Test in staging first
- Schedule maintenance window

### 2. Backup Everything

```bash
# etcd backup
ETCDCTL_API=3 etcdctl snapshot save backup.db

# Configuration backup
tar -czf k8s-config-backup.tar.gz /etc/kubernetes
```

### 3. Upgrade Strategy

**Small clusters (< 10 nodes):**
- One node at a time
- 1-2 hour maintenance window

**Large clusters (100+ nodes):**
- Blue-green deployment
- Canary upgrade (10% nodes first)
- 24-48 hour rollout

### 4. Monitor Everything

- Watch pod distribution
- Track resource usage
- Monitor application health
- Check error logs

### 5. Have Rollback Plan

```bash
# If upgrade fails on node
systemctl stop kubelet
apt-get install -y kubelet=1.28.0-00
systemctl start kubelet
kubectl uncordon <node>
```

---

## 🔧 Upgrade Checklist

### Pre-Upgrade
- [ ] Review release notes
- [ ] Backup etcd
- [ ] Backup /etc/kubernetes
- [ ] Test in staging
- [ ] Check version skew policy
- [ ] Notify stakeholders
- [ ] Prepare rollback plan

### During Upgrade
- [ ] Upgrade control plane first
- [ ] Validate control plane health
- [ ] Upgrade worker nodes one by one
- [ ] Verify each node after upgrade
- [ ] Monitor application health

### Post-Upgrade
- [ ] Verify all nodes upgraded
- [ ] Check all pods running
- [ ] Test application functionality
- [ ] Update documentation
- [ ] Remove old backups

---

## 📊 Upgrade Timeline (Example)

**Cluster:** 1 control plane + 3 workers

```
00:00 - Backup etcd (5 min)
00:05 - Upgrade control plane (15 min)
00:20 - Validate control plane (5 min)
00:25 - Upgrade worker-1 (10 min)
00:35 - Upgrade worker-2 (10 min)
00:45 - Upgrade worker-3 (10 min)
00:55 - Final validation (5 min)
01:00 - Complete ✅

Total: 1 hour
```

---

## 🎓 Key Takeaways

✅ Upgrade one minor version at a time
✅ Control plane before worker nodes
✅ Backup etcd before any upgrade
✅ Drain nodes before upgrading
✅ Test in staging first
✅ Monitor during upgrade
✅ Validate after each step
✅ Have rollback plan ready
✅ Follow version skew policy
✅ Zero downtime is possible with planning

---

## 🔗 Resources

- [Kubernetes Version Skew Policy](https://kubernetes.io/releases/version-skew-policy/)
- [Upgrading kubeadm clusters](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/)
- [Release Notes](https://kubernetes.io/releases/)

---

## 🚀 Next Steps

1. Complete GUIDEME.md hands-on upgrade
2. Practice in test cluster
3. Plan production upgrade
4. Document your process
5. Move to advanced topics

**Happy Upgrading! 🔄**
