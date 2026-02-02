# Node Scheduling - Troubleshooting Guide

## Common Issues and Solutions

---

## Issue 1: Pod Stuck in Pending State

### Symptoms
```bash
kubectl get pods
# NAME        READY   STATUS    RESTARTS   AGE
# my-pod      0/1     Pending   0          5m
```

### Diagnosis

```bash
# 1. Describe the pod
kubectl describe pod my-pod

# Look for events at the bottom
# Events:
#   Warning  FailedScheduling  ... 0/3 nodes are available: 3 node(s) didn't match Pod's node affinity/selector
```

### Common Causes & Solutions

**A. No nodes match nodeSelector**

```bash
# Check pod's nodeSelector
kubectl get pod my-pod -o jsonpath='{.spec.nodeSelector}'

# Check which nodes have the required labels
kubectl get nodes -l disktype=ssd

# Solutions:
# 1. Add label to nodes
kubectl label node worker-1 disktype=ssd

# 2. Remove/update nodeSelector
kubectl patch pod my-pod --type=json -p='[{"op": "remove", "path": "/spec/nodeSelector"}]'

# 3. Use preferred affinity instead of required
```

**B. Insufficient Resources**

```bash
# Check node resources
kubectl describe node <node-name> | grep -A 10 "Allocated resources"

# Solutions:
# 1. Reduce pod resource requests
kubectl set resources deployment my-app --limits=cpu=200m,memory=256Mi

# 2. Scale down other workloads
kubectl scale deployment other-app --replicas=2

# 3. Add more nodes to cluster
```

**C. Node Taint Without Toleration**

```bash
# Check node taints
kubectl describe node <node-name> | grep Taints

# If tainted:
# Taints: dedicated=gpu:NoSchedule

# Solution: Add toleration to pod
kubectl patch pod my-pod --type=json -p='[
  {
    "op": "add",
    "path": "/spec/tolerations",
    "value": [{
      "key": "dedicated",
      "value": "gpu",
      "effect": "NoSchedule"
    }]
  }
]'
```

**D. Anti-Affinity Rules Too Strict**

```bash
# Check pod anti-affinity
kubectl get pod my-pod -o yaml | grep -A 20 podAntiAffinity

# If using requiredDuringSchedulingIgnoredDuringExecution
# and not enough nodes available

# Solutions:
# 1. Change to preferredDuringSchedulingIgnoredDuringExecution
# 2. Add more nodes
# 3. Reduce replica count
```

---

## Issue 2: Pod Scheduled on Wrong Node

### Symptoms
```bash
kubectl get pod my-pod -o wide
# Expected: worker-1
# Actual: worker-2
```

### Diagnosis

```bash
# 1. Check pod's scheduling constraints
kubectl get pod my-pod -o yaml | grep -A 30 "affinity\|nodeSelector\|nodeName"

# 2. Check node labels
kubectl get node worker-1 --show-labels
kubectl get node worker-2 --show-labels

# 3. Check scheduler logs
kubectl logs -n kube-system kube-scheduler-<pod> | grep my-pod
```

### Common Causes & Solutions

**A. Preferred Affinity (Not Required)**

```yaml
# This is SOFT preference, not hard requirement
preferredDuringSchedulingIgnoredDuringExecution:
- weight: 100
  preference:
    matchExpressions:
    - key: disktype
      operator: In
      values:
      - ssd
```

**Solution:** If you need hard requirement, use `required`:
```yaml
requiredDuringSchedulingIgnoredDuringExecution:
  nodeSelectorTerms:
  - matchExpressions:
    - key: disktype
      operator: In
      values:
      - ssd
```

**B. Node Labels Missing or Incorrect**

```bash
# Check actual labels
kubectl get node worker-1 -o jsonpath='{.metadata.labels}' | jq

# Solution: Add/fix labels
kubectl label node worker-1 disktype=ssd --overwrite
```

**C. Multiple Nodes Match, Scheduler Picks Different One**

