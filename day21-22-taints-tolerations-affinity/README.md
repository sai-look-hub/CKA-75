# Day 21-22: Taints, Tolerations & Affinity

## 📋 Overview

Master **advanced pod scheduling** in Kubernetes using Taints, Tolerations, Node Affinity, and Pod Affinity/Anti-Affinity. Learn to control pod placement for high availability, performance optimization, and resource management.

## 🎯 Learning Objectives

By the end of this module, you will:

- ✅ Understand taints and how they repel pods
- ✅ Configure tolerations to allow pods on tainted nodes
- ✅ Implement node affinity for hardware requirements
- ✅ Use pod affinity for co-location strategies
- ✅ Apply pod anti-affinity for high availability
- ✅ Combine scheduling mechanisms effectively
- ✅ Build fault-tolerant pod distributions
- ✅ Optimize resource utilization
- ✅ Troubleshoot scheduling issues

## 📚 Topics Covered

### Taints
- Taint effects (NoSchedule, PreferNoSchedule, NoExecute)
- Adding and removing taints
- Multiple taints per node
- Common use cases
- Master node isolation

### Tolerations
- Exact match tolerations
- Exists operator
- TolerationSeconds for NoExecute
- Multiple tolerations
- System pod patterns

### Node Affinity
- requiredDuringSchedulingIgnoredDuringExecution
- preferredDuringSchedulingIgnoredDuringExecution
- In/NotIn/Exists/DoesNotExist operators
- Weight-based preferences
- Hardware selection

### Pod Affinity & Anti-Affinity
- Co-location with affinity
- Separation with anti-affinity
- Topology keys (hostname, zone, region)
- Required vs preferred rules
- High availability patterns

## 🚀 Projects

### Project 1: High-Availability Web Application
Deploy a fault-tolerant 3-tier application:
- **Frontend**: 6 replicas spread across zones
- **Backend API**: 6 replicas with anti-affinity
- **Redis Cache**: Co-located with API using affinity
- **PostgreSQL**: 3 replicas on SSD nodes
- **Result**: 99.99% uptime, zero single points of failure

### Project 2: Specialized Hardware Utilization
Optimize resource usage with taints:
- **GPU Nodes**: Tainted for ML workloads only
- **SSD Nodes**: Reserved for databases
- **Master Nodes**: Isolated from regular workloads
- **Monitoring**: Tolerates all taints (runs everywhere)

## 📁 Repository Structure

```
day21-22-taints-tolerations-affinity/
├── README.md                          # This file
├── GUIDE.md                          # Comprehensive guide
├── INTERVIEW-QA.md                   # Interview questions
├── COMMANDS-CHEATSHEET.md            # Quick reference
├── TROUBLESHOOTING.md                # Common issues
│
├── scripts/
│   ├── taint-operations.sh           # Taint management
│   ├── affinity-helpers.sh           # Affinity utilities
│   └── scheduling-verification.sh    # Verify pod placement
│
└── yaml-examples/
    ├── 01-taints-tolerations/
    │   ├── tainted-nodes.yaml
    │   ├── basic-toleration.yaml
    │   ├── noexecute-toleration.yaml
    │   ├── multiple-tolerations.yaml
    │   └── system-pod-tolerations.yaml
    │
    ├── 02-node-affinity/
    │   ├── required-affinity.yaml
    │   ├── preferred-affinity.yaml
    │   ├── multiple-requirements.yaml
    │   ├── ssd-affinity.yaml
    │   └── zone-affinity.yaml
    │
    ├── 03-pod-affinity/
    │   ├── pod-affinity.yaml
    │   ├── pod-anti-affinity.yaml
    │   ├── hostname-topology.yaml
    │   ├── zone-topology.yaml
    │   └── combined-affinity.yaml
    │
    ├── 04-high-availability/
    │   ├── frontend-deployment.yaml
    │   ├── backend-deployment.yaml
    │   ├── database-statefulset.yaml
    │   ├── cache-deployment.yaml
    │   └── deploy-all.sh
    │
    └── 05-specialized-hardware/
        ├── gpu-node-setup.yaml
        ├── ml-workload.yaml
        ├── ssd-database.yaml
        ├── monitoring-daemonset.yaml
        └── setup-cluster.sh
```

## 🛠️ Prerequisites

- Kubernetes cluster (v1.19+)
- kubectl configured
- Multiple nodes (recommended 3+)
- Understanding of Pods and Deployments

## 🚀 Quick Start

### Apply Taints to Nodes

