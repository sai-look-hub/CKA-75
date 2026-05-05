# ⚡ Kubernetes Troubleshooting Cheatsheet

> Day 74 | One-page quick reference — print and keep handy

---

## Pod Debug Flow

```bash
kubectl get pod <pod> -n <ns> -o wide                    # Status + Node
kubectl describe pod <pod> -n <ns>                        # Events + Conditions
kubectl logs <pod> -n <ns> --previous                     # Crash logs
kubectl exec -it <pod> -n <ns> -- sh                      # Live shell
kubectl get events -n <ns> --sort-by='.lastTimestamp'     # Timeline
```

## Pod States Quick Reference

| State | Cause | Fix |
|-------|-------|-----|
| `Pending` | Can't schedule | Check capacity, taints, affinity |
| `CrashLoopBackOff` | Container crashes | `logs --previous`, fix exit code |
| `OOMKilled` | Memory exceeded | Increase `limits.memory` |
| `ImagePullBackOff` | Can't pull image | Fix image name or pull secret |
| `Init:Error` | Init container failed | `logs -c <init-container>` |
| `Terminating` stuck | Finalizer blocking | Patch finalizers to null |

## Exit Codes

| Code | Meaning |
|------|---------|
| `0` | Clean exit |
| `1` | App error |
| `137` | OOMKilled |
| `139` | Segfault |
| `143` | SIGTERM |

## Service Debug Flow

```bash
kubectl get endpoints <svc> -n <ns>                       # Empty = label mismatch!
kubectl get svc <svc> -n <ns> -o jsonpath='{.spec.selector}'
kubectl get pods -n <ns> --show-labels
kubectl run test --rm -it --image=busybox -- nslookup <svc>.<ns>.svc.cluster.local
```

## Node Triage

```bash
kubectl get nodes -o wide
kubectl describe node <node>                    # Conditions, taints, resources
kubectl top nodes
ssh <node>; sudo journalctl -u kubelet -n 50    # Kubelet logs
sudo systemctl restart kubelet                  # Restart kubelet
kubectl cordon <node>                           # Stop scheduling
kubectl drain <node> --ignore-daemonsets \
  --delete-emptydir-data                        # Evict pods
kubectl uncordon <node>                         # Re-enable scheduling
```

## Resource Debug

```bash
kubectl top pods -A --sort-by=memory            # Memory hogs
kubectl top pods -A --sort-by=cpu               # CPU hogs
kubectl describe resourcequota -n <ns>          # Quota usage
kubectl describe limitrange -n <ns>             # Default limits
kubectl get hpa -n <ns>                         # HPA status
```

## RBAC Debug

```bash
kubectl auth can-i <verb> <resource> \
  --as=system:serviceaccount:<ns>:<sa> -n <ns>
kubectl auth can-i --list \
  --as=system:serviceaccount:<ns>:<sa>
kubectl get rolebinding,clusterrolebinding -A -o wide | grep <sa>
```

## Storage Debug

```bash
kubectl get pvc -n <ns>                         # PVC status
kubectl describe pvc <name> -n <ns>             # Why it's Pending
kubectl get pv                                  # Available PVs
kubectl get storageclass                        # Storage classes
```

## Cluster Health

```bash
kubectl get pods -n kube-system                 # Control plane pods
kubectl get componentstatuses                   # API/Scheduler/etcd
kubectl get events -A --field-selector type=Warning \
  --sort-by='.lastTimestamp'                    # Warning events
```

## Advanced

```bash
# Ephemeral debug container
kubectl debug -it <pod> -n <ns> --image=busybox --target=<container>

# Network debug pod
kubectl run netshoot --rm -it --image=nicolaka/netshoot -- bash

# Port forward
kubectl port-forward pod/<pod> 8080:80 -n <ns>

# All non-Running pods
kubectl get pods -A | grep -v -E "(Running|Completed)"

# Decode secret
kubectl get secret <name> -n <ns> \
  -o jsonpath='{.data.<key>}' | base64 -d

# Remove stuck finalizers
kubectl patch pod <pod> -n <ns> \
  -p '{"metadata":{"finalizers":null}}' --type=merge

# Rollback deployment
kubectl rollout undo deployment/<name> -n <ns>
```

---

*[TROUBLESHOOTING.md](./TROUBLESHOOTING.md) | [GUIDE.md](./GUIDE.md) | [Interview Q&A](./interview-questions-answers.md)*