```bash
# If multiple nodes match, scheduler uses scoring
# Node with highest score gets the pod

# Check which nodes match
kubectl get nodes -l disktype=ssd

# Solution: Be more specific with selectors
kubectl label node worker-1 app-type=database
# Then update pod to require app-type=database
```

---

## Issue 3: Pods Not Spreading Across Nodes

### Symptoms
```bash
kubectl get pods -o wide
# All pods on node-1, none on node-2 or node-3
```

### Diagnosis

```bash
# Check deployment's anti-affinity
kubectl get deployment my-app -o yaml | grep -A 20 podAntiAffinity

# Count pods per node
kubectl get pods -o jsonpath='{range .items[*]}{.spec.nodeName}{"\n"}{end}' | sort | uniq -c
```

### Solutions

**Add Pod Anti-Affinity:**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  replicas: 5
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
    spec:
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:  # Soft
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchLabels:
                  app: my-app
              topologyKey: kubernetes.io/hostname
```

**Or use Topology Spread Constraints:**

```yaml
spec:
  topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: kubernetes.io/hostname
    whenUnsatisfiable: ScheduleAnyway
    labelSelector:
      matchLabels:
        app: my-app
```

---

## Issue 4: Node Labels Not Working

### Symptoms
```bash
# Added label but pod still not scheduling
kubectl label node worker-1 disktype=ssd
kubectl get pod my-pod
# Still Pending
```

### Diagnosis

```bash
# 1. Verify label was added
kubectl get node worker-1 -L disktype

# 2. Check for typos in pod spec
kubectl get pod my-pod -o yaml | grep nodeSelector -A 5

# 3. Check exact label key and value
```

### Common Mistakes

**A. Typo in Label Key/Value**
```yaml
# Wrong
nodeSelector:
  diskType: ssd  # Capital T

# Correct
nodeSelector:
  disktype: ssd  # lowercase t
```

**B. Wrong Operator**
```yaml
# This requires label to NOT exist
- key: disktype
  operator: DoesNotExist  # Wrong!

# Should be:
- key: disktype
  operator: In
  values:
  - ssd
```

**C. Label on Wrong Node**
```bash
# Verify you labeled the correct node
kubectl get nodes -L disktype
```

---

## Issue 5: Taint/Toleration Not Working

### Symptoms
```bash
# Pod should tolerate taint but still Pending
```

### Diagnosis

```bash
# 1. Check node taints
kubectl describe node worker-1 | grep Taints

# 2. Check pod tolerations
kubectl get pod my-pod -o yaml | grep -A 10 tolerations
```

### Common Mistakes

**A. Mismatched Taint Effect**
```bash
# Node taint
kubectl taint node worker-1 dedicated=gpu:NoSchedule

# Wrong toleration (different effect)
tolerations:
- key: dedicated
  value: gpu
  effect: NoExecute  # Should be NoSchedule!

# Correct
tolerations:
- key: dedicated
  value: gpu
  effect: NoSchedule
```

**B. Operator Mismatch**
```yaml
# Taint: dedicated=gpu:NoSchedule

# Wrong (looking for Exists, but has value)
tolerations:
- key: dedicated
  operator: Exists
  effect: NoSchedule

# Correct
tolerations:
- key: dedicated
  operator: Equal
  value: gpu
  effect: NoSchedule
```

**C. Missing Toleration**
```bash
# Node has multiple taints
Taints: dedicated=gpu:NoSchedule
        spot-instance=true:NoSchedule

# Pod needs to tolerate ALL taints
tolerations:
- key: dedicated
  value: gpu
  effect: NoSchedule
- key: spot-instance
  value: "true"
  effect: NoSchedule
```

---

## Issue 6: Deployment Replicas Not Spreading

### Symptoms
```bash
kubectl get deployment my-app
# READY: 3/5

# Only 3 pods running instead of 5
```

### Diagnosis

```bash
# Check replica set
kubectl get rs

# Describe deployment
kubectl describe deployment my-app

