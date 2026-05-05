# 🗺️ Kubernetes Debugging Guide — Systematic Methodology

> Day 74 | DevOps Mastery Series

This guide teaches you **how to think** about Kubernetes debugging — not just which commands to run, but *why* and *in what order*.

---

## The Debugging Mindset

> "Every Kubernetes failure is a layer problem. Find the layer first, then dig in."

Three layers govern almost every failure:

```
┌─────────────────────────────────────┐
│  Layer 3: APPLICATION               │  ← Code bugs, config errors, missing secrets
├─────────────────────────────────────┤
│  Layer 2: KUBERNETES OBJECTS        │  ← Pod spec, Service selector, RBAC, Quotas
├─────────────────────────────────────┤
│  Layer 1: INFRASTRUCTURE            │  ← Nodes, Network CNI, Storage CSI
└─────────────────────────────────────┘
```

**Rule:** Always start at Layer 2 (K8s objects). Work up to app issues or down to infra issues based on what you find.

---

## Part 1: Pod Debugging — Decision Tree

```
Pod not working?
       │
       ▼
kubectl get pod → What's the STATUS?
       │
       ├── Pending ──────────────────► Section 1.A
       ├── CrashLoopBackOff ─────────► Section 1.B  
       ├── OOMKilled ────────────────► Section 1.C
       ├── ImagePullBackOff ─────────► Section 1.D
       ├── Init:X/Y or Init:Error ───► Section 1.E
       ├── Running but unhealthy ────► Section 1.F
       └── Terminating (stuck) ──────► Section 1.G
```

---

### Section 1.A — Pending Pod

**Goal:** Find why the scheduler cannot place the pod.

```bash
# Step 1: Read the scheduler message
kubectl describe pod <pod> -n <ns> | grep -A15 "Events:"
# Look for: "0/3 nodes are available: ..."

# Step 2: Decode the message
# "Insufficient cpu"          → Node resource exhausted
# "node(s) had taint"         → Taint/toleration mismatch
# "node(s) didn't match"      → NodeSelector/Affinity mismatch
# "pod has unbound PVC"       → Storage not provisioned yet

# Step 3: Check nodes
kubectl get nodes
kubectl describe nodes | grep -E "(Taints|Allocatable|Conditions)"
kubectl top nodes
```

**Resolution paths:**

| Scheduler Message | Action |
|-------------------|--------|
| Insufficient CPU/memory | Add nodes, reduce requests, or adjust LimitRange |
| Node taint | Add toleration to pod or remove taint from node |
| NodeSelector mismatch | Fix label on node or remove selector from pod |
| PVC unbound | Fix StorageClass / provisioner |

---

### Section 1.B — CrashLoopBackOff

**Goal:** Find what is making the container exit.

```bash
# Step 1: Get exit code (tells you everything)
kubectl get pod <pod> -n <ns> \
  -o jsonpath='{.status.containerStatuses[0].lastState.terminated}'

# Step 2: Read crash logs
kubectl logs <pod> -n <ns> --previous

# Step 3: Check liveness probe settings
kubectl get pod <pod> -n <ns> -o yaml | grep -A15 livenessProbe
```

**Exit code reference:**

| Exit Code | Meaning | Action |
|-----------|---------|--------|
| `0` | Clean exit (should not crash loop) | Check restart policy |
| `1` | App error | Check application logs |
| `137` | OOMKilled (SIGKILL) | Increase memory limit |
| `139` | Segfault | Check app / binary |
| `143` | SIGTERM (graceful) | Check terminationGracePeriodSeconds |

**Liveness probe too aggressive?**
```yaml
# Bad — kills container before it starts
livenessProbe:
  initialDelaySeconds: 3     # Too short for slow apps

# Better
livenessProbe:
  initialDelaySeconds: 30    # Give the app time to start
  periodSeconds: 10
  failureThreshold: 3
```

---

### Section 1.C — OOMKilled

**Goal:** Identify and fix memory limit.

```bash
# Confirm OOM
kubectl describe pod <pod> -n <ns> | grep -B2 -A5 OOMKilled

# Current usage
kubectl top pod <pod> -n <ns>

# Current limits
kubectl get pod <pod> -n <ns> \
  -o jsonpath='{.spec.containers[*].resources}'
```

**Fix in Deployment:**
```yaml
resources:
  requests:
    memory: "256Mi"    # Reservation for scheduling
  limits:
    memory: "1Gi"      # Hard cap — increase if OOMKilled
```

---

### Section 1.D — ImagePullBackOff

**Checklist:**

```bash
# 1. Is the image name/tag correct?
kubectl get pod <pod> -n <ns> \
  -o jsonpath='{.spec.containers[0].image}'
# → Try pulling manually: docker pull <image>

# 2. Is the registry private?
kubectl describe pod <pod> -n <ns> | grep "Failed to pull image"

# 3. Does imagePullSecret exist?
kubectl get secrets -n <ns>
kubectl get pod <pod> -n <ns> \
  -o jsonpath='{.spec.imagePullSecrets}'

# 4. Is the secret in the same namespace?
```

---

### Section 1.E — Init Container Failures

```bash
# See which init container is failing
kubectl describe pod <pod> -n <ns> | grep -A5 "Init Containers:"

# Read its logs
kubectl logs <pod> -n <ns> -c <init-container-name>
```

