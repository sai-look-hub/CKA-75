# Multi-Environment Deployment - Troubleshooting Guide

## Common Issues and Solutions

---

## Issue 1: Pods Stuck in Pending in Production

### Symptoms
```bash
kubectl get pods -n production
# NAME                       READY   STATUS    RESTARTS   AGE
# backend-7d9f8c4b5d-xk2jl   0/1     Pending   0          5m
```

### Diagnosis

```bash
# Check pod events
kubectl describe pod backend-7d9f8c4b5d-xk2jl -n production

# Common errors:
# - "0/3 nodes are available: 3 node(s) didn't match Pod's node affinity"
# - "0/3 nodes are available: 3 Insufficient cpu"
# - "exceeded quota"
```

### Root Causes & Solutions

**A. Node Affinity Not Matched**

```bash
# Check node labels
kubectl get nodes -L environment

# Pod requires environment=production but no nodes labeled
```

**Solution:**
```bash
# Label production nodes
kubectl label nodes node-1 environment=production
kubectl label nodes node-2 environment=production

# Verify
kubectl get nodes -L environment
```

**B. Anti-Affinity Too Strict**

```yaml
# Pod requires different zones but only 1 zone available
podAntiAffinity:
  requiredDuringScheduling...:
    topologyKey: topology.kubernetes.io/zone
```

**Solution:**
```bash
# Option 1: Label nodes with zones
kubectl label nodes node-1 topology.kubernetes.io/zone=us-west-1a
kubectl label nodes node-2 topology.kubernetes.io/zone=us-west-1b

# Option 2: Change to preferred (soft)
# Edit deployment to use preferredDuringScheduling
```

**C. ResourceQuota Exceeded**

```bash
# Check quota
kubectl describe resourcequota prod-quota -n production

# Output shows:
# requests.cpu       51      50    ← Exceeded!
```

**Solution:**
```bash
# Option 1: Increase quota
kubectl patch resourcequota prod-quota -n production -p \
  '{"spec":{"hard":{"requests.cpu":"100"}}}'

# Option 2: Scale down other deployments
kubectl scale deployment other-app --replicas=2 -n production

# Option 3: Optimize resource requests
kubectl set resources deployment backend \
  --requests=cpu=500m -n production
```

---

## Issue 2: Environment Isolation Broken

### Symptoms
```bash
# Dev pods running on production nodes
kubectl get pods -n development -o wide
# NAME        NODE
# dev-pod     prod-node-1  ← Wrong!
```

### Diagnosis

```bash
# Check node affinity
kubectl get deployment backend -n development -o yaml | grep -A 10 nodeAffinity

# Check node labels
kubectl get nodes -L environment
```

### Solutions

**A. Add Node Affinity to Development**

```yaml
# Update deployment
spec:
  template:
    spec:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: environment
                operator: In
                values:
                - development
```

**B. Use Taints for Production Nodes**

```bash
# Taint production nodes
kubectl taint nodes prod-node-1 environment=production:NoSchedule
kubectl taint nodes prod-node-2 environment=production:NoSchedule

# Add tolerations to production pods
tolerations:
- key: environment
  value: production
  effect: NoSchedule
```

---

## Issue 3: HPA Not Scaling

### Symptoms
```bash
kubectl get hpa -n production
# NAME          REFERENCE          TARGETS         MINPODS   MAXPODS   REPLICAS
# backend-hpa   Deployment/backend <unknown>/70%   5         20        5
```

### Diagnosis

```bash
# Check metrics server
kubectl get deployment metrics-server -n kube-system

# Check HPA status
kubectl describe hpa backend-hpa -n production

# Check pod metrics
kubectl top pods -n production
```

### Root Causes & Solutions

**A. Metrics Server Not Running**

```bash
# Install metrics server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Verify
kubectl get pods -n kube-system | grep metrics-server
```

**B. Pods Don't Have Resource Requests**

```yaml
# HPA requires resource requests
resources:
  requests:
    cpu: "500m"    # Required for CPU-based HPA
    memory: "512Mi" # Required for memory-based HPA
```

**Solution:**
```bash
# Add resource requests
kubectl set resources deployment backend \
  --requests=cpu=500m,memory=512Mi -n production
```

**C. Target Metrics Unreachable**

```bash
# Check if pods are serving metrics
kubectl top pod backend-xxx -n production

# If "error: Metrics not available"
# Wait a few minutes for metrics to populate
```

---

## Issue 4: StatefulSet Pods Not Starting

### Symptoms
```bash
kubectl get pods -n production | grep database
# database-0   0/1     Pending   0          5m
# database-1   0/1     Pending   0          5m
```

