# 🎤 Interview Q&A: Cluster Upgrades - Day 71

## Q1: Explain Kubernetes version skew policy.

**Answer:**

**Version skew policy** defines allowed version differences between cluster components.

**Key Rules:**

**1. kube-apiserver is reference:**
- Most recent component
- All others reference it

**2. kubelet:**
- Can be up to 2 minor versions older
- Example: apiserver v1.30 → kubelet v1.28 ✅

**3. Controller manager & scheduler:**
- Can be 1 minor version older
- Example: apiserver v1.30 → controller-manager v1.29 ✅

**4. kubectl:**
- Within ±1 minor version
- Example: apiserver v1.30 → kubectl v1.29, v1.30, v1.31 ✅

**Why it matters:**
- Ensures compatibility
- Prevents API breakage
- Defines upgrade order

**Upgrade order:**
```
1. Control plane (apiserver first)
2. Worker nodes (kubelet)
3. Client tools (kubectl)
```

---

## Q2: What's the correct process to upgrade a Kubernetes cluster?

**Answer:**

**Step-by-step process:**

**1. Pre-upgrade:**
```bash
# Backup etcd
etcdctl snapshot save backup.db

# Backup configuration
tar -czf k8s-config.tar.gz /etc/kubernetes

# Review release notes
# Test in staging
```

**2. Upgrade control plane:**
```bash
# Upgrade kubeadm
apt-get install kubeadm=1.29.0-00

# Plan upgrade
kubeadm upgrade plan

# Apply upgrade
kubeadm upgrade apply v1.29.0

# Drain node
kubectl drain <node> --ignore-daemonsets

# Upgrade kubelet
apt-get install kubelet=1.29.0-00
systemctl restart kubelet

# Uncordon
kubectl uncordon <node>
```

**3. Upgrade worker nodes:**
```bash
# One at a time
kubectl drain worker-1 --ignore-daemonsets

# On worker:
apt-get install kubeadm=1.29.0-00 kubelet=1.29.0-00
kubeadm upgrade node
systemctl restart kubelet

# Uncordon
kubectl uncordon worker-1
```

**4. Validate:**
```bash
kubectl get nodes
kubectl get pods -A
```

**Critical points:**
- Backup first
- Control plane before workers
- One minor version at a time
- Drain before upgrade
- Validate each step

---

## Q3: How do you achieve zero-downtime during cluster upgrades?

**Answer:**

**Zero-downtime strategies:**

**1. Rolling node upgrades:**
```bash
# Upgrade nodes one at a time
# Pods automatically reschedule

kubectl drain worker-1  # Pods move to worker-2, worker-3
# Upgrade worker-1
kubectl uncordon worker-1

kubectl drain worker-2  # Pods move to worker-1, worker-3
# Upgrade worker-2
# ... and so on
```

**2. Sufficient capacity:**
```
# Ensure cluster can handle N-1 nodes
# During drain, pods need somewhere to go
# Plan for 20-30% extra capacity
```

**3. Pod Disruption Budgets:**
```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
spec:
  minAvailable: 2  # Always keep 2 pods running
```

**4. Multiple replicas:**
```yaml
spec:
  replicas: 3  # Minimum for HA
```

**5. Health checks:**
```yaml
readinessProbe:  # Don't route until ready
livenessProbe:   # Restart if unhealthy
```

**6. Blue-green for critical apps:**
```
# Keep old version running
# Deploy new version
# Switch traffic
```

**Result:**
- Pods reschedule automatically
- Load balancer routes to healthy pods
- Users see no interruption

---

## Q4: What should you do if an upgrade fails?

**Answer:**

**Rollback procedure:**

**1. Immediate actions:**
```bash
# Don't panic
# Stop upgrading additional nodes
# Assess the damage
```

**2. If control plane upgrade failed:**
```bash
# Restore etcd from backup
etcdctl snapshot restore backup.db \
  --data-dir /var/lib/etcd-restore

# Restore configuration
tar -xzf k8s-config-backup.tar.gz -C /

# Restart kubelet
systemctl restart kubelet
```

**3. If worker node upgrade failed:**
```bash
# Stop kubelet
systemctl stop kubelet

# Downgrade packages
apt-get install kubelet=1.28.0-00

# Restart
systemctl start kubelet

# Uncordon if needed
kubectl uncordon <node>
```

**4. If pods not starting:**
```bash
# Check pod events
kubectl describe pod <pod>

# Check logs
kubectl logs <pod>

# Rollback deployment if needed
kubectl rollout undo deployment <name>
```

**Prevention:**
- Test in staging first
- Backup everything
- Upgrade one node at a time
- Monitor continuously
- Have rollback plan ready

**Best practice:**
Never upgrade production directly.

---

## Q5: How do you plan cluster upgrades for large production environments?

**Answer:**

**Planning checklist:**

**1. Timeline:**
```
3 months before:
- Review release notes
- Identify deprecations
- Test in dev

1 month before:
- Test in staging
- Create runbooks
- Plan maintenance window

1 week before:
- Final staging test
- Notify stakeholders
- Prepare rollback plan

Day of:
- Execute upgrade
- Monitor closely
```

**2. Strategy by cluster size:**

**Small (< 10 nodes):**
- One node at a time
- 1-2 hour window

**Medium (10-100 nodes):**
- Canary approach (10% nodes)
- 4-6 hour window
- Pause if issues

**Large (100+ nodes):**
- Blue-green deployment
- New node pool
- Gradual migration
- 24-48 hour rollout

**3. Risk mitigation:**
```
- Backup everything
- Test exhaustively
- Canary deployments
- Feature flags
- Gradual rollout
- Monitor continuously
```

**4. Communication:**
```
- Notify users
- Status page updates
- Slack/email alerts
- Post-mortem if issues
```

**5. Automation:**
```bash
# Automated validation
kubectl get nodes
kubectl get pods -A
# Run health checks
# Alert if issues
```

**Result:**
Controlled, predictable upgrades with minimal risk.
