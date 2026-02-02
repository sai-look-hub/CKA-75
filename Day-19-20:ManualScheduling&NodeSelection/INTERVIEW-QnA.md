# Node Scheduling - Interview Questions & Answers

## Table of Contents
1. [Fundamentals](#fundamentals)
2. [nodeName vs nodeSelector vs Node Affinity](#nodename-vs-nodeselector-vs-node-affinity)
3. [Node Affinity Deep Dive](#node-affinity-deep-dive)
4. [Pod Affinity & Anti-Affinity](#pod-affinity--anti-affinity)
5. [Advanced Concepts](#advanced-concepts)
6. [Troubleshooting](#troubleshooting)
7. [Real-World Scenarios](#real-world-scenarios)
8. [Best Practices](#best-practices)

---

## Fundamentals

### Q1: What is pod scheduling in Kubernetes and how does it work?

**Answer:**

Pod scheduling is the process of assigning pods to nodes in a Kubernetes cluster. The **kube-scheduler** is responsible for this process.

**How it works:**

1. **Watch for unscheduled pods**: Scheduler watches for pods with `spec.nodeName` not set
2. **Filter nodes**: Applies predicates to filter out unsuitable nodes
   - Sufficient resources (CPU, memory)
   - Node affinity/selector matches
   - Taints and tolerations
   - Pod anti-affinity rules
3. **Score nodes**: Ranks remaining nodes based on priorities
   - Resource availability
   - Pod spread
   - Image locality
   - Custom priorities
4. **Bind pod**: Selects highest-scoring node and binds pod to it
5. **Update status**: Updates pod's `spec.nodeName` field

**Example:**
```yaml
# Before scheduling
apiVersion: v1
kind: Pod
metadata:
  name: my-pod
spec:
  containers:
  - name: nginx
    image: nginx
  # No nodeName set

# After scheduling
apiVersion: v1
kind: Pod
metadata:
  name: my-pod
spec:
  nodeName: worker-node-1  # Scheduler adds this
  containers:
  - name: nginx
    image: nginx
```

**Scheduling can be influenced by:**
- nodeName (direct assignment)
- nodeSelector (label-based)
- Node affinity (advanced rules)
- Taints and tolerations
- Pod affinity/anti-affinity
- Resource requests/limits

---

### Q2: What are the different ways to schedule pods on specific nodes?

**Answer:**

There are **5 main methods** to control pod placement:

**1. nodeName (Direct Assignment)**
```yaml
spec:
  nodeName: worker-node-1  # Bypasses scheduler
```
- Simplest method
- Not recommended for production
- No fallback if node unavailable

**2. nodeSelector (Label-Based)**
```yaml
spec:
  nodeSelector:
    disktype: ssd
```
- Simple and effective
- Uses node labels
- Supports AND logic only
- Recommended for straightforward cases

**3. Node Affinity (Rule-Based)**
```yaml
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: disktype
            operator: In
            values:
            - ssd
```
- Most flexible
- Supports complex rules
- Required (hard) and preferred (soft) constraints
- Multiple operators (In, NotIn, Exists, etc.)

**4. Taints and Tolerations**
```yaml
# Taint on node
kubectl taint node worker-1 dedicated=gpu:NoSchedule

# Toleration in pod
spec:
  tolerations:
  - key: dedicated
    value: gpu
    effect: NoSchedule
```
- Prevents pods from being scheduled
- Pod must have matching toleration
- Used for node isolation

**5. Pod Affinity/Anti-Affinity**
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
- Based on other pods
- Useful for co-location or spreading
- High availability patterns

---

### Q3: Explain the Kubernetes scheduler workflow with an example.

**Answer:**

**Scheduler Workflow:**

```
┌─────────────────┐
│  Pod Created    │
│ (no nodeName)   │
└────────┬────────┘
         │
         ▼
┌────────────────────┐
│  FILTER Phase      │
│  (Predicates)      │
├────────────────────┤
│ ✓ Resource check   │
│ ✓ Node selector    │
│ ✓ Affinity rules   │
│ ✓ Taints/tolerate  │
│ ✓ Pod anti-affinity│
└────────┬───────────┘
         │
         ▼
┌────────────────────┐
│  SCORE Phase       │
│  (Priorities)      │
├────────────────────┤
│ • Resource balance │
│ • Pod spread       │
│ • Image locality   │
│ • Affinity weights │
└────────┬───────────┘
         │
         ▼
┌────────────────────┐
│  BIND Phase        │
│  (Select & Bind)   │
└────────────────────┘
```

**Example Scenario:**

**Cluster State:**
- 3 nodes: node-1, node-2, node-3
- Pod needs: 1 CPU, 1Gi memory, disktype=ssd

**Pod Spec:**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: db-pod
spec:
  nodeSelector:
    disktype: ssd
  containers:
  - name: postgres
    image: postgres:14
    resources:
      requests:
        cpu: "1"
        memory: "1Gi"
```

**Step 1 - FILTER:**
- node-1: ✅ Has disktype=ssd, 2 CPU, 4Gi available
- node-2: ❌ No disktype label (filtered out)
- node-3: ✅ Has disktype=ssd, 4 CPU, 2Gi available

**Step 2 - SCORE:**
- node-1: Score 60 (moderate resources)
- node-3: Score 80 (more available CPU)

**Step 3 - BIND:**
- Selected: node-3 (highest score)
- Pod's `nodeName` set to `node-3`

---

## nodeName vs nodeSelector vs Node Affinity

### Q4: Compare nodeName, nodeSelector, and node affinity. When should each be used?

**Answer:**

**Comparison Table:**

| Feature | nodeName | nodeSelector | Node Affinity |
|---------|----------|--------------|---------------|
| **Complexity** | Very Low | Low | Medium-High |
| **Flexibility** | None | Low | Very High |
| **Scheduler** | Bypasses | Uses | Uses |
| **Operators** | N/A | Equality only | In, NotIn, Exists, etc. |
| **Multiple Conditions** | No | Yes (AND only) | Yes (AND/OR) |
| **Soft Requirements** | No | No | Yes (preferred) |
| **Fallback** | No | No | Yes (with preferred) |
| **Production Ready** | ❌ No | ✅ Yes | ✅ Yes |

**When to Use Each:**

**Use nodeName when:**
- Testing/debugging specific node
- System-level pods (very rare)
- ⚠️ Almost NEVER in production

**Example:**
```yaml
spec:
  nodeName: worker-node-1  # Direct assignment
```

**Use nodeSelector when:**
- Simple label-based requirements
- Single or multiple labels (AND logic)
- Straightforward, non-complex needs
- ✅ Good for most common cases

**Example:**
```yaml
spec:
  nodeSelector:
    disktype: ssd
    region: us-west
```

**Use Node Affinity when:**
- Complex scheduling requirements
- Need OR logic between rules
- Want soft preferences (not hard requirements)
- Need advanced operators (NotIn, Exists, etc.)
- ✅ Best for sophisticated scenarios

**Example:**
```yaml
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: disktype
            operator: In
            values:
            - ssd
            - nvme
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        preference:
          matchExpressions:
          - key: zone
            operator: In
            values:
            - us-west-1a
```

**Real-World Decision Tree:**

```
Need to schedule pod?
│
├─ Simple single label? → Use nodeSelector
│
├─ Multiple labels (AND)? → Use nodeSelector
│
├─ Complex rules (OR, NotIn, etc.)? → Use node affinity
│
├─ Want fallback/preferences? → Use node affinity (preferred)
│
└─ Testing specific node? → Use nodeName (dev only!)
```

---

### Q5: Why is nodeName not recommended for production use?

**Answer:**

**Problems with nodeName:**

**1. No Scheduler Validation**
```yaml
spec:
  nodeName: worker-node-1
```
- Bypasses all scheduler checks
- No resource verification
- No affinity/anti-affinity enforcement
- Pod can fail to start if resources insufficient

**2. No Fallback Mechanism**
- If node doesn't exist → Pod stuck Pending
- If node is unavailable → Pod stuck Pending
- If node goes down → Pod not rescheduled automatically

**Example Problem:**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: broken-pod
spec:
  nodeName: node-that-doesnt-exist  # Will be Pending forever!
  containers:
  - name: nginx
    image: nginx
```

**3. Hard to Maintain**
- Node names change
- Cluster scales up/down
- Hardware changes
- No flexibility

**4. Breaks High Availability**
```yaml
# BAD: All replicas on same node!
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
spec:
  replicas: 5
  template:
    spec:
      nodeName: worker-1  # Single point of failure!
```

**5. Environment Portability**
- Dev/staging/prod have different node names
- Can't use same manifests across environments

**Correct Approach:**
```yaml
# GOOD: Use labels and nodeSelector/affinity
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
spec:
  replicas: 5
  template:
    spec:
      nodeSelector:
        environment: production  # Works across any prod nodes
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchLabels:
                app: webapp
            topologyKey: kubernetes.io/hostname  # Spread across nodes
```

**Only Valid Use Case:**
- DaemonSet that MUST run on specific node (rare)
- Debugging/testing (temporary)
- System-level components with very specific requirements

---

## Node Affinity Deep Dive

### Q6: Explain the difference between requiredDuringSchedulingIgnoredDuringExecution and preferredDuringSchedulingIgnoredDuringExecution.

**Answer:**

**Two Types of Node Affinity:**

**1. requiredDuringSchedulingIgnoredDuringExecution (HARD requirement)**

```yaml
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: disktype
            operator: In
            values:
            - ssd
```

**Characteristics:**
- **MUST match** or pod won't be scheduled
- Pod remains Pending if no matching nodes
- Multiple nodeSelectorTerms use OR logic
- Multiple matchExpressions within a term use AND logic

**2. preferredDuringSchedulingIgnoredDuringExecution (SOFT preference)**

```yaml
spec:
  affinity:
    nodeAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100  # 1-100 scale
        preference:
          matchExpressions:
          - key: disktype
            operator: In
            values:
            - ssd
```

**Characteristics:**
- **SHOULD match** but not mandatory
- Pod can be scheduled on non-matching nodes
- Weight determines preference strength (1-100)
- Scheduler scores nodes and picks highest

**Comparison:**

| Aspect | Required | Preferred |
|--------|----------|-----------|
| Mandatory | Yes | No |
| Fallback | None | Any node |
| Pending Risk | High | Low |
| Flexibility | Low | High |
| Weight | N/A | 1-100 |
| Production Use | Caution | Recommended |

**Real Example:**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: database-pod
spec:
  affinity:
    nodeAffinity:
      # MUST run in us-west region
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: region
            operator: In
            values:
            - us-west
      
      # PREFER SSD and high memory within us-west
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
          - key: memory
            operator: In
            values:
            - high
  containers:
  - name: postgres
    image: postgres:14
```

**Scheduling Logic:**

1. **Filter**: Only us-west nodes pass (required)
2. **Score**: Among us-west nodes:
   - SSD + high memory: 80 + 20 = 100 points
   - Only SSD: 80 points
   - Only high memory: 20 points
   - Neither: 0 points
3. **Select**: Highest-scoring us-west node

**IgnoredDuringExecution Meaning:**
- Rules checked during scheduling
- **NOT re-evaluated** if node labels change after pod is running
- Pod keeps running even if node no longer matches
- Future: `requiredDuringSchedulingRequiredDuringExecution` will evict pods

---

### Q7: Explain node affinity operators and provide examples for each.

**Answer:**

Node affinity supports **6 operators**:

**1. In - Value must be in the list**
```yaml
matchExpressions:
- key: environment
  operator: In
  values:
  - production
  - staging
```
Use case: Pod can run in production OR staging

**2. NotIn - Value must NOT be in the list**
```yaml
matchExpressions:
- key: zone
  operator: NotIn
  values:
  - us-east-1c
  - eu-west-1a
```
Use case: Avoid specific zones (maybe due to issues)

**3. Exists - Key must exist (any value)**
```yaml
matchExpressions:
- key: gpu
  operator: Exists
```
Use case: Node must have GPU (don't care about model/version)

**4. DoesNotExist - Key must NOT exist**
```yaml
matchExpressions:
- key: spot-instance
  operator: DoesNotExist
```
Use case: Only on non-spot instances (on-demand/reserved)

**5. Gt - Greater than (numeric)**
```yaml
matchExpressions:
- key: node-capacity
  operator: Gt
  values:
  - "100"
```
Use case: Nodes with more than 100 capacity units

**6. Lt - Less than (numeric)**
```yaml
matchExpressions:
- key: node-age-days
  operator: Lt
  values:
  - "30"
```
Use case: Only newer nodes (less than 30 days old)

**Complex Example:**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: complex-scheduling
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          # MUST be in production or staging
          - key: environment
            operator: In
            values:
            - production
            - staging
          # MUST have SSD or NVMe
          - key: disktype
            operator: In
            values:
            - ssd
            - nvme
          # MUST NOT be in zone us-east-1c
          - key: zone
            operator: NotIn
            values:
            - us-east-1c
          # MUST have GPU label (any value)
          - key: gpu
            operator: Exists
          # MUST NOT be a spot instance
          - key: spot-instance
            operator: DoesNotExist
  containers:
  - name: ml-training
    image: tensorflow/tensorflow:latest-gpu
```

---

### Q8: How does OR logic work in node affinity?

**Answer:**

**OR logic is between nodeSelectorTerms, AND logic is within each term.**

**Structure:**
```yaml
nodeAffinity:
  requiredDuringSchedulingIgnoredDuringExecution:
    nodeSelectorTerms:      # OR between terms
    - matchExpressions:     # AND within term
      - expression1
      - expression2
    - matchExpressions:     # OR another option
      - expression3
```

**Example:**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: flexible-pod
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        # Option 1: GPU nodes
        - matchExpressions:
          - key: hardware
            operator: In
            values:
            - gpu
        # OR Option 2: High memory nodes
        - matchExpressions:
          - key: memory
            operator: In
            values:
            - high
  containers:
  - name: app
    image: myapp:latest
```

**Logic:** Pod can run on nodes with (GPU) OR (high memory)

**More Complex:**
```yaml
nodeAffinity:
  requiredDuringSchedulingIgnoredDuringExecution:
    nodeSelectorTerms:
    # Option 1: Production + SSD
    - matchExpressions:
      - key: environment
        operator: In
        values:
        - production
      - key: disktype    # AND
        operator: In
        values:
        - ssd
    # OR Option 2: Staging + NVMe
    - matchExpressions:
      - key: environment
        operator: In
        values:
        - staging
      - key: disktype    # AND
        operator: In
        values:
        - nvme
```

**Logic:** (production AND ssd) OR (staging AND nvme)

**Visual:**
```
Matching Nodes:
✅ production + ssd
✅ staging + nvme
❌ production + hdd (missing ssd)
❌ development + ssd (wrong environment)
```

---

## Pod Affinity & Anti-Affinity

### Q9: What is pod anti-affinity and why is it important for high availability?

**Answer:**

**Pod Anti-Affinity** prevents pods from being scheduled together on the same topology domain (node, zone, region, etc.).

**Why Important for HA:**

**1. Node Failure Protection**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-ha
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchLabels:
                app: web
            topologyKey: kubernetes.io/hostname  # Spread across nodes
```

**Without Anti-Affinity:**
```
Node-1: pod-1, pod-2, pod-3  ← All replicas here!
Node-2: (empty)
Node-3: (empty)

Node-1 fails → ALL replicas down! ❌
```

**With Anti-Affinity:**
```
Node-1: pod-1
Node-2: pod-2
Node-3: pod-3

Node-1 fails → 2/3 replicas still running ✅
```

**2. Zone Failure Protection**
```yaml
spec:
  affinity:
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchLabels:
            app: database
        topologyKey: topology.kubernetes.io/zone  # Spread across zones
```

**Zone Distribution:**
```
us-west-1a: pod-1
us-west-1b: pod-2
us-west-1c: pod-3

Entire zone fails → Still 2/3 available ✅
```

**3. Preferred vs Required:**

**Required (Hard):**
```yaml
podAntiAffinity:
  requiredDuringSchedulingIgnoredDuringExecution:
  - labelSelector:
      matchLabels:
        app: cache
    topologyKey: kubernetes.io/hostname
```
- Pods MUST be on different nodes
- If not enough nodes, some pods stay Pending
- Best for critical workloads

**Preferred (Soft):**
```yaml
podAntiAffinity:
  preferredDuringSchedulingIgnoredDuringExecution:
  - weight: 100
    podAffinityTerm:
      labelSelector:
        matchLabels:
          app: worker
      topologyKey: kubernetes.io/hostname
```
- Pods SHOULD be on different nodes
- Will still schedule if not enough nodes
- Better for flexibility

**Real-World Example:**
```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: elasticsearch
spec:
  replicas: 6
  serviceName: elasticsearch
  selector:
    matchLabels:
      app: elasticsearch
  template:
    metadata:
      labels:
        app: elasticsearch
    spec:
      affinity:
        # Spread across nodes (hard requirement)
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchLabels:
                app: elasticsearch
            topologyKey: kubernetes.io/hostname
        
        # Prefer different zones (soft preference)
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchLabels:
                  app: elasticsearch
              topologyKey: topology.kubernetes.io/zone
```

**Result:**
- Each Elasticsearch pod on different node (required)
- Try to spread across zones too (preferred)
- Survives node AND zone failures

---

### Q10: Explain topology spread constraints and how they differ from pod anti-affinity.

**Answer:**

**Topology Spread Constraints** provide fine-grained control over pod distribution.

**Pod Anti-Affinity:**
- Binary: pods together or apart
- Hard to achieve even distribution
- Can result in uneven spread

**Topology Spread:**
- Controls HOW EVENLY pods are distributed
- Specifies maximum "skew" (difference between domains)
- More predictable distribution

**Example Problem with Anti-Affinity:**
```yaml
# 9 replicas with pod anti-affinity
Cluster: 3 zones, 3 nodes per zone

Possible result:
zone-a: 5 pods  ← Uneven!
zone-b: 2 pods
zone-c: 2 pods
```

**Solution with Topology Spread:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
spec:
  replicas: 9
  selector:
    matchLabels:
      app: webapp
  template:
    metadata:
      labels:
        app: webapp
    spec:
      topologySpreadConstraints:
      - maxSkew: 1  # Max difference between zones
        topologyKey: topology.kubernetes.io/zone
        whenUnsatisfiable: DoNotSchedule
        labelSelector:
          matchLabels:
            app: webapp
```

**Result:**
```
zone-a: 3 pods  ← Even distribution!
zone-b: 3 pods
zone-c: 3 pods
```

**Key Parameters:**

**1. maxSkew**
```yaml
maxSkew: 1  # Difference of max 1 pod between domains
```
- 0: Perfectly even (may be impossible)
- 1: Very balanced
- 2+: More flexible

**2. topologyKey**
```yaml
topologyKey: topology.kubernetes.io/zone  # Spread across zones
topologyKey: kubernetes.io/hostname       # Spread across nodes
topologyKey: region                       # Spread across regions
```

**3. whenUnsatisfiable**
```yaml
whenUnsatisfiable: DoNotSchedule  # Hard constraint
whenUnsatisfiable: ScheduleAnyway # Soft constraint
```

**Complete Example:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: multi-constraint
spec:
  replicas: 12
  selector:
    matchLabels:
      app: api
  template:
    metadata:
      labels:
        app: api
    spec:
      topologySpreadConstraints:
      # Spread evenly across zones
      - maxSkew: 1
        topologyKey: topology.kubernetes.io/zone
        whenUnsatisfiable: DoNotSchedule
        labelSelector:
          matchLabels:
            app: api
      # Spread evenly across nodes (more flexible)
      - maxSkew: 2
        topologyKey: kubernetes.io/hostname
        whenUnsatisfiable: ScheduleAnyway
        labelSelector:
          matchLabels:
            app: api
```

**Comparison:**

| Feature | Pod Anti-Affinity | Topology Spread |
|---------|-------------------|-----------------|
| Control | Binary (together/apart) | Fine-grained (skew) |
| Distribution | Can be uneven | Even distribution |
| Complexity | Simpler | More complex |
| Predictability | Lower | Higher |
| Use Case | Basic spreading | Precise balance |

---

This comprehensive Q&A covers all major concepts of Kubernetes node scheduling!
Continue with more questions? Let me know!