### Diagnosis

```bash
# Describe pod
kubectl describe pod database-0 -n production

# Common errors:
# - "pod has unbound immediate PersistentVolumeClaims"
# - "0/3 nodes are available: 3 pod has anti-affinity"
```

### Root Causes & Solutions

**A. PVC Not Bound**

```bash
# Check PVCs
kubectl get pvc -n production

# Output:
# NAME                STATUS    VOLUME
# data-database-0     Pending   
```

**Solution:**
```bash
# Option 1: Create PV manually
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-database-0
spec:
  capacity:
    storage: 10Gi
  accessModes:
  - ReadWriteOnce
  hostPath:
    path: /mnt/data/database-0
EOF

# Option 2: Install dynamic provisioner
# For local testing: local-path-provisioner
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml

# Set as default
kubectl patch storageclass local-path \
  -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

**B. Anti-Affinity Conflict**

```bash
# StatefulSet requires different nodes but not enough nodes
# Replicas: 5, Available nodes: 3

# Check node count
kubectl get nodes --no-headers | wc -l
```

**Solution:**
```bash
# Option 1: Reduce replicas
kubectl scale statefulset database --replicas=3 -n production

# Option 2: Use preferred anti-affinity (soft)
# Edit StatefulSet to use preferredDuringScheduling
```

---

## Issue 5: Resource Quota Prevents Deployment

### Symptoms
```bash
kubectl apply -f deployment.yaml -n development
# Error from server (Forbidden): error when creating "deployment.yaml": 
# pods "backend-xxx" is forbidden: exceeded quota: dev-quota, 
# requested: requests.cpu=2, used: requests.cpu=9, limited: requests.cpu=10
```

### Diagnosis

```bash
# Check current usage
kubectl describe resourcequota dev-quota -n development

# See what's using resources
kubectl get pods -n development -o custom-columns=\
NAME:.metadata.name,\
CPU_REQ:.spec.containers[*].resources.requests.cpu,\
MEM_REQ:.spec.containers[*].resources.requests.memory
```

### Solutions

**A. Increase Quota**

```bash
kubectl patch resourcequota dev-quota -n development -p \
  '{"spec":{"hard":{"requests.cpu":"20","requests.memory":"40Gi"}}}'
```

**B. Reduce Individual Requests**

```bash
# Lower resource requests
kubectl set resources deployment backend \
  --requests=cpu=500m,memory=512Mi -n development
```

**C. Clean Up Unused Resources**

```bash
# Find and delete unused deployments
kubectl get deployments -n development
kubectl delete deployment old-app -n development

# Delete completed jobs
kubectl delete jobs --field-selector status.successful=1 -n development
```

---

## Issue 6: Different Behavior Across Environments

### Symptoms
```bash
# Works in dev, fails in production
# Same YAML, different results
```

### Diagnosis

```bash
# Compare resource quotas
kubectl describe resourcequota -n development
kubectl describe resourcequota -n production

# Compare limit ranges
kubectl describe limitrange -n development
kubectl describe limitrange -n production

# Compare actual resources
kubectl get deployment backend -n development -o yaml | grep -A 10 resources
kubectl get deployment backend -n production -o yaml | grep -A 10 resources
```

### Root Causes

**A. Different Default Resources**

```bash
# Development LimitRange:
default:
  cpu: "250m"
  memory: "256Mi"

# Production LimitRange:
default:
  cpu: "1000m"
  memory: "1Gi"
```

**Solution:**
```bash
# Always specify resources explicitly
# Don't rely on defaults
resources:
  requests:
    cpu: "500m"
    memory: "512Mi"
  limits:
    cpu: "1000m"
    memory: "1Gi"
```

**B. Different Node Labels**

```bash
# Production has GPU nodes, dev doesn't
# Check node labels
kubectl get nodes -L hardware -n production
```

**Solution:**
```bash
# Use environment-appropriate affinity
# Or make affinity preferred instead of required
```

---

## Issue 7: Namespace Won't Delete

### Symptoms
```bash
kubectl delete namespace staging
# Stuck in Terminating state for 10+ minutes
```

### Diagnosis

```bash
# Check remaining resources
kubectl get all -n staging

# Check finalizers
kubectl get namespace staging -o yaml | grep -A 5 finalizers
```

### Solutions

**A. Force Delete Resources**

```bash
# Delete all resources
kubectl delete all --all -n staging --force --grace-period=0

# Delete PVCs
kubectl delete pvc --all -n staging --force --grace-period=0

