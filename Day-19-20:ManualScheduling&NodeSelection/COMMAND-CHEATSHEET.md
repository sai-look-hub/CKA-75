# Node Scheduling - Command Cheatsheet

## Quick Reference for Kubernetes Node Scheduling

---

## Node Management

### Viewing Nodes

```bash
# List all nodes
kubectl get nodes

# List nodes with labels
kubectl get nodes --show-labels

# Get nodes with specific columns
kubectl get nodes -o custom-columns=NAME:.metadata.name,STATUS:.status.conditions[-1].type,ROLES:.metadata.labels."node-role\.kubernetes\.io/.*"

# Get nodes in wide format
kubectl get nodes -o wide

# Describe specific node
kubectl describe node <node-name>

# Get node YAML
kubectl get node <node-name> -o yaml

# Watch nodes
kubectl get nodes -w
```

### Node Labels

```bash
# Add label to node
kubectl label node <node-name> <key>=<value>
kubectl label node worker-1 disktype=ssd

# Add multiple labels
kubectl label node <node-name> env=prod tier=frontend region=us-west

# Remove label from node
kubectl label node <node-name> <key>-
kubectl label node worker-1 disktype-

# Overwrite existing label
kubectl label node <node-name> <key>=<value> --overwrite
kubectl label node worker-1 env=production --overwrite

# Label multiple nodes
kubectl label nodes --all environment=production

# Show specific labels
kubectl get nodes -L disktype,environment,region
kubectl get nodes --label-columns=disktype,env

# Filter nodes by label
kubectl get nodes -l disktype=ssd
kubectl get nodes -l environment=production,region=us-west
kubectl get nodes -l 'environment in (production,staging)'
kubectl get nodes -l environment!=development
```

---

## Pod Scheduling with nodeName

### Direct Node Assignment

```bash
# Create pod with nodeName (not recommended for production)
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: nginx-direct
spec:
  nodeName: worker-node-1  # Direct assignment
  containers:
  - name: nginx
    image: nginx:latest
EOF

# Check where pod is scheduled
kubectl get pod nginx-direct -o wide
kubectl get pod nginx-direct -o jsonpath='{.spec.nodeName}'
```

---

## Pod Scheduling with nodeSelector

### Label-Based Selection

```bash
# Create pod with nodeSelector
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: gpu-pod
spec:
  nodeSelector:
    hardware: gpu
  containers:
  - name: app
    image: myapp:latest
EOF

# Multiple selectors (AND logic)
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: ssd-prod-pod
spec:
  nodeSelector:
    disktype: ssd
    environment: production
  containers:
  - name: app
    image: myapp:latest
EOF

# Check pod placement
kubectl get pod <pod-name> -o wide
kubectl describe pod <pod-name> | grep "Node:"
```

---

## Node Affinity

### Required Affinity (Hard Constraint)

```bash
# Create pod with required affinity
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: affinity-required
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
  containers:
  - name: app
    image: nginx:latest
EOF

# Multiple expressions (OR between terms)
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: affinity-or
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:  # Option 1
          - key: hardware
            operator: In
            values:
            - gpu
        - matchExpressions:  # OR Option 2
          - key: memory
            operator: In
            values:
            - high
  containers:
  - name: app
    image: nginx:latest
EOF
```

### Preferred Affinity (Soft Constraint)

```bash
# Create pod with preferred affinity
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: affinity-preferred
spec:
  affinity:
    nodeAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 80  # Higher weight = stronger preference
        preference:
          matchExpressions:
          - key: disktype
            operator: In
            values:
            - ssd
      - weight: 20
        preference:
          matchExpressions:
          - key: zone
            operator: In
            values:
            - us-west-1a
  containers:
  - name: app
    image: nginx:latest
EOF
```

### Combined Required + Preferred

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: affinity-combined
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: region
            operator: In
            values:
            - us-west
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        preference:
          matchExpressions:
          - key: disktype
            operator: In
            values:
            - ssd
  containers:
  - name: app
    image: nginx:latest
EOF
```

### Affinity Operators

```bash
# In - value must be in list
- key: environment
  operator: In
  values:
  - production
  - staging

# NotIn - value must NOT be in list
- key: zone
  operator: NotIn
  values:
  - us-east-1c

# Exists - key must exist (any value)
- key: disktype
  operator: Exists

# DoesNotExist - key must NOT exist
- key: spot-instance
  operator: DoesNotExist

# Gt - greater than (for numeric values)
- key: node-capacity
  operator: Gt
  values:
  - "100"

# Lt - less than (for numeric values)
- key: node-age
  operator: Lt
  values:
  - "30"
```

---

## Pod Anti-Affinity

### Spread Pods Across Nodes

```bash
# Required anti-affinity (hard constraint)
cat <<EOF | kubectl apply -f -
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
              matchExpressions:
              - key: app
                operator: In
                values:
                - web
            topologyKey: kubernetes.io/hostname  # Each pod on different node
      containers:
      - name: nginx
        image: nginx:latest
