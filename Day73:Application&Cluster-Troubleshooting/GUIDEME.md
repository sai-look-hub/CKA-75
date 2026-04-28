# GUIDEME — Day 73: Application & Cluster Troubleshooting

## Step-by-Step Hands-On Lab

---

## 🔧 Lab Setup

```bash
# Create dedicated namespace
kubectl create namespace debug-lab

# Label it for easy cleanup
kubectl label namespace debug-lab purpose=troubleshooting-lab day=73
```

---

## 🧪 Scenario 1: CrashLoopBackOff

### What's broken
A pod that exits immediately due to a bad command, causing Kubernetes to restart it in a loop with exponential backoff.

### Apply the broken manifest
```bash
kubectl apply -f manifests/01-broken-pod-crashloop.yaml -n debug-lab
```

### Diagnose
```bash
# Step 1 — Check pod status
kubectl get pod crashloop-demo -n debug-lab

# Expected output:
# NAME             READY   STATUS             RESTARTS   AGE
# crashloop-demo   0/1     CrashLoopBackOff   4          2m

# Step 2 — Check previous container logs (the crash output)
kubectl logs crashloop-demo -n debug-lab --previous

# Step 3 — Describe for events
kubectl describe pod crashloop-demo -n debug-lab
# Look for: Exit Code, Last State, Events section

# Step 4 — Identify root cause
# Exit Code 1 = application error
# Exit Code 137 = OOMKilled
# Exit Code 139 = Segfault
```

### Fix
```bash
kubectl patch pod crashloop-demo -n debug-lab \
  --type='json' \
  -p='[{"op":"replace","path":"/spec/containers/0/command","value":["sh","-c","echo hello && sleep 3600"]}]'

# Or delete and recreate with fixed manifest
kubectl apply -f manifests/09-fixed-versions.yaml -n debug-lab
```

---

## 🧪 Scenario 2: OOMKilled

### What's broken
Container is given a memory limit of 30Mi but the app allocates 100Mi.

### Apply
```bash
kubectl apply -f manifests/02-broken-pod-oom.yaml -n debug-lab
```

### Diagnose
```bash
# Check state
kubectl get pod oom-demo -n debug-lab

# Describe reveals:
# Last State: Terminated
#   Reason: OOMKilled
#   Exit Code: 137

kubectl describe pod oom-demo -n debug-lab | grep -A5 "Last State"

# Check actual usage
kubectl top pod oom-demo -n debug-lab
```

### Fix
```bash
# Increase memory limit in manifest
# resources:
#   limits:
#     memory: "256Mi"
#   requests:
#     memory: "128Mi"
kubectl apply -f manifests/09-fixed-versions.yaml -n debug-lab
```

---

## 🧪 Scenario 3: ImagePullBackOff

### What's broken
Image tag `nginx:nonexistent-tag-9999` does not exist in the registry.

### Apply
```bash
kubectl apply -f manifests/03-broken-pod-imagepull.yaml -n debug-lab
```

### Diagnose
```bash
kubectl describe pod imagepull-demo -n debug-lab

# Events section shows:
# Failed to pull image "nginx:nonexistent-tag-9999": rpc error
# Back-off pulling image "nginx:nonexistent-tag-9999"

# Check if it's an auth issue vs bad tag:
# - ErrImagePull = transient pull failure
# - ImagePullBackOff = repeated failures, backing off
# - For private registries, check imagePullSecrets
```

### Fix
```bash
# Correct the image tag
kubectl set image pod/imagepull-demo demo-container=nginx:1.25 -n debug-lab

# For private registry — create pull secret:
kubectl create secret docker-registry regcred \
  --docker-server=<registry> \
  --docker-username=<user> \
  --docker-password=<pass> \
  -n debug-lab
```

---

## 🧪 Scenario 4: Pod Stuck in Pending

### What's broken
Pod requests 64 CPU cores — more than any node has.

### Apply
```bash
kubectl apply -f manifests/04-broken-pod-pending.yaml -n debug-lab
```

### Diagnose
```bash
kubectl describe pod pending-demo -n debug-lab

# Events:
# 0/3 nodes are available: 3 Insufficient cpu

# Check node capacity
kubectl describe nodes | grep -A5 "Allocated resources"

# Check if taints are blocking
kubectl describe nodes | grep Taints

# Check resource quotas
kubectl describe resourcequota -n debug-lab
```

