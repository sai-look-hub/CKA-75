# GUIDEME: Week 3-4 Review & Multi-Environment Deployment

## 🎯 Overview

Complete step-by-step guide to building a production-ready multi-environment Kubernetes deployment, bringing together all concepts from Weeks 3-4.

**Estimated Time**: 4-6 hours  
**Difficulty**: Intermediate to Advanced

---

## 📚 Table of Contents

1. [Environment Setup](#step-1-environment-setup)
2. [Infrastructure Configuration](#step-2-infrastructure-configuration)
3. [Development Environment](#step-3-development-environment)
4. [Staging Environment](#step-4-staging-environment)
5. [Production Environment](#step-5-production-environment)
6. [Shared Services](#step-6-shared-services)
7. [Testing & Validation](#step-7-testing--validation)
8. [Monitoring & Optimization](#step-8-monitoring--optimization)
9. [Cleanup](#step-9-cleanup)

---

## Step 1: Environment Setup

### 1.1 Verify Cluster

```bash
# Check cluster access
kubectl cluster-info

# Check nodes (need at least 3)
kubectl get nodes

# Check metrics server
kubectl top nodes

# Expected: At least 3 worker nodes running
```

### 1.2 Label Nodes

```bash
# Label production nodes
kubectl label nodes node-1 environment=production tier=high-performance zone=us-west-1a
kubectl label nodes node-2 environment=production tier=high-performance zone=us-west-1b

# Label staging nodes
kubectl label nodes node-3 environment=staging tier=medium-performance zone=us-west-1c

# If you have more nodes:
# kubectl label nodes node-4 environment=development tier=standard zone=us-west-1a

# Verify labels
kubectl get nodes --show-labels
kubectl get nodes -L environment,tier,zone
```

### 1.3 Review Week 3-4 Concepts

```bash
# Topics we'll use:
# - Node affinity (Day 19-20)
# - Pod anti-affinity (Day 19-20)
# - Resource quotas (Day 23-24)
# - LimitRanges (Day 23-24)
# - HPA (Day 25-26)
# - DaemonSets (Day 15-16)
# - StatefulSets (Day 15-16)
```

**✅ Checkpoint**: Nodes labeled, cluster ready.

---

## Step 2: Infrastructure Configuration

### 2.1 Create Namespaces

```bash
# Create all three namespaces
kubectl apply -f examples/01-infrastructure/namespaces.yaml

# Verify
kubectl get namespaces

# Expected output:
# NAME          STATUS   AGE
# development   Active   5s
# staging       Active   5s
# production    Active   5s
```

### 2.2 Apply ResourceQuotas and LimitRanges

```bash
# Apply resource policies
kubectl apply -f examples/01-infrastructure/resource-quotas.yaml

# Verify development
kubectl describe resourcequota -n development
kubectl describe limitrange -n development

# Expected:
# Resource           Used  Hard
# --------           ----  ----
# limits.cpu         0     20
# limits.memory      0     40Gi
# requests.cpu       0     10
# requests.memory    0     20Gi
# pods              0     50

# Verify staging
kubectl describe resourcequota -n staging

# Expected quotas:
# requests.cpu: 20, requests.memory: 40Gi

# Verify production
kubectl describe resourcequota -n production

# Expected quotas:
# requests.cpu: 50, requests.memory: 100Gi
```

### 2.3 Understand Resource Distribution

```bash
# View all quotas
kubectl get resourcequota -A

# Compare limits
kubectl get resourcequota -A -o custom-columns=\
NAMESPACE:.metadata.namespace,\
CPU:.spec.hard.requests\\.cpu,\
MEMORY:.spec.hard.requests\\.memory,\
PODS:.spec.hard.pods
```

**✅ Checkpoint**: All namespaces created with proper quotas.

---

## Step 3: Development Environment

### 3.1 Deploy Backend Service

Create: `examples/02-development/backend-dev.yaml`

```bash
# Apply backend
kubectl apply -f examples/02-development/backend-dev.yaml

# Verify
kubectl get deployment backend -n development
kubectl get pods -n development -o wide

# Check resources
kubectl describe pod -n development | grep -A 5 "Requests\|Limits"

# Expected:
# - 1 replica
# - Burstable QoS
# - Minimal resources
```

### 3.2 Deploy Frontend Service

Create: `examples/02-development/frontend-dev.yaml`

```bash
# Apply frontend
kubectl apply -f examples/02-development/frontend-dev.yaml

# Check service
kubectl get svc -n development

# Test connectivity
kubectl run test --rm -it --image=busybox -n development -- \
  wget -qO- http://backend:8080/health
```

### 3.3 Deploy Database (StatefulSet)

Create: `examples/02-development/database-dev.yaml`

```bash
# Apply database
kubectl apply -f examples/02-development/database-dev.yaml

# Watch StatefulSet
kubectl get statefulset -n development -w

# Check PVCs
kubectl get pvc -n development

# Expected:
# - 1 replica
# - PVC created
# - Pod running
```

### 3.4 Check Resource Usage

```bash
# View quota usage
kubectl describe resourcequota dev-quota -n development

# Expected:
# requests.cpu       600m     10    (6% used)
# requests.memory    896Mi    20Gi  (4% used)
# pods              3        50    (6% used)

# Check actual usage
kubectl top pods -n development
```

**✅ Checkpoint**: Development environment running with minimal resources.

---

## Step 4: Staging Environment

### 4.1 Deploy Backend with Anti-Affinity

Create: `examples/03-staging/backend-staging.yaml`

```bash
# Apply backend
kubectl apply -f examples/03-staging/backend-staging.yaml

# Verify pod spread
kubectl get pods -n staging -o wide

# Expected:
# - 2 replicas
# - On different nodes (anti-affinity)
# - Medium resources
```

### 4.2 Deploy Frontend

Create: `examples/03-staging/frontend-staging.yaml`

```bash
# Apply frontend
kubectl apply -f examples/03-staging/frontend-staging.yaml

# Check deployment
kubectl get deployment frontend -n staging

# Verify node placement
kubectl get pods -n staging -o custom-columns=\
NAME:.metadata.name,\
NODE:.spec.nodeName,\
QOS:.status.qosClass
```

### 4.3 Deploy Database StatefulSet

Create: `examples/03-staging/database-staging.yaml`

```bash
# Apply database
kubectl apply -f examples/03-staging/database-staging.yaml

# Watch creation
kubectl get pods -n staging -w

# Check PVCs
kubectl get pvc -n staging

# Expected:
# - 2 replicas (ha)
# - Different nodes
# - 2 PVCs
```

### 4.4 Deploy CronJob

Create: `examples/03-staging/cronjob-staging.yaml`

```bash
# Apply cronjob
kubectl apply -f examples/03-staging/cronjob-staging.yaml

# Verify cronjob
kubectl get cronjob -n staging

# Manually trigger job
kubectl create job --from=cronjob/backup-job manual-backup -n staging

# Check job status
kubectl get jobs -n staging
```

### 4.5 Check Resource Usage

```bash
# View quota usage
kubectl describe resourcequota staging-quota -n staging

# Check actual usage
kubectl top pods -n staging

# Compare with development
kubectl top pods -A
```

**✅ Checkpoint**: Staging environment with HA and medium resources.

---

## Step 5: Production Environment

### 5.1 Deploy Backend with Full HA

Create: `examples/04-production/backend-prod.yaml`

```bash
# Apply backend
kubectl apply -f examples/04-production/backend-prod.yaml

# Verify deployment
kubectl get deployment backend -n production

# Check pod distribution
kubectl get pods -n production -o custom-columns=\
NAME:.metadata.name,\
NODE:.spec.nodeName,\
ZONE:.metadata.labels.zone

# Expected:
# - 5 replicas
# - Spread across zones
# - Guaranteed QoS
```

### 5.2 Verify HPA Configuration

```bash
# Check HPA
kubectl get hpa -n production

# Describe HPA
kubectl describe hpa backend-hpa -n production

# Expected:
# - minReplicas: 5
# - maxReplicas: 20
# - Target CPU: 70%
# - Target Memory: 80%
```

### 5.3 Deploy Frontend with LoadBalancer

Create: `examples/04-production/frontend-prod.yaml`

```bash
# Apply frontend
kubectl apply -f examples/04-production/frontend-prod.yaml

# Get external IP (if LoadBalancer available)
kubectl get svc frontend -n production

# Test
curl http://<EXTERNAL-IP>
```

### 5.4 Deploy Database Cluster

Create: `examples/04-production/database-prod.yaml`

```bash
# Apply database
kubectl apply -f examples/04-production/database-prod.yaml

# Watch StatefulSet
kubectl get statefulset -n production -w

# Check all replicas
kubectl get pods -n production -l app=database

# Verify zone spread
kubectl get pods -n production -l app=database -o custom-columns=\
NAME:.metadata.name,\
NODE:.spec.nodeName

# Expected:
# - 3 replicas
# - Different zones
# - PVCs created
```

### 5.5 Deploy Cache (Redis)

Create: `examples/04-production/cache-prod.yaml`

```bash
# Apply Redis
kubectl apply -f examples/04-production/cache-prod.yaml

# Verify
kubectl get statefulset redis -n production

# Check service
kubectl get svc redis -n production

# Test connection
kubectl run redis-test --rm -it --image=redis -n production -- \
  redis-cli -h redis ping
```

### 5.6 Check Resource Usage

```bash
# View quota usage
kubectl describe resourcequota prod-quota -n production

# Expected:
# requests.cpu       30       50    (60% used)
# requests.memory    40Gi     100Gi (40% used)
# pods              15       200   (7.5% used)

# Check actual usage
kubectl top pods -n production
```

**✅ Checkpoint**: Production environment with full HA and generous resources.

---

## Step 6: Shared Services

### 6.1 Deploy Logging DaemonSet

Create: `examples/05-shared-services/logging-daemonset.yaml`

```bash
# Apply logging
kubectl apply -f examples/05-shared-services/logging-daemonset.yaml

# Verify on all nodes
kubectl get pods -l app=fluentd -o wide

# Expected: One pod per node
```

### 6.2 Deploy Monitoring DaemonSet

Create: `examples/05-shared-services/monitoring-daemonset.yaml`

```bash
# Apply monitoring
kubectl apply -f examples/05-shared-services/monitoring-daemonset.yaml

# Check status
kubectl get daemonset -n kube-system
```

### 6.3 Verify DaemonSet Coverage

```bash
# Count nodes
kubectl get nodes --no-headers | wc -l

# Count logging pods
kubectl get pods -l app=fluentd --no-headers | wc -l

# Should match!

# Check which nodes have logging
kubectl get pods -l app=fluentd -o wide
```

**✅ Checkpoint**: Shared services running on all nodes.

---

## Step 7: Testing & Validation

### 7.1 Validate Environment Isolation

```bash
# Try to access production from dev (should fail with NetworkPolicy)
kubectl run test -it --rm --image=busybox -n development -- \
  wget -qO- http://backend.production:8080

# Check resource isolation
kubectl get resourcequota -A
```

### 7.2 Test Pod Distribution

```bash
# Check pods per node
kubectl get pods -A -o wide | awk '{print $8}' | sort | uniq -c

# Verify anti-affinity
kubectl get pods -n production -o custom-columns=\
APP:.metadata.labels.app,\
NODE:.spec.nodeName | grep backend

# All backend pods should be on different nodes
```

### 7.3 Test QoS Classes

```bash
# Check QoS distribution
kubectl get pods -A -o custom-columns=\
NAMESPACE:.metadata.namespace,\
NAME:.metadata.name,\
QOS:.status.qosClass | grep -E 'production|staging|development'

# Expected:
# development: Burstable/BestEffort
# staging: Burstable
# production: Guaranteed
```

### 7.4 Test Resource Limits

```bash
# Try to exceed quota in dev
kubectl run big-pod --image=nginx -n development \
  --requests='cpu=15,memory=25Gi'

# Should fail with quota exceeded

# Verify quota enforcement
kubectl describe resourcequota -n development
```

### 7.5 Test HPA

```bash
# Generate load on production backend
kubectl run load-generator --rm -it --image=busybox -n production -- \
  /bin/sh -c "while true; do wget -q -O- http://backend:8080; done"

# Watch HPA scale up
watch kubectl get hpa -n production

# Check pod count increase
kubectl get deployment backend -n production

# Stop load generator (Ctrl+C)
# Watch scale down
```

**✅ Checkpoint**: All environments tested and validated.

---

## Step 8: Monitoring & Optimization

### 8.1 Check Cluster Utilization

```bash
# Node usage
kubectl top nodes

# Pod usage by namespace
kubectl top pods -n development
kubectl top pods -n staging
kubectl top pods -n production

# Total resource requests
kubectl get pods -A -o json | jq -r '
  .items[] | 
  .spec.containers[] | 
  .resources.requests.cpu' | 
  awk '{s+=$1} END {print s}'
```

### 8.2 Review Quota Usage

```bash
# Check all quotas
kubectl get resourcequota -A

# Detailed view
for ns in development staging production; do
  echo "=== $ns ==="
  kubectl describe resourcequota -n $ns | grep -A 10 "Used"
done
```

### 8.3 Identify Optimization Opportunities

```bash
# Find pods with low CPU usage
kubectl top pods -A --sort-by=cpu | head -20

# Find pods with low memory usage
kubectl top pods -A --sort-by=memory | head -20

# Compare requests vs actual usage
kubectl get pods -A -o custom-columns=\
NAMESPACE:.metadata.namespace,\
NAME:.metadata.name,\
CPU_REQ:.spec.containers[*].resources.requests.cpu,\
MEM_REQ:.spec.containers[*].resources.requests.memory

# Then compare with kubectl top output
```

### 8.4 Generate Summary Report

```bash
# Environment summary
cat << 'EOF' > /tmp/summary.sh
#!/bin/bash
for ns in development staging production; do
  echo "==================================="
  echo "Environment: $ns"
  echo "==================================="
  echo "Deployments: $(kubectl get deploy -n $ns --no-headers | wc -l)"
  echo "StatefulSets: $(kubectl get sts -n $ns --no-headers | wc -l)"
  echo "Services: $(kubectl get svc -n $ns --no-headers | wc -l)"
  echo "Pods: $(kubectl get pods -n $ns --no-headers | wc -l)"
  echo ""
  kubectl describe resourcequota -n $ns | grep -A 8 "Resource.*Used.*Hard"
  echo ""
done
EOF

chmod +x /tmp/summary.sh
/tmp/summary.sh
```

**✅ Checkpoint**: Complete monitoring and optimization review done.

---

## Step 9: Cleanup

### 9.1 Delete by Environment

```bash
# Option 1: Delete specific environment
kubectl delete namespace development

# Option 2: Delete all test namespaces
kubectl delete namespace development staging production

# Verify deletion
kubectl get namespaces
```

### 9.2 Remove Node Labels (Optional)

```bash
# Remove labels
kubectl label nodes --all environment- tier- zone-

# Verify
kubectl get nodes --show-labels
```

### 9.3 Delete Shared Services

```bash
# Delete DaemonSets
kubectl delete daemonset fluentd -n kube-system
kubectl delete daemonset node-exporter -n kube-system
```

### 9.4 Verify Cleanup

```bash
# Check namespaces
kubectl get namespaces

# Check remaining resources
kubectl get all -A

# Should only see kube-system and default
```

**✅ Checkpoint**: Clean cluster ready for next project!

---

## 🎓 What You've Accomplished

Congratulations! You've completed a production-ready multi-environment deployment!

**Skills Applied:**
1. ✅ Node labeling and affinity (Day 19-20)
2. ✅ Pod anti-affinity for HA (Day 19-20)
3. ✅ ResourceQuotas and LimitRanges (Day 23-24)
4. ✅ QoS classes (Day 23-24)
5. ✅ HPA configuration (Day 25-26)
6. ✅ StatefulSets for databases (Day 15-16)
7. ✅ DaemonSets for shared services (Day 15-16)
8. ✅ CronJobs for scheduled tasks (Day 17-18)

**Environments Created:**
- ✅ Development (cost-optimized)
- ✅ Staging (production-like)
- ✅ Production (high-availability)

**Best Practices Applied:**
- ✅ Environment isolation
- ✅ Resource governance
- ✅ High availability
- ✅ Auto-scaling
- ✅ Proper scheduling

---

## 📖 Next Steps

1. **Review**: Go through each environment configuration
2. **Customize**: Adapt to your specific needs
3. **Document**: Create runbooks for your team
4. **Share**: Post your journey on LinkedIn
5. **Continue**: Move to Week 5 topics!

---

**Happy Deploying! 🚀**
