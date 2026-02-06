# 🎤 Interview Q&A: Static Pods & Multiple Schedulers

Complete guide with questions and detailed answers for interview preparation.

---

## 📚 Table of Contents

1. [Basic Concepts](#basic-concepts)
2. [Static Pods - Fundamentals](#static-pods---fundamentals)
3. [Static Pods - Advanced](#static-pods---advanced)
4. [Multiple Schedulers - Fundamentals](#multiple-schedulers---fundamentals)
5. [Multiple Schedulers - Advanced](#multiple-schedulers---advanced)
6. [Scenario-Based Questions](#scenario-based-questions)
7. [Troubleshooting Questions](#troubleshooting-questions)
8. [Practical Implementation](#practical-implementation)

---

## 🔰 Basic Concepts

### Q1: What are static pods in Kubernetes?

**Answer:**

Static pods are pods that are directly managed by the kubelet daemon on a specific node, rather than being managed by the Kubernetes API server through controllers like Deployments or ReplicaSets.

Key characteristics:
- Created and managed by kubelet, not the control plane
- Defined by manifest files in a local directory on the node
- Cannot be managed via standard kubectl commands (delete, update via API)
- Kubelet creates a mirror pod in the API server for visibility
- Automatically restarted if they crash
- Bound to a specific node (cannot be moved to other nodes)

**Follow-up points:**
- Kubelet watches a specified directory (usually `/etc/kubernetes/manifests/`)
- When a manifest file is added/modified/deleted, kubelet responds accordingly
- Control plane components (apiserver, controller-manager, scheduler, etcd) typically run as static pods

---

### Q2: What is a scheduler in Kubernetes?

**Answer:**

A scheduler is a control plane component responsible for assigning newly created pods to nodes based on various criteria such as resource availability, constraints, affinity/anti-affinity rules, and taints/tolerations.

Key responsibilities:
1. **Watch for new pods**: Monitors unscheduled pods (pods with no nodeName)
2. **Filter nodes**: Eliminates nodes that don't meet pod requirements
3. **Score nodes**: Ranks suitable nodes based on scheduling policies
4. **Bind pod**: Assigns the pod to the highest-scored node
5. **Update API server**: Sets the nodeName field in the pod spec

The default scheduler is `kube-scheduler`, but Kubernetes supports running multiple schedulers simultaneously.

---

### Q3: Why would you need multiple schedulers?

**Answer:**

Multiple schedulers allow different scheduling policies for different workloads:

**Common use cases:**

1. **Specialized hardware**: Different schedulers for GPU, FPGA, or high-memory workloads
2. **Cost optimization**: Scheduler that prefers spot instances or cheaper nodes
3. **Performance requirements**: Different scheduling strategies for latency-sensitive vs batch workloads
4. **Multi-tenancy**: Separate schedulers with different policies per tenant/team
5. **Compliance**: Scheduler ensuring pods land on nodes meeting regulatory requirements
6. **Development vs Production**: Different scheduling policies per environment

**Example scenario:**
```
Default scheduler: General workloads (spread for HA)
GPU scheduler: ML workloads (node affinity for GPU nodes)
Batch scheduler: Long-running jobs (bin-packing for efficiency)
```

---

## 📦 Static Pods - Fundamentals

### Q4: How does kubelet detect and manage static pods?

**Answer:**

The kubelet manages static pods through a file-based watch mechanism:

1. **Configuration**: Kubelet reads `staticPodPath` from its configuration file (`/var/lib/kubelet/config.yaml`)
2. **Directory watching**: Kubelet watches this directory for changes (default check frequency: 20 seconds)
3. **Detection**: When a manifest file is added/modified/deleted, kubelet detects it
4. **Pod creation**: Kubelet creates the pod using the local container runtime (containerd/Docker/CRI-O)
5. **Mirror pod**: Kubelet creates a mirror pod object in the API server for visibility
6. **Lifecycle management**: Kubelet monitors the pod and restarts containers if they fail
7. **Updates**: When manifest changes, kubelet recreates the pod with new configuration
8. **Deletion**: When manifest is removed, kubelet deletes the pod

**Key configuration:**
```yaml
# /var/lib/kubelet/config.yaml
staticPodPath: /etc/kubernetes/manifests/
fileCheckFrequency: 20s
```

---

### Q5: What is a mirror pod and how is it different from the actual static pod?

**Answer:**

A **mirror pod** is a read-only representation of a static pod in the Kubernetes API server.

**Differences:**

| Aspect | Static Pod | Mirror Pod |
|--------|-----------|------------|
| Location | Runs on node | Object in API server |
| Managed by | Kubelet | API server (read-only) |
| Creation | From manifest file | Created by kubelet |
| Deletion | Remove manifest file | Automatically removed when static pod stops |
| Editing | Edit manifest file | Cannot edit via API |
| Visibility | Only visible on node | Visible via kubectl |
| Owner | Node | Has ownerReference to the Node |

**Mirror pod purpose:**
- Provides visibility of static pods through kubectl
- Allows monitoring and observability tools to track static pods
- Shows in `kubectl get pods` output with node name suffix
- Cannot be deleted directly (will be recreated by kubelet)

**Identifying a mirror pod:**
```bash
kubectl get pod <pod-name> -o yaml | grep -A5 ownerReferences
# ownerReferences:
# - kind: Node
#   name: node01
```

---

### Q6: Where are static pod manifests typically stored?

**Answer:**

Static pod manifest locations vary by Kubernetes distribution:

| Distribution | Default Path |
|--------------|-------------|
| kubeadm | `/etc/kubernetes/manifests/` |
| minikube | `/etc/kubernetes/manifests/` |
| kind | `/etc/kubernetes/manifests/` |
| k3s | `/var/lib/rancher/k3s/server/manifests/` |
| k0s | `/var/lib/k0s/manifests/` |
| MicroK8s | Custom, check `/var/snap/microk8s/current/args/kubelet` |

**How to find the path:**
```bash
# Method 1: Check kubelet config
cat /var/lib/kubelet/config.yaml | grep staticPodPath

# Method 2: Check kubelet process
ps aux | grep kubelet | grep "pod-manifest-path"

# Method 3: Check systemd service
systemctl cat kubelet | grep "pod-manifest-path"
```

**Alternative to directory:** You can also use a URL:
```yaml
staticPodURL: "http://example.com/manifests/"
```

---

### Q7: Can you update a static pod? If yes, how?

**Answer:**

Yes, you can update a static pod, but the process is different from regular pods.

**Update methods:**

**Method 1: Edit the manifest file directly (on the node)**
```bash
# SSH to the node
ssh node01

# Edit the manifest
sudo vi /etc/kubernetes/manifests/static-pod.yaml
# Make changes (e.g., update image version)

# Save the file
# Kubelet will detect changes within ~20-60 seconds and recreate the pod

# Verify update
exit
kubectl get pod static-pod-node01 -o yaml | grep image:
```

**Method 2: Replace the manifest file**
```bash
# Create updated manifest locally
vi static-pod-updated.yaml

# Copy to node
scp static-pod-updated.yaml node01:/tmp/

# SSH to node
ssh node01

# Replace manifest
sudo mv /tmp/static-pod-updated.yaml /etc/kubernetes/manifests/static-pod.yaml

exit
```

**Method 3: Restart kubelet (for immediate update)**
```bash
ssh node01
sudo systemctl restart kubelet
exit
```

**Important notes:**
- Changes via `kubectl edit` won't work (mirror pod is read-only)
- Kubelet detects file changes automatically
- Pod is recreated (not updated in-place)
- There will be brief downtime during recreation
- Old pod is deleted before new one is created

---

### Q8: How do you delete a static pod?

**Answer:**

To delete a static pod, you must remove its manifest file from the node.

**Incorrect method (won't work permanently):**
```bash
kubectl delete pod static-pod-node01
# Pod deleted, but kubelet will recreate it immediately!
```

**Correct method:**
```bash
# Step 1: SSH to the node
ssh node01

# Step 2: Remove the manifest file
sudo rm /etc/kubernetes/manifests/static-pod.yaml

# Step 3: Exit the node
exit

# Step 4: Verify deletion
kubectl get pods -A | grep static-pod
# Should return nothing
```

**Alternative: Temporarily stop kubelet**
```bash
ssh node01

# Stop kubelet
sudo systemctl stop kubelet

# The static pod will stop
# To start again:
sudo systemctl start kubelet

exit
```

**Why kubectl delete doesn't work:**
- `kubectl delete` removes the mirror pod from API server
- Kubelet sees the manifest file still exists
- Kubelet recreates the pod immediately
- The manifest file is the source of truth, not the API server

---

## 🔧 Static Pods - Advanced

### Q9: What happens if the node running a static pod goes down?

**Answer:**

When a node running static pods goes down:

**Immediate effects:**
1. Static pods on that node stop running (no containers running)
2. Mirror pods in API server show as "NodeNotReady" or similar status
3. API server marks the node as NotReady after grace period (default ~40s)

**Important differences from regular pods:**
- Static pods **DO NOT** get rescheduled to other nodes
- No controller will create replacement pods
- Static pods are tied to their specific node
- They will only run again when that specific node comes back online

**When node recovers:**
1. Kubelet starts on the node
2. Kubelet reads manifest files from the static pod directory
3. Kubelet recreates all static pods
4. Mirror pods in API server are updated to Running status

**Comparison with DaemonSets:**
| Aspect | Static Pod | DaemonSet |
|--------|-----------|-----------|
| Node failure | Stops, not rescheduled | Not rescheduled (one per node) |
| New node added | Not deployed | Automatically deployed |
| Managed by | Kubelet | DaemonSet controller |
| Use case | Control plane | Node agents |

**Best practices:**
- For control plane: This is acceptable (HA through multiple master nodes)
- For applications: Use DaemonSets or Deployments instead
- Monitor node health to detect failures quickly

---

### Q10: Can static pods use Persistent Volumes? What about ConfigMaps and Secrets?

**Answer:**

Static pods have specific limitations regarding volume types:

**Supported volume types:**
1. **hostPath**: ✅ Yes - Most common for static pods
2. **emptyDir**: ✅ Yes - Temporary storage
3. **configMap**: ❌ No - Requires API server
4. **secret**: ❌ No - Requires API server
5. **persistentVolumeClaim**: ❌ No - Requires API server
6. **projected**: ⚠️ Partial - Only for serviceAccountToken

**Why the restrictions?**
Static pods are managed by kubelet alone, which doesn't have full access to Kubernetes resources that require API server interaction.

**Example - What works:**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: static-pod-with-volumes
spec:
  containers:
  - name: app
    image: nginx
    volumeMounts:
    - name: data
      mountPath: /data
    - name: config
      mountPath: /config
  volumes:
  - name: data
    hostPath:
      path: /var/lib/app-data
      type: DirectoryOrCreate
  - name: config
    emptyDir: {}
```

**Workarounds for ConfigMaps/Secrets:**

1. **Use hostPath with files:**
```yaml
volumes:
- name: config
  hostPath:
    path: /etc/app/config
    type: Directory
```
Then manually create config files on the node.

2. **Init container to fetch from API:**
```yaml
initContainers:
- name: fetch-config
  image: bitnami/kubectl
  command:
  - sh
  - -c
  - kubectl get configmap my-config -o jsonpath='{.data.config}' > /config/app.conf
  volumeMounts:
  - name: config
    mountPath: /config
```

3. **Embed configuration in the manifest:**
```yaml
env:
- name: CONFIG_VALUE
  value: "hardcoded-value"
```

**Best practice:**
For pods needing ConfigMaps/Secrets, use DaemonSets instead of static pods.

---

### Q11: How do static pods differ from DaemonSets?

**Answer:**

While both run on nodes, they have significant differences:

**Comparison Table:**

| Feature | Static Pods | DaemonSets |
|---------|-------------|------------|
| **Management** | Kubelet | DaemonSet controller |
| **API Server Required** | No (kubelet only) | Yes |
| **Node Selection** | Specific node only | All nodes (or node selector) |
| **New Nodes** | Must manually create | Automatically deployed |
| **Updates** | Edit manifest on each node | Rolling updates |
| **Configuration** | File-based | API object |
| **Scheduling** | No scheduler | Scheduler (with special handling) |
| **Replicas** | One per configured node | One per matching node |
| **Use Case** | Control plane components | Node agents (monitoring, logging) |
| **Volume Support** | Limited (no ConfigMaps) | Full support |
| **Deletion** | Remove file on node | Delete DaemonSet object |
| **Visibility** | Mirror pod (read-only) | Full API objects |

**When to use Static Pods:**
- Kubernetes control plane components (apiserver, scheduler, controller-manager, etcd)
- Bootstrap scenarios where API server isn't available
- Absolute critical node-level services that must survive API server failures

**When to use DaemonSets:**
- Node monitoring agents (node-exporter, cAdvisor)
- Log collectors (fluentd, filebeat)
- Storage daemons (ceph, gluster)
- Network plugins (calico, flannel)
- Any node-level service that can tolerate API server dependency

**Code Example - DaemonSet vs Static Pod:**

DaemonSet:
```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: node-exporter
spec:
  selector:
    matchLabels:
      app: node-exporter
  template:
    metadata:
      labels:
        app: node-exporter
    spec:
      containers:
      - name: node-exporter
        image: prom/node-exporter
```

Static Pod (on each node):
```yaml
# /etc/kubernetes/manifests/node-exporter.yaml
apiVersion: v1
kind: Pod
metadata:
  name: node-exporter
spec:
  containers:
  - name: node-exporter
    image: prom/node-exporter
```

**Key insight:**
Static pods are lower level and more primitive - they work without the control plane. DaemonSets are higher level and provide more features but require a functioning control plane.

---

### Q12: Explain the lifecycle of a static pod from creation to deletion.

**Answer:**

**Complete Static Pod Lifecycle:**

**Phase 1: Creation**
```
1. Admin creates manifest file
   → Write YAML to /etc/kubernetes/manifests/static-pod.yaml

2. Kubelet detects new file
   → FileWatcher triggers (checks every ~20s)
   → Kubelet reads and validates YAML

3. Kubelet creates pod
   → Pulls container image
   → Creates container via runtime (containerd/Docker)
   → Starts container
   → Sets up networking

4. Kubelet creates mirror pod
   → Creates read-only pod object in API server
   → Sets ownerReference to Node
   → Adds annotations (kubernetes.io/config.source: file)

5. Pod becomes Running
   → Container is healthy
   → Mirror pod shows status in API
```

**Phase 2: Running & Monitoring**
```
6. Kubelet monitors pod
   → Executes health probes (liveness, readiness)
   → Monitors resource usage
   → Watches for file changes

7. If container crashes
   → Kubelet detects crash
   → Restarts container according to restartPolicy
   → Updates mirror pod status
   → Continues monitoring
```

**Phase 3: Update**
```
8. Admin updates manifest
   → Edit /etc/kubernetes/manifests/static-pod.yaml
   → Change image or configuration

9. Kubelet detects change
   → File modification detected
   → Validates new manifest

10. Kubelet recreates pod
    → Stops old container
    → Deletes old container
    → Creates new container with new config
    → Updates mirror pod
```

**Phase 4: Deletion**
```
11. Admin removes manifest
    → rm /etc/kubernetes/manifests/static-pod.yaml

12. Kubelet detects removal
    → File deletion detected
    → Initiates pod termination

13. Kubelet stops pod
    → Sends SIGTERM to container
    → Waits for graceful shutdown (terminationGracePeriodSeconds)
    → Sends SIGKILL if needed
    → Removes container

14. Mirror pod removed
    → Kubelet deletes mirror pod from API server
    → Pod disappears from kubectl output
```

**Timeline:**
```
T+0s:     Manifest file created
T+20s:    Kubelet detects (next file check)
T+25s:    Image pull starts
T+30s:    Container created and started
T+31s:    Mirror pod created in API
T+35s:    Pod fully running and ready

[Time passes - pod runs normally]

T+1000s:  Manifest file deleted
T+1020s:  Kubelet detects deletion
T+1021s:  SIGTERM sent to container
T+1051s:  SIGKILL sent (if still running, 30s grace period)
T+1052s:  Container removed
T+1053s:  Mirror pod deleted
```

**Special cases:**

**If API server is down:**
- Static pod still operates normally
- Mirror pod cannot be created/updated
- Pod continues running (kubelet doesn't depend on API server)

**If kubelet crashes:**
- Container keeps running (managed by container runtime)
- When kubelet restarts, it reconciles state
- Recreates mirror pod if needed

**If node reboots:**
- All containers stop
- On boot, kubelet starts
- Kubelet reads manifests and recreates all static pods

---

## 📅 Multiple Schedulers - Fundamentals

### Q13: How does a pod specify which scheduler to use?

**Answer:**

Pods specify their scheduler using the `schedulerName` field in the pod specification.

**Syntax:**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-pod
spec:
  schedulerName: custom-scheduler  # Specifies which scheduler to use
  containers:
  - name: nginx
    image: nginx
```

**Default behavior:**
- If `schedulerName` is not specified, Kubernetes uses `default-scheduler`
- The scheduler name must exactly match a running scheduler's name

**How it works:**

1. **Pod creation:**
   ```bash
   kubectl create -f pod.yaml
   # Pod created with schedulerName: custom-scheduler
   ```

2. **Scheduler watches:**
   ```
   All schedulers watch for new pods
   Each scheduler checks: pod.spec.schedulerName == mySchedulerName
   Only matching scheduler processes the pod
   ```

3. **Scheduling:**
   ```
   custom-scheduler sees the pod
   → Filters nodes
   → Scores nodes
   → Binds pod to best node
   → Updates pod.spec.nodeName
   ```

**For Deployments/ReplicaSets:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-deployment
spec:
  replicas: 3
  template:
    spec:
      schedulerName: custom-scheduler  # All pods use this scheduler
      containers:
      - name: nginx
        image: nginx
```

**Verification:**
```bash
# Check which scheduler was used
kubectl get pod my-pod -o jsonpath='{.spec.schedulerName}'

# Check scheduling events
kubectl get events --sort-by=.metadata.creationTimestamp | grep Scheduled
```

**Important notes:**
- Scheduler name is case-sensitive
- If specified scheduler doesn't exist, pod stays Pending
- Cannot change schedulerName after pod creation (immutable)
- Each pod can only use one scheduler

---

### Q14: What happens if you specify a non-existent scheduler name?

**Answer:**

If you specify a scheduler name that doesn't exist, the pod will remain in **Pending** state indefinitely.

**Example:**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: orphan-pod
spec:
  schedulerName: non-existent-scheduler
  containers:
  - name: nginx
    image: nginx
```

**What happens:**

1. **Pod created:**
   ```bash
   kubectl create -f pod.yaml
   # pod/orphan-pod created
   ```

2. **Pod status:**
   ```bash
   kubectl get pods
   # NAME          READY   STATUS    RESTARTS   AGE
   # orphan-pod    0/1     Pending   0          5m
   ```

3. **Events:**
   ```bash
   kubectl describe pod orphan-pod
   # Events:
   #   Type     Reason            Age                From               Message
   #   ----     ------            ----               ----               -------
   #   Warning  FailedScheduling  30s (x5 over 5m)   default-scheduler  0/3 nodes are available: pod did not match any schedulers.
   ```
   
   Wait - the event actually shows nothing because no scheduler is watching for this pod!

4. **Actual behavior:**
   ```bash
   kubectl get events --sort-by=.metadata.creationTimestamp | tail
   # No scheduling events appear because no scheduler claimed the pod
   ```

**How schedulers work:**
```
For each scheduler (default-scheduler, custom-scheduler, etc.):
  1. Watch for pods where schedulerName matches my name
  2. Ignore all other pods
  
If no scheduler matches:
  → Nobody watches the pod
  → Pod stays Pending forever
  → No events are generated
```

**Fix options:**

**Option 1: Change to existing scheduler**
```bash
kubectl delete pod orphan-pod
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: orphan-pod
spec:
  schedulerName: default-scheduler  # Use existing scheduler
  containers:
  - name: nginx
    image: nginx
EOF
```

**Option 2: Deploy the missing scheduler**
```bash
# Deploy the scheduler that was specified
kubectl apply -f custom-scheduler-deployment.yaml

# Wait for scheduler to start
kubectl wait --for=condition=ready pod -l component=non-existent-scheduler -n kube-system

# Pod will be scheduled automatically once scheduler starts
```

**Option 3: Remove schedulerName (uses default)**
```bash
kubectl delete pod orphan-pod
kubectl run orphan-pod --image=nginx
# Uses default-scheduler automatically
```

**Monitoring and alerting:**
```bash
# Find pending pods
kubectl get pods --field-selector=status.phase=Pending

# Find pods with no schedulerName match
kubectl get pods -A -o json | jq '.items[] | select(.status.phase=="Pending") | {name: .metadata.name, scheduler: .spec.schedulerName}'
```

**Prevention:**
- Always verify scheduler exists before deploying pods
- Use admission webhooks to validate schedulerName
- Set up monitoring alerts for long-pending pods
- Document available schedulers in your cluster

---

### Q15: Can the default scheduler and custom scheduler run simultaneously?

**Answer:**

Yes, absolutely! Multiple schedulers can run simultaneously in a Kubernetes cluster. This is a core feature that enables workload-specific scheduling policies.

**How it works:**

**Architecture:**
```
┌─────────────────────────────────────────┐
│         API Server                      │
│  ┌──────────────────────────────────┐  │
│  │         Unscheduled Pods         │  │
│  │                                  │  │
│  │  Pod A: schedulerName: default   │  │
│  │  Pod B: schedulerName: gpu       │  │
│  │  Pod C: schedulerName: batch     │  │
│  └──────────────────────────────────┘  │
└─────────────────────────────────────────┘
           ↓           ↓           ↓
    ┌──────────┐  ┌─────────┐  ┌────────┐
    │ Default  │  │   GPU   │  │ Batch  │
    │Scheduler │  │Scheduler│  │Scheduler│
    │          │  │         │  │         │
    │ Watches  │  │ Watches │  │ Watches │
    │ Pod A    │  │ Pod B   │  │ Pod C  │
    └──────────┘  └─────────┘  └────────┘
```

**Implementation:**

1. **Default scheduler** (already running):
```bash
kubectl get pods -n kube-system | grep scheduler
# kube-scheduler-master   1/1   Running   0   10d
```

2. **Deploy custom scheduler:**
```bash
kubectl apply -f custom-scheduler-deployment.yaml
# Creates another scheduler pod
```

3. **Both running simultaneously:**
```bash
kubectl get pods -n kube-system | grep scheduler
# kube-scheduler-master        1/1   Running   0   10d
# custom-scheduler-xyz123      1/1   Running   0   5m
```

**Isolation mechanisms:**

**1. Name-based filtering:**
Each scheduler only watches pods with matching `schedulerName`:
```go
// Pseudocode for scheduler logic
for pod in unscheduledPods {
    if pod.spec.schedulerName == mySchedulerName {
        schedule(pod)
    } else {
        ignore(pod)
    }
}
```

**2. Leader election (for HA):**
If running multiple replicas of the same scheduler:
```yaml
# In scheduler configuration
leaderElection:
  leaderElect: true
  resourceName: custom-scheduler
  resourceNamespace: kube-system
```

Only one instance becomes leader and schedules pods. Others stand by.

**3. RBAC permissions:**
Each scheduler has its own ServiceAccount and permissions:
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: custom-scheduler
  namespace: kube-system
---
# ClusterRole and ClusterRoleBinding for this scheduler
```

**Example usage:**

```bash
# Create pods using different schedulers
kubectl run default-pod --image=nginx
# Uses default-scheduler (no schedulerName specified)

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: custom-pod
spec:
  schedulerName: custom-scheduler
  containers:
  - name: nginx
    image: nginx
EOF

# Check which scheduler handled each pod
kubectl get events --sort-by=.metadata.creationTimestamp | grep Scheduled
# default-pod: Scheduled by default-scheduler
# custom-pod: Scheduled by custom-scheduler
```

**Benefits:**

1. **Workload isolation**: Different policies for different workload types
2. **Gradual rollout**: Test new scheduling logic without affecting all pods
3. **Specialization**: GPU scheduler, cost-optimizer scheduler, etc.
4. **Multi-tenancy**: Different schedulers per team with different priorities

**Considerations:**

1. **Resource overhead**: Each scheduler consumes CPU/memory
2. **Complexity**: More schedulers = more complexity to manage
3. **Debugging**: Need to track which scheduler handled which pod
4. **Node contention**: Schedulers might compete for same nodes

**Best practices:**

1. **Clear naming**: Use descriptive scheduler names (gpu-scheduler, not scheduler-2)
2. **Documentation**: Document what each scheduler does
3. **Monitoring**: Track scheduler performance and decisions
4. **Start small**: Begin with default scheduler, add custom only when needed
5. **Testing**: Thoroughly test custom schedulers before production

---

## 🎯 Multiple Schedulers - Advanced

### Q16: How do you implement a custom scheduler? Describe the process.

**Answer:**

Implementing a custom scheduler involves several steps:

**Approach 1: Deploy kube-scheduler with custom configuration**

This is the easiest approach - use the existing kube-scheduler binary with custom config.

**Step 1: Create scheduler configuration**
```yaml
apiVersion: kubescheduler.config.k8s.io/v1
kind: KubeSchedulerConfiguration
leaderElection:
  leaderElect: true
  resourceName: custom-scheduler
  resourceNamespace: kube-system
profiles:
- schedulerName: custom-scheduler
  plugins:
    score:
      enabled:
      - name: NodeResourcesFit
      - name: NodeAffinity
    disabled:
    - name: "*"  # Disable other default plugins
  pluginConfig:
  - name: NodeResourcesFit
    args:
      scoringStrategy:
        type: MostAllocated  # Bin packing strategy
```

**Step 2: Create RBAC resources**
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: custom-scheduler
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: custom-scheduler
rules:
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch", "update", "patch"]
- apiGroups: [""]
  resources: ["bindings", "pods/binding"]
  verbs: ["create"]
# ... more permissions
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: custom-scheduler
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: custom-scheduler
subjects:
- kind: ServiceAccount
  name: custom-scheduler
  namespace: kube-system
```

**Step 3: Deploy scheduler**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: custom-scheduler
  namespace: kube-system
spec:
  replicas: 1
  selector:
    matchLabels:
      component: custom-scheduler
  template:
    metadata:
      labels:
        component: custom-scheduler
    spec:
      serviceAccountName: custom-scheduler
      containers:
      - name: scheduler
        image: registry.k8s.io/kube-scheduler:v1.28.0
        command:
        - kube-scheduler
        - --config=/etc/kubernetes/scheduler-config.yaml
        - --v=2
        volumeMounts:
        - name: config
          mountPath: /etc/kubernetes
      volumes:
      - name: config
        configMap:
          name: custom-scheduler-config
```

**Step 4: Use the scheduler**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
spec:
  schedulerName: custom-scheduler
  containers:
  - name: nginx
    image: nginx
```

---

**Approach 2: Write completely custom scheduler**

For advanced use cases requiring custom logic.

**Architecture:**
```
1. Watch for unscheduled pods (pods with no nodeName)
2. Filter pods where schedulerName matches
3. For each pod:
   a. Get all nodes
   b. Filter nodes (predicates)
   c. Score nodes (priorities)
   d. Select best node
   e. Bind pod to node
4. Update pod status
```

**Basic implementation (Go pseudocode):**
```go
package main

import (
    "context"
    "k8s.io/client-go/kubernetes"
    "k8s.io/client-go/rest"
)

const schedulerName = "custom-scheduler"

func main() {
    config, _ := rest.InClusterConfig()
    clientset, _ := kubernetes.NewForConfig(config)
    
    // Watch for unscheduled pods
    watcher, _ := clientset.CoreV1().Pods("").Watch(context.TODO(), metav1.ListOptions{
        FieldSelector: "spec.nodeName=",
    })
    
    for event := range watcher.ResultChan() {
        pod := event.Object.(*v1.Pod)
        
        // Only handle pods for this scheduler
        if pod.Spec.SchedulerName != schedulerName {
            continue
        }
        
        // Get all nodes
        nodes, _ := clientset.CoreV1().Nodes().List(context.TODO(), metav1.ListOptions{})
        
        // Filter nodes
        suitableNodes := filterNodes(pod, nodes)
        
        // Score nodes
        bestNode := scoreNodes(pod, suitableNodes)
        
        // Bind pod to node
        bindPodToNode(clientset, pod, bestNode)
    }
}

func filterNodes(pod *v1.Pod, nodes *v1.NodeList) []v1.Node {
    var suitable []v1.Node
    for _, node := range nodes.Items {
        // Custom filtering logic
        if nodeHasEnoughResources(pod, node) &&
           nodeTolerateTaints(pod, node) &&
           nodeMatchesAffinity(pod, node) {
            suitable = append(suitable, node)
        }
    }
    return suitable
}

func scoreNodes(pod *v1.Pod, nodes []v1.Node) v1.Node {
    bestScore := 0
    var bestNode v1.Node
    
    for _, node := range nodes {
        score := calculateScore(pod, node)  // Custom scoring logic
        if score > bestScore {
            bestScore = score
            bestNode = node
        }
    }
    return bestNode
}

func bindPodToNode(clientset *kubernetes.Clientset, pod *v1.Pod, node v1.Node) {
    binding := &v1.Binding{
        ObjectMeta: metav1.ObjectMeta{
            Name: pod.Name,
            Namespace: pod.Namespace,
        },
        Target: v1.ObjectReference{
            Kind: "Node",
            Name: node.Name,
        },
    }
    clientset.CoreV1().Pods(pod.Namespace).Bind(context.TODO(), binding, metav1.CreateOptions{})
}
```

**Deploy as container:**
```dockerfile
FROM golang:1.21 as builder
WORKDIR /app
COPY . .
RUN go build -o scheduler main.go

FROM alpine:latest
COPY --from=builder /app/scheduler /scheduler
CMD ["/scheduler"]
```

---

**Approach 3: Use Scheduler Framework (plugin-based)**

Kubernetes 1.19+ supports writing plugins without rewriting entire scheduler.

**Plugin example:**
```go
package main

import (
    framework "k8s.io/kubernetes/pkg/scheduler/framework"
)

type CustomScorePlugin struct{}

func (pl *CustomScorePlugin) Name() string {
    return "CustomScore"
}

func (pl *CustomScorePlugin) Score(ctx context.Context, state *framework.CycleState, pod *v1.Pod, nodeName string) (int64, *framework.Status) {
    // Custom scoring logic
    node := getNode(nodeName)
    score := calculateCustomScore(pod, node)
    return score, nil
}

func New(obj runtime.Object, h framework.Handle) (framework.Plugin, error) {
    return &CustomScorePlugin{}, nil
}
```

**Register plugin:**
```yaml
apiVersion: kubescheduler.config.k8s.io/v1
kind: KubeSchedulerConfiguration
profiles:
- plugins:
    score:
      enabled:
      - name: CustomScore
```

---

**Summary:**

| Approach | Complexity | Flexibility | When to Use |
|----------|------------|-------------|-------------|
| Config-based | Low | Medium | Tweaking existing logic |
| Custom scheduler | High | Full | Completely different algorithm |
| Plugin framework | Medium | High | Adding specific logic |

---

### Q17: What is the scheduler framework and how does it work?

**Answer:**

The Kubernetes **Scheduler Framework** is a pluggable architecture introduced in v1.15 (stable in v1.19) that allows you to customize scheduling behavior without rewriting the entire scheduler.

**Architecture:**

```
┌──────────────────────────────────────────────────────────────┐
│                    Scheduling Cycle                          │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  1. QueueSort         │  Sort pods in scheduling queue      │
│           ↓                                                  │
│  2. PreFilter         │  Pre-process before filtering       │
│           ↓                                                  │
│  3. Filter            │  Filter nodes (predicates)          │
│           ↓                                                  │
│  4. PostFilter        │  Run if no nodes found              │
│           ↓                                                  │
│  5. PreScore          │  Pre-process before scoring         │
│           ↓                                                  │
│  6. Score             │  Rank nodes (priorities)            │
│           ↓                                                  │
│  7. NormalizeScore    │  Normalize scores across plugins    │
│           ↓                                                  │
│  8. Reserve           │  Reserve resources on node          │
│           ↓                                                  │
│  9. Permit            │  Approve/deny/wait scheduling       │
│           ↓                                                  │
│                                                              │
├──────────────────────────────────────────────────────────────┤
│                     Binding Cycle                            │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  10. PreBind          │  Prepare for binding                │
│           ↓                                                  │
│  11. Bind             │  Bind pod to node                   │
│           ↓                                                  │
│  12. PostBind         │  Cleanup after binding              │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

**Extension Points:**

**1. QueueSort**
- **Purpose**: Determines order of pods in scheduling queue
- **Example use**: Prioritize pods based on custom criteria
```go
func (pl *PrioritySort) Less(pInfo1, pInfo2 *framework.QueuedPodInfo) bool {
    return pInfo1.Pod.Spec.Priority > pInfo2.Pod.Spec.Priority
}
```

**2. PreFilter**
- **Purpose**: Pre-process pod or cluster state
- **Example use**: Calculate pod requirements once instead of per-node
```go
func (pl *InterPodAffinity) PreFilter(ctx context.Context, state *CycleState, pod *v1.Pod) *Status {
    // Calculate affinity terms once
    state.Write("affinity-terms", calculateAffinityTerms(pod))
    return nil
}
```

**3. Filter (Predicates)**
- **Purpose**: Filter out nodes that can't run the pod
- **Example use**: Check resource availability, taints, node selectors
```go
func (pl *NodeResourcesFit) Filter(ctx context.Context, state *CycleState, pod *v1.Pod, nodeInfo *NodeInfo) *Status {
    if !nodeHasEnoughResources(nodeInfo, pod) {
        return framework.NewStatus(framework.Unschedulable, "insufficient resources")
    }
    return nil
}
```

**4. PostFilter**
- **Purpose**: Runs when no nodes pass filters (e.g., preemption)
- **Example use**: Try to make room by evicting lower-priority pods
```go
func (pl *DefaultPreemption) PostFilter(ctx context.Context, state *CycleState, pod *v1.Pod, filteredNodes NodeToStatusMap) (*PostFilterResult, *Status) {
    // Try to preempt pods to make room
    return preemptLowerPriorityPods(pod, filteredNodes)
}
```

**5. PreScore**
- **Purpose**: Pre-process before scoring
- **Example use**: Calculate data needed for scoring
```go
func (pl *TaintToleration) PreScore(ctx context.Context, state *CycleState, pod *v1.Pod, nodes []*v1.Node) *Status {
    // Cache toleration checks
    return nil
}
```

**6. Score (Priorities)**
- **Purpose**: Rank remaining nodes
- **Example use**: Prefer nodes with more free resources
```go
func (pl *NodeResourcesBalancedAllocation) Score(ctx context.Context, state *CycleState, pod *v1.Pod, nodeName string) (int64, *Status) {
    node := getNode(nodeName)
    score := calculateBalanceScore(node, pod)
    return score, nil  // Score 0-100
}
```

**7. NormalizeScore**
- **Purpose**: Normalize scores from different plugins
- **Example use**: Ensure all scores are in same range
```go
func (pl *MyPlugin) NormalizeScore(ctx context.Context, state *CycleState, pod *v1.Pod, scores NodeScoreList) *Status {
    // Normalize scores to 0-100 range
    return nil
}
```

**8. Reserve**
- **Purpose**: Maintain plugin state or reserve resources
- **Example use**: Track resource reservations
```go
func (pl *VolumeBinding) Reserve(ctx context.Context, state *CycleState, pod *v1.Pod, nodeName string) *Status {
    // Reserve volume for this pod
    return reserveVolumes(pod, nodeName)
}
```

**9. Permit**
- **Purpose**: Approve, reject, or wait before binding
- **Example use**: Wait for external approval
```go
func (pl *Coscheduling) Permit(ctx context.Context, state *CycleState, pod *v1.Pod, nodeName string) (*Status, time.Duration) {
    if allRelatedPodsReady() {
        return framework.NewStatus(framework.Success), 0
    }
    return framework.NewStatus(framework.Wait), 30*time.Second
}
```

**10. PreBind**
- **Purpose**: Prepare before binding
- **Example use**: Provision volumes
```go
func (pl *VolumeBinding) PreBind(ctx context.Context, state *CycleState, pod *v1.Pod, nodeName string) *Status {
    return provisionVolumes(pod, nodeName)
}
```

**11. Bind**
- **Purpose**: Bind pod to node
- **Example use**: Custom binding logic
```go
func (pl *DefaultBinder) Bind(ctx context.Context, state *CycleState, pod *v1.Pod, nodeName string) *Status {
    binding := &v1.Binding{
        ObjectMeta: metav1.ObjectMeta{Name: pod.Name, Namespace: pod.Namespace},
        Target: v1.ObjectReference{Kind: "Node", Name: nodeName},
    }
    return client.Bind(ctx, binding)
}
```

**12. PostBind**
- **Purpose**: Cleanup after binding
- **Example use**: Update external systems
```go
func (pl *MyPlugin) PostBind(ctx context.Context, state *CycleState, pod *v1.Pod, nodeName string) {
    // Notify external system
    notifyExternalSystem(pod, nodeName)
}
```

---

**Configuration Example:**

```yaml
apiVersion: kubescheduler.config.k8s.io/v1
kind: KubeSchedulerConfiguration
profiles:
- schedulerName: my-scheduler
  plugins:
    # Enable plugins
    filter:
      enabled:
      - name: NodeResourcesFit
      - name: NodeAffinity
      - name: MyCustomFilter
    score:
      enabled:
      - name: NodeResourcesFit
      - name: MyCustomScore
      disabled:
      - name: ImageLocality  # Disable default plugin
    
  # Plugin configuration
  pluginConfig:
  - name: NodeResourcesFit
    args:
      scoringStrategy:
        type: MostAllocated
  - name: MyCustomFilter
    args:
      customParameter: value
```

---

**Built-in Plugins:**

| Plugin | Extension Point | Purpose |
|--------|----------------|---------|
| NodeResourcesFit | Filter, Score | Check/score resource availability |
| NodeAffinity | Filter, Score | Node affinity rules |
| PodTopologySpread | Filter, Score | Spread pods across topology |
| TaintToleration | Filter, Score | Taint/toleration matching |
| InterPodAffinity | Filter, Score | Pod affinity/anti-affinity |
| VolumeBinding | Filter, Reserve, PreBind | Volume provisioning |
| DefaultPreemption | PostFilter | Preempt low-priority pods |

---

**Benefits of Scheduler Framework:**

1. **Modularity**: Change specific behavior without rewriting scheduler
2. **Performance**: Plugins can cache computation across extension points
3. **Maintainability**: Use default plugins where possible
4. **Testing**: Test plugins independently
5. **Versioning**: Plugins can be versioned separately from scheduler

**When to use:**
- Need to customize specific scheduling behavior
- Want to keep most of default scheduling logic
- Need performance optimization through caching
- Building enterprise-grade custom scheduling

---

### Q18: How do you debug scheduler decisions?

**Answer:**

Debugging scheduler decisions requires understanding events, logs, and scheduler internals.

**Method 1: Check Events**

Events are the first place to look for scheduling information.

```bash
# Get all events sorted by time
kubectl get events --sort-by=.metadata.creationTimestamp

# Filter for scheduling events
kubectl get events --sort-by=.metadata.creationTimestamp | grep -i schedul

# Get events for a specific pod
kubectl get events --field-selector involvedObject.name=my-pod

# Describe pod to see events
kubectl describe pod my-pod

# Example output:
Events:
  Type     Reason            Age   From               Message
  ----     ------            ----  ----               -------
  Warning  FailedScheduling  2m    default-scheduler  0/3 nodes are available: 1 node(s) had taint {node-role.kubernetes.io/master: }, that the pod didn't tolerate, 2 Insufficient cpu.
  Normal   Scheduled         1m    custom-scheduler   Successfully assigned default/my-pod to worker-1
```

**Method 2: Scheduler Logs**

Scheduler logs contain detailed information about decision-making process.

```bash
# For default scheduler (static pod)
kubectl logs -n kube-system kube-scheduler-master

# For custom scheduler
kubectl logs -n kube-system -l component=custom-scheduler

# Follow logs in real-time
kubectl logs -n kube-system -l component=custom-scheduler -f

# Increase verbosity (requires scheduler restart with --v=5 or higher)
# v=2: Info level
# v=4: Debug level
# v=6: Trace level
```

**Example log output:**
```
I0205 10:15:30.123456 scheduler.go:555] "Attempting to schedule pod" pod="default/my-pod"
I0205 10:15:30.234567 scheduler.go:610] "Feasible nodes found for pod" pod="default/my-pod" feasibleNodeCount=2
I0205 10:15:30.345678 scheduler.go:642] "Priorities used for pod" pod="default/my-pod" priorities=[map[Name:NodeResourcesFit Weight:1] map[Name:ImageLocality Weight:1]]
I0205 10:15:30.456789 scheduler.go:701] "Host with highest score selected" pod="default/my-pod" node="worker-1" score=85
```

**Method 3: Scheduler Metrics**

Schedulers expose Prometheus metrics.

```bash
# Port-forward to scheduler metrics endpoint
kubectl port-forward -n kube-system kube-scheduler-master 10259:10259

# Get metrics (in another terminal)
curl -k https://localhost:10259/metrics | grep scheduler

# Key metrics:
# scheduler_pending_pods: Number of pending pods
# scheduler_schedule_attempts_total: Total scheduling attempts
# scheduler_scheduling_attempt_duration_seconds: Time to schedule
# scheduler_e2e_scheduling_duration_seconds: End-to-end scheduling latency
# scheduler_binding_duration_seconds: Time to bind pod
# scheduler_framework_extension_point_duration_seconds: Plugin execution time
```

**Method 4: Enable Scheduler Debugging**

Increase scheduler verbosity for detailed debugging.

**For default scheduler (kubeadm):**
```bash
# Edit static pod manifest
ssh master
sudo vi /etc/kubernetes/manifests/kube-scheduler.yaml

# Add to command:
spec:
  containers:
  - command:
    - kube-scheduler
    - --v=5  # Increase verbosity
    
# Save and kubelet will restart scheduler
```

**For custom scheduler:**
```bash
# Update deployment
kubectl edit deployment custom-scheduler -n kube-system

# Change:
command:
- kube-scheduler
- --config=/etc/kubernetes/scheduler-config.yaml
- --v=5  # Add this line
```

**Method 5: Use kubectl-score Plugin**

Third-party tool to simulate scheduling.

```bash
# Install kubectl-score
kubectl krew install score

# Check score for a pod
kubectl score pod my-pod.yaml

# Output shows scores per node
NODE        SCORE   DETAILS
worker-1    85      NodeResourcesFit: 40, NodeAffinity: 45
worker-2    72      NodeResourcesFit: 35, NodeAffinity: 37
worker-3    60      NodeResourcesFit: 30, NodeAffinity: 30
```

**Method 6: Check Scheduler Configuration**

Verify scheduler is configured correctly.

```bash
# Check scheduler configuration
kubectl get configmap custom-scheduler-config -n kube-system -o yaml

# Verify scheduler pod is running
kubectl get pods -n kube-system -l component=custom-scheduler

# Check scheduler command line
kubectl get pod kube-scheduler-master -n kube-system -o jsonpath='{.spec.containers[0].command}'

# Check RBAC permissions
kubectl auth can-i list pods --as=system:serviceaccount:kube-system:custom-scheduler
kubectl auth can-i create bindings --as=system:serviceaccount:kube-system:custom-scheduler
```

**Method 7: Dry-run Scheduling**

Test pod scheduling without actually creating it.

```bash
# Server-side dry run
kubectl create -f pod.yaml --dry-run=server -o yaml

# This validates but doesn't actually create
# Scheduler doesn't bind, but you can see if it would fit
```

**Method 8: Analyze Node Capacity**

Understanding node resources helps debug scheduling failures.

```bash
# Get node capacity and allocatable resources
kubectl describe nodes

# View allocatable resources
kubectl get nodes -o custom-columns=NAME:.metadata.name,CAPACITY:.status.capacity,ALLOCATABLE:.status.allocatable

# Check current resource usage
kubectl top nodes

# Check resource requests/limits of all pods on a node
kubectl describe node worker-1 | grep -A10 "Allocated resources"
```

**Common Debugging Scenarios:**

**Scenario 1: Pod Pending with "Insufficient CPU"**
```bash
# Check node resources
kubectl describe nodes | grep -E "Name:|Allocated|cpu"

# Check pod requests
kubectl get pod my-pod -o jsonpath='{.spec.containers[*].resources.requests}'

# Solution: Reduce requests or add more nodes
```

**Scenario 2: Pod Pending with "No matching node"**
```bash
# Check pod node selector
kubectl get pod my-pod -o jsonpath='{.spec.nodeSelector}'

# Check node labels
kubectl get nodes --show-labels

# Solution: Add matching labels or fix node selector
```

**Scenario 3: Scheduler Not Picking Up Pod**
```bash
# Check scheduler name
kubectl get pod my-pod -o jsonpath='{.spec.schedulerName}'

# Verify scheduler is running
kubectl get pods -n kube-system | grep scheduler

# Check scheduler logs
kubectl logs -n kube-system <scheduler-pod>

# Solution: Fix scheduler name or deploy missing scheduler
```

---

**Summary: Debugging Checklist**

```bash
# 1. Check pod status
kubectl get pod <pod> -o wide

# 2. Check events
kubectl describe pod <pod> | grep -A10 Events

# 3. Check scheduler logs
kubectl logs -n kube-system <scheduler-pod>

# 4. Check node resources
kubectl describe nodes | grep -A5 "Allocated resources"

# 5. Check scheduler configuration
kubectl get configmap <scheduler-config> -n kube-system -o yaml

# 6. Check RBAC
kubectl auth can-i <verb> <resource> --as=system:serviceaccount:kube-system:<scheduler-sa>

# 7. Check metrics
kubectl top nodes
kubectl top pods

# 8. Increase verbosity if needed
# Edit scheduler manifest to add --v=5
```

---

## 🎯 Scenario-Based Questions

### Q19: You need to ensure a critical pod always runs on a specific node. How would you implement this using static pods vs. other methods?

**Answer:**

There are multiple approaches, each with trade-offs:

**Approach 1: Static Pod (Highest Guarantee)**

**Pros:**
- Survives API server failures
- Managed by kubelet, always restarted
- No controller or scheduler dependency
- Perfect for control plane components

**Cons:**
- Node-specific (won't relocate if node fails)
- Harder to update (must SSH to node)
- Limited to one instance per node

**Implementation:**
```bash
# SSH to the specific node
ssh critical-node

# Create manifest
cat > /etc/kubernetes/manifests/critical-app.yaml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: critical-app
  labels:
    app: critical
spec:
  containers:
  - name: app
    image: critical-app:latest
    resources:
      requests:
        memory: "256Mi"
        cpu: "500m"
      limits:
        memory: "512Mi"
        cpu: "1000m"
  # High priority to prevent eviction
  priorityClassName: system-cluster-critical
EOF

exit

# Verify
kubectl get pod critical-app-critical-node
```

---

**Approach 2: NodeSelector + Taints**

**Pros:**
- Can be managed via kubectl
- Can have replicas for HA
- Easier to update

**Cons:**
- Depends on scheduler and API server
- Could be evicted under resource pressure

**Implementation:**
```bash
# Label the node
kubectl label nodes critical-node dedicated=critical

# Taint the node to prevent other pods
kubectl taint nodes critical-node dedicated=critical:NoSchedule

# Create pod with nodeSelector and toleration
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: critical-app
spec:
  # Ensure pod only runs on this node
  nodeSelector:
    dedicated: critical
  
  # Tolerate the taint
  tolerations:
  - key: dedicated
    operator: Equal
    value: critical
    effect: NoSchedule
  
  # High priority
  priorityClassName: system-node-critical
  
  containers:
  - name: app
    image: critical-app:latest
    resources:
      requests:
        memory: "256Mi"
        cpu: "500m"
EOF
```

---

**Approach 3: Node Affinity (Soft Requirements)**

**Pros:**
- More flexible
- Can prefer but not require specific node

**Cons:**
- Not guaranteed to land on specific node

**Implementation:**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: critical-app
spec:
  affinity:
    nodeAffinity:
      # MUST run on node with this label
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: kubernetes.io/hostname
            operator: In
            values:
            - critical-node
      
      # PREFER nodes with high performance
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        preference:
          matchExpressions:
          - key: performance
            operator: In
            values:
            - high
  
  containers:
  - name: app
    image: critical-app:latest
```

---

**Approach 4: DaemonSet with NodeSelector**

**Pros:**
- Ensures one pod per matching node
- Automatic scheduling on new matching nodes
- Survives pod deletion

**Cons:**
- Only one pod per node
- Not suitable if you need specific node only

**Implementation:**
```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: critical-app
spec:
  selector:
    matchLabels:
      app: critical
  template:
    metadata:
      labels:
        app: critical
    spec:
      nodeSelector:
        dedicated: critical
      
      containers:
      - name: app
        image: critical-app:latest
```

---

**Comparison Matrix:**

| Method | Survives API Failure | Movable | Multiple Replicas | Ease of Update | Best For |
|--------|---------------------|---------|-------------------|----------------|----------|
| Static Pod | ✅ Yes | ❌ No | ❌ No | ⚠️ Manual | Control plane |
| NodeSelector + Taint | ❌ No | ❌ No | ✅ Yes (multiple pods) | ✅ Easy | Dedicated workloads |
| Node Affinity | ❌ No | ⚠️ Soft | ✅ Yes | ✅ Easy | Preferred placement |
| DaemonSet | ❌ No | ❌ No | ⚠️ One per node | ✅ Easy | Node agents |

---

**Recommendation by Use Case:**

**1. Control Plane Component (API Server, etcd)**
→ **Static Pod**
- Must survive API server outage
- Node-specific is acceptable
- Updates are infrequent

**2. Monitoring Agent (node-exporter, fluentd)**
→ **DaemonSet with NodeSelector**
- One per node is perfect
- Easy updates via kubectl
- Can target specific nodes

**3. Critical Application with HA**
→ **Deployment + Node Affinity + PodDisruptionBudget**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: critical-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: critical
  template:
    spec:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: zone
                operator: In
                values:
                - critical-zone
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values:
                - critical
            topologyKey: kubernetes.io/hostname
      containers:
      - name: app
        image: critical-app:latest
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: critical-app-pdb
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: critical
```

**4. Database that Must Stay on Specific Node**
→ **StatefulSet + NodeSelector + Taints**
```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: database
spec:
  serviceName: database
  replicas: 1
  selector:
    matchLabels:
      app: database
  template:
    spec:
      nodeSelector:
        database: "true"
      tolerations:
      - key: database
        operator: Equal
        value: "true"
        effect: NoSchedule
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
      accessModes: [ "ReadWriteOnce" ]
      resources:
        requests:
          storage: 100Gi
```

---

### Q20: Scenario-based troubleshooting questions

Will continue with more scenario questions in the next response due to length...

**Answer:**

**Scenario 1: Pod Stuck in Pending - No Scheduler Events**

**Problem:**
```bash
kubectl get pods
# NAME       READY   STATUS    RESTARTS   AGE
# my-pod     0/1     Pending   0          10m

kubectl describe pod my-pod
# Events: <none>
```

**Root Cause:** Scheduler name mismatch or scheduler not running

**Troubleshooting Steps:**
```bash
# 1. Check scheduler name
kubectl get pod my-pod -o jsonpath='{.spec.schedulerName}'
# Output: custom-scheduler

# 2. Check if scheduler exists
kubectl get pods -n kube-system | grep custom-scheduler
# If nothing returned, scheduler doesn't exist

# 3. Check scheduler logs (if it exists)
kubectl logs -n kube-system -l component=custom-scheduler

# 4. Solution: Deploy scheduler or fix pod
kubectl delete pod my-pod
kubectl run my-pod --image=nginx  # Uses default scheduler
```

---

**Scenario 2: Static Pod Changes Not Reflecting**

**Problem:**
```bash
# Updated static pod manifest 5 minutes ago
# Pod still shows old configuration

kubectl get pod static-nginx-node01 -o yaml | grep image:
# image: nginx:1.19  # Should be 1.25!
```

**Troubleshooting:**
```bash
# 1. Verify manifest file on node
ssh node01
cat /etc/kubernetes/manifests/static-nginx.yaml | grep image:
# image: nginx:1.25  # File is correct!

# 2. Check kubelet logs
journalctl -u kubelet -n 50 | grep -i "static\|manifest"
# No recent activity

# 3. Check kubelet file watch frequency
cat /var/lib/kubelet/config.yaml | grep fileCheckFrequency
# fileCheckFrequency: 20s

# 4. Force kubelet to detect changes
sudo systemctl restart kubelet

# 5. Verify update
exit
kubectl get pod static-nginx-node01 -o yaml | grep image:
# image: nginx:1.25  # Fixed!
```

**Root Cause:** Kubelet caching or missed file system events

---

**Scenario 3: Multiple Schedulers Fighting Over Same Pods**

**Problem:**
```bash
# Deployed 2 schedulers with same name
kubectl get pods -n kube-system | grep my-scheduler
# my-scheduler-abc123   1/1   Running
# my-scheduler-def456   1/1   Running

# Pods being scheduled inconsistently
# Sometimes go to wrong nodes
```

**Troubleshooting:**
```bash
# 1. Check scheduler names in configuration
kubectl get pod my-scheduler-abc123 -n kube-system -o yaml | grep "scheduler-name"
kubectl get pod my-scheduler-def456 -n kube-system -o yaml | grep "scheduler-name"
# Both show: --leader-elect=false  # Problem!

# 2. Check which scheduler is actually scheduling
kubectl get events --sort-by=.metadata.creationTimestamp | grep Scheduled

# 3. Enable leader election
kubectl edit deployment my-scheduler -n kube-system
# Add:
command:
- kube-scheduler
- --leader-elect=true
- --leader-elect-resource-name=my-scheduler

# 4. Verify only one is active
kubectl get lease my-scheduler -n kube-system
# Shows which pod holds the lease
```

**Root Cause:** Leader election not enabled, both schedulers active

