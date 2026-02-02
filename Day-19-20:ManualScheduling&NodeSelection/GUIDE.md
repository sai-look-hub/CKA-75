# GUIDEME: Step-by-Step Node Scheduling Tutorial

## 🎯 Overview

This guide will walk you through implementing various node scheduling techniques in Kubernetes. Each section builds upon the previous, taking you from basic to advanced scheduling concepts.

**Estimated Time**: 2-3 hours  
**Difficulty**: Beginner to Intermediate

---

## 📚 Table of Contents

1. [Environment Setup](#step-1-environment-setup)
2. [Node Labeling](#step-2-node-labeling)
3. [Basic Scheduling with nodeName](#step-3-basic-scheduling-with-nodename)
4. [Label-Based Scheduling with nodeSelector](#step-4-label-based-scheduling-with-nodeselector)
5. [Advanced Scheduling with Node Affinity](#step-5-advanced-scheduling-with-node-affinity)
6. [Pod Anti-Affinity](#step-6-pod-anti-affinity)
7. [Real-World Scenarios](#step-7-real-world-scenarios)
8. [Testing and Validation](#step-8-testing-and-validation)
9. [Cleanup](#step-9-cleanup)

---

## Step 1: Environment Setup

### 1.1 Verify Cluster Access

```bash
# Check cluster connection
kubectl cluster-info

# Expected output:
# Kubernetes control plane is running at https://...
# CoreDNS is running at https://...
```

### 1.2 List Available Nodes

```bash
# Get all nodes
kubectl get nodes

# Get nodes with more details
kubectl get nodes -o wide

# Expected output:
# NAME            STATUS   ROLES           AGE   VERSION
# control-plane   Ready    control-plane   10d   v1.28.0
# worker-node-1   Ready    <none>          10d   v1.28.0
# worker-node-2   Ready    <none>          10d   v1.28.0
# worker-node-3   Ready    <none>          10d   v1.28.0
```

### 1.3 Check Current Node Labels

```bash
# View all node labels
kubectl get nodes --show-labels

# Check labels for specific node
kubectl describe node worker-node-1 | grep Labels -A 10
```

### 1.4 Create Namespace for Practice

```bash
# Create dedicated namespace
kubectl create namespace scheduling-demo

# Set as default namespace (optional)
kubectl config set-context --current --namespace=scheduling-demo

# Verify
kubectl config view --minify | grep namespace:
```

**✅ Checkpoint**: You should have access to your cluster and see all nodes.

---

## Step 2: Node Labeling

### 2.1 Understanding Node Labels

Node labels are key-value pairs attached to nodes. They're used to organize and select nodes for scheduling.

**Common Label Categories**:
- Environment: `environment=production`
- Hardware: `hardware=gpu`, `disktype=ssd`
- Geography: `region=us-west`, `zone=us-west-1a`
- Workload: `workload=compute-intensive`

### 2.2 Label Nodes by Environment

```bash
# Label nodes with environment
kubectl label node worker-node-1 environment=production
kubectl label node worker-node-2 environment=staging
kubectl label node worker-node-3 environment=development

# Verify labels
kubectl get nodes -L environment

# Expected output:
# NAME            STATUS   ROLES    AGE   VERSION   ENVIRONMENT
# worker-node-1   Ready    <none>   10d   v1.28.0   production
# worker-node-2   Ready    <none>   10d   v1.28.0   staging
# worker-node-3   Ready    <none>   10d   v1.28.0   development
```

### 2.3 Label Nodes by Hardware

```bash
# Label worker-node-1 (high-end hardware)
kubectl label node worker-node-1 hardware=gpu
kubectl label node worker-node-1 disktype=ssd
kubectl label node worker-node-1 memory=high

# Label worker-node-2 (medium hardware)
kubectl label node worker-node-2 hardware=cpu
kubectl label node worker-node-2 disktype=ssd
kubectl label node worker-node-2 memory=medium

# Label worker-node-3 (standard hardware)
kubectl label node worker-node-3 hardware=cpu
kubectl label node worker-node-3 disktype=hdd
kubectl label node worker-node-3 memory=medium

# Verify all hardware labels
kubectl get nodes -L hardware,disktype,memory
```

### 2.4 Label Nodes by Region/Zone

```bash
# Label nodes with geographic information
kubectl label node worker-node-1 region=us-west zone=us-west-1a
kubectl label node worker-node-2 region=us-west zone=us-west-1b
kubectl label node worker-node-3 region=us-east zone=us-east-1a

# Verify
kubectl get nodes -L region,zone
```

### 2.5 View All Labels

```bash
# See all labels for a specific node
kubectl get node worker-node-1 --show-labels

# Filter nodes by label
kubectl get nodes -l environment=production
kubectl get nodes -l hardware=gpu
kubectl get nodes -l disktype=ssd
```

**✅ Checkpoint**: All nodes should have environment, hardware, and region labels.

---

## Step 3: Basic Scheduling with nodeName

### 3.1 Understanding nodeName

`nodeName` directly assigns a pod to a specific node, bypassing the scheduler.

**When to use**:
- Testing/debugging
- System pods that must run on specific nodes
- Very specific one-off requirements

**When NOT to use**:
- Production deployments
- Workloads requiring high availability
- When node might not exist

### 3.2 Create Pod with nodeName

Create file: `examples/01-nodename/pod-nodename.yaml`

```bash
# Apply the pod
kubectl apply -f examples/01-nodename/pod-nodename.yaml

# Check pod status
kubectl get pod nginx-nodename -o wide

# Expected output:
# NAME             READY   STATUS    RESTARTS   AGE   IP           NODE
# nginx-nodename   1/1     Running   0          10s   10.244.1.5   worker-node-1
```

### 3.3 Verify Pod Placement

```bash
# Describe pod to see scheduling details
kubectl describe pod nginx-nodename

# Look for these fields in output:
# Node: worker-node-1/...
# Status: Running
```

### 3.4 Test with Non-Existent Node

Create file: `examples/01-nodename/pod-nodename-invalid.yaml`

```bash
# Apply the pod with invalid node
kubectl apply -f examples/01-nodename/pod-nodename-invalid.yaml

# Check status (should be Pending)
kubectl get pod nginx-invalid

# Describe to see error
kubectl describe pod nginx-invalid | grep -A 5 Events

# Expected error:
# Warning  FailedScheduling  ... 0/3 nodes are available: 3 node(s) didn't match Pod's node affinity/selector
```

### 3.5 Deploy with Deployment

Create file: `examples/01-nodename/deployment-nodename.yaml`

```bash
# Apply deployment
kubectl apply -f examples/01-nodename/deployment-nodename.yaml

# Watch pods being created
kubectl get pods -l app=nginx-deploy -w

# All pods should be on worker-node-1
kubectl get pods -l app=nginx-deploy -o wide
```

**⚠️ Important**: Notice all replicas are on the SAME node - this is why nodeName is not recommended for production!

### 3.6 Cleanup

```bash
kubectl delete -f examples/01-nodename/
```

**✅ Checkpoint**: You understand that nodeName bypasses the scheduler and isn't flexible.

---

## Step 4: Label-Based Scheduling with nodeSelector

### 4.1 Understanding nodeSelector

`nodeSelector` uses node labels to select where pods should run. Much better than nodeName!

**Advantages**:
- Works with scheduler
- Can target multiple nodes
- Based on labels (flexible)

### 4.2 Schedule GPU Workload

Create file: `examples/02-nodeselector/pod-nodeselector.yaml`

```bash
# Apply GPU pod
kubectl apply -f examples/02-nodeselector/pod-nodeselector.yaml

# Verify it's scheduled on GPU node
kubectl get pod gpu-pod -o wide

# Expected: Should be on worker-node-1 (labeled with hardware=gpu)
```

### 4.3 Multiple Label Selectors

Create file: `examples/02-nodeselector/pod-multi-selector.yaml`

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: ssd-high-mem-pod
spec:
  nodeSelector:
    disktype: ssd      # AND
    memory: high       # AND
  containers:
  - name: app
    image: nginx:latest
```

```bash
# Apply pod
kubectl apply -f examples/02-nodeselector/pod-multi-selector.yaml

# Should be on worker-node-1 (only node with BOTH labels)
kubectl get pod ssd-high-mem-pod -o wide
```

### 4.4 Test Unmatched Labels

Create file: `examples/02-nodeselector/pod-unmatched.yaml`

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nonexistent-label-pod
spec:
  nodeSelector:
    special-hardware: quantum-computer  # Doesn't exist
  containers:
  - name: app
    image: nginx:latest
```

```bash
# Apply pod
kubectl apply -f examples/02-nodeselector/pod-unmatched.yaml

# Should be Pending
kubectl get pod nonexistent-label-pod

# Check why
kubectl describe pod nonexistent-label-pod | grep -A 5 Events

# Expected: "0/3 nodes are available: 3 node(s) didn't match Pod's node affinity/selector"
```

### 4.5 Environment-Based Deployment

Create file: `examples/02-nodeselector/deployment-nodeselector.yaml`

```bash
# Apply deployment
kubectl apply -f examples/02-nodeselector/deployment-nodeselector.yaml

# Check pod distribution
kubectl get pods -l app=production-app -o wide

# All should be on production nodes
kubectl get pods -l app=production-app -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName
```

### 4.6 Cleanup

```bash
kubectl delete -f examples/02-nodeselector/
```

**✅ Checkpoint**: You can schedule pods based on node labels using nodeSelector.

---

## Step 5: Advanced Scheduling with Node Affinity

### 5.1 Understanding Node Affinity

Node affinity is like nodeSelector but much more powerful!

**Two Types**:
1. **requiredDuringSchedulingIgnoredDuringExecution**: HARD requirement (must match)
2. **preferredDuringSchedulingIgnoredDuringExecution**: SOFT preference (should match)

**Operators**:
- `In`: Label value must be in the list
- `NotIn`: Label value must NOT be in the list
- `Exists`: Label key must exist (any value)
- `DoesNotExist`: Label key must NOT exist
- `Gt`: Label value greater than (numeric)
- `Lt`: Label value less than (numeric)

### 5.2 Required Affinity (Hard Rule)

Create file: `examples/03-node-affinity/pod-affinity-required.yaml`

```bash
# Apply pod with required affinity
kubectl apply -f examples/03-node-affinity/pod-affinity-required.yaml

# Check placement
kubectl get pod affinity-required -o wide

# Should be on worker-node-1 or worker-node-2 (both in us-west)
```

### 5.3 Preferred Affinity (Soft Rule)

Create file: `examples/03-node-affinity/pod-affinity-preferred.yaml`

```bash
# Apply pod with preferred affinity
kubectl apply -f examples/03-node-affinity/pod-affinity-preferred.yaml

# Check placement
kubectl get pod affinity-preferred -o wide

# Scheduler will TRY to place on SSD node, but will use others if needed
```

### 5.4 Understanding Weights

Weights (1-100) determine preference priority:
- Higher weight = stronger preference
- Scheduler calculates score for each node
- Pod goes to highest-scoring node

Example:
```yaml
preferredDuringSchedulingIgnoredDuringExecution:
- weight: 80  # Strong preference
  preference:
    matchExpressions:
    - key: disktype
      operator: In
      values:
      - ssd
- weight: 20  # Weaker preference
  preference:
    matchExpressions:
    - key: zone
      operator: In
      values:
      - us-west-1a
```

Node scores:
- Node with SSD + us-west-1a: 80 + 20 = 100 (best)
- Node with only SSD: 80
- Node with only us-west-1a: 20
- Node with neither: 0

### 5.5 Combined Required + Preferred

Create file: `examples/03-node-affinity/pod-affinity-combined.yaml`

```bash
# Apply combined affinity pod
kubectl apply -f examples/03-node-affinity/pod-affinity-combined.yaml

# This pod MUST be in us-west, but PREFERS SSD
kubectl get pod affinity-combined -o wide
```

### 5.6 Multiple NodeSelectorTerms (OR Logic)

Create file: `examples/03-node-affinity/pod-affinity-or.yaml`

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: affinity-or-logic
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:  # OR between terms
        - matchExpressions:  # Option 1: GPU node
          - key: hardware
            operator: In
            values:
            - gpu
        - matchExpressions:  # OR Option 2: High memory
          - key: memory
            operator: In
            values:
            - high
  containers:
  - name: app
    image: nginx:latest
```

```bash
# Apply OR logic pod
kubectl apply -f examples/03-node-affinity/pod-affinity-or.yaml

# Can be scheduled on worker-node-1 (has gpu OR high memory)
kubectl get pod affinity-or-logic -o wide
```

### 5.7 Operator Examples

Create file: `examples/03-node-affinity/pod-operators.yaml`

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: operator-examples
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          # NotIn: Avoid certain zones
          - key: zone
            operator: NotIn
            values:
            - us-west-1c
            - eu-central-1a
          # Exists: Must have region label (any value)
          - key: region
            operator: Exists
          # In: Must be one of these environments
          - key: environment
            operator: In
            values:
            - production
            - staging
  containers:
  - name: app
    image: nginx:latest
```

```bash
# Apply operator examples
kubectl apply -f examples/03-node-affinity/pod-operators.yaml

# Check scheduling
kubectl describe pod operator-examples | grep "Node-Selectors" -A 20
```

### 5.8 Deployment with Affinity

Create file: `examples/03-node-affinity/deployment-affinity.yaml`

```bash
# Apply deployment with affinity
kubectl apply -f examples/03-node-affinity/deployment-affinity.yaml

# Check pod distribution
kubectl get pods -l app=regional-app -o wide

# Pods should prefer us-west region
kubectl get pods -l app=regional-app -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName
```

### 5.9 Cleanup

```bash
kubectl delete -f examples/03-node-affinity/
```

**✅ Checkpoint**: You can create complex scheduling rules with node affinity!

---

## Step 6: Pod Anti-Affinity

### 6.1 Understanding Pod Anti-Affinity

While node affinity controls pod-to-node relationships, pod anti-affinity controls pod-to-pod relationships.

**Use Cases**:
- Spread replicas across nodes (high availability)
- Spread replicas across zones (disaster recovery)
- Avoid scheduling pods with specific other pods

### 6.2 Spread Across Nodes

Create file: `examples/04-anti-affinity/pod-anti-affinity.yaml`

```bash
# Apply anti-affinity deployment
kubectl apply -f examples/04-anti-affinity/pod-anti-affinity.yaml

# Check pod distribution
kubectl get pods -l app=web-ha -o wide

# Expected: Each pod on DIFFERENT node
```

### 6.3 Spread Across Zones

Create file: `examples/04-anti-affinity/deployment-spread.yaml`

```bash
# Apply zone-spread deployment
kubectl apply -f examples/04-anti-affinity/deployment-spread.yaml

# Check zone distribution
kubectl get pods -l app=multi-zone -o custom-columns=\
NAME:.metadata.name,\
NODE:.spec.nodeName,\
ZONE:.spec.nodeSelector.zone

# Pods should be spread across zones
```

### 6.4 Topology Spread Constraints

Create file: `examples/04-anti-affinity/topology-spread.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: topology-spread-demo
spec:
  replicas: 6
  selector:
    matchLabels:
      app: spread-demo
  template:
    metadata:
      labels:
        app: spread-demo
    spec:
      topologySpreadConstraints:
      - maxSkew: 1  # Max difference between zones
        topologyKey: zone
        whenUnsatisfiable: DoNotSchedule
        labelSelector:
          matchLabels:
            app: spread-demo
      containers:
      - name: nginx
        image: nginx:latest
```

```bash
# Apply topology spread
kubectl apply -f examples/04-anti-affinity/topology-spread.yaml

# Check distribution
kubectl get pods -l app=spread-demo -o wide

# Should be evenly distributed across zones
```

### 6.5 Cleanup

```bash
kubectl delete -f examples/04-anti-affinity/
```

**✅ Checkpoint**: You can spread pods for high availability!

---

## Step 7: Real-World Scenarios

### 7.1 Scenario: GPU Machine Learning Workload

Create file: `examples/05-real-world/gpu-workload.yaml`

```bash
# Apply GPU workload
kubectl apply -f examples/05-real-world/gpu-workload.yaml

# Verify on GPU node
kubectl get pod ml-training -o jsonpath='{.spec.nodeName}'
```

### 7.2 Scenario: Database on SSD Storage

Create file: `examples/05-real-world/database-ssd.yaml`

```bash
# Apply database StatefulSet
kubectl apply -f examples/05-real-world/database-ssd.yaml

# Wait for pods
kubectl get pods -l app=postgres -w

# Verify all on SSD nodes
kubectl get pods -l app=postgres -o wide
```

### 7.3 Scenario: Regional Web Application

Create file: `examples/05-real-world/regional-deployment.yaml`

```bash
# Apply regional deployment
kubectl apply -f examples/05-real-world/regional-deployment.yaml

# Check region distribution
kubectl get pods -l app=webapp-global -o custom-columns=\
NAME:.metadata.name,\
NODE:.spec.nodeName

# Should prioritize us-west, then us-east
```

### 7.4 Scenario: Multi-Tier Application

Create file: `examples/05-real-world/multi-tier-app.yaml`

This file contains:
- Frontend: Spread across all nodes
- Backend: Prefer production nodes
- Database: Required on SSD nodes
- Cache: Prefer memory-optimized nodes

```bash
# Apply complete stack
kubectl apply -f examples/05-real-world/multi-tier-app.yaml

# Check all tiers
kubectl get pods -o wide

# Verify scheduling
kubectl get pods -l tier=frontend -o wide
kubectl get pods -l tier=backend -o wide
kubectl get pods -l tier=database -o wide
kubectl get pods -l tier=cache -o wide
```

### 7.5 Cleanup

```bash
kubectl delete -f examples/05-real-world/
```

**✅ Checkpoint**: You can apply scheduling in real-world scenarios!

---

## Step 8: Testing and Validation

### 8.1 Test Scheduling Decisions

```bash
# Create test pod
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-scheduling
spec:
  affinity:
    nodeAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        preference:
          matchExpressions:
          - key: disktype
            operator: In
            values:
            - ssd
  containers:
  - name: nginx
    image: nginx:latest
EOF

# Describe to see scheduling decisions
kubectl describe pod test-scheduling | grep -A 20 "Events:"
```

### 8.2 Validate Node Assignment

```bash
# Get node for pod
POD_NODE=$(kubectl get pod test-scheduling -o jsonpath='{.spec.nodeName}')
echo "Pod scheduled on: $POD_NODE"

# Check node labels
kubectl get node $POD_NODE --show-labels | grep disktype

# Verify label match
if kubectl get node $POD_NODE -o jsonpath='{.metadata.labels.disktype}' | grep -q "ssd"; then
  echo "✅ Correctly scheduled on SSD node"
else
  echo "ℹ️ Scheduled on non-SSD node (soft preference allowed this)"
fi
```

### 8.3 Test Failure Scenarios

```bash
# Create pod with impossible requirements
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: impossible-requirements
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: impossible-label
            operator: In
            values:
            - does-not-exist
  containers:
  - name: nginx
    image: nginx:latest
EOF

# Should be Pending
kubectl get pod impossible-requirements

# Check why it failed
kubectl describe pod impossible-requirements | grep "Warning"
```

### 8.4 Verify Resource Distribution

```bash
# Check pod distribution across nodes
kubectl get pods -A -o wide | awk '{print $8}' | sort | uniq -c | sort -rn

# Expected output shows count per node:
#   5 worker-node-1
#   3 worker-node-2
#   2 worker-node-3
```

### 8.5 Cleanup Tests

```bash
kubectl delete pod test-scheduling impossible-requirements
```

**✅ Checkpoint**: You can test and validate scheduling decisions!

---

## Step 9: Cleanup

### 9.1 Delete All Resources

```bash
# Delete all pods in namespace
kubectl delete pods --all -n scheduling-demo

# Delete all deployments
kubectl delete deployments --all -n scheduling-demo

# Delete all statefulsets
kubectl delete statefulsets --all -n scheduling-demo

# Delete namespace
kubectl delete namespace scheduling-demo
```

### 9.2 Remove Node Labels (Optional)

```bash
# Remove custom labels from nodes
kubectl label node worker-node-1 environment- hardware- disktype- memory- region- zone-
kubectl label node worker-node-2 environment- hardware- disktype- memory- region- zone-
kubectl label node worker-node-3 environment- hardware- disktype- memory- region- zone-

# Verify labels removed
kubectl get nodes --show-labels
```

### 9.3 Reset Default Namespace

```bash
# Switch back to default namespace
kubectl config set-context --current --namespace=default
```

**✅ Checkpoint**: Environment cleaned up!

---

## 🎓 What You've Learned

Congratulations! You've completed the Node Scheduling tutorial. You now know:

1. ✅ How to label nodes strategically
2. ✅ When to use nodeName (almost never in production!)
3. ✅ How to use nodeSelector for simple scheduling
4. ✅ How to create complex rules with node affinity
5. ✅ How to use required vs preferred affinity
6. ✅ How to spread pods with anti-affinity
7. ✅ How to apply scheduling in real-world scenarios
8. ✅ How to test and validate scheduling decisions

---

## 📖 Next Steps

1. **Practice**: Try creating your own scheduling scenarios
2. **Experiment**: Test different affinity combinations
3. **Read**: Check out the [INTERVIEW-QA.md](./INTERVIEW-QA.md) for common questions
4. **Reference**: Use [COMMAND-CHEATSHEET.md](./COMMAND-CHEATSHEET.md) for quick lookups
5. **Troubleshoot**: Review [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) for common issues

---

## 🆘 Need Help?

- **Issues?**: Check [TROUBLESHOOTING.md](./TROUBLESHOOTING.md)
- **Questions?**: Review [INTERVIEW-QA.md](./INTERVIEW-QA.md)
- **Commands?**: See [COMMAND-CHEATSHEET.md](./COMMAND-CHEATSHEET.md)

**Happy Scheduling! 🚀**
