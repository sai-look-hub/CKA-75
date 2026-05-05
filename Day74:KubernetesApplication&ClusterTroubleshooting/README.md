# 🔧 Day 74: Kubernetes Application & Cluster Troubleshooting

> **DevOps Mastery Series** | 75 Days of CKA 

[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.29+-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white)](https://kubernetes.io/)
[![kubectl](https://img.shields.io/badge/kubectl-CLI-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white)](https://kubernetes.io/docs/reference/kubectl/)
[![DevOps](https://img.shields.io/badge/DevOps-Day%2074-FF6B35?style=for-the-badge)](https://github.com)

---

## 📋 Overview

This repository contains a complete reference guide for **Kubernetes Application & Cluster Troubleshooting** — one of the most critical skills for any DevOps / Platform Engineer. Whether you're debugging CrashLoopBackOff pods, tracking down networking issues, or diagnosing node-level failures, this guide has you covered.

---

## 📁 Repository Structure

```
day74-k8s-troubleshooting/
├── README.md                          # This file — overview & navigation
├── TROUBLESHOOTING.md                 # Complete kubectl command reference
├── GUIDE.md                           # Step-by-step debugging methodology
├── interview-questions-answers.md     # 40+ interview Q&A (all levels)
├── scripts/
│   ├── debug-pod.sh                   # Automated pod diagnostics
│   ├── node-health-check.sh           # Node triage script
│   └── cluster-health-report.sh       # Full cluster health overview
├── manifests/
│   ├── debug-pod.yaml                 # Ephemeral debug container spec
│   ├── resource-quota-check.yaml      # Resource quota diagnostic
│   └── network-policy-test.yaml       # Network connectivity tester
└── cheatsheet.md                      # Quick-reference command cheatsheet
```

---

## 🎯 What You'll Learn

| Area | Topics Covered |
|------|---------------|
| **Pod Debugging** | CrashLoopBackOff, OOMKilled, ImagePullBackOff, Pending, Init containers |
| **Service & Networking** | DNS failures, Service unreachable, Endpoint mismatches, NetworkPolicy blocks |
| **Node Troubleshooting** | NotReady nodes, Resource pressure, Kubelet failures, DiskPressure |
| **Cluster-Level** | API server issues, etcd health, RBAC permission errors, PVC binding |
| **Observability** | Logs, Events, Metrics, kubectl exec/debug strategies |

---

## 🚀 Quick Start

```bash
# Clone this repository
git clone https://github.com/yourusername/100-days-devops.git
cd 100-days-devops/day74-k8s-troubleshooting

# Run the cluster health report
chmod +x scripts/cluster-health-report.sh
./scripts/cluster-health-report.sh

# Debug a specific pod
chmod +x scripts/debug-pod.sh
./scripts/debug-pod.sh <pod-name> <namespace>
```

---

## 🔍 Troubleshooting Quick Reference

### Pod States Decoded

| State | What It Means | First Action |
|-------|--------------|--------------|
| `Pending` | Not scheduled yet | Check node capacity & taints |
| `CrashLoopBackOff` | Container keeps crashing | `kubectl logs --previous` |
| `OOMKilled` | Out of memory | Check & increase memory limits |
| `ImagePullBackOff` | Image not found/accessible | Verify image name & pull secrets |
| `Init:Error` | Init container failed | Check init container logs |
| `Terminating` (stuck) | Finalizer blocking deletion | Check/remove finalizers |

### The 5-Step Pod Debug Flow

```
1. kubectl get pod <name> -n <ns> -o wide       → Location & Status
2. kubectl describe pod <name> -n <ns>           → Events & Conditions
3. kubectl logs <name> -n <ns> --previous        → Crash logs
4. kubectl exec -it <name> -n <ns> -- sh         → Live shell
5. kubectl get events -n <ns> --sort-by='.lastTimestamp'  → Timeline
```

---

## 📚 Contents

- 📖 [Troubleshooting Reference](./TROUBLESHOOTING.md) — Complete command reference for all failure scenarios
- 🗺️ [Debugging Guide](./GUIDE.md) — Systematic methodology with decision trees
- 💬 [Interview Q&A](./interview-questions-answers.md) — 40+ questions from beginner to expert
- ⚡ [Cheatsheet](./cheatsheet.md) — One-page quick reference

---

## 🧠 Key Concepts

### Pod Lifecycle Troubleshooting
Pods transition through states: `Pending → Running → Succeeded/Failed`. Understanding what blocks each transition is the foundation of effective debugging.

### The 3-Layer Debugging Model
```
Layer 1: Application   → Container logs, env vars, config
Layer 2: Kubernetes    → Pod spec, resource limits, RBAC, service accounts  
Layer 3: Infrastructure → Node health, network CNI, storage CSI
```

### Golden Signals for K8s
- **Latency**: Request/response times via metrics
- **Traffic**: Request rates across services
- **Errors**: Error rates in logs and metrics
- **Saturation**: CPU/Memory utilization vs limits

---

## 🔗 Related Topics

- [Day 70: Kubernetes Architecture Deep Dive](../day70/)
- [Day 71: RBAC & Security Contexts](../day71/)
- [Day 72: Networking & CNI Plugins](../day72/)
- [Day 73: Persistent Volumes & Storage](../day73/)
- [Day 75: Helm Charts & GitOps](../day75/)

---

## 📝 Author

**Sai Kumar** | DevOps Engineer | 100 Days of DevOps  
[![LinkedIn](https://img.shields.io/badge/LinkedIn-Connect-0077B5?style=flat&logo=linkedin)](https://linkedin.com/in/yourusername)
[![GitHub](https://img.shields.io/badge/GitHub-Follow-181717?style=flat&logo=github)](https://github.com/yourusername)

---

*Part of the #CKA75 challenge — sharing daily learnings in public.*
