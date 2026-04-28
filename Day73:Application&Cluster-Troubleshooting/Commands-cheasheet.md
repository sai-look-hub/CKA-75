# COMMANDS-Day73.md
# Kubernetes Troubleshooting — Command Cheatsheet

---

## 🔵 POD DEBUGGING

```bash
# ── Status & State ───────────────────────────────────────────────────────────
kubectl get pods -A                                         # All namespaces
kubectl get pods -n <ns> -o wide                           # With node info
kubectl get pods -A --field-selector=status.phase!=Running # All non-running
kubectl get pods -A --field-selector=status.phase=Failed   # All failed
kubectl get pods -n <ns> --sort-by='.status.startTime'     # Sorted by start

# ── Logs ────────────────────────────────────────────────────────────────────
kubectl logs <pod> -n <ns>                                 # Current container
kubectl logs <pod> -n <ns> --previous                      # Previous crash
kubectl logs <pod> -n <ns> -c <container>                  # Specific container
kubectl logs <pod> -n <ns> --all-containers=true           # All containers
kubectl logs <pod> -n <ns> --since=1h                      # Last hour only
kubectl logs <pod> -n <ns> --tail=50                       # Last 50 lines
kubectl logs <pod> -n <ns> -f                              # Follow (stream)
kubectl logs <pod> -n <ns> --previous --tail=100           # Last 100 of crash

# ── Describe & Events ────────────────────────────────────────────────────────
kubectl describe pod <pod> -n <ns>                         # Full pod details
kubectl get events -n <ns> --sort-by='.lastTimestamp'      # Events by time
kubectl get events -A --field-selector reason=BackOff      # CrashLoop events
kubectl get events -A --field-selector reason=OOMKilling   # OOM events
kubectl get events -n <ns> --field-selector involvedObject.name=<pod>

# ── Exec & Debug ────────────────────────────────────────────────────────────
kubectl exec -it <pod> -n <ns> -- /bin/sh                  # Shell into pod
kubectl exec -it <pod> -n <ns> -c <container> -- bash      # Specific container
kubectl exec <pod> -n <ns> -- env                          # Print env vars
kubectl exec <pod> -n <ns> -- cat /etc/resolv.conf         # DNS config

# Ephemeral debug container (distroless pods)
kubectl debug -it <pod> -n <ns> --image=busybox --target=<container>
kubectl debug pod/<pod> -n <ns> --copy-to=debug-copy --image=ubuntu -- bash

# ── Resource Usage ───────────────────────────────────────────────────────────
kubectl top pods -n <ns>
kubectl top pods -n <ns> --containers
kubectl top pods -A --sort-by=memory
kubectl top pods -A --sort-by=cpu
```

---

## 🟠 SERVICE & NETWORKING DEBUG

```bash
# ── Service Inspection ───────────────────────────────────────────────────────
kubectl get svc -n <ns>
kubectl describe svc <svc> -n <ns>
kubectl get svc -n <ns> -o yaml                            # Full YAML

# ── ENDPOINTS — Check This First! ────────────────────────────────────────────
kubectl get endpoints -n <ns>                              # All endpoints
kubectl get endpoints <svc> -n <ns>                        # Specific service
kubectl describe endpoints <svc> -n <ns>                   # Details

# ── DNS Testing ─────────────────────────────────────────────────────────────
kubectl run dns-test --image=busybox --rm -it --restart=Never -- \
  nslookup <svc>.<ns>.svc.cluster.local

kubectl run dns-test --image=busybox --rm -it --restart=Never -- \
  nslookup kubernetes.default

# ── Connectivity Testing ─────────────────────────────────────────────────────
kubectl run curl-test --image=curlimages/curl --rm -it --restart=Never -- \
  curl -v http://<svc>.<ns>:80

kubectl run nettest --image=busybox --rm -it --restart=Never -- \
  wget -qO- http://<clusterIP>:<port>

# ── Network Policies ─────────────────────────────────────────────────────────
kubectl get networkpolicies -n <ns>
kubectl describe networkpolicy <np> -n <ns>

# ── Port Forward for Local Testing ───────────────────────────────────────────
kubectl port-forward pod/<pod> 8080:80 -n <ns>
kubectl port-forward svc/<svc> 8080:80 -n <ns>
kubectl port-forward deploy/<deploy> 8080:80 -n <ns>
```

---

## 🟡 NODE DEBUGGING

