# TROUBLESHOOTING-Day73.md
# Kubernetes Application & Cluster Troubleshooting — Complete Reference

---

## 🔴 SECTION 1: Pod Failures

---

### Problem: CrashLoopBackOff

**Symptoms:**
```
NAME    READY   STATUS             RESTARTS   AGE
mypod   0/1     CrashLoopBackOff   8          15m
```

**Diagnosis Steps:**
```bash
# 1. Read the crash logs (--previous is critical)
kubectl logs <pod> --previous -n <ns>

# 2. Check last known state
kubectl describe pod <pod> -n <ns> | grep -A10 "Last State"

# 3. Check exit code
#    Exit 1   → Application error
#    Exit 127 → Command not found
#    Exit 137 → OOMKilled (SIGKILL)
#    Exit 139 → Segfault (SIGSEGV)
#    Exit 143 → Graceful termination (SIGTERM)

# 4. Check for missing config
kubectl describe pod <pod> -n <ns> | grep -A5 "Environment"
kubectl get cm,secret -n <ns>
```

**Common Root Causes & Fixes:**

| Root Cause | Evidence | Fix |
|------------|----------|-----|
| App startup error | Exit 1 in logs | Fix application code/config |
| Missing env var | `KeyError` / `undefined` in logs | Add env var or configmap ref |
| Bad command | `exec: not found` | Fix container command/args |
| Config mount missing | `No such file` | Check configmap/secret mounts |
| DB not reachable | Connection refused | Fix DB URL, check network policy |

---

### Problem: OOMKilled

**Symptoms:**
```
Last State: Terminated
  Reason: OOMKilled
  Exit Code: 137
```

**Diagnosis:**
```bash
kubectl describe pod <pod> -n <ns> | grep -B2 -A5 "OOMKilled"
kubectl top pod <pod> -n <ns>
kubectl top pod <pod> -n <ns> --containers
```

**Fix:**
```yaml
resources:
  requests:
    memory: "256Mi"   # Scheduler uses this
  limits:
    memory: "512Mi"   # OOM trigger point — increase this
```

**Prevention:** Set VPA (Vertical Pod Autoscaler) to auto-tune memory.

---

### Problem: ImagePullBackOff / ErrImagePull

**Diagnosis:**
```bash
kubectl describe pod <pod> -n <ns> | grep -A10 "Events"

# For private registry — check pull secret
kubectl get pod <pod> -n <ns> -o jsonpath='{.spec.imagePullSecrets}'

# Verify secret exists
kubectl get secret regcred -n <ns>
```

**Fix Matrix:**

| Scenario | Fix |
|----------|-----|
| Wrong tag | Update image tag in spec |
| Private registry, no secret | Create docker-registry secret + add imagePullSecrets |
| Expired credentials | Recreate pull secret with new creds |
| Registry unreachable | Check node egress/firewall rules |
| Rate limit (Docker Hub) | Add credentials even for public images |

```bash
# Create pull secret
kubectl create secret docker-registry regcred \
  --docker-server=<server> \
  --docker-username=<user> \
  --docker-password=<token> \
  -n <ns>
```

---

### Problem: Pod Stuck in Pending

**Diagnosis:**
```bash
kubectl describe pod <pod> -n <ns>
# Read the Events section at the bottom

# Check node resources
kubectl describe nodes | grep -A8 "Allocated resources"

# Check taints
kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints

# Check resource quotas
kubectl get resourcequota -n <ns>
kubectl describe resourcequota -n <ns>

# Check PVC status
kubectl get pvc -n <ns>
```

**Common Events & Fixes:**

| Event Message | Root Cause | Fix |
|---------------|-----------|-----|
| `Insufficient cpu` | Node CPU maxed | Reduce requests or add nodes |
| `Insufficient memory` | Node RAM maxed | Reduce requests or add nodes |
| `didn't match node selector` | Wrong labels | Fix nodeSelector or node labels |
| `had taints that pod didn't tolerate` | Untolerated taint | Add toleration to pod spec |
| `has unbound PersistentVolumeClaims` | PVC not bound | Fix storageClass or PV |
| `maximum pods exceeded` | Node pod limit | Spread across more nodes |