```bash
# Taint a node to repel pods
kubectl taint nodes worker-1 workload=frontend:NoSchedule

# Taint GPU node
kubectl taint nodes gpu-node gpu=true:NoSchedule

# Taint node for maintenance
kubectl taint nodes worker-2 maintenance=true:NoExecute

# Remove taint
kubectl taint nodes worker-1 workload:NoSchedule-
```

### Add Tolerations to Pods

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: frontend-pod
spec:
  tolerations:
  - key: "workload"
    operator: "Equal"
    value: "frontend"
    effect: "NoSchedule"
  containers:
  - name: frontend
    image: nginx:1.21
```

### Configure Node Affinity

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: database
spec:
  template:
    spec:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: disk-type
                operator: In
                values:
                - ssd
      containers:
      - name: postgres
        image: postgres:15
```

### Set Up Pod Anti-Affinity for HA

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
spec:
  replicas: 3
  template:
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchLabels:
                app: web-app
            topologyKey: kubernetes.io/hostname
      containers:
      - name: app
        image: web-app:1.0
```

## 📊 Key Concepts

### Taint Effects

| Effect | New Pods | Existing Pods | Use Case |
|--------|----------|---------------|----------|
| **NoSchedule** | Blocked | Stay | Dedicated nodes |
| **PreferNoSchedule** | Avoided | Stay | Soft restriction |
| **NoExecute** | Blocked | Evicted | Maintenance mode |

### Affinity Types

| Type | Direction | Purpose | Example |
|------|-----------|---------|---------|
| **Node Affinity** | Pod → Node | Hardware requirements | SSD for DB |
| **Pod Affinity** | Pod → Pod (together) | Co-location | Cache + API |
| **Pod Anti-Affinity** | Pod → Pod (apart) | Distribution | HA replicas |

### Required vs Preferred

| Type | Behavior | Use Case |
|------|----------|----------|
| **Required** | Hard constraint (must match) | Critical requirements |
| **Preferred** | Soft constraint (best effort) | Optimization hints |

## 🎓 Important Concepts

### Topology Keys

Common topology keys for pod affinity/anti-affinity:

```yaml
# Spread across nodes
topologyKey: kubernetes.io/hostname

# Spread across zones
topologyKey: topology.kubernetes.io/zone

# Spread across regions
topologyKey: topology.kubernetes.io/region

# Custom labels
topologyKey: rack
topologyKey: datacenter
```

### Operators

Node affinity operators:

| Operator | Meaning | Example |
|----------|---------|---------|
| **In** | Value in list | env In [prod, staging] |
| **NotIn** | Value not in list | env NotIn [dev] |
| **Exists** | Key exists | gpu Exists |
| **DoesNotExist** | Key doesn't exist | temp DoesNotExist |
| **Gt** | Greater than | cpu Gt 8 |
| **Lt** | Less than | memory Lt 16 |

## 📈 Architecture Patterns

### Pattern 1: High Availability

```
┌─────────────────────────────────────┐
│         Load Balancer               │
└────────────┬────────────────────────┘
             │
    ┌────────┴────────┐
    │                 │
┌───▼────┐       ┌───▼────┐
│ Node 1 │       │ Node 2 │
│ Pod A  │       │ Pod B  │  ← Anti-Affinity
└────────┘       └────────┘
    │                 │
    └────────┬────────┘
          ┌──▼───┐
          │ Node 3│
          │ Pod C │
          └───────┘
```

### Pattern 2: Hardware Specialization

```
┌─────────────────────────────────────┐
│ GPU Nodes (Tainted)                 │
│ ├── ML Training Pod                 │
│ └── AI Inference Pod                │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│ SSD Nodes (Node Affinity)           │
│ ├── PostgreSQL-0                    │
│ ├── PostgreSQL-1                    │
│ └── PostgreSQL-2                    │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│ Standard Nodes                       │
│ ├── Frontend Pods                   │
│ ├── Backend Pods                    │
│ └── Cache Pods                      │
└─────────────────────────────────────┘
```

### Pattern 3: Co-location

```
┌─────────────────────────┐
│ Node 1                  │
│ ┌─────────┐ ┌─────────┐│
│ │ API Pod │─│Cache Pod││ ← Pod Affinity
│ └─────────┘ └─────────┘│  (Low Latency)
└─────────────────────────┘
```

## 🔍 Quick Commands

```bash
# Taints
kubectl taint nodes <n> key=value:NoSchedule
kubectl taint nodes <n> key:NoSchedule-
kubectl describe node <n> | grep Taints

