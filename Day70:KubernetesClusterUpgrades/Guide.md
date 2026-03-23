# 📖 GUIDEME: Cluster Upgrades - Day 70

## 🎯 Complete Walkthrough (4-6 hours)

Hands-on cluster upgrade from v1.28.0 to v1.29.0.

**Prerequisites:**
- Kubernetes cluster (v1.28.x)
- SSH access to all nodes
- kubeadm-based cluster

---

## Phase 1: Pre-Upgrade Preparation (30 min)

### Check Current State
```bash
# Check cluster version
kubectl version --short
kubectl get nodes

# List all nodes with versions
kubectl get nodes -o wide

# Check component health
kubectl get componentstatuses

# List all pods
kubectl get pods -A
```

### Backup etcd
```bash
# SSH to control plane node
ssh control-plane

# Backup etcd
sudo ETCDCTL_API=3 etcdctl snapshot save /tmp/etcd-backup.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# Verify backup
sudo ETCDCTL_API=3 etcdctl snapshot status /tmp/etcd-backup.db
```

### Backup Kubernetes Configuration
```bash
# Backup /etc/kubernetes
sudo tar -czf /tmp/k8s-config-backup.tar.gz /etc/kubernetes

# Copy to safe location
scp control-plane:/tmp/etcd-backup.db ~/backups/
scp control-plane:/tmp/k8s-config-backup.tar.gz ~/backups/
```

**✅ Checkpoint:** Backups created and verified.

---

## Phase 2: Upgrade Control Plane (45 min)

### Step 1: Upgrade kubeadm
```bash
# SSH to control plane
ssh control-plane

# Find target version
sudo apt update
sudo apt-cache madison kubeadm | grep 1.29

# Unhold kubeadm
sudo apt-mark unhold kubeadm

# Upgrade kubeadm
sudo apt-get update && sudo apt-get install -y kubeadm=1.29.0-00

# Hold kubeadm
sudo apt-mark hold kubeadm

# Verify version
kubeadm version
```

### Step 2: Plan Upgrade
```bash
# Check upgrade plan
sudo kubeadm upgrade plan

# Output shows:
# - Current version
# - Available upgrades
# - Component versions after upgrade
```

### Step 3: Apply Upgrade
```bash
# Apply upgrade
sudo kubeadm upgrade apply v1.29.0

# Follow prompts
# Type 'y' to continue

# Wait for completion (5-10 minutes)
```

### Step 4: Drain Control Plane Node
```bash
# From another machine with kubectl
kubectl drain <control-plane-node> \
  --ignore-daemonsets \
  --delete-emptydir-data

# Verify node status
kubectl get nodes
# Should show "SchedulingDisabled"
```

### Step 5: Upgrade kubelet and kubectl
```bash
# SSH to control plane
ssh control-plane

# Unhold packages
sudo apt-mark unhold kubelet kubectl

# Upgrade
sudo apt-get update && sudo apt-get install -y \
  kubelet=1.29.0-00 \
  kubectl=1.29.0-00

# Hold packages
sudo apt-mark hold kubelet kubectl

# Restart kubelet
sudo systemctl daemon-reload
sudo systemctl restart kubelet

# Check status
sudo systemctl status kubelet
```

### Step 6: Uncordon Node
```bash
# From kubectl machine
kubectl uncordon <control-plane-node>

# Verify
kubectl get nodes
# Should show "Ready"
```

**✅ Checkpoint:** Control plane upgraded to v1.29.0.

---

## Phase 3: Validate Control Plane (15 min)

### Check Component Versions
```bash
# API server version
kubectl version --short

# Node versions
kubectl get nodes

# Component status
kubectl get componentstatuses

# All pods running?
kubectl get pods -A

# API resources available?
kubectl api-resources | head -20
```

### Test Functionality
```bash
# Create test pod
kubectl run nginx-test --image=nginx --port=80

# Expose service
kubectl expose pod nginx-test --port=80 --target-port=80

# Test access
kubectl run test --image=busybox --rm -it -- wget -O- http://nginx-test

# Clean up
kubectl delete pod nginx-test
kubectl delete service nginx-test
```

**✅ Checkpoint:** Control plane healthy and functional.

---

## Phase 4: Upgrade Worker Nodes (1-2 hours)

### Upgrade Worker Node 1

**Step 1: Drain node**
```bash
kubectl drain worker-1 \
  --ignore-daemonsets \
  --delete-emptydir-data \
  --force

# Watch pods migrate
kubectl get pods -A -o wide | grep worker-1
```