---

### Problem: Pod Stuck in Terminating

```bash
# Check finalizers
kubectl get pod <pod> -n <ns> -o jsonpath='{.metadata.finalizers}'

# Force delete (last resort)
kubectl delete pod <pod> -n <ns> --grace-period=0 --force

# Remove finalizers
kubectl patch pod <pod> -n <ns> \
  -p '{"metadata":{"finalizers":[]}}' \
  --type=merge
```

---

## 🔴 SECTION 2: Service & Networking Failures

---

### Problem: Service Has No Endpoints

**This is the #1 service issue — always check endpoints first.**

```bash
kubectl get endpoints <svc> -n <ns>
# If ENDPOINTS shows <none> → selector mismatch

# Compare selector vs pod labels
kubectl describe svc <svc> -n <ns> | grep Selector
kubectl get pods -n <ns> --show-labels
```

**Fix:**
```bash
# Fix service selector
kubectl patch svc <svc> -n <ns> \
  -p '{"spec":{"selector":{"app":"correct-label-value"}}}'
```

---

### Problem: DNS Resolution Failing

```bash
# Test DNS from inside cluster
kubectl run dns-debug --image=busybox --rm -it --restart=Never -- sh

# Inside the debug pod:
nslookup kubernetes.default
nslookup <svc>.<ns>.svc.cluster.local

# Check CoreDNS
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl logs -n kube-system -l k8s-app=kube-dns
```

**Full DNS Name Format:**
```
<service>.<namespace>.svc.<cluster-domain>
# Example:
myapp.production.svc.cluster.local
```

---

### Problem: Cannot Connect to Service from Another Pod

**5-Step Network Debug Process:**
```bash
# 1. Does the service exist?
kubectl get svc <svc> -n <ns>

# 2. Do endpoints exist?
kubectl get endpoints <svc> -n <ns>

# 3. Can we reach the ClusterIP?
kubectl run netdebug --image=busybox --rm -it --restart=Never -- \
  wget -qO- <clusterIP>:<port>

# 4. Can we resolve DNS?
kubectl run netdebug --image=busybox --rm -it --restart=Never -- \
  nslookup <svc>.<ns>

# 5. Is a NetworkPolicy blocking?
kubectl get networkpolicy -n <ns>
kubectl describe networkpolicy -n <ns>
```

---

### Problem: NodePort / LoadBalancer Not Accessible

```bash
# Check service type
kubectl get svc <svc> -n <ns>

# For NodePort — verify firewall rules allow the port (30000-32767)
# Check actual NodePort assigned
kubectl get svc <svc> -n <ns> -o jsonpath='{.spec.ports[0].nodePort}'

# For LoadBalancer — check EXTERNAL-IP
kubectl get svc <svc> -n <ns>
# If EXTERNAL-IP = <pending>, check cloud provider integration / metallb

# Verify kube-proxy is running on nodes
kubectl get pods -n kube-system -l k8s-app=kube-proxy
```

---

## 🔴 SECTION 3: Node Issues

---

### Problem: Node in NotReady State

```bash
# Identify affected node
kubectl get nodes

# Get detailed conditions
kubectl describe node <node> | grep -A20 "Conditions:"

# Conditions to look for:
# MemoryPressure=True  → node is low on memory
# DiskPressure=True    → node disk is full
# PIDPressure=True     → too many processes
# Ready=False          → kubelet stopped reporting

# SSH to node and check kubelet
sudo systemctl status kubelet
sudo journalctl -u kubelet -n 100 --no-pager

# Check node disk usage
df -h
du -sh /var/lib/docker  # or /var/lib/containerd
```

**Fixes by Condition:**

| Condition | Fix |
|-----------|-----|
| DiskPressure | Clean docker images: `docker system prune -af` |
| MemoryPressure | Kill memory-hungry processes, add swap, or add RAM |
| PIDPressure | Find rogue processes: `ps aux --sort=-%cpu \| head` |
| Ready=False (kubelet) | `systemctl restart kubelet` |
| Ready=False (network) | Check CNI plugin, restart network plugin pods |

---

### Problem: Node Disk Pressure