# Check pod placement
kubectl get pods -o wide
kubectl get pods --field-selector spec.nodeName=<n>

# Debug scheduling
kubectl describe pod <n> | grep -A 10 Events
kubectl get events --field-selector involvedObject.name=<pod>

# Node labels
kubectl label nodes <n> disk-type=ssd
kubectl get nodes --show-labels
```

## 💡 Pro Tips

### Best Practices

**Taints**:
- Document all taints clearly
- Use NoSchedule for most cases
- Be cautious with NoExecute (evicts pods!)
- Remove taints after maintenance
- Use descriptive key names

**Tolerations**:
- Match exactly to taint key/value/effect
- Set tolerationSeconds for NoExecute
- Don't tolerate everything
- Review and cleanup regularly

**Node Affinity**:
- Use `required` for must-have requirements
- Use `preferred` with weights for nice-to-have
- Keep selectors simple
- Test with `--dry-run` first

**Pod Anti-Affinity**:
- Essential for stateful applications
- Use `hostname` topology for node spread
- Use `zone` topology for AZ spread
- Combine with replica count > number of nodes/zones

**Pod Affinity**:
- Use sparingly (can cause scheduling constraints)
- Prefer soft (preferred) over hard (required)
- Document pod relationships
- Monitor for scheduling failures

## 🐛 Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| Pod pending | No nodes match affinity | Check node labels |
| Pod evicted | NoExecute taint added | Add toleration |
| Pods clustering | No anti-affinity | Add podAntiAffinity |
| Can't schedule | Too many required rules | Use preferred rules |

## 📖 Documentation Files

| File | Description | Lines |
|------|-------------|-------|
| **GUIDE.md** | Complete guide | ~3000 |
| **INTERVIEW-QA.md** | 25 interview Q&A | ~2500 |
| **COMMANDS-CHEATSHEET.md** | Quick reference | ~500 |
| **TROUBLESHOOTING.md** | Issues & solutions | ~1500 |
| **Scripts** | Automation | ~800 |
| **YAML Examples** | 40+ examples | ~2000 |

## 🎯 Learning Path

### Day 1: Taints & Tolerations
1. Understand taint effects
2. Apply taints to nodes
3. Add tolerations to pods
4. Test NoExecute behavior
5. Practice master node isolation

### Day 2: Affinity & Anti-Affinity
1. Configure node affinity
2. Implement pod anti-affinity for HA
3. Use pod affinity for co-location
4. Build complete HA architecture
5. Optimize resource placement

## 🧪 Hands-On Exercises

1. **Exercise 1**: Taint GPU nodes, deploy ML workload with toleration
2. **Exercise 2**: Spread 5 replicas across 3 nodes using anti-affinity
3. **Exercise 3**: Co-locate cache with API using pod affinity
4. **Exercise 4**: Build 3-tier HA application
5. **Exercise 5**: Debug pods stuck in Pending state

## 📚 Additional Resources

- [Taints & Tolerations](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/)
- [Assign Pods to Nodes](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/)
- [Pod Affinity/Anti-Affinity](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#affinity-and-anti-affinity)
- [Topology Spread Constraints](https://kubernetes.io/docs/concepts/scheduling-eviction/topology-spread-constraints/)

## 🎓 CKA Exam Preparation

### Must Know Topics
- Apply/remove taints from nodes
- Add tolerations to pod specs
- Configure requiredDuringScheduling node affinity
- Set up pod anti-affinity for HA
- Debug scheduling failures
- Understand topology keys

### Practice Scenarios
1. Isolate master nodes with taints
2. Dedicate GPU nodes for ML workloads
3. Ensure database pods on SSD nodes
4. Spread replicas for high availability
5. Co-locate related services
6. Fix pods stuck in Pending

## 🚀 Next Steps

After completing this module:
1. ✅ Implement HA for production applications
2. ✅ Optimize hardware utilization
3. ✅ Build fault-tolerant architectures
4. ✅ Practice scheduling scenarios
5. ✅ Move to **Day 23-24: RBAC & Security**

## 📞 Support & Feedback

- Questions? Check TROUBLESHOOTING.md
- Issues? Review INTERVIEW-QA.md
- Need help? Use automation scripts
- Practice? Run hands-on exercises

---

**🎯 Current Status**: Day 21-22 Complete  
**📈 Progress**: 29% of Kubernetes Learning Path  
**⏭️ Next Module**: Day 23-24 - RBAC & Security  
**🎓 Certification Ready**: Advanced Scheduling ✅

---

*Master pod scheduling for production-ready Kubernetes! 🚀*