### Common Pending Causes
| Cause | Event Message |
|-------|--------------|
| Insufficient CPU | `0/N nodes available: N Insufficient cpu` |
| Insufficient Memory | `0/N nodes available: N Insufficient memory` |
| No matching node selector | `0/N nodes available: N node(s) didn't match node selector` |
| Taints | `0/N nodes available: N node(s) had taints` |
| PVC unbound | `pod has unbound immediate PersistentVolumeClaims` |

---

## 🧪 Scenario 5: Service Not Routing Traffic

### What's broken
Service selector `app: frontend` but pod has label `app: web` — endpoints list is empty.

### Apply
```bash
kubectl apply -f manifests/05-broken-service-selector.yaml -n debug-lab
```

### Diagnose
```bash
# Step 1 — Check endpoints (most important command!)
kubectl get endpoints broken-svc -n debug-lab
# NAME          ENDPOINTS   AGE
# broken-svc    <none>      30s   ← THIS is the smoking gun

# Step 2 — Compare service selector vs pod labels
kubectl describe svc broken-svc -n debug-lab | grep Selector
kubectl get pods -n debug-lab --show-labels

# Step 3 — Port mismatch check
kubectl describe svc broken-svc -n debug-lab | grep Port
# Service port 80 → Pod port 8080?

# Step 4 — DNS resolution test
kubectl run dns-test --image=busybox --rm -it --restart=Never -- \
  nslookup broken-svc.debug-lab.svc.cluster.local

# Step 5 — Connectivity test
kubectl run curl-test --image=curlimages/curl --rm -it --restart=Never -- \
  curl -v broken-svc.debug-lab.svc.cluster.local
```

### Fix
```bash
# Option A: Fix service selector
kubectl patch svc broken-svc -n debug-lab \
  -p '{"spec":{"selector":{"app":"web"}}}'

# Option B: Fix pod labels
kubectl label pod <pod-name> app=frontend --overwrite -n debug-lab

# Verify fix
kubectl get endpoints broken-svc -n debug-lab
```

---

## 🧪 Scenario 6: Node in NotReady State

### Simulate
```bash
# On the node (or via exec):
# Stop kubelet to simulate NotReady
sudo systemctl stop kubelet
```

### Diagnose
```bash
# Check node status
kubectl get nodes
# NAME     STATUS     ROLES   AGE   VERSION
# node01   NotReady   <none>  1d    v1.28.0

# Get conditions
kubectl describe node node01 | grep -A10 Conditions

# Common conditions:
# MemoryPressure — node OOM
# DiskPressure  — disk full
# PIDPressure   — too many processes
# Ready=False   — kubelet not reporting

# Check kubelet logs (SSH to node)
journalctl -u kubelet -f --since "10 minutes ago"

# Check node resource usage
kubectl top node node01

# Check what's running on the node
kubectl get pods -A --field-selector spec.nodeName=node01
```

### Fix
```bash
# If disk pressure — free space
df -h  # on node
docker system prune -f  # or crictl

# If kubelet stopped
sudo systemctl start kubelet
sudo systemctl enable kubelet

# If node needs eviction
kubectl drain node01 --ignore-daemonsets --delete-emptydir-data
kubectl cordon node01   # prevent new scheduling
```

---

## 🧪 Scenario 7: Ephemeral Debug Container

When a pod has no shell (distroless image), use ephemeral containers:

```bash
# Inject debug container into running pod
kubectl debug -it <pod-name> -n debug-lab \
  --image=busybox \
  --target=<container-name>

# Copy pod for debugging (creates a new pod)
kubectl debug pod/<pod-name> -n debug-lab \
  --copy-to=debug-copy \
  --image=ubuntu \
  -- bash
```

---

## 🔍 Cluster-Level Diagnostics

```bash
# Check control plane components
kubectl get componentstatuses  # deprecated but works on older clusters
kubectl get pods -n kube-system

# Check API server
kubectl cluster-info
kubectl cluster-info dump --output-directory=/tmp/cluster-dump

# etcd health (run from control plane node)
ETCDCTL_API=3 etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  endpoint health

# Check certificate expiry
kubeadm certs check-expiration

# RBAC issues — check if action is denied
kubectl auth can-i get pods -n debug-lab --as=system:serviceaccount:debug-lab:default
```

---

## 🏁 Cleanup

```bash
kubectl delete namespace debug-lab
```