```bash
# SSH to node
df -h
du -sh /var/lib/containerd/*

# Clean container images
crictl rmi --prune         # Remove unused images
crictl rm $(crictl ps -a -q)  # Remove stopped containers

# Or with docker
docker system prune -af --volumes

# Clean logs
find /var/log -name "*.log" -mtime +7 -delete
journalctl --vacuum-size=500M
```

---

## 🔴 SECTION 4: Control Plane Issues

---

### Problem: API Server Unreachable

```bash
# Check API server pod
kubectl get pods -n kube-system | grep api-server
# If kubectl itself fails, SSH to control plane:
sudo crictl ps | grep kube-apiserver
sudo crictl logs <api-server-container-id>

# Check API server manifest
cat /etc/kubernetes/manifests/kube-apiserver.yaml

# Check certificates
sudo openssl x509 -in /etc/kubernetes/pki/apiserver.crt -noout -dates
kubeadm certs check-expiration
```

---

### Problem: etcd Unhealthy

```bash
# Check etcd pod
kubectl get pods -n kube-system | grep etcd
kubectl logs -n kube-system etcd-<node>

# Run etcdctl health check
ETCDCTL_API=3 etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/peer.crt \
  --key=/etc/kubernetes/pki/etcd/peer.key \
  endpoint health

# Check etcd members
ETCDCTL_API=3 etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/peer.crt \
  --key=/etc/kubernetes/pki/etcd/peer.key \
  member list
```

---

### Problem: Certificate Expired

```bash
# Check all cert expiry dates
kubeadm certs check-expiration

# Renew all certs
kubeadm certs renew all

# Restart control plane components
sudo systemctl restart kubelet
# Static pods restart automatically when certs are renewed
```

---

## 🔴 SECTION 5: RBAC & Auth Issues

---

### Problem: Forbidden / Unauthorized

```bash
# Check what a user/SA can do
kubectl auth can-i get pods -n production \
  --as=system:serviceaccount:default:myapp-sa

kubectl auth can-i list secrets -n production \
  --as=system:serviceaccount:default:myapp-sa

# Get all permissions for a service account
kubectl get rolebindings,clusterrolebindings -A \
  -o jsonpath='{range .items[*]}{.metadata.name} {.subjects[*].name}{"\n"}{end}' \
  | grep myapp-sa

# Check what roles exist
kubectl describe role <role> -n <ns>
kubectl describe clusterrole <role>
```

---

## 🔴 SECTION 6: Quick Reference — Exit Codes

| Exit Code | Signal | Meaning |
|-----------|--------|---------|
| 0 | — | Success |
| 1 | — | Application error |
| 2 | — | Misuse of shell built-in |
| 125 | — | Container failed to run |
| 126 | — | Command not executable |
| 127 | — | Command not found |
| 128+N | Signal N | Killed by signal |
| 130 | SIGINT | Ctrl+C / interrupted |
| 137 | SIGKILL | OOMKilled or force-killed |
| 139 | SIGSEGV | Segmentation fault |
| 143 | SIGTERM | Graceful termination |

---

## 🔴 SECTION 7: Troubleshooting Decision Tree

```
Pod not working?
├── kubectl get pod → STATUS?
│   ├── Pending
│   │   └── kubectl describe pod → Events?
│   │       ├── Insufficient resources → Reduce requests or scale cluster
│   │       ├── Taint → Add toleration
│   │       ├── NodeSelector → Fix labels or selector
│   │       └── PVC unbound → Fix storage class
│   ├── ImagePullBackOff
│   │   └── Bad tag? → Fix image tag
│   │   └── Private registry? → Add imagePullSecrets
│   ├── CrashLoopBackOff
│   │   └── kubectl logs --previous → Read crash output
│   │       ├── Config missing → Add env/configmap
│   │       ├── DB unreachable → Fix service/network
│   │       └── OOM → Increase memory limit
│   ├── Running but app not reachable
│   │   └── kubectl get endpoints → <none>?
│   │       ├── Yes → Fix service selector
│   │       └── No → kubectl exec curl → NetworkPolicy?
│   └── Terminating stuck
│       └── kubectl get pod -o json | grep finalizer → Remove finalizers
```
