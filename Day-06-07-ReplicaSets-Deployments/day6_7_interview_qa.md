# Interview Questions - ReplicaSets & Deployments

## 📚 Table of Contents
1. [ReplicaSet Questions](#replicaset)
2. [Deployment Questions](#deployment)
3. [Rolling Updates & Rollbacks](#updates)
4. [Scaling Questions](#scaling)
5. [Strategy Questions](#strategy)
6. [Troubleshooting Questions](#troubleshooting)
7. [Scenario-Based Questions](#scenarios)

---

## ReplicaSet Questions {#replicaset}

### Q1: What is a ReplicaSet and why do we need it?

**Answer:**
A ReplicaSet is a Kubernetes controller that ensures a specified number of pod replicas are running at all times.

**Why we need it:**
- **Self-healing**: Automatically replaces failed pods
- **Scaling**: Easy to scale up/down
- **High availability**: Maintains desired number of pods
- **Load distribution**: Spreads pods across nodes

**Example:**
```yaml
spec:
  replicas: 3  # Always maintains 3 pods
```

If one pod dies, ReplicaSet creates a new one to maintain count of 3.

---

### Q2: What's the difference between ReplicationController and ReplicaSet?

**Answer:**

| Feature | ReplicationController | ReplicaSet |
|---------|----------------------|------------|
| Selector | Equality-based only | Set-based (more flexible) |
| Label matching | `app=nginx` only | `app in (nginx, apache)` |
| Status | Deprecated | Current standard |
| Used by | Old apps | Deployments |

**ReplicationController:**
```yaml
selector:
  app: nginx  # Only equality
```

**ReplicaSet:**
```yaml
selector:
  matchLabels:
    app: nginx
  matchExpressions:
  - key: tier
    operator: In
    values: [frontend, backend]
```

**Recommendation:** Always use ReplicaSets (via Deployments), not ReplicationControllers.

---

### Q3: How does a ReplicaSet identify which pods to manage?

**Answer:**
ReplicaSets use **label selectors** to identify pods.

**Matching rules:**
1. Selector in ReplicaSet must match labels in pod template
2. ReplicaSet manages ALL pods with matching labels (even if created manually)
3. If labels don't match, ReplicaSet ignores those pods

**Example:**
```yaml
spec:
  selector:
    matchLabels:
      app: nginx      # ReplicaSet looks for pods with these labels
  template:
    metadata:
      labels:
        app: nginx    # Must match selector above!
```

**What happens if labels don't match?**
- ReplicaSet won't manage the pods
- Deployment will fail to create

---

### Q4: Can you create pods manually that a ReplicaSet will manage?

**Answer:**
Yes! If you create a pod with matching labels, the ReplicaSet will adopt it.

**Example:**
```bash
# ReplicaSet wants 3 pods with label app=nginx
kubectl get rs
# nginx-rs   2/3   (only 2 pods running)

# Manually create pod with matching label
kubectl run manual-pod --image=nginx --labels="app=nginx"

# ReplicaSet now shows 3/3
kubectl get rs
# nginx-rs   3/3   (ReplicaSet adopted manual pod!)
```

**Important:** If you create MORE pods than desired replicas, ReplicaSet will DELETE extras to maintain desired count.

---

## Deployment Questions {#deployment}

### Q5: What is a Deployment and why use it instead of ReplicaSets?

**Answer:**
A Deployment provides declarative updates for Pods and ReplicaSets.

**Why Deployments over ReplicaSets:**

| Feature | ReplicaSet | Deployment |
|---------|-----------|------------|
| Pod replication | ✅ Yes | ✅ Yes |
| Self-healing | ✅ Yes | ✅ Yes |
| Rolling updates | ❌ No | ✅ Yes |
| Rollback | ❌ No | ✅ Yes |
| Update pause/resume | ❌ No | ✅ Yes |
| Revision history | ❌ No | ✅ Yes |

**Hierarchy:**
```
Deployment (manages updates)
    ↓
ReplicaSet (manages replicas)
    ↓
Pods (run containers)
```

**Best Practice:** Always use Deployments in production, not bare ReplicaSets.

---

### Q6: What happens when you create a Deployment?

**Answer:**
Step-by-step process:

1. **You create Deployment:**
   ```bash
   kubectl apply -f deployment.yaml
   ```

2. **Deployment controller creates ReplicaSet:**
   ```
   Deployment: nginx-deployment
       ↓
   ReplicaSet: nginx-deployment-abc123 (generated name)
   ```

3. **ReplicaSet creates Pods:**
   ```
   ReplicaSet: nginx-deployment-abc123
       ↓
   Pods: nginx-deployment-abc123-p1, p2, p3
   ```

4. **Deployment tracks revision history:**
   ```
   Revision 1: ReplicaSet-abc123 (current)
   ```

**Verify:**
```bash
kubectl get deployment,rs,pods
# Shows all three levels
```

---

### Q7: Explain the relationship between Deployment, ReplicaSet, and Pods.

**Answer:**

**Ownership hierarchy:**
```
┌──────────────────────────────────────────┐
│         Deployment                       │
│  - Manages versions                      │
│  - Handles updates                       │
│  - Stores history                        │
└──────────────────────────────────────────┘
                 │ owns
                 ↓
┌──────────────────────────────────────────┐
│         ReplicaSet                       │
│  - Maintains replica count               │
│  - Self-healing                          │
│  - Pod scheduling                        │
└──────────────────────────────────────────┘
                 │ owns
                 ↓
┌──────────────────────────────────────────┐
│         Pods                             │
│  - Run containers                        │
│  - Actual workload                       │
└──────────────────────────────────────────┘
```

**When you update Deployment:**
```
Deployment (updated)
    ↓
ReplicaSet-v2 (new) → Creates new pods
ReplicaSet-v1 (old) → Scales down old pods
```

**Important:** Don't edit ReplicaSets directly. Always edit Deployments.

---

## Rolling Updates & Rollbacks {#updates}

### Q8: How do rolling updates work in Kubernetes?

**Answer:**
Rolling updates gradually replace old pods with new ones, maintaining availability.

**Process:**
```
Step 1: 3 old pods running (v1.25)
  [Pod-v1] [Pod-v1] [Pod-v1]

Step 2: Create 1 new pod (v1.26)
  [Pod-v1] [Pod-v1] [Pod-v1] [Pod-v2]

Step 3: Terminate 1 old pod
  [Pod-v1] [Pod-v1] [Pod-v2]

Step 4: Create 1 new pod
  [Pod-v1] [Pod-v1] [Pod-v2] [Pod-v2]

Step 5: Continue until complete
  [Pod-v2] [Pod-v2] [Pod-v2]
```

**Controlled by:**
```yaml
strategy:
  rollingUpdate:
    maxSurge: 1        # Max 1 extra pod during update
    maxUnavailable: 1  # Max 1 pod unavailable
```

**Result:** Zero-downtime deployment!

---

### Q9: What is maxSurge and maxUnavailable in RollingUpdate?

**Answer:**

**maxSurge:** Maximum number of pods that can be created ABOVE desired replicas during update.

**maxUnavailable:** Maximum number of pods that can be unavailable during update.

**Example with replicas: 4**

```yaml
strategy:
  rollingUpdate:
    maxSurge: 2
    maxUnavailable: 1
```

**During update:**
- **Max total pods:** 4 + 2 = 6 (replicas + maxSurge)
- **Min available pods:** 4 - 1 = 3 (replicas - maxUnavailable)

**Scenarios:**

| maxSurge | maxUnavailable | Behavior |
|----------|----------------|----------|
| 1 | 1 | Slow, conservative update |
| 2 | 2 | Faster update, less safe |
| 25% | 25% | Percentage-based |
| 0 | 1 | Can't create extra, terminates first |
| 1 | 0 | Creates new before terminating |

**Best practice:** `maxSurge: 25%, maxUnavailable: 25%` balances speed and safety.

---

### Q10: How do you perform a rollback in Kubernetes?

**Answer:**

**Method 1: Rollback to previous version**
```bash
kubectl rollout undo deployment/nginx-deployment
```

**Method 2: Rollback to specific revision**
```bash
# View history
kubectl rollout history deployment/nginx-deployment

# Output shows:
# REVISION  CHANGE-CAUSE
# 1         Initial deployment
# 2         Updated to v1.26
# 3         Updated to v1.27

# Rollback to revision 2
kubectl rollout undo deployment/nginx-deployment --to-revision=2
```

**Method 3: Edit deployment directly**
```bash
kubectl edit deployment nginx-deployment
# Change image back to previous version
```

**Monitor rollback:**
```bash
kubectl rollout status deployment/nginx-deployment
```

**What happens during rollback:**
1. Old ReplicaSet (previous version) scaled up
2. New ReplicaSet (failed version) scaled down
3. New revision created in history

---

### Q11: How many revisions does Kubernetes keep by default?

**Answer:**
**Default:** 10 revisions

**Configure:**
```yaml
spec:
  revisionHistoryLimit: 5  # Keep only 5 revisions
```

**Why limit?**
- Saves etcd storage
- Reduces clutter
- Faster rollback queries

**View revisions:**
```bash
kubectl rollout history deployment/nginx-deployment
```

**Best practices:**
- Production: 10-20 revisions
- Dev/Test: 3-5 revisions
- CI/CD: 5 revisions

---

### Q12: Can you pause and resume a deployment?

**Answer:**
Yes! Useful when making multiple changes.

**Pause deployment:**
```bash
kubectl rollout pause deployment/nginx-deployment
```

**Make multiple changes:**
```bash
kubectl set image deployment/nginx-deployment nginx=nginx:1.26
kubectl set resources deployment/nginx-deployment -c=nginx --limits=cpu=200m
kubectl set env deployment/nginx-deployment LOG_LEVEL=debug
```

**Resume deployment (applies all changes at once):**
```bash
kubectl rollout resume deployment/nginx-deployment
```

**Why pause?**
- Avoid multiple rolling updates
- Apply changes atomically
- Test configuration before deploying

---

## Scaling Questions {#scaling}

### Q13: What's the difference between vertical and horizontal scaling?

**Answer:**

**Horizontal Scaling (Scale OUT):**
- Add MORE pods
- `kubectl scale deployment nginx --replicas=10`
- Increases capacity by adding instances

**Vertical Scaling (Scale UP):**
- Add MORE resources (CPU/memory) to existing pods
- Edit resource limits in deployment
- Requires pod restart

**Comparison:**

| Aspect | Horizontal | Vertical |
|--------|-----------|----------|
| What changes | Number of pods | Resources per pod |
| Downtime | No | Yes (pod restart) |
| Limit | Cluster capacity | Node capacity |
| Best for | Stateless apps | Stateful apps |
| K8s support | Excellent (HPA) | Manual/VPA |

**Example:**

Horizontal:
```bash
kubectl scale deployment app --replicas=5
# 3 pods → 5 pods
```

Vertical:
```yaml
resources:
  requests:
    memory: "256Mi"  # Increased from 128Mi
    cpu: "200m"      # Increased from 100m
```

---

### Q14: How does Horizontal Pod Autoscaler (HPA) work?

**Answer:**
HPA automatically scales pods based on metrics.

**Architecture:**
```
Metrics Server → HPA Controller → Deployment → ReplicaSet → Pods
     ↓                ↓
  CPU/Memory      Decision
  Usage           (scale up/down)
```

**Configuration:**
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: nginx-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: nginx-deployment
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 80
```

**How it works:**
1. Metrics Server collects CPU/memory usage every 15 seconds
2. HPA checks metrics every 30 seconds
3. If average CPU > 80%, scales up
4. If average CPU < 80%, scales down
5. Respects min/max replica limits

**Example:**
```
CPU usage: 85% → Scale from 3 to 4 pods
CPU usage: 40% → Scale from 4 to 3 pods
```

---

### Q15: What's the cooldown period in HPA?

**Answer:**
Cooldown prevents rapid scaling oscillations.

**Default cooldowns:**
- **Scale up:** 3 minutes
- **Scale down:** 5 minutes

**Why different?**
- Scale up fast (handle load quickly)
- Scale down slow (avoid premature scale-down)

**Example scenario:**
```
Time 0:00 - CPU spike to 90%
Time 0:01 - HPA scales from 3 to 4 pods
Time 0:02 - CPU drops to 60%
Time 0:03 - HPA does NOTHING (cooldown)
Time 0:08 - Still low CPU? Scale down to 3
```

**Configure custom cooldown:**
```yaml
behavior:
  scaleUp:
    stabilizationWindowSeconds: 60  # 1 minute cooldown
  scaleDown:
    stabilizationWindowSeconds: 300  # 5 minutes cooldown
```

---

## Strategy Questions {#strategy}

### Q16: What deployment strategies does Kubernetes support?

**Answer:**

**1. RollingUpdate (Default)**
```yaml
strategy:
  type: RollingUpdate
```
- Gradual pod replacement
- Zero downtime
- Both versions run briefly

**2. Recreate**
```yaml
strategy:
  type: Recreate
```
- Delete all old pods first
- Then create new pods
- Downtime during switch

**Comparison:**

| Strategy | Downtime | Complexity | Use Case |
|----------|----------|------------|----------|
| RollingUpdate | No | Medium | Most deployments |
| Recreate | Yes | Low | Breaking changes, DB migrations |
| Blue-Green | No | High | Major releases |
| Canary | No | High | Risk mitigation |

---

### Q17: Explain Blue-Green deployment strategy.

**Answer:**
Blue-Green maintains two identical environments, switching traffic instantly.

**Architecture:**
```
┌──────────────┐     ┌──────────────┐
│     Blue     │     │    Green     │
│  (Current)   │     │    (New)     │
│   v1.25      │     │   v1.26      │
│              │     │              │
│  3 pods      │     │  3 pods      │
└──────────────┘     └──────────────┘
       ↑                     ↑
       │                     │
  ┌────┴──────┐         (Ready, waiting)
  │  Service  │
  │ (Traffic) │
  └───────────┘
```

**Process:**
1. Blue (v1.25) serves production traffic
2. Deploy Green (v1.26) alongside Blue
3. Test Green thoroughly
4. Switch Service selector from Blue to Green
5. If issues, instant switch back to Blue
6. After validation, delete Blue

**Implementation:**
```bash
# Service initially points to blue
kubectl patch service app-service \
  -p '{"spec":{"selector":{"version":"green"}}}'

# Instant cutover! Zero downtime.
```

**Pros:**
- Instant rollback
- Zero downtime
- Safe testing

**Cons:**
- 2x resources temporarily
- Database migrations tricky

---

### Q18: What is Canary deployment?

**Answer:**
Canary routes small percentage of traffic to new version first.

**Concept:**
```
┌─────────────────────────────────────┐
│         Traffic: 100 users/sec      │
└──────────────┬──────────────────────┘
               │
      ┌────────┴─────────┐
      │                  │
   90 users           10 users
      ↓                  ↓
┌──────────┐      ┌──────────┐
│  Stable  │      │  Canary  │
│  v1.25   │      │  v1.26   │
│ 9 pods   │      │  1 pod   │
└──────────┘      └──────────┘
```

**Process:**
1. Deploy canary (10% traffic)
2. Monitor metrics, errors, logs
3. If healthy, increase canary %
4. Eventually, canary becomes stable
5. If issues, delete canary

**Implementation:**
```yaml
# Stable: 9 replicas
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-stable
spec:
  replicas: 9

---
# Canary: 1 replica
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-canary
spec:
  replicas: 1

# Service selects both (10% to canary)
```

**Gradually increase:**
```bash
# 20% canary
kubectl scale deployment app-canary --replicas=2
kubectl scale deployment app-stable --replicas=8

# 50% canary
kubectl scale deployment app-canary --replicas=5
kubectl scale deployment app-stable --replicas=5
```

---

## Troubleshooting Questions {#troubleshooting}

### Q19: Deployment stuck at "Waiting for rollout to finish". How to troubleshoot?

**Answer:**

**Steps to troubleshoot:**

**1. Check deployment status:**
```bash
kubectl rollout status deployment/app
# Output: Waiting for deployment "app" rollout to finish: 1 out of 3 new replicas have been updated...
```

**2. Check pod status:**
```bash
kubectl get pods
# Look for: Pending, ImagePullBackOff, CrashLoopBackOff
```

**3. Describe problematic pod:**
```bash
kubectl describe pod <pod-name>
# Check Events section
```

**4. Check logs:**
```bash
kubectl logs <pod-name>
kubectl logs <pod-name> --previous  # Previous crashed container
```

**Common causes:**

| Issue | Symptom | Solution |
|-------|---------|----------|
| Image not found | ImagePullBackOff | Fix image name/tag |
| App crashes | CrashLoopBackOff | Check logs |
| No resources | Pending | Add nodes or reduce requests |
| Failed health check | Not Ready | Fix liveness/readiness probe |

**5. Rollback if needed:**
```bash
kubectl rollout undo deployment/app
```

---

### Q20: How to debug a CrashLoopBackOff in a Deployment?

**Answer:**

**CrashLoopBackOff** = Container starts, crashes, Kubernetes restarts it, repeat.

**Debugging steps:**

**1. Check pod logs:**
```bash
kubectl logs <pod-name>
kubectl logs <pod-name> --previous  # Logs from crashed container
```

**2. Describe pod:**
```bash
kubectl describe pod <pod-name>
# Look for:
# - Liveness probe failed
# - Exit code (0=success, 1=error, 137=killed)
# - Restart count
```

**3. Check events:**
```bash
kubectl get events --sort-by=.metadata.creationTimestamp | grep <pod-name>
```

**4. Exec into container (if possible):**
```bash
kubectl exec -it <pod-name> -- sh
# Check app configuration, files, environment
```

**5. Common causes:**

| Cause | Detection | Fix |
|-------|-----------|-----|
| Application error | Check logs | Fix code |
| Missing config | `describe pod` | Add ConfigMap |
| Wrong command | `describe pod` | Fix command/args |
| Failed health check | Events | Adjust probe settings |
| Resource limits | `describe pod` | Increase limits |

**6. Temporary fixes for debugging:**
```yaml
# Disable liveness probe temporarily
livenessProbe:
  exec:
    command: ['true']  # Always succeeds

# Or increase failure threshold
livenessProbe:
  failureThreshold: 10  # More retries
```

---

## Scenario-Based Questions {#scenarios}

### Q21: You deployed a bad version to production. Walk through recovery.

**Answer:**

**Scenario:** Deployed v2.0 with critical bug. Users affected.

**Immediate actions (under 60 seconds):**

```bash
# 1. Quick rollback (5 seconds)
kubectl rollout undo deployment/app

# 2. Monitor rollback
kubectl rollout status deployment/app

# 3. Verify pods healthy
kubectl get pods -w

# 4. Check application working
curl http://app-service/health
```

**Post-recovery:**

```bash
# 1. Verify all pods on old version
kubectl describe deployment app | grep Image

# 2. Check logs from failed version
kubectl logs deployment/app --previous

# 3. Get failure details
kubectl rollout history deployment/app

# 4. Document incident
# - What failed?
# - How many users affected?
# - Recovery time?
```

**Prevention for next time:**

1. **Add smoke tests:**
```yaml
readinessProbe:
  httpGet:
    path: /health
  failureThreshold: 3
```

2. **Use Canary deployment** (10% traffic first)

3. **Automated rollback:**
```yaml
progressDeadlineSeconds: 600  # Rollback if stuck > 10 min
```

4. **Better testing** (staging environment)

---

### Q22: Your deployment needs to scale from 3 to 100 pods. What considerations?

**Answer:**

**Challenges:**

1. **Resource availability**
2. **Image pull time**
3. **Application startup**
4. **Network limits**
5. **Load balancer capacity**

**Solution:**

**1. Pre-check cluster capacity:**
```bash
# Check available resources
kubectl describe nodes | grep -A 5 "Allocated resources"

# Estimate: 100 pods * 128Mi = 12.8GB memory needed
```

**2. Use gradual scaling:**
```bash
# Don't scale 3→100 instantly!
kubectl scale deployment app --replicas=10
# Wait, verify
kubectl scale deployment app --replicas=30
# Wait, verify
kubectl scale deployment app --replicas=100
```

**3. Optimize for fast scaling:**
```yaml
spec:
  strategy:
    rollingUpdate:
      maxSurge: 50  # Create many pods quickly
```

**4. Pre-pull images:**
```bash
# Use DaemonSet to pre-pull on all nodes
kubectl apply -f image-pre-puller.yaml
```

**5. Configure autoscaling instead:**
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
spec:
  minReplicas: 3
  maxReplicas: 100
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        averageUtilization: 70
```

**6. Monitor scaling:**
```bash
kubectl get pods -w
kubectl top nodes
kubectl top pods
```

**Timeline:**
- 3→10 pods: 30 seconds
- 10→30 pods: 1 minute
- 30→100 pods: 3-5 minutes

Total: ~5-7 minutes for safe scaling

---

### Q23: How would you implement a maintenance window with zero downtime?

**Answer:**

**Scenario:** Need to update all pods for security patch during business hours.

**Strategy:**

**1. Prepare:**
```bash
# Verify current state
kubectl get deployment app
kubectl get pods -o wide

# Check revision history
kubectl rollout history deployment/app
```

**2. Configure safe rollout:**
```yaml
spec:
  replicas: 10
  strategy:
    rollingUpdate:
      maxSurge: 2        # Don't overwhelm cluster
      maxUnavailable: 1  # Keep 9/10 pods always running
```

**3. Update with monitoring:**
```bash
# Terminal 1: Update
kubectl set image deployment/app nginx=nginx:1.26-patched --record

# Terminal 2: Watch pods
kubectl get pods -w

# Terminal 3: Monitor rollout
kubectl rollout status deployment/app

# Terminal 4: Check application health
watch -n 2 'curl -s http://app/health'
```

**4. Validate during rollout:**
```bash
# Check error rates
kubectl logs -l app=app --since=1m | grep ERROR

# Monitor resource usage
kubectl top pods -l app=app
```

**5. Rollback plan ready:**
```bash
# If ANY issues:
kubectl rollout undo deployment/app
```

**Result:** Zero downtime!
- 10 pods → 11 pods (maxSurge)
- Terminate 1 old → 10 pods (9 old, 1 new)
- Continue until all updated
- Users never affected

---

**📝 CKA Exam Tips:**

1. **Know rollback commands by heart**
2. **Understand maxSurge/maxUnavailable**
3. **Practice scaling quickly**
4. **Can troubleshoot stuck deployments**
5. **Understand Blue-Green vs Canary**

**Most tested topics:**
- Rolling updates (30%)
- Rollbacks (25%)
- Scaling (20%)
- Troubleshooting (25%)

---

**Practice these scenarios multiple times!**