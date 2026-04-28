# Day 73: Application & Cluster Troubleshooting

## 🎯 Overview

Master systematic Kubernetes troubleshooting — from failing pods and broken services to degraded nodes and cluster-wide issues. This day covers the complete debugging lifecycle with production-grade methodologies.

---

## 📚 What You'll Learn

| Area | Topics |
|------|--------|
| Pod Troubleshooting | CrashLoopBackOff, OOMKilled, ImagePullBackOff, Pending states |
| Service Debugging | ClusterIP resolution, endpoint mismatches, kube-proxy issues |
| Node Issues | NotReady nodes, resource pressure, kubelet failures, taints |
| Cluster Diagnostics | etcd health, API server issues, control plane debugging |
| Logging & Events | kubectl logs, events, describe deep-dives |

---

## 🏗️ Lab Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                    Troubleshooting Lab                        │
│                                                              │
│  ┌─────────────────┐    ┌─────────────────┐                 │
│  │  Broken Pod     │    │  Service Debug  │                 │
│  │  Scenarios      │    │  Scenarios      │                 │
│  │                 │    │                 │                 │
│  │ • CrashLoop     │    │ • No Endpoints  │                 │
│  │ • OOMKilled     │    │ • Wrong Selector│                 │
│  │ • ImagePull     │    │ • Port Mismatch │                 │
│  │ • Pending       │    │ • DNS Failure   │                 │
│  └─────────────────┘    └─────────────────┘                 │
│                                                              │
│  ┌─────────────────┐    ┌─────────────────┐                 │
│  │  Node Issues    │    │  Cluster Issues │                 │
│  │                 │    │                 │                 │
│  │ • NotReady      │    │ • etcd health   │                 │
│  │ • DiskPressure  │    │ • API server    │                 │
│  │ • MemPressure   │    │ • Cert expiry   │                 │
│  │ • Kubelet down  │    │ • RBAC deny     │                 │
│  └─────────────────┘    └─────────────────┘                 │
└──────────────────────────────────────────────────────────────┘
```

---

## 📁 Repository Structure

```
day73-troubleshooting/
├── README-Day73.md
├── GUIDEME-Day73.md
├── TROUBLESHOOTING-Day73.md
├── INTERVIEW-QA-Day73.md
├── COMMANDS-Day73.md
├── manifests/
│   ├── 01-broken-pod-crashloop.yaml
│   ├── 02-broken-pod-oom.yaml
│   ├── 03-broken-pod-imagepull.yaml
│   ├── 04-broken-pod-pending.yaml
│   ├── 05-broken-service-selector.yaml
│   ├── 06-broken-service-port.yaml
│   ├── 07-resource-quota-block.yaml
│   ├── 08-debug-tools-pod.yaml
│   └── 09-fixed-versions.yaml
└── scripts/
    ├── diagnose-cluster.sh
    └── pod-health-check.sh
```

---

## 🔑 Key Concepts

### The Troubleshooting Hierarchy

```
1. Cluster Level    → Is the control plane healthy?
2. Node Level       → Are nodes Ready? Any pressure conditions?
3. Namespace Level  → Any resource quotas/limits blocking?
4. Pod Level        → Pod phase, container states, events
5. Application      → Logs, config, dependencies
6. Network Level    → Services, endpoints, DNS, policies
```

### Pod Lifecycle States

| State | Meaning | Common Cause |
|-------|---------|-------------|
| Pending | Not scheduled | No resources, taints, PVC unbound |
| ContainerCreating | Pulling image | Slow registry, large image |
| Running | All containers up | — |
| CrashLoopBackOff | Crash + restart loop | App crash, bad config |
| OOMKilled | Memory exceeded limit | Memory leak, limit too low |
| ImagePullBackOff | Cannot pull image | Bad tag, auth failure |
| Evicted | Removed by kubelet | Node disk/memory pressure |
| Terminating | Stuck on delete | Finalizers, PVC stuck |

---

## 🧰 Core Debugging Commands

```bash
# ── Pod Debugging ──────────────────────────────────────────
kubectl get pods -A --field-selector=status.phase!=Running
kubectl describe pod <pod> -n <ns>
kubectl logs <pod> -n <ns> --previous
kubectl logs <pod> -n <ns> -c <container>
kubectl exec -it <pod> -- /bin/sh

# ── Service Debugging ──────────────────────────────────────
kubectl get endpoints <svc> -n <ns>
kubectl describe svc <svc> -n <ns>
kubectl run debug --image=busybox --rm -it -- nslookup <svc>

# ── Node Debugging ─────────────────────────────────────────
kubectl get nodes
kubectl describe node <node>
kubectl top nodes
kubectl cordon <node>   # prevent scheduling
kubectl drain <node>    # evict pods

# ── Events ─────────────────────────────────────────────────
kubectl get events -n <ns> --sort-by='.lastTimestamp'
kubectl get events -A --field-selector reason=BackOff
```

---

## ✅ Prerequisites

- Kubernetes cluster (minikube / kind / kubeadm)
- kubectl configured and working
- Days 1–72 concepts (pods, services, RBAC, storage)
- Basic Linux debugging skills

---

## 🚀 Quick Start

```bash
# Clone and navigate
git clone https://github.com/yourusername/kubernetes-learning
cd day73-troubleshooting

# Apply broken scenarios
kubectl create namespace debug-lab
kubectl apply -f manifests/ -n debug-lab

# Verify broken state (expected!)
kubectl get pods -n debug-lab

# Follow GUIDEME-Day73.md to debug each scenario
```

---

## 📊 Lab Outcomes

After completing this lab you will be able to:

- Diagnose any pod failure state in under 2 minutes
- Debug service connectivity with a systematic 5-step approach
- Identify and resolve node pressure conditions
- Distinguish between application bugs vs infrastructure issues
- Use ephemeral debug containers for live pod inspection
- Read and act on Kubernetes events effectively

---

## 📎 References

- [Kubernetes Debugging Pods](https://kubernetes.io/docs/tasks/debug/debug-application/debug-pods/)
- [Kubernetes Debugging Services](https://kubernetes.io/docs/tasks/debug/debug-application/debug-service/)
- [Node Troubleshooting](https://kubernetes.io/docs/tasks/debug/debug-cluster/debug-cluster/)
- [Ephemeral Containers](https://kubernetes.io/docs/tasks/debug/debug-application/debug-running-pod/#ephemeral-container)