**Common init container patterns and fixes:**

| Pattern | What It Does | If It Fails |
|---------|-------------|-------------|
| `wait-for-db` | Checks DB is ready | DB not deployed / wrong host |
| `migrations` | Runs DB schema migration | Bad credentials or schema |
| `download-config` | Pulls config from S3/Vault | Network policy / IRSA issue |

---

### Section 1.F — Pod Running but Unhealthy

```bash
# Check readiness probe
kubectl describe pod <pod> -n <ns> | grep -A10 readinessProbe

# Is the pod receiving traffic? Check endpoints
kubectl get endpoints <service> -n <ns>
# Empty endpoints = pod not ready = readiness probe failing

# Exec in to test manually
kubectl exec -it <pod> -n <ns> -- curl localhost:<port>/health
```

---

### Section 1.G — Stuck Terminating

```bash
# Check finalizers
kubectl get pod <pod> -n <ns> -o yaml | grep -A5 finalizers

# Remove finalizers
kubectl patch pod <pod> -n <ns> \
  -p '{"metadata":{"finalizers":null}}' --type=merge
```

---

## Part 2: Service Connectivity — Step-by-Step

### The Connectivity Chain

```
Client → Ingress → Service → Endpoint → Pod
```

Debug each link in the chain, from right to left (pod first):

```bash
# Step 1: Is the pod healthy?
kubectl get pods -n <ns> -l <selector>

# Step 2: Are there endpoints? (Most common failure point)
kubectl get endpoints <svc> -n <ns>
# Empty? → Label mismatch between service and pods

# Step 3: Compare labels
kubectl get svc <svc> -n <ns> -o yaml | grep -A5 selector
kubectl get pods -n <ns> --show-labels

# Step 4: Can another pod reach the service?
kubectl run test --rm -it --image=busybox -- \
  wget -qO- http://<svc>.<ns>.svc.cluster.local:<port>/

# Step 5: DNS resolving?
kubectl run test --rm -it --image=busybox -- \
  nslookup <svc>.<ns>.svc.cluster.local

# Step 6: Check Ingress (if applicable)
kubectl describe ingress <name> -n <ns>
kubectl logs -n ingress-nginx deploy/ingress-nginx-controller --tail=20
```

---

## Part 3: Node Triage — Runbook

When a node goes `NotReady`:

```bash
# Step 1: Identify the problem
kubectl describe node <node> | grep -A10 Conditions:

# Step 2: SSH to the node
ssh <node-ip>

# Step 3: Check kubelet
sudo systemctl status kubelet
sudo journalctl -u kubelet --since "10 minutes ago" -n 50

# Step 4: Check disk
df -h
# Full disk → clean images, logs

# Step 5: Check memory
free -h
top

# Step 6: Check container runtime
sudo systemctl status containerd
# or
sudo systemctl status docker

# Step 7: Network reachability
ping <control-plane-ip>
curl -k https://<api-server-ip>:6443/healthz

# Step 8: If fixable → restart kubelet
sudo systemctl restart kubelet

# Step 9: If not fixable → drain and replace
kubectl drain <node> --ignore-daemonsets --delete-emptydir-data
```

---

## Part 4: Cluster Health Check Runbook

Run this when something "feels wrong" but you're not sure where:

```bash
#!/bin/bash
echo "=== Node Status ==="
kubectl get nodes -o wide

echo "=== Component Status ==="
kubectl get pods -n kube-system

echo "=== Failed Pods (all namespaces) ==="
kubectl get pods -A | grep -v Running | grep -v Completed | grep -v Pending

echo "=== Recent Warning Events ==="
kubectl get events -A --field-selector type=Warning \
  --sort-by='.lastTimestamp' | tail -30

echo "=== Resource Usage ==="
kubectl top nodes
kubectl top pods -A --sort-by=cpu | head -10

echo "=== PVC Status ==="
kubectl get pvc -A | grep -v Bound
```

---

## Part 5: Observability-First Debugging

### What to Check First for Production Incidents

**Metrics → Logs → Traces** (in that order)

```bash
# 1. Are nodes healthy? (Metrics)
kubectl top nodes

# 2. Any pods restarting? (Metrics)
kubectl get pods -A | awk '{print $5}' | sort -rn | head

# 3. Any warning events? (Events)
kubectl get events -A --field-selector type=Warning \
  --sort-by='.lastTimestamp' | tail -20

# 4. Specific pod logs (Logs)
kubectl logs <pod> -n <ns> --since=10m

# 5. Distributed traces (if Jaeger/Tempo deployed)
# → Use your observability platform
```

---

## Quick Reference: Kubectl Flags You Must Know

| Flag | Use Case |
|------|----------|
| `--previous` | Logs from crashed container |
| `-c <container>` | Specific container in multi-container pod |
| `-A` / `--all-namespaces` | Cluster-wide scope |
| `--sort-by='.lastTimestamp'` | Sort events by time |
| `--field-selector type=Warning` | Filter warning events |
| `-o wide` | Show node/IP columns |
| `-o yaml` | Full spec dump |
| `-o jsonpath='{...}'` | Extract specific fields |
| `--since=10m` | Recent logs only |
| `-f` | Stream/follow logs |
| `--dry-run=client` | Preview changes |

---

*Continue to [interview-questions-answers.md](./interview-questions-answers.md) →*
