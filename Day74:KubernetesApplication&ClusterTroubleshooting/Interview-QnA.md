# 💬 Kubernetes Troubleshooting — Interview Questions & Answers

> Day 74 | DevOps Mastery Series  
> **40+ Questions** — Beginner → Intermediate → Expert → Scenario-Based

---

## Table of Contents

- [Beginner (L1)](#beginner-l1--foundational)
- [Intermediate (L2)](#intermediate-l2--operational)
- [Expert (L3)](#expert-l3--architectural)
- [Scenario-Based](#scenario-based--real-world-incidents)
- [CKA-Style](#cka-style--hands-on-challenges)

---

## Beginner (L1) — Foundational

---

**Q1. A pod is in `CrashLoopBackOff`. What are your first three steps?**

**A:**
1. `kubectl describe pod <name> -n <ns>` — read the **Events** section for error messages and the **Last State** to get the exit code.
2. `kubectl logs <name> -n <ns> --previous` — read the logs from the **previous (crashed)** container instance, not the current one.
3. Interpret the exit code: `137` = OOMKilled (increase memory), `1` = app error (read logs), `143` = SIGTERM (check graceful shutdown handling).

---

**Q2. What is the difference between `kubectl logs <pod>` and `kubectl logs <pod> --previous`?**

**A:** `kubectl logs` shows logs from the **currently running** container. `--previous` shows logs from the **last terminated** container instance. For a CrashLoopBackOff pod, you almost always want `--previous` because the current container may have just started and the crash happened in a prior run.

---

**Q3. A pod is `Pending`. How do you find out why it's not being scheduled?**

**A:**
```bash
kubectl describe pod <name> -n <ns>
```
Look at the **Events** section. The scheduler outputs a message like:
- `"0/3 nodes are available: 3 Insufficient memory"` → Not enough resources
- `"0/3 nodes are available: node(s) had taint"` → Pod needs a matching toleration
- `"0/3 nodes are available: node(s) didn't match Pod's node affinity/selector"` → Label mismatch

---

**Q4. What does `ImagePullBackOff` mean and how do you fix it?**

**A:** The kubelet cannot pull the container image. Common causes and fixes:

| Cause | Fix |
|-------|-----|
| Wrong image name/tag | Correct the image in the pod spec |
| Private registry, no secret | Create a `docker-registry` secret and add it to `imagePullSecrets` |
| Secret in wrong namespace | Create secret in same namespace as pod |
| Network issue reaching registry | Check node network / proxy settings |

```bash
kubectl create secret docker-registry regcred \
  --docker-server=<registry> \
  --docker-username=<user> \
  --docker-password=<pass> \
  -n <namespace>
```

---

**Q5. A pod is `Running` but not receiving traffic from its Service. What do you check?**

**A:** The first thing to check is **Endpoints**:
```bash
kubectl get endpoints <service-name> -n <namespace>
```
If the endpoints list is **empty**, the Service selector does not match any pod labels. Compare:
```bash
kubectl get svc <name> -n <ns> -o jsonpath='{.spec.selector}'
kubectl get pods -n <ns> --show-labels
```
This is the most common cause — a typo in a label key or value.

---

**Q6. What is the difference between a `Readiness Probe` and a `Liveness Probe`?**

**A:**
- **Liveness Probe**: Checks if the container is alive. If it fails, kubelet **restarts** the container. Used to recover from deadlocks or infinite loops.
- **Readiness Probe**: Checks if the container is ready to serve traffic. If it fails, the pod is **removed from Service endpoints** but NOT restarted. Used during startup delays or when a pod is temporarily overloaded.

**Interview tip:** A pod can be Running + Liveness passing but Readiness failing → it won't receive traffic but won't be restarted.

---

**Q7. What does `OOMKilled` mean and how do you prevent it?**

**A:** `OOMKilled` (Out of Memory Killed) means the Linux kernel killed the container process because it exceeded its memory limit. Fix: increase the `limits.memory` in the pod spec. Also set `requests.memory` appropriately so the pod is scheduled on a node with sufficient memory.

```yaml
resources:
  requests:
    memory: "256Mi"
  limits:
    memory: "1Gi"
```

---

**Q8. How do you check the resource usage of pods?**

**A:**
```bash
kubectl top pods -n <namespace>           # Current CPU/mem usage
kubectl top pods -A --sort-by=cpu         # Most CPU-hungry pods cluster-wide
kubectl top pods -A --sort-by=memory      # Most memory-hungry pods
kubectl top nodes                          # Node-level usage
```
Requires metrics-server to be installed.

---

## Intermediate (L2) — Operational

---

**Q9. A node goes `NotReady`. Walk me through your investigation.**

**A:**
1. `kubectl describe node <name>` → Check **Conditions** section for `MemoryPressure`, `DiskPressure`, `PIDPressure`
2. SSH to the node → `sudo systemctl status kubelet` + `sudo journalctl -u kubelet -n 50`
3. Check disk: `df -h` — full `/var/lib/containerd` or `/var/log` is common
4. Check memory: `free -h`
5. Verify container runtime: `sudo systemctl status containerd`
6. Check API server connectivity: `curl -k https://<api-server>:6443/healthz`
7. Restart kubelet if fixable: `sudo systemctl restart kubelet`
8. If not fixable: `kubectl drain <node> --ignore-daemonsets` and replace

---

**Q10. What is a pod's finalizer and when does it cause stuck Terminating pods?**

**A:** Finalizers are keys in `metadata.finalizers` that prevent a resource from being deleted until all finalizers are removed. They're used by controllers to ensure cleanup (e.g., releasing cloud resources, updating IPAM). A pod gets stuck in `Terminating` when a controller that owns a finalizer has crashed or is misconfigured. Fix:
```bash
kubectl patch pod <name> -n <ns> \
  -p '{"metadata":{"finalizers":null}}' --type=merge
```

---

**Q11. How does Kubernetes DNS work? How would you debug a DNS failure?**

**A:** CoreDNS runs in `kube-system` and resolves in-cluster names. The full DNS format is: `<service>.<namespace>.svc.cluster.local`.

Debug steps:
```bash
# 1. Test resolution from a pod
kubectl run test --rm -it --image=busybox -- nslookup kubernetes.default

# 2. Check CoreDNS pods
kubectl get pods -n kube-system -l k8s-app=kube-dns

# 3. Check CoreDNS logs
kubectl logs -n kube-system -l k8s-app=kube-dns

# 4. Verify CoreDNS ConfigMap
kubectl get cm coredns -n kube-system -o yaml

# 5. Check resolv.conf in the pod
kubectl exec <pod> -n <ns> -- cat /etc/resolv.conf
```

---

**Q12. What are init containers and what problems can they cause?**

**A:** Init containers run sequentially before app containers start. They must exit 0 for the next one (or the main container) to start. Common issues:
- Init container waits forever for a dependency that's down
- DB credential rotation causes init container auth failure
- Network policy blocks init container's external calls
- Resource limits too low → init container OOMKilled before main container starts

Debugging:
```bash
kubectl logs <pod> -n <ns> -c <init-container-name>
```

---

**Q13. A deployment rollout is stuck. How do you investigate and rollback?**

**A:**
```bash
# Check rollout status
kubectl rollout status deployment/<name> -n <ns>

# See rollout history
kubectl rollout history deployment/<name> -n <ns>

# Check which ReplicaSet is new/old
kubectl get rs -n <ns>

# Check new pods
kubectl describe pod <new-pod> -n <ns>
kubectl logs <new-pod> -n <ns>

# Rollback to previous version
kubectl rollout undo deployment/<name> -n <ns>

# Rollback to specific revision
kubectl rollout undo deployment/<name> -n <ns> --to-revision=3
```

---

**Q14. How do you check if RBAC is causing a permission error?**

**A:**
```bash
# Test if a service account can perform an action
kubectl auth can-i get pods \
  --as=system:serviceaccount:<namespace>:<sa-name> \
  -n <namespace>

# List all permissions for a service account
kubectl auth can-i --list \
  --as=system:serviceaccount:<namespace>:<sa-name> \
  -n <namespace>

# Find what roles are bound to the SA
kubectl get rolebinding,clusterrolebinding -A -o wide | grep <sa-name>
```

---

**Q15. What is the difference between `kubectl exec` and `kubectl debug`?**

**A:**
- `kubectl exec` connects to an **already-running** container in a pod. Requires the container to be running and have the needed tools (sh, bash, etc.)
- `kubectl debug` creates an **ephemeral debug container** in a running pod (K8s 1.23+) that shares the pod's network/PID namespace. Useful when the main container is too minimal (distroless images) or has crashed.

```bash
kubectl debug -it <pod> -n <ns> \
  --image=busybox \
  --target=<main-container>
```

---

**Q16. A PVC is stuck in `Pending`. What are the common causes?**

**A:**
1. **No matching PV** (static provisioning) — check `kubectl get pv`
2. **StorageClass doesn't exist** — `kubectl get storageclass`
3. **Provisioner pod is down** — `kubectl get pods -n kube-system | grep provisioner`
4. **Wrong access mode** — PVC requests `ReadWriteMany` but PV only supports `ReadWriteOnce`
5. **Insufficient capacity** — requested size is larger than available PV
6. **Cloud quota exceeded** — check cloud provider console

---

## Expert (L3) — Architectural

---

**Q17. Explain the full lifecycle of a pod from creation to running.**

**A:**
1. `kubectl apply` sends the manifest to the **API server**
2. API server persists the pod object in **etcd**
3. **Scheduler** watches for unscheduled pods and assigns a `nodeName`
4. API server updates etcd with the node assignment
5. **Kubelet** on the target node watches for pods assigned to it
6. Kubelet calls the **Container Runtime** (containerd) to pull images and create containers
7. **CNI plugin** sets up pod networking (veth pair, IP allocation)
8. Kubelet updates pod status to `Running` in API server

---

**Q18. How does kube-proxy create service routing? What happens when a Service is deleted?**

**A:** kube-proxy watches the API server for Service and Endpoint changes and programs `iptables` (or IPVS) rules on every node. When a Service is created, kube-proxy creates NAT rules that DNAT traffic from the ClusterIP to one of the endpoint pod IPs.

When a Service is deleted:
1. API server deletes the Service object
2. Endpoint controller removes the Endpoints object
3. kube-proxy detects the change and **removes** the iptables/IPVS rules
4. Traffic to that ClusterIP immediately stops routing

---

**Q19. What is the difference between `requests` and `limits`? What happens with no limits set?**

**A:**
- **Requests**: What the scheduler uses to find a suitable node. The pod is guaranteed this amount.
- **Limits**: The hard cap. If CPU exceeds the limit, the container is throttled. If memory exceeds, it's OOMKilled.

Without limits: A pod can consume all available node resources, starving other pods. This is called a "noisy neighbor" problem. LimitRange objects can enforce defaults at the namespace level.

---

**Q20. What happens when etcd loses quorum?**

**A:** When etcd loses quorum (more than half of members are down), the cluster becomes **read-only** — the API server can read state but cannot write. This means:
- Existing workloads continue running (kubelet operates independently)
- No new deployments, scaling, or changes can be made
- Controllers cannot reconcile state

To recover: Restore from an etcd snapshot or repair the quorum by bringing back members.

```bash
ETCDCTL_API=3 etcdctl snapshot restore snapshot.db \
  --data-dir /var/lib/etcd-restored
```

---

**Q21. How does a NodePort Service work and what are its limitations?**

**A:** A NodePort Service opens a port (default: 30000-32767) on **every node** in the cluster. Traffic to `<any-node-ip>:<nodePort>` is forwarded to the Service's ClusterIP and then to an endpoint pod.

Limitations:
- Port range restricted (30000-32767)
- Only one service per port
- Exposes node IPs directly (security concern)
- No load balancing at the cloud layer
- For production, use LoadBalancer type or Ingress

---

**Q22. How do you handle a pod that's running but consuming too much CPU?**

**A:**
```bash
# Confirm with metrics
kubectl top pod <name> -n <ns>

# Set a CPU limit to throttle it
kubectl set resources deployment/<name> -n <ns> \
  --limits=cpu=500m

# Or configure HPA to scale out instead of throttle
kubectl autoscale deployment <name> \
  --cpu-percent=70 \
  --min=2 --max=10 -n <ns>
```

CPU throttling vs. OOMKill: Unlike memory, hitting the CPU limit doesn't kill the container — it just slows it down (throttling). This can cause latency spikes. Watch for `Throttled` in metrics.

---

## Scenario-Based — Real-World Incidents

---

**Q23. Scenario: Your application suddenly returns 503 errors in production. Walk me through the incident response.**

**A:**
```
1. Check pod status immediately
   kubectl get pods -n <prod-ns> | grep -v Running

2. Check endpoints (are pods receiving traffic?)
   kubectl get endpoints <svc> -n <prod-ns>

3. Look for recent events
   kubectl get events -n <prod-ns> --sort-by='.lastTimestamp' | tail -20

4. Check pod logs for errors
   kubectl logs -l app=<name> -n <prod-ns> --tail=50 --since=5m

5. Check if nodes are healthy
   kubectl get nodes
   kubectl top nodes

6. Check HPA (are we under-scaled?)
   kubectl get hpa -n <prod-ns>

7. Check for recent deployments
   kubectl rollout history deployment/<name> -n <prod-ns>
   → If recent bad deploy: kubectl rollout undo deployment/<name> -n <prod-ns>
```

---

**Q24. Scenario: A Deployment is stuck — new pods are `Pending` and old pods aren't being killed. Why?**

**A:** This is a **maxUnavailable=0 with insufficient cluster capacity** situation. The rolling update creates new pods first (up to `maxSurge`), but if the cluster has no room, new pods stay `Pending` and the old pods can't be removed (because `maxUnavailable=0` prevents it).

Fix options:
1. Add node capacity
2. Change rollout strategy: `maxUnavailable: 1` allows old pods to be removed first
3. Temporarily cordon excess pods to free up space

---

**Q25. Scenario: A pod works fine locally with Docker but CrashLoops in Kubernetes. What are the top 3 causes?**

**A:**
1. **Missing environment variables or secrets** — Docker had them set locally; Kubernetes needs them in `env` or `envFrom`
2. **File system permissions** — Container running as non-root in K8s (SecurityContext) but the process needs to write to a directory it doesn't own
3. **Resource limits too low** — Docker has no limits by default; K8s limits might be set at namespace level via LimitRange and cause immediate OOM

---

**Q26. Scenario: DNS stops working for pods in a specific namespace. What's your investigation?**

**A:**
```bash
# 1. Test from a pod in that namespace
kubectl run test -n <broken-ns> --rm -it \
  --image=busybox -- nslookup kubernetes.default

# 2. Test from a pod in a different namespace
kubectl run test -n default --rm -it \
  --image=busybox -- nslookup kubernetes.default

# 3. Check if NetworkPolicy is blocking DNS (UDP/TCP port 53 to kube-dns)
kubectl get netpol -n <broken-ns>

# 4. Check CoreDNS pods
kubectl get pods -n kube-system -l k8s-app=kube-dns

# 5. Check node-level DNS resolver
# → NetworkPolicy blocking egress to kube-system is the most common cause
```

---

**Q27. Scenario: A node drains but one pod keeps coming back. What's happening?**

**A:** The pod is likely managed by a **DaemonSet**. DaemonSet pods run on every node and are not evicted by drain unless you pass `--ignore-daemonsets`. If the pod keeps coming back after eviction, it's the DaemonSet controller recreating it. 

To truly prevent it: `kubectl cordon` the node and don't uncordon it — DaemonSet respects `Unschedulable` taints with `NoSchedule`.

---

## CKA-Style — Hands-On Challenges

---

**Q28. How do you create an ephemeral debug container without modifying the original pod spec?**

**A:**
```bash
kubectl debug -it <pod-name> -n <ns> \
  --image=nicolaka/netshoot \
  --target=<container-name>
```
This attaches an ephemeral container that shares the pod's network namespace. No pod restart needed.

---

**Q29. How do you quickly find all pods that are NOT in Running or Completed state across the cluster?**

**A:**
```bash
kubectl get pods -A | grep -v -E "(Running|Completed|Terminating)"
```

Or with more context:
```bash
kubectl get pods -A -o wide | \
  awk 'NR==1 || ($4 != "Running" && $4 != "Completed")'
```

---

**Q30. A secret was accidentally deleted and a pod is now failing. How do you quickly recover?**

**A:**
```bash
# 1. Check what the pod expects
kubectl describe pod <pod> -n <ns> | grep -A5 "Volumes\|Env"

# 2. Recreate the secret (from backup or re-generate)
kubectl create secret generic <name> -n <ns> \
  --from-literal=key=value

# 3. If pod is CrashLooping due to missing secret, restart it
kubectl rollout restart deployment/<name> -n <ns>
```

---

**Q31. How do you check the certificates on the Kubernetes API server and when they expire?**

**A:**
```bash
# Using kubeadm
kubeadm certs check-expiration

# Manual check
openssl x509 -in /etc/kubernetes/pki/apiserver.crt \
  -noout -text | grep -A2 Validity

# Check from kubectl
kubectl get secret -n kube-system \
  -o yaml | grep tls.crt | base64 -d | openssl x509 -noout -text
```

---

**Q32. What command would you use to tail logs from all pods in a deployment simultaneously?**

**A:**
```bash
# Using label selector
kubectl logs -n <ns> -l app=<app-label> -f --max-log-requests=10

# Or using stern (third-party tool) for colored multi-pod logs
stern -n <ns> <deployment-name>
```

---

## Bonus: Advanced Topics

**Q33. How does the Vertical Pod Autoscaler (VPA) interact with troubleshooting?**

**A:** VPA automatically adjusts pod resource requests based on historical usage. When troubleshooting OOM or throttling issues, check if VPA is present — it might be overriding your manually set requests. In `Auto` mode, VPA evicts and recreates pods to apply new resource recommendations.

```bash
kubectl get vpa -n <namespace>
kubectl describe vpa <name> -n <namespace>
```

---

**Q34. What is a `PodDisruptionBudget` and how can it block node draining?**

**A:** A PDB specifies the minimum number of pods that must be available during voluntary disruptions (like node drains). If draining a node would violate a PDB, the drain will **hang** with a warning.

```bash
# Check PDBs
kubectl get pdb -n <namespace>
kubectl describe pdb <name> -n <namespace>

# Override (not recommended in production)
kubectl drain <node> --disable-eviction
```

---

**Q35. Explain what happens when you run `kubectl delete pod` vs deleting the Deployment.**

**A:**
- `kubectl delete pod`: The pod is deleted, but if it's managed by a ReplicaSet/Deployment, the controller **immediately creates a replacement** pod to maintain desired replica count. Use this to force a restart.
- `kubectl delete deployment`: The Deployment, its ReplicaSet, and all its pods are deleted. No replacement is created. Workload is fully terminated.

---

*End of Interview Q&A — 35+ questions covering L1 through expert scenario-based rounds.*

*For hands-on practice, work through the [GUIDE.md](./GUIDE.md) debugging scenarios.*