# Check events
kubectl get events --sort-by='.lastTimestamp' | grep my-app
```

### Common Causes

**A. Anti-Affinity Too Strict + Not Enough Nodes**
```yaml
# Required anti-affinity with 5 replicas but only 3 nodes
podAntiAffinity:
  requiredDuringSchedulingIgnoredDuringExecution:  # Hard requirement
  - labelSelector:
      matchLabels:
        app: my-app
    topologyKey: kubernetes.io/hostname

# Can only schedule 3 pods (one per node)
```

**Solution:**
```yaml
# Change to preferred
podAntiAffinity:
  preferredDuringSchedulingIgnoredDuringExecution:  # Soft preference
  - weight: 100
    podAffinityTerm:
      labelSelector:
        matchLabels:
          app: my-app
      topologyKey: kubernetes.io/hostname
```

---

## Debug Commands

### Essential Debugging Commands

```bash
# 1. Check pod status and node
kubectl get pod <pod-name> -o wide

# 2. See why pod is pending
kubectl describe pod <pod-name> | grep -A 20 Events

# 3. Check pod's scheduling constraints
kubectl get pod <pod-name> -o yaml | grep -A 30 "affinity\|nodeSelector"

# 4. Check node labels
kubectl get nodes --show-labels
kubectl get nodes -L disktype,region,zone

# 5. Check node resources
kubectl describe node <node-name> | grep -A 10 "Allocated resources"

# 6. Check node taints
kubectl describe node <node-name> | grep Taints

# 7. Check which pods are on which nodes
kubectl get pods -A -o wide | grep <node-name>

# 8. Count pods per node
kubectl get pods -A -o jsonpath='{range .items[*]}{.spec.nodeName}{"\n"}{end}' | sort | uniq -c

# 9. Check scheduler logs
kubectl logs -n kube-system -l component=kube-scheduler --tail=100

# 10. Get all pending pods
kubectl get pods -A --field-selector=status.phase=Pending

# 11. Check node conditions
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}'

# 12. Verify label syntax
kubectl get pod <pod-name> -o jsonpath='{.spec.nodeSelector}' | jq

# 13. Test if node matches selector
kubectl get nodes -l <label-selector>

# 14. Check pod distribution
kubectl get pods -l app=myapp -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName
```

---

## Prevention Best Practices

### 1. Always Use Labels Wisely
```bash
# Good naming convention
kubectl label node worker-1 \
  environment=production \
  disktype=ssd \
  region=us-west \
  zone=us-west-1a \
  node-role=database
```

### 2. Prefer Soft Over Hard Constraints
```yaml
# Instead of required
requiredDuringSchedulingIgnoredDuringExecution

# Consider using
preferredDuringSchedulingIgnoredDuringExecution
```

### 3. Test in Development First
```bash
# Dry run to see if pod can be scheduled
kubectl apply -f pod.yaml --dry-run=server
```

### 4. Monitor Pod Distribution
```bash
# Regular checks
kubectl get pods -o wide
kubectl get nodes -o custom-columns=NAME:.metadata.name,PODS:.status.allocatable.pods
```

### 5. Document Your Strategy
```yaml
# Add comments in YAML
spec:
  nodeSelector:
    disktype: ssd  # Requires SSD for database performance
```

---

## Quick Fixes

```bash
# Remove nodeSelector
kubectl patch pod <pod> --type=json -p='[{"op": "remove", "path": "/spec/nodeSelector"}]'

# Change deployment to not use affinity
kubectl patch deployment <name> --type=json -p='[{"op": "remove", "path": "/spec/template/spec/affinity"}]'

# Uncordon node
kubectl uncordon <node-name>

# Remove taint
kubectl taint node <node-name> <key>:<effect>-

# Force delete pending pod
kubectl delete pod <pod-name> --grace-period=0 --force

# Scale deployment to 0 and back
kubectl scale deployment <name> --replicas=0
kubectl scale deployment <name> --replicas=3
```

---

**Remember**: Most scheduling issues are due to:
1. Typos in labels/selectors
2. Too strict requirements (use preferred when possible)
3. Insufficient resources
4. Missing tolerations for taints

Always check these first!