**Step 2: Upgrade node**
```bash
# SSH to worker-1
ssh worker-1

# Upgrade kubeadm
sudo apt-mark unhold kubeadm
sudo apt-get update && sudo apt-get install -y kubeadm=1.29.0-00
sudo apt-mark hold kubeadm

# Upgrade node configuration
sudo kubeadm upgrade node

# Upgrade kubelet and kubectl
sudo apt-mark unhold kubelet kubectl
sudo apt-get update && sudo apt-get install -y \
  kubelet=1.29.0-00 \
  kubectl=1.29.0-00
sudo apt-mark hold kubelet kubectl

# Restart kubelet
sudo systemctl daemon-reload
sudo systemctl restart kubelet
```

**Step 3: Uncordon node**
```bash
# From kubectl machine
kubectl uncordon worker-1

# Verify
kubectl get nodes
# worker-1 should show v1.29.0
```

### Upgrade Worker Node 2

**Repeat same steps for worker-2:**
```bash
# Drain
kubectl drain worker-2 --ignore-daemonsets --delete-emptydir-data --force

# SSH and upgrade
ssh worker-2
# [same upgrade commands as worker-1]

# Uncordon
kubectl uncordon worker-2
```

### Upgrade Worker Node 3

**Repeat for worker-3:**
```bash
kubectl drain worker-3 --ignore-daemonsets --delete-emptydir-data --force
# [upgrade commands]
kubectl uncordon worker-3
```

**✅ Checkpoint:** All worker nodes upgraded.

---

## Phase 5: Post-Upgrade Validation (30 min)

### Comprehensive Checks
```bash
# 1. All nodes upgraded
kubectl get nodes
# All should show v1.29.0

# 2. All pods running
kubectl get pods -A
# Check for CrashLoopBackOff, ImagePullBackOff

# 3. Check system pods
kubectl get pods -n kube-system

# 4. Verify etcd
kubectl get pods -n kube-system -l component=etcd

# 5. Check API server
kubectl get pods -n kube-system -l component=kube-apiserver

# 6. Verify scheduler
kubectl get pods -n kube-system -l component=kube-scheduler

# 7. Check controller manager
kubectl get pods -n kube-system -l component=kube-controller-manager
```

### Application Testing
```bash
# Deploy test application
kubectl create deployment nginx --image=nginx --replicas=3

# Expose service
kubectl expose deployment nginx --port=80 --type=NodePort

# Get service
kubectl get svc nginx

# Test access
curl http://<node-ip>:<nodeport>

# Check pod distribution
kubectl get pods -o wide

# Clean up
kubectl delete deployment nginx
kubectl delete service nginx
```

### Performance Check
```bash
# Check resource usage
kubectl top nodes
kubectl top pods -A

# Verify no errors in logs
kubectl logs -n kube-system -l component=kube-apiserver --tail=50

# Check for deprecation warnings
kubectl get events -A | grep -i deprecat
```

**✅ Checkpoint:** Cluster healthy and operational.

---

## Phase 6: Documentation & Cleanup (15 min)

### Update Documentation
```bash
# Create upgrade log
cat > upgrade-log-$(date +%Y%m%d).txt <<EOF
Cluster Upgrade Log
Date: $(date)
From: v1.28.0
To: v1.29.0

Control Plane:
- Upgraded: $(date)
- Downtime: <5 minutes
- Issues: None

Worker Nodes:
- worker-1: Upgraded successfully
- worker-2: Upgraded successfully
- worker-3: Upgraded successfully

Validation:
- All nodes: Ready
- All pods: Running
- Application tests: Passed

Notes:
- Total time: 2 hours
- Zero application downtime
EOF
```

### Archive Old Backups
```bash
# Move backups to archive
mv ~/backups/etcd-backup.db ~/backups/archive/etcd-backup-v1.28-$(date +%Y%m%d).db

# Keep backups for 30 days
find ~/backups/archive/ -name "*.db" -mtime +30 -delete
```

**✅ Checkpoint:** Upgrade complete and documented.

---

## ✅ Final Validation Checklist

- [ ] All nodes show v1.29.0
- [ ] All system pods running
- [ ] All application pods running
- [ ] No CrashLoopBackOff pods
- [ ] API server responsive
- [ ] kubectl commands working
- [ ] Applications accessible
- [ ] No error logs
- [ ] Resource usage normal
- [ ] Documentation updated

---

## 🎯 Success Criteria

✅ Cluster upgraded from v1.28.0 to v1.29.0
✅ Zero application downtime
✅ All nodes healthy
✅ All pods running
✅ No regressions detected

---

**Congratulations! You've successfully upgraded a Kubernetes cluster! 🔄🚀**