EOF

# Preferred anti-affinity (soft constraint)
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
spec:
  replicas: 5
  selector:
    matchLabels:
      app: api
  template:
    metadata:
      labels:
        app: api
    spec:
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values:
                  - api
              topologyKey: kubernetes.io/hostname
      containers:
      - name: api
        image: api:latest
EOF
```

### Spread Across Zones

```bash
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: multi-zone
spec:
  replicas: 6
  selector:
    matchLabels:
      app: webapp
  template:
    metadata:
      labels:
        app: webapp
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchLabels:
                app: webapp
            topologyKey: topology.kubernetes.io/zone  # Spread across zones
      containers:
      - name: app
        image: nginx:latest
EOF
```

---

## Topology Spread Constraints

```bash
# Even distribution across topology domains
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: evenly-spread
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
        whenUnsatisfiable: DoNotSchedule  # or ScheduleAnyway
        labelSelector:
          matchLabels:
            app: spread-demo
      containers:
      - name: app
        image: nginx:latest
EOF

# Multiple topology constraints
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: multi-topology
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
      - maxSkew: 1
        topologyKey: zone
        whenUnsatisfiable: DoNotSchedule
        labelSelector:
          matchLabels:
            app: webapp
      - maxSkew: 2
        topologyKey: kubernetes.io/hostname
        whenUnsatisfiable: ScheduleAnyway
        labelSelector:
          matchLabels:
            app: webapp
      containers:
      - name: app
        image: nginx:latest
EOF
```

---

## Debugging & Inspection

### Check Pod Scheduling

```bash
# Get pod with node information
kubectl get pod <pod-name> -o wide

# Get pod's node name
kubectl get pod <pod-name> -o jsonpath='{.spec.nodeName}'

# Check why pod is pending
kubectl describe pod <pod-name> | grep -A 10 Events

# See scheduling decisions
kubectl describe pod <pod-name> | grep "Node-Selectors" -A 10

# Check pod's affinity rules
kubectl get pod <pod-name> -o yaml | grep -A 30 affinity

# View all pods on a specific node
kubectl get pods --all-namespaces -o wide --field-selector spec.nodeName=<node-name>

# Count pods per node
kubectl get pods -A -o wide | awk '{print $8}' | sort | uniq -c
```

### Check Node Capacity & Allocation

```bash
# See node resource usage
kubectl top node
kubectl top node <node-name>

# Describe node to see allocated resources
kubectl describe node <node-name> | grep -A 10 "Allocated resources"

# Check node conditions
kubectl describe node <node-name> | grep -A 5 Conditions

# See node capacity
kubectl get node <node-name> -o jsonpath='{.status.capacity}'

# See allocatable resources
kubectl get node <node-name> -o jsonpath='{.status.allocatable}'
```

### Scheduler Logs

```bash
# Get scheduler pods
kubectl get pods -n kube-system | grep scheduler

# View scheduler logs
kubectl logs -n kube-system kube-scheduler-<name>

# Follow scheduler logs
kubectl logs -n kube-system kube-scheduler-<name> -f

# Search for specific pod scheduling
kubectl logs -n kube-system kube-scheduler-<name> | grep <pod-name>
```

### Events

```bash
# Get all events
kubectl get events --sort-by='.lastTimestamp'

# Get events for specific pod
kubectl get events --field-selector involvedObject.name=<pod-name>

# Get scheduling events
kubectl get events --field-selector reason=Scheduled

# Get failed scheduling events
kubectl get events --field-selector reason=FailedScheduling

# Watch events
kubectl get events -w
```

---

## Taints and Tolerations

### Taint Nodes

```bash
# Add taint to node
kubectl taint node <node-name> <key>=<value>:<effect>
kubectl taint node worker-1 dedicated=gpu:NoSchedule

# Effects:
# - NoSchedule: No new pods without toleration
# - PreferNoSchedule: Try not to schedule
# - NoExecute: Evict existing pods without toleration

# Examples
kubectl taint node worker-1 special=true:NoSchedule
kubectl taint node worker-2 maintenance=true:NoExecute
kubectl taint node worker-3 spot-instance=true:PreferNoSchedule

# Remove taint
kubectl taint node <node-name> <key>:<effect>-
kubectl taint node worker-1 dedicated:NoSchedule-

# List taints on node
kubectl describe node <node-name> | grep Taints
```

### Pod Tolerations

```bash
# Create pod with toleration
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: gpu-pod
spec:
  tolerations:
  - key: "dedicated"
    operator: "Equal"
    value: "gpu"
    effect: "NoSchedule"
  containers:
  - name: app
    image: gpu-app:latest
EOF

# Tolerate any value
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: flexible-pod
spec:
  tolerations:
  - key: "special"
    operator: "Exists"
    effect: "NoSchedule"
  containers:
  - name: app
    image: myapp:latest
