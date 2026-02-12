# Day 27-28: Week 3-4 Review & Multi-Environment Project

## 📋 Table of Contents
- [Overview](#overview)
- [Week 3-4 Topics Covered](#week-3-4-topics-covered)
- [Multi-Environment Architecture](#multi-environment-architecture)
- [Prerequisites](#prerequisites)
- [Project Structure](#project-structure)
- [Quick Start](#quick-start)
- [Learning Objectives](#learning-objectives)
- [Best Practices](#best-practices)
- [Additional Resources](#additional-resources)

## 📖 Overview

This capstone project brings together everything learned in Weeks 3-4, implementing a complete multi-environment deployment with proper workload scheduling, resource management, and production-ready patterns.

**What You'll Build:**
- 3 environments (Development, Staging, Production)
- Different scheduling policies per environment
- Resource quotas and limits
- Node affinity and anti-affinity
- Complete CI/CD-ready structure

## 🎯 Week 3-4 Topics Covered

### Week 3: Advanced Pod Scheduling

**Day 15-16: DaemonSets & StatefulSets**
- DaemonSets for node-level services
- StatefulSets for stateful applications
- Persistent storage management
- Ordered deployment/scaling

**Day 17-18: Jobs & CronJobs**
- Batch processing with Jobs
- Scheduled tasks with CronJobs
- Job completion and cleanup
- Parallel execution patterns

**Day 19-20: Manual Scheduling & Node Selection**
- nodeName direct assignment
- nodeSelector label-based scheduling
- Node affinity (required/preferred)
- Topology spread constraints

**Day 21-22: Taints, Tolerations & Node Affinity**
- Taints to repel pods from nodes
- Tolerations to allow scheduling
- Advanced node affinity patterns
- Multi-zone deployments

### Week 4: Resource Management & Optimization

**Day 23-24: Resource Limits & Requests**
- CPU and memory management
- QoS classes (Guaranteed, Burstable, BestEffort)
- ResourceQuotas for namespaces
- LimitRanges for defaults

**Day 25-26: Horizontal Pod Autoscaler (HPA)**
- Automatic scaling based on metrics
- CPU/Memory-based scaling
- Custom metrics scaling
- Scaling best practices

**Day 27-28: Week Review & Multi-Environment Project** ← You are here!

## 🏗️ Multi-Environment Architecture

### Environment Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                       │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌───────────────────────────────────────────────────┐     │
│  │ Production Namespace                              │     │
│  ├───────────────────────────────────────────────────┤     │
│  │ • High resource quotas (50 CPU, 100Gi RAM)       │     │
│  │ • Guaranteed QoS for critical services           │     │
│  │ • Node affinity: production nodes only           │     │
│  │ • Anti-affinity: spread across zones             │     │
│  │ • Strict limits enforcement                      │     │
│  │ • 3 replicas minimum                             │     │
│  └───────────────────────────────────────────────────┘     │
│                                                             │
│  ┌───────────────────────────────────────────────────┐     │
│  │ Staging Namespace                                 │     │
│  ├───────────────────────────────────────────────────┤     │
│  │ • Medium resource quotas (20 CPU, 40Gi RAM)      │     │
│  │ • Burstable QoS                                  │     │
│  │ • Node affinity: staging nodes preferred         │     │
│  │ • Anti-affinity: spread across nodes             │     │
│  │ • Moderate limits                                │     │
│  │ • 2 replicas                                     │     │
│  └───────────────────────────────────────────────────┘     │
│                                                             │
│  ┌───────────────────────────────────────────────────┐     │
│  │ Development Namespace                             │     │
│  ├───────────────────────────────────────────────────┤     │
│  │ • Lower resource quotas (10 CPU, 20Gi RAM)       │     │
│  │ • Burstable/BestEffort QoS                       │     │
│  │ • Node affinity: development nodes               │     │
│  │ • No anti-affinity (cost saving)                 │     │
│  │ • Flexible limits                                │     │
│  │ • 1 replica                                      │     │
│  └───────────────────────────────────────────────────┘     │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Node Labeling Strategy

```bash
# Production nodes
kubectl label nodes prod-node-{1,2,3} \
  environment=production \
  tier=high-performance \
  zone=us-west-1a

# Staging nodes
kubectl label nodes staging-node-{1,2} \
  environment=staging \
  tier=medium-performance \
  zone=us-west-1b

# Development nodes
kubectl label nodes dev-node-1 \
  environment=development \
  tier=standard \
  zone=us-west-1c
```

## 📋 Prerequisites

- Kubernetes cluster (v1.24+)
- kubectl configured with admin access
- At least 3 worker nodes (ideally 6+ for full separation)
- Metrics Server installed
- Basic understanding of all Week 3-4 topics

### Verify Setup

```bash
# Check cluster
kubectl cluster-info

# Check nodes
kubectl get nodes

# Check metrics server
kubectl top nodes

# Verify permissions
kubectl auth can-i create namespace
kubectl auth can-i create resourcequota
```

## 📁 Project Structure

```
day27-28-week-review/
├── README.md
├── GUIDEME.md
├── COMMAND-CHEATSHEET.md
├── INTERVIEW-QA.md
├── TROUBLESHOOTING.md
├── LINKEDIN-POSTS.md
├── examples/
│   ├── 01-infrastructure/
│   │   ├── namespaces.yaml
│   │   ├── node-labels.sh
│   │   └── resource-quotas.yaml
│   ├── 02-development/
│   │   ├── backend-dev.yaml
│   │   ├── frontend-dev.yaml
│   │   ├── database-dev.yaml
│   │   └── jobs-dev.yaml
│   ├── 03-staging/
│   │   ├── backend-staging.yaml
│   │   ├── frontend-staging.yaml
│   │   ├── database-staging.yaml
│   │   └── cronjobs-staging.yaml
│   ├── 04-production/
│   │   ├── backend-prod.yaml
│   │   ├── frontend-prod.yaml
│   │   ├── database-prod.yaml
│   │   ├── cache-prod.yaml
│   │   └── monitoring-prod.yaml
│   ├── 05-shared-services/
│   │   ├── logging-daemonset.yaml
│   │   ├── monitoring-daemonset.yaml
│   │   └── ingress-controller.yaml
│   └── 06-complete-stack/
│       └── full-deployment.yaml
├── scripts/
│   ├── setup-cluster.sh
│   ├── deploy-dev.sh
│   ├── deploy-staging.sh
│   ├── deploy-prod.sh
│   ├── validate-deployment.sh
│   └── cleanup.sh
└── docs/
    ├── architecture.md
    └── decision-log.md
```

## 🚀 Quick Start

### Step 1: Setup Infrastructure

```bash
# Label nodes
./scripts/setup-cluster.sh

# Create namespaces and quotas
kubectl apply -f examples/01-infrastructure/
```

### Step 2: Deploy Development Environment

```bash
# Deploy dev environment
./scripts/deploy-dev.sh

# Verify
kubectl get all -n development
```

### Step 3: Deploy Staging Environment

```bash
# Deploy staging
./scripts/deploy-staging.sh

# Verify
kubectl get all -n staging
```

### Step 4: Deploy Production Environment

```bash
# Deploy production
./scripts/deploy-prod.sh

# Verify
kubectl get all -n production
```

### Step 5: Validate Complete Setup

```bash
# Run validation
./scripts/validate-deployment.sh

# Check resource usage
kubectl top pods -A
```

## 🎓 Learning Objectives

By completing this project, you will:

1. ✅ Apply all Week 3-4 concepts in real scenario
2. ✅ Build production-ready multi-environment setup
3. ✅ Implement proper resource governance
4. ✅ Use advanced scheduling patterns
5. ✅ Configure environment-specific policies
6. ✅ Create reusable deployment templates
7. ✅ Understand CI/CD integration patterns
8. ✅ Master troubleshooting multi-env issues

## 🌍 Environment Specifications

### Development Environment

**Purpose**: Fast iteration, experimentation

**Characteristics:**
```yaml
Replicas: 1
QoS: Burstable or BestEffort
Resources: Minimal (100m CPU, 128Mi RAM)
Node Affinity: development nodes
Anti-Affinity: None (cost saving)
ResourceQuota: 10 CPU, 20Gi RAM, 50 pods
LimitRange: Flexible (50m-2 CPU, 64Mi-2Gi)
```

**Use Cases:**
- Feature development
- Bug fixes
- Integration testing
- Experimentation

### Staging Environment

**Purpose**: Pre-production validation

**Characteristics:**
```yaml
Replicas: 2
QoS: Burstable
Resources: Medium (250m CPU, 256Mi RAM)
Node Affinity: staging nodes preferred
Anti-Affinity: Spread across nodes
ResourceQuota: 20 CPU, 40Gi RAM, 100 pods
LimitRange: Moderate (100m-4 CPU, 128Mi-4Gi)
```

**Use Cases:**
- Integration testing
- Performance testing
- UAT
- Release validation

### Production Environment

**Purpose**: Live customer traffic

**Characteristics:**
```yaml
Replicas: 3+ (minimum)
QoS: Guaranteed for critical services
Resources: Generous (500m CPU, 512Mi RAM minimum)
Node Affinity: production nodes required
Anti-Affinity: Spread across zones
ResourceQuota: 50 CPU, 100Gi RAM, 200 pods
LimitRange: Strict (250m-8 CPU, 256Mi-16Gi)
```

**Use Cases:**
- Customer-facing applications
- Critical services
- High availability required
- Performance critical

## ✅ Best Practices Applied

### 1. Environment Isolation

```yaml
# Production namespace with strict isolation
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    environment: production
    tier: critical
---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: prod-quota
  namespace: production
spec:
  hard:
    requests.cpu: "50"
    requests.memory: 100Gi
    limits.cpu: "100"
    limits.memory: 200Gi
    pods: "200"
---
apiVersion: v1
kind: LimitRange
metadata:
  name: prod-limits
  namespace: production
spec:
  limits:
  - type: Container
    min:
      cpu: "250m"
      memory: "256Mi"
    max:
      cpu: "8"
      memory: "16Gi"
    defaultRequest:
      cpu: "500m"
      memory: "512Mi"
    default:
      cpu: "1000m"
      memory: "1Gi"
```

### 2. Progressive Deployment

```
Development → Staging → Production

1. Deploy to dev
2. Run tests
3. Promote to staging
4. Run integration tests
5. Manual approval
6. Deploy to production
7. Monitor & validate
```

### 3. High Availability

```yaml
# Production deployment with HA
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend-prod
  namespace: production
spec:
  replicas: 5  # Minimum 3 for HA
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
  selector:
    matchLabels:
      app: backend
      environment: production
  template:
    metadata:
      labels:
        app: backend
        environment: production
    spec:
      # Node affinity: production nodes only
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: environment
                operator: In
                values:
                - production
        # Pod anti-affinity: spread across zones
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchLabels:
                app: backend
                environment: production
            topologyKey: topology.kubernetes.io/zone
      # Guaranteed QoS for stability
      containers:
      - name: backend
        image: backend:v1.0.0
        resources:
          requests:
            cpu: "1000m"
            memory: "1Gi"
          limits:
            cpu: "1000m"
            memory: "1Gi"
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 5
```

### 4. Resource Optimization

```yaml
# Development: Minimal resources
resources:
  requests:
    cpu: "100m"
    memory: "128Mi"
  limits:
    cpu: "250m"
    memory: "256Mi"

# Staging: Medium resources
resources:
  requests:
    cpu: "250m"
    memory: "256Mi"
  limits:
    cpu: "500m"
    memory: "512Mi"

# Production: Generous resources
resources:
  requests:
    cpu: "1000m"
    memory: "1Gi"
  limits:
    cpu: "1000m"  # Guaranteed QoS
    memory: "1Gi"
```

### 5. Shared Services

```yaml
# DaemonSet for logging (all nodes)
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluentd
  namespace: kube-system
spec:
  selector:
    matchLabels:
      app: fluentd
  template:
    metadata:
      labels:
        app: fluentd
    spec:
      tolerations:
      - key: node-role.kubernetes.io/control-plane
        effect: NoSchedule
      containers:
      - name: fluentd
        image: fluent/fluentd-kubernetes-daemonset:v1
        resources:
          requests:
            cpu: "100m"
            memory: "200Mi"
          limits:
            cpu: "200m"
            memory: "400Mi"
        volumeMounts:
        - name: varlog
          mountPath: /var/log
      volumes:
      - name: varlog
        hostPath:
          path: /var/log
```

## 🔍 Comparison Matrix

| Feature | Development | Staging | Production |
|---------|-------------|---------|------------|
| **Replicas** | 1 | 2 | 3-5+ |
| **QoS Class** | Burstable/BestEffort | Burstable | Guaranteed |
| **CPU Request** | 100m | 250m | 1000m |
| **Memory Request** | 128Mi | 256Mi | 1Gi |
| **Anti-Affinity** | None | Node-level | Zone-level |
| **Resource Quota** | 10 CPU, 20Gi | 20 CPU, 40Gi | 50 CPU, 100Gi |
| **Max Pods** | 50 | 100 | 200 |
| **Health Checks** | Optional | Required | Required |
| **Monitoring** | Basic | Standard | Advanced |
| **Backup** | None | Daily | Hourly |
| **Cost** | Low | Medium | High |

## 📊 Resource Allocation

### Cluster Resource Distribution

```
Total Cluster: 60 CPUs, 120Gi RAM

Production:   50 CPUs (83%), 100Gi RAM (83%)
Staging:      20 CPUs (33%), 40Gi RAM (33%)
Development:  10 CPUs (17%), 20Gi RAM (17%)

Note: Quotas are limits, not reservations
Actual usage typically much lower
```


### Official Documentation
- [Resource Management](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)
- [Assigning Pods to Nodes](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/)
- [Multi-tenancy](https://kubernetes.io/docs/concepts/security/multi-tenancy/)

### Learning Resources
- Command Cheatsheet: [COMMAND-CHEATSHEET.md](./COMMAND-CHEATSHEET.md)
- Interview Questions: [INTERVIEW-QA.md](./INTERVIEW-QA.md)
- Step-by-Step Guide: [GUIDEME.md](./GUIDEME.md)
- Troubleshooting: [TROUBLESHOOTING.md](./TROUBLESHOOTING.md)

---

## 🤝 Contributing

This is a capstone project combining all Week 3-4 learnings!

## 📝 License

This project is licensed under the MIT License.

## 👨‍💻 Author

**Your Name**
- GitHub: (https://github.com/sai-look-hub/CKA-75/new/main)
- LinkedIn: www.linkedin.com/in/saikumara

---

**Happy Learning! 🚀**

*Master Kubernetes workload scheduling and build production-ready multi-environment deployments!*