# Delete remaining objects
kubectl delete configmap,secret --all -n staging --force --grace-period=0
```

**B. Remove Finalizers**

```bash
# Edit namespace and remove finalizers
kubectl get namespace staging -o json > /tmp/staging.json
# Edit file, remove "finalizers" section
kubectl replace --raw "/api/v1/namespaces/staging/finalize" -f /tmp/staging.json
```

---

## Issue 8: Pods Evicted Under Load

### Symptoms
```bash
kubectl get pods -n production
# NAME                       READY   STATUS    RESTARTS   AGE
# backend-7d9f8c4b5d-xk2jl   0/1     Evicted   0          2m
```

### Diagnosis

```bash
# Check eviction reason
kubectl describe pod backend-7d9f8c4b5d-xk2jl -n production | grep -i evicted

# Common reasons:
# - "The node was low on resource: memory"
# - "The node had condition: DiskPressure"
```

### Root Causes & Solutions

**A. BestEffort Pods Evicted**

```bash
# Check QoS class
kubectl get pods -n production -o custom-columns=\
NAME:.metadata.name,\
QOS:.status.qosClass

# BestEffort pods evicted first
```

**Solution:**
```bash
# Always set resource requests in production
# Minimum: Burstable QoS
# Best: Guaranteed QoS for critical services
resources:
  requests:
    cpu: "500m"
    memory: "512Mi"
  limits:
    cpu: "1000m"
    memory: "1Gi"
```

**B. Node Resource Pressure**

```bash
# Check node conditions
kubectl describe nodes | grep -A 10 Conditions

# Check node resources
kubectl top nodes
```

**Solution:**
```bash
# Option 1: Add more nodes

# Option 2: Reduce resource requests

# Option 3: Enable cluster autoscaler
```

---

## Debugging Commands

### Essential Debugging Commands

```bash
# 1. Check pod status and events
kubectl describe pod <pod-name> -n <namespace>

# 2. Check deployment status
kubectl rollout status deployment/<name> -n <namespace>

# 3. Check resource quota
kubectl describe resourcequota -n <namespace>

# 4. Check node affinity
kubectl get pod <pod-name> -n <namespace> -o yaml | grep -A 20 affinity

# 5. Check actual resource usage
kubectl top pod <pod-name> -n <namespace>

# 6. View logs
kubectl logs <pod-name> -n <namespace>

# 7. Check events
kubectl get events -n <namespace> --sort-by='.lastTimestamp'

# 8. Check HPA
kubectl describe hpa <hpa-name> -n <namespace>

# 9. Check PVC status
kubectl get pvc -n <namespace>

# 10. Test connectivity
kubectl run test --rm -it --image=busybox -n <namespace> -- sh
```

---

## Prevention Best Practices

### 1. Always Label Nodes Correctly

```bash
# Production nodes
kubectl label nodes prod-node-{1,2,3} \
  environment=production \
  tier=high-performance \
  topology.kubernetes.io/zone=us-west-1a

# Staging nodes
kubectl label nodes staging-node-{1,2} \
  environment=staging \
  tier=medium-performance
```

### 2. Set Appropriate ResourceQuotas

```yaml
# Don't set quotas too tight
# Leave 20-30% buffer for bursting
spec:
  hard:
    requests.cpu: "50"    # If you need 40, set 50
    requests.memory: 100Gi # If you need 80Gi, set 100Gi
```

### 3. Always Specify Resources

```yaml
# Never rely on defaults
# Always be explicit
resources:
  requests:
    cpu: "500m"
    memory: "512Mi"
  limits:
    cpu: "1000m"
    memory: "1Gi"
```

### 4. Use Preferred Over Required When Possible

```yaml
# Soft constraints are more flexible
affinity:
  nodeAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:  # Soft
    - weight: 100
      preference:
        matchExpressions:
        - key: environment
          operator: In
          values:
          - production
```

### 5. Monitor Continuously

```bash
# Set up alerts for:
# - Quota usage > 80%
# - Pending pods > 5 minutes
# - Failed deployments
# - Node resource pressure
```

---

## Quick Fixes

```bash
# Force pod restart
kubectl rollout restart deployment/<name> -n <namespace>

# Increase quota quickly
kubectl patch resourcequota <quota-name> -n <namespace> -p \
  '{"spec":{"hard":{"requests.cpu":"100"}}}'

# Scale down temporarily
kubectl scale deployment <name> --replicas=0 -n <namespace>

# Remove stuck finalizer
kubectl patch namespace <namespace> -p '{"metadata":{"finalizers":null}}'

# Force delete pod
kubectl delete pod <pod-name> -n <namespace> --force --grace-period=0
```

---

**Remember**: Most issues can be prevented with proper planning, labeling, and resource allocation!