EOF

# Tolerate all taints
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: tolerant-pod
spec:
  tolerations:
  - operator: "Exists"
  containers:
  - name: app
    image: myapp:latest
EOF
```

---

## Node Maintenance

### Cordon & Drain

```bash
# Mark node as unschedulable (no new pods)
kubectl cordon <node-name>

# Mark as schedulable again
kubectl uncordon <node-name>

# Drain node (evict all pods)
kubectl drain <node-name>

# Drain ignoring DaemonSets
kubectl drain <node-name> --ignore-daemonsets

# Drain with grace period
kubectl drain <node-name> --grace-period=300

# Drain and delete local data
kubectl drain <node-name> --delete-emptydir-data

# Force drain (dangerous!)
kubectl drain <node-name> --force --delete-emptydir-data

# Check if node is cordoned
kubectl get nodes
# Look for SchedulingDisabled in STATUS
```

---

## Patching & Updates

### Update Deployment Scheduling

```bash
# Add nodeSelector to deployment
kubectl patch deployment <name> -p '
{
  "spec": {
    "template": {
      "spec": {
        "nodeSelector": {
          "disktype": "ssd"
        }
      }
    }
  }
}'

# Add node affinity to deployment
kubectl patch deployment <name> --type=json -p='[
  {
    "op": "add",
    "path": "/spec/template/spec/affinity",
    "value": {
      "nodeAffinity": {
        "requiredDuringSchedulingIgnoredDuringExecution": {
          "nodeSelectorTerms": [{
            "matchExpressions": [{
              "key": "disktype",
              "operator": "In",
              "values": ["ssd"]
            }]
          }]
        }
      }
    }
  }
]'

# Remove nodeSelector
kubectl patch deployment <name> --type=json -p='[
  {"op": "remove", "path": "/spec/template/spec/nodeSelector"}
]'
```

---

## Useful One-Liners

```bash
# Find pods on specific node
kubectl get pods -A -o wide | grep <node-name>

# Count pods per node
kubectl get pods -A -o jsonpath='{range .items[*]}{.spec.nodeName}{"\n"}{end}' | sort | uniq -c

# Find pending pods
kubectl get pods -A --field-selector=status.phase=Pending

# Find pods without node assignment
kubectl get pods -A -o wide | grep '<none>'

# Get pod distribution by label
kubectl get pods -l app=myapp -o custom-columns=POD:.metadata.name,NODE:.spec.nodeName

# Find nodes with specific label
kubectl get nodes -l disktype=ssd -o name

# Check if affinity is working
kubectl get pod <name> -o jsonpath='{.spec.affinity}'

# Get all node labels as JSON
kubectl get nodes -o json | jq '.items[].metadata.labels'

# List all node names
kubectl get nodes -o jsonpath='{.items[*].metadata.name}'

# Get scheduling info for all pods
kubectl get pods -A -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName,STATUS:.status.phase
```

---

## Tips & Best Practices

### General Guidelines

- Use `nodeSelector` for simple, straightforward requirements
- Use `node affinity` for complex scheduling logic
- Use `preferred` affinity when possible (more flexible than `required`)
- Combine `required` and `preferred` for best results
- Always test scheduling rules in dev/staging first
- Document your labeling strategy
- Use anti-affinity for high availability
- Consider topology spread constraints for even distribution

### Label Naming Conventions

```bash
# Good label names
kubectl label node <name> environment=production
kubectl label node <name> hardware-type=gpu
kubectl label node <name> disk-type=ssd
kubectl label node <name> zone=us-west-1a

# Hierarchical labels
kubectl label node <name> region=us-west
kubectl label node <name> zone=us-west-1a
kubectl label node <name> rack=rack-01
```

### Testing Scheduling

```bash
# Create test pod
kubectl run test-pod --image=nginx --dry-run=client -o yaml > test-pod.yaml

# Add scheduling rules, then apply
kubectl apply -f test-pod.yaml

# Check placement
kubectl get pod test-pod -o wide

# Cleanup
kubectl delete pod test-pod
```

---

**Quick Reference Card**

| Task | Command |
|------|---------|
| Add label | `kubectl label node <node> <key>=<value>` |
| Remove label | `kubectl label node <node> <key>-` |
| View labels | `kubectl get nodes --show-labels` |
| Taint node | `kubectl taint node <node> <key>=<value>:<effect>` |
| Remove taint | `kubectl taint node <node> <key>:<effect>-` |
| Cordon node | `kubectl cordon <node>` |
| Uncordon node | `kubectl uncordon <node>` |
| Drain node | `kubectl drain <node> --ignore-daemonsets` |
| Check pod node | `kubectl get pod <pod> -o wide` |
| Pending pods | `kubectl get pods --field-selector=status.phase=Pending` |

---

This cheatsheet covers all essential node scheduling commands in Kubernetes!