```bash
# ── Node Status ──────────────────────────────────────────────────────────────
kubectl get nodes
kubectl get nodes -o wide
kubectl describe node <node>                               # Full node details
kubectl describe nodes | grep -A5 "Conditions"
kubectl describe nodes | grep -A8 "Allocated resources"

# ── Node Resource Usage ──────────────────────────────────────────────────────
kubectl top nodes
kubectl top nodes --sort-by=cpu
kubectl top nodes --sort-by=memory

# ── Node Management ──────────────────────────────────────────────────────────
kubectl cordon <node>                                      # Stop scheduling
kubectl uncordon <node>                                    # Resume scheduling
kubectl drain <node> --ignore-daemonsets --delete-emptydir-data
kubectl taint nodes <node> key=value:NoSchedule            # Add taint
kubectl taint nodes <node> key=value:NoSchedule-           # Remove taint

# ── Pods on Specific Node ────────────────────────────────────────────────────
kubectl get pods -A --field-selector spec.nodeName=<node>

# ── Node Labels ─────────────────────────────────────────────────────────────
kubectl get nodes --show-labels
kubectl label node <node> disktype=ssd
```

---

## 🔴 CLUSTER HEALTH

```bash
# ── Control Plane ────────────────────────────────────────────────────────────
kubectl get pods -n kube-system
kubectl get pods -n kube-system -l component=etcd
kubectl get pods -n kube-system -l component=kube-apiserver

# ── Component Status ─────────────────────────────────────────────────────────
kubectl cluster-info
kubectl cluster-info dump --output-directory=/tmp/dump     # Full dump

# ── etcd Health ─────────────────────────────────────────────────────────────
ETCDCTL_API=3 etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  endpoint health

ETCDCTL_API=3 etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  member list

# ── Certificate Health ────────────────────────────────────────────────────────
kubeadm certs check-expiration
kubeadm certs renew all
openssl x509 -in /etc/kubernetes/pki/apiserver.crt -noout -dates

# ── CoreDNS ──────────────────────────────────────────────────────────────────
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl logs -n kube-system -l k8s-app=kube-dns
kubectl rollout restart deployment/coredns -n kube-system
```

---

## 🟣 RBAC & AUTH DEBUG

```bash
# ── Check Permissions ────────────────────────────────────────────────────────
kubectl auth can-i get pods -n <ns>
kubectl auth can-i get pods -n <ns> --as=<user>
kubectl auth can-i list secrets -n <ns> \
  --as=system:serviceaccount:<ns>:<sa-name>
kubectl auth can-i '*' '*'                                 # Full cluster access?

# ── List Bindings ────────────────────────────────────────────────────────────
kubectl get rolebindings -n <ns>
kubectl get clusterrolebindings
kubectl describe rolebinding <rb> -n <ns>
kubectl describe clusterrolebinding <crb>

# ── Who can do what ──────────────────────────────────────────────────────────
kubectl get rolebindings -A -o jsonpath=\
'{range .items[*]}{.metadata.namespace} {.metadata.name} {.subjects[*].name}{"\n"}{end}'
```

---

## ⚫ RESOURCE MANAGEMENT DEBUG

```bash
# ── Resource Quotas ──────────────────────────────────────────────────────────
kubectl get resourcequota -n <ns>
kubectl describe resourcequota -n <ns>

# ── LimitRanges ─────────────────────────────────────────────────────────────
kubectl get limitrange -n <ns>
kubectl describe limitrange -n <ns>

# ── PVC / Storage ────────────────────────────────────────────────────────────
kubectl get pvc -n <ns>
kubectl describe pvc <pvc> -n <ns>
kubectl get pv
kubectl describe pv <pv>
kubectl get storageclass

# ── HPA / VPA ────────────────────────────────────────────────────────────────
kubectl describe hpa -n <ns>
kubectl get hpa -n <ns>
```

---

## 🟤 ROLLOUT DEBUG

```bash
kubectl rollout status deployment/<deploy> -n <ns>
kubectl rollout history deployment/<deploy> -n <ns>
kubectl rollout undo deployment/<deploy> -n <ns>
kubectl rollout undo deployment/<deploy> -n <ns> --to-revision=2
kubectl rollout pause deployment/<deploy> -n <ns>
kubectl rollout resume deployment/<deploy> -n <ns>
kubectl rollout restart deployment/<deploy> -n <ns>
```

---

## 🔧 ONE-LINERS

```bash
# Delete all evicted pods cluster-wide
kubectl get pods -A | grep Evicted | awk '{print $2 " -n " $1}' | xargs -I{} kubectl delete pod {}

# Get all non-running pods
kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded

# Watch pod status live
watch -n 2 kubectl get pods -n <ns>

# Get pod restart counts
kubectl get pods -n <ns> -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{range .status.containerStatuses[*]}{.restartCount}{end}{"\n"}{end}'

# Find pods with high restarts
kubectl get pods -A | awk '$5 > 5'   # More than 5 restarts

# Get pod IPs
kubectl get pods -n <ns> -o custom-columns=NAME:.metadata.name,IP:.status.podIP

# Port-forward and test immediately
kubectl port-forward svc/<svc> 8080:80 -n <ns> & sleep 2 && curl localhost:8080

# Tail logs of all pods matching label
kubectl logs -l app=myapp -n <ns> --all-containers=true -f
```
