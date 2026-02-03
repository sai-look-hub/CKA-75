# Day 21-22: Taints, Tolerations & Affinity - Complete Guide

## Table of Contents
1. [Introduction](#introduction)
2. [Taints Deep Dive](#taints-deep-dive)
3. [Tolerations Mastery](#tolerations-mastery)
4. [Node Affinity](#node-affinity)
5. [Pod Affinity & Anti-Affinity](#pod-affinity--anti-affinity)
6. [Topology Spread Constraints](#topology-spread-constraints)
7. [Real-World Patterns](#real-world-patterns)
8. [Best Practices](#best-practices)
9. [Troubleshooting](#troubleshooting)

---

## Introduction

### Pod Scheduling Overview

By default, Kubernetes scheduler places pods on any available node. Advanced scheduling allows you to:
- **Control** where pods run
- **Optimize** resource utilization
- **Ensure** high availability
- **Isolate** workloads
- **Co-locate** related services

### Scheduling Mechanisms

**1. Taints & Tolerations** (Node → Pod)
- Nodes repel pods unless tolerated
- Access control mechanism

**2. Node Affinity** (Pod → Node)
- Pods attracted to specific nodes
- Hardware/label-based selection

**3. Pod Affinity/Anti-Affinity** (Pod → Pod)
- Pods attracted to or repelled by other pods
- Co-location or separation

---

## Taints Deep Dive

### What are Taints?

Taints are properties applied to **nodes** that repel pods unless they have matching tolerations.

**Analogy**: Like a "Do Not Enter" sign on a node.

### Taint Structure

```
key=value:effect
```

**Components**:
- `key`: Taint identifier (e.g., `gpu`, `dedicated`)
- `value`: Optional value (e.g., `true`, `frontend`)
- `effect`: What happens to pods

### Taint Effects

#### 1. NoSchedule

```bash
kubectl taint nodes node1 dedicated=frontend:NoSchedule
```

**Behavior**:
- New pods **cannot** be scheduled on this node
- Existing pods **remain** on the node
- Only pods with matching toleration can schedule

**Use Cases**:
- Dedicated node pools
- Hardware isolation
- Workload separation

**Example**:
```bash
# Taint node for GPU workloads
kubectl taint nodes gpu-node gpu=true:NoSchedule

# Now only pods with gpu toleration can schedule here
```

#### 2. PreferNoSchedule

```bash
kubectl taint nodes node2 workload=batch:PreferNoSchedule
```

**Behavior**:
- Scheduler **prefers** not to schedule pods here
- Will schedule if no other option
- Soft restriction
- Existing pods remain

**Use Cases**:
- Soft resource reservations
- Maintenance preparation
- Load balancing hints

**Example**:
```bash
# Prefer not to schedule on this node
kubectl taint nodes node2 maintenance=soon:PreferNoSchedule

# Scheduler will avoid but may use if necessary
```

#### 3. NoExecute

```bash
kubectl taint nodes node3 status=unhealthy:NoExecute
```

**Behavior**:
- New pods **cannot** schedule
- Existing pods **are evicted** (unless they tolerate)
- Immediate action
- Pods without toleration are terminated

**Use Cases**:
- Node maintenance (drain)
- Hardware failures
- Immediate workload migration
- Emergency situations

**Example**:
```bash
# Evict all non-tolerating pods immediately
kubectl taint nodes node3 node.kubernetes.io/unreachable:NoExecute

# Existing pods without toleration will be evicted
```

### Working with Taints

#### Add Taint
```bash
# Basic taint
kubectl taint nodes node1 key=value:NoSchedule

# Taint with just key (no value)
kubectl taint nodes node1 dedicated:NoSchedule

# Multiple taints
kubectl taint nodes node1 gpu=true:NoSchedule
kubectl taint nodes node1 ssd=true:NoSchedule
```

#### Remove Taint
```bash
# Remove specific taint
kubectl taint nodes node1 key:NoSchedule-

# Remove all taints with key
kubectl taint nodes node1 key-
```

#### View Taints
```bash
# Describe node
kubectl describe node node1 | grep Taints

# Get all node taints
kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints
```

### Common Taint Patterns

#### Master Node Isolation
```bash
kubectl taint nodes master-1 \
  node-role.kubernetes.io/master:NoSchedule
```

#### GPU Nodes
```bash
kubectl taint nodes gpu-node-1 \
  nvidia.com/gpu=true:NoSchedule
```

#### Maintenance Mode
```bash
kubectl taint nodes worker-2 \
  maintenance=true:NoExecute
```

#### Failed Node
```bash
# Automatically added by kubelet
# node.kubernetes.io/unreachable:NoExecute
# node.kubernetes.io/not-ready:NoExecute
```

---

## Tolerations Mastery

### What are Tolerations?

Tolerations are properties added to **pods** that allow them to schedule on nodes with matching taints.

**Analogy**: Like a "VIP Pass" to enter a tainted node.

### Toleration Structure

```yaml
tolerations:
- key: "key1"
  operator: "Equal"
  value: "value1"
  effect: "NoSchedule"
```

### Toleration Operators

#### 1. Equal (Exact Match)

```yaml
tolerations:
- key: "gpu"
  operator: "Equal"
  value: "true"
  effect: "NoSchedule"
```

**Matches Taint**: `gpu=true:NoSchedule`

**Behavior**: All fields must match exactly

#### 2. Exists (Key Only)

```yaml
tolerations:
- key: "gpu"
  operator: "Exists"
  effect: "NoSchedule"
```

**Matches Taints**:
- `gpu=true:NoSchedule`
- `gpu=false:NoSchedule`
- `gpu:NoSchedule`

**Behavior**: Only key and effect must match

#### 3. Match All (Wildcard)

```yaml
tolerations:
- operator: "Exists"
```

**Matches**: **ALL** taints

**Use Case**: System pods that must run everywhere

### Toleration Effects

Must match taint effect:
- `NoSchedule`
- `PreferNoSchedule`
- `NoExecute`

**Empty effect** matches all effects:
```yaml
tolerations:
- key: "key1"
  operator: "Exists"
  # No effect specified - matches all effects
```

### TolerationSeconds (NoExecute Only)

```yaml
tolerations:
- key: "node.kubernetes.io/unreachable"
  operator: "Exists"
  effect: "NoExecute"
  tolerationSeconds: 300
```

**Behavior**:
- Pod stays on node for 300 seconds after taint added
- Then evicted if taint still present
- Useful for temporary issues

**Example Scenario**:
```
Time 0s:   Node becomes unreachable, taint added
Time 0-300s: Pod continues running (toleration period)
Time 300s:  Pod evicted and rescheduled
```

### Complete Toleration Examples

#### Example 1: GPU Workload
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: ml-training
spec:
  tolerations:
  - key: "gpu"
    operator: "Equal"
    value: "true"
    effect: "NoSchedule"
  containers:
  - name: trainer
    image: ml-trainer:1.0
    resources:
      limits:
        nvidia.com/gpu: 1
```

#### Example 2: System Pod (Monitoring)
```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: node-exporter
spec:
  template:
    spec:
      tolerations:
      # Tolerate master taint
      - key: node-role.kubernetes.io/master
        operator: Exists
        effect: NoSchedule
      # Tolerate control-plane taint
      - key: node-role.kubernetes.io/control-plane
        operator: Exists
        effect: NoSchedule
      # Tolerate all NoExecute taints
      - effect: NoExecute
        operator: Exists
      containers:
      - name: node-exporter
        image: prom/node-exporter:v1.6.1
```

#### Example 3: Temporary Failure Tolerance
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: resilient-app
spec:
  tolerations:
  - key: "node.kubernetes.io/not-ready"
    operator: "Exists"
    effect: "NoExecute"
    tolerationSeconds: 300
  - key: "node.kubernetes.io/unreachable"
    operator: "Exists"
    effect: "NoExecute"
    tolerationSeconds: 300
  containers:
  - name: app
    image: my-app:1.0
```

---

## Node Affinity

### What is Node Affinity?

Node affinity is a property of pods that attracts them to a set of nodes based on labels.

**Analogy**: Like selecting a hotel based on amenities (pool, gym, location).

### Types of Node Affinity

#### 1. requiredDuringSchedulingIgnoredDuringExecution

**Hard Constraint**: Pod **must** be placed on matching node.

```yaml
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
```

**Behavior**:
- If no matching node → Pod stays **Pending**
- Required for scheduling
- Ignored after scheduling (pod not evicted if label changes)

**Use Cases**:
- Must-have requirements (SSD, GPU)
- Compliance requirements (data locality)
- Hardware dependencies

#### 2. preferredDuringSchedulingIgnoredDuringExecution

**Soft Constraint**: Scheduler **prefers** matching nodes.

```yaml
spec:
  affinity:
    nodeAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        preference:
          matchExpressions:
          - key: disk-type
            operator: In
            values:
            - ssd
```

**Behavior**:
- Scheduler tries to place on matching node
- Falls back to other nodes if needed
- Uses weights to prioritize

**Use Cases**:
- Performance optimization (prefer SSD)
- Cost optimization (prefer spot instances)
- Geographic preferences

### Node Affinity Operators

#### In
```yaml
- key: environment
  operator: In
  values:
  - production
  - staging
```
Matches if label value is in the list.

#### NotIn
```yaml
- key: environment
  operator: NotIn
  values:
  - development
```
Matches if label value is NOT in the list.

#### Exists
```yaml
- key: gpu
  operator: Exists
```
Matches if label key exists (any value).

#### DoesNotExist
```yaml
- key: spot-instance
  operator: DoesNotExist
```
Matches if label key does NOT exist.

#### Gt (Greater Than)
```yaml
- key: cpu-cores
  operator: Gt
  values:
  - "8"
```
Matches if numeric value > specified value.

#### Lt (Less Than)
```yaml
- key: memory-gb
  operator: Lt
  values:
  - "16"
```
Matches if numeric value < specified value.

### Complete Node Affinity Examples

#### Example 1: SSD Requirement
```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
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

#### Example 2: Zone Preference
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
spec:
  template:
    spec:
      affinity:
        nodeAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 80
            preference:
              matchExpressions:
              - key: topology.kubernetes.io/zone
                operator: In
                values:
                - us-east-1a
          - weight: 20
            preference:
              matchExpressions:
              - key: topology.kubernetes.io/zone
                operator: In
                values:
                - us-east-1b
      containers:
      - name: web
        image: web:1.0
```

#### Example 3: Multiple Requirements
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: ml-workload
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          # Must have GPU
          - key: gpu
            operator: Exists
          # Must be high-memory node
          - key: memory-class
            operator: In
            values:
            - high
            - very-high
          # Must NOT be spot instance
          - key: instance-type
            operator: NotIn
            values:
            - spot
  containers:
  - name: ml-trainer
    image: ml:1.0
```

---

## Pod Affinity & Anti-Affinity

### Pod Affinity

Attracts pods to nodes where certain pods are running.

**Analogy**: "I want to be near my friends."

#### Basic Pod Affinity
```yaml
spec:
  affinity:
    podAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchLabels:
            app: web
        topologyKey: kubernetes.io/hostname
```

**Behavior**: Schedule this pod on same node as pods with `app=web`.

#### Use Cases
- Co-locate cache with application
- Keep related microservices together
- Reduce network latency
- Share resources

### Pod Anti-Affinity

Repels pods from nodes where certain pods are running.

**Analogy**: "I want to be away from them."

#### Basic Pod Anti-Affinity
```yaml
spec:
  affinity:
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchLabels:
            app: web
        topologyKey: kubernetes.io/hostname
```

**Behavior**: Don't schedule this pod on same node as pods with `app=web`.

#### Use Cases
- High availability (spread replicas)
- Avoid resource contention
- Fault tolerance
- Prevent overloading

### Topology Keys

Defines the scope of pod (anti)affinity.

#### kubernetes.io/hostname
```yaml
topologyKey: kubernetes.io/hostname
```
**Scope**: Single node
**Effect**: Pods on same/different **node**

#### topology.kubernetes.io/zone
```yaml
topologyKey: topology.kubernetes.io/zone
```
**Scope**: Availability zone
**Effect**: Pods in same/different **zone**

#### topology.kubernetes.io/region
```yaml
topologyKey: topology.kubernetes.io/region
```
**Scope**: Region
**Effect**: Pods in same/different **region**

#### Custom Labels
```yaml
topologyKey: rack
topologyKey: datacenter
```
**Scope**: Whatever you define
**Effect**: Based on custom node labels

### Complete Examples

#### Example 1: High Availability Web App
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web-app
  template:
    metadata:
      labels:
        app: web-app
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchLabels:
                app: web-app
            topologyKey: kubernetes.io/hostname
      containers:
      - name: web
        image: nginx:1.21
```

**Result**:
```
Node 1: web-app-0
Node 2: web-app-1
Node 3: web-app-2
```

#### Example 2: Cache Co-location
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis-cache
spec:
  replicas: 3
  template:
    metadata:
      labels:
        app: redis
    spec:
      affinity:
        podAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchLabels:
                  app: api
              topologyKey: kubernetes.io/hostname
      containers:
      - name: redis
        image: redis:7.0
```

**Result**: Redis pods prefer to run on same nodes as API pods.

#### Example 3: Zone-Level Anti-Affinity
```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: database
spec:
  replicas: 3
  template:
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchLabels:
                app: database
            topologyKey: topology.kubernetes.io/zone
      containers:
      - name: postgres
        image: postgres:15
```

**Result**:
```
Zone A: database-0
Zone B: database-1
Zone C: database-2
```

---

## Topology Spread Constraints

### What are Topology Spread Constraints?

Fine-grained control over how pods are distributed across topology domains (nodes, zones, regions).

**More flexible** than pod anti-affinity.

### Basic Structure

```yaml
spec:
  topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: kubernetes.io/hostname
    whenUnsatisfiable: DoNotSchedule
    labelSelector:
      matchLabels:
        app: web
```

### Fields

**maxSkew**: Maximum difference in pod count between any two topology domains.

**topologyKey**: Label key defining topology domain (hostname, zone, region).

**whenUnsatisfiable**:
- `DoNotSchedule`: Hard constraint (like required)
- `ScheduleAnyway`: Soft constraint (like preferred)

**labelSelector**: Which pods to consider for spreading.

### Examples

#### Example 1: Even Node Distribution
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
spec:
  replicas: 6
  template:
    spec:
      topologySpreadConstraints:
      - maxSkew: 1
        topologyKey: kubernetes.io/hostname
        whenUnsatisfiable: DoNotSchedule
        labelSelector:
          matchLabels:
            app: web-app
```

**Result** (3 nodes):
```
Node 1: 2 pods
Node 2: 2 pods
Node 3: 2 pods
```

#### Example 2: Zone Distribution
```yaml
spec:
  topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: topology.kubernetes.io/zone
    whenUnsatisfiable: DoNotSchedule
    labelSelector:
      matchLabels:
        app: web-app
```

**Result** (3 zones, 9 replicas):
```
Zone A: 3 pods
Zone B: 3 pods
Zone C: 3 pods
```

---

## Real-World Patterns

### Pattern 1: High-Availability Web Application

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
spec:
  replicas: 6
  selector:
    matchLabels:
      app: frontend
      tier: web
  template:
    metadata:
      labels:
        app: frontend
        tier: web
    spec:
      # Spread across zones
      topologySpreadConstraints:
      - maxSkew: 1
        topologyKey: topology.kubernetes.io/zone
        whenUnsatisfiable: DoNotSchedule
        labelSelector:
          matchLabels:
            app: frontend
      
      # Anti-affinity within zone (spread across nodes)
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchLabels:
                  app: frontend
              topologyKey: kubernetes.io/hostname
      
      containers:
      - name: frontend
        image: frontend:1.0
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
```

### Pattern 2: Database with SSD and HA

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
spec:
  replicas: 3
  serviceName: postgres
  template:
    spec:
      # Must run on SSD nodes
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: disk-type
                operator: In
                values:
                - ssd
        # Spread across zones
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchLabels:
                app: postgres
            topologyKey: topology.kubernetes.io/zone
      
      containers:
      - name: postgres
        image: postgres:15
        volumeMounts:
        - name: data
          mountPath: /var/lib/postgresql/data
  
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: fast-ssd
      resources:
        requests:
          storage: 100Gi
```

### Pattern 3: ML Workload on GPU Nodes

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: ml-training
spec:
  template:
    spec:
      # Tolerate GPU node taint
      tolerations:
      - key: nvidia.com/gpu
        operator: Exists
        effect: NoSchedule
      
      # Require GPU node
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: accelerator
                operator: In
                values:
                - gpu
      
      containers:
      - name: trainer
        image: ml-trainer:2.0
        resources:
          limits:
            nvidia.com/gpu: 2
      
      restartPolicy: Never
```

---

## Best Practices

### Taints & Tolerations

1. **Document All Taints**
   ```bash
   kubectl taint nodes gpu-1 gpu=v100:NoSchedule \
     --overwrite
   kubectl annotate node gpu-1 \
     description="V100 GPU node for ML workloads"
   ```

2. **Use NoExecute Carefully**
   - Evicts existing pods immediately
   - Test in non-production first
   - Have tolerationSeconds for grace period

3. **Descriptive Taint Keys**
   ```bash
   # Good
   kubectl taint nodes node1 workload-type=database:NoSchedule
   
   # Bad
   kubectl taint nodes node1 db:NoSchedule
   ```

4. **Remove Taints After Maintenance**
   ```bash
   kubectl taint nodes node1 maintenance:NoExecute-
   ```

### Node Affinity

1. **Use Required for Critical**
   ```yaml
   # Database MUST run on SSD
   requiredDuringSchedulingIgnoredDuringExecution
   ```

2. **Use Preferred for Optimization**
   ```yaml
   # Web app PREFERS zone-a
   preferredDuringSchedulingIgnoredDuringExecution
   ```

3. **Combine with Weights**
   ```yaml
   - weight: 80  # Strong preference
   - weight: 20  # Weak preference
   ```

### Pod Anti-Affinity

1. **Always Use for Stateful Apps**
   ```yaml
   # Spread database replicas
   podAntiAffinity:
     requiredDuringScheduling...
   ```

2. **Match Replicas to Topology**
   ```yaml
   # 3 replicas, 3 zones
   replicas: 3
   topologyKey: topology.kubernetes.io/zone
   ```

3. **Use Topology Spread for Better Control**
   ```yaml
   topologySpreadConstraints:
   - maxSkew: 1
   ```

---

## Summary

**Taints** repel pods from nodes.
**Tolerations** allow pods on tainted nodes.
**Node Affinity** attracts pods to nodes.
**Pod Affinity** co-locates pods.
**Pod Anti-Affinity** separates pods.

**Use Together** for ultimate scheduling control! 🎯

**Next Steps**: Day 23-24 - Resource Limits & Requests
