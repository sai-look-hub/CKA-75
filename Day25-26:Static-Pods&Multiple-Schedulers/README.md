# Day 25-26: Static Pods & Multiple Schedulers

## 📋 Overview

Welcome to Day 25-26 of your Kubernetes learning journey! Today, we'll explore **Static Pods** and **Multiple Schedulers** - advanced concepts that give you greater control over pod placement and scheduling in your cluster.

### What You'll Learn

- Understanding static pods and their use cases
- Creating and managing static pods
- Implementing custom schedulers
- Configuring multiple schedulers in a cluster
- Pod scheduling with specific schedulers
- Troubleshooting static pods and scheduler issues

### Prerequisites

- Kubernetes cluster (minikube, kind, or any K8s cluster)
- kubectl configured and working
- Basic understanding of Pods and scheduling
- Knowledge of YAML manifests
- Familiarity with kubelet

---

## 🎯 Learning Objectives

By the end of this module, you will be able to:

1. Explain what static pods are and how they differ from regular pods
2. Create and manage static pods using manifests
3. Understand the kubelet's role in static pod management
4. Deploy and configure custom schedulers
5. Schedule pods using specific schedulers
6. Troubleshoot common static pod and scheduler issues

---

## 📚 Concepts

### Static Pods

**Static Pods** are pods managed directly by the kubelet daemon on a specific node, without the API server observing them. The kubelet watches each static Pod and automatically restarts it if it crashes.

#### Key Characteristics:

- **Node-specific**: Bound to a specific node
- **No controller**: Not managed by replication controllers or deployments
- **Kubelet managed**: Created and managed by kubelet directly
- **Mirror pods**: API server creates a mirror pod for visibility
- **Automatic restart**: Kubelet ensures they're always running
- **Configuration-based**: Defined by manifest files in a specific directory

#### Use Cases:

1. **Control plane components**: kube-apiserver, kube-controller-manager, kube-scheduler, etcd
2. **Node-level services**: Monitoring agents, logging collectors
3. **Critical infrastructure**: Components that must run on specific nodes
4. **Bootstrap scenarios**: Initial cluster setup

#### How Static Pods Work:

```
┌─────────────────────────────────────────┐
│           Kubelet Node                  │
│                                         │
│  ┌──────────────────────────────────┐  │
│  │  Static Pod Manifest Directory   │  │
│  │  /etc/kubernetes/manifests/      │  │
│  │                                  │  │
│  │  - static-pod.yaml              │  │
│  └──────────────────────────────────┘  │
│              ↓                          │
│  ┌──────────────────────────────────┐  │
│  │         Kubelet                  │  │
│  │  - Watches manifest directory    │  │
│  │  - Creates pods from manifests   │  │
│  │  - Manages pod lifecycle         │  │
│  └──────────────────────────────────┘  │
│              ↓                          │
│  ┌──────────────────────────────────┐  │
│  │      Static Pod Running          │  │
│  └──────────────────────────────────┘  │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│         API Server                      │
│                                         │
│  ┌──────────────────────────────────┐  │
│  │     Mirror Pod (read-only)       │  │
│  │  - Visible via kubectl           │  │
│  │  - Cannot be deleted via API     │  │
│  └──────────────────────────────────┘  │
└─────────────────────────────────────────┘
```

### Multiple Schedulers

Kubernetes allows you to run **multiple schedulers** simultaneously and configure which scheduler is used for specific pods. This is useful when you need different scheduling policies for different workloads.

#### Default Scheduler vs Custom Scheduler:

| Feature | Default Scheduler | Custom Scheduler |
|---------|------------------|------------------|
| Name | `default-scheduler` | User-defined name |
| Deployment | Built-in | Must be deployed |
| Algorithm | Standard K8s logic | Custom logic |
| Configuration | Via KubeSchedulerConfiguration | Custom configuration |
| Use case | General workloads | Specialized requirements |

#### Custom Scheduler Use Cases:

1. **Hardware affinity**: Schedule pods on nodes with specific hardware (GPU, SSD)
2. **Cost optimization**: Schedule based on node costs or spot instances
3. **Compliance**: Schedule based on data locality or regulatory requirements
4. **Performance**: Custom algorithms for high-performance computing
5. **Multi-tenancy**: Different scheduling policies per tenant

#### How Multiple Schedulers Work:

```
┌────────────────────────────────────────────────┐
│              API Server                        │
│                                                │
│  ┌──────────────────────────────────────────┐  │
│  │           Pod Definitions                │  │
│  │                                          │  │
│  │  Pod A: schedulerName: default-scheduler │  │
│  │  Pod B: schedulerName: custom-scheduler  │  │
│  └──────────────────────────────────────────┘  │
└────────────────────────────────────────────────┘
         ↓                            ↓
┌─────────────────────┐    ┌─────────────────────┐
│  Default Scheduler  │    │  Custom Scheduler   │
│                     │    │                     │
│  - Watches Pods     │    │  - Watches Pods     │
│  - Filters nodes    │    │  - Custom filtering │
│  - Scores nodes     │    │  - Custom scoring   │
│  - Binds Pod        │    │  - Binds Pod        │
└─────────────────────┘    └─────────────────────┘
```

---

## 🛠️ Hands-On Labs

### Lab 1: Creating Static Pods

#### Method 1: Using Static Pod Path

1. **Find the static pod path on your node:**

```bash
# SSH to the node or use docker exec for kind/minikube
ssh node01

# Check kubelet configuration
ps aux | grep kubelet | grep config

# Or check the kubelet config file
cat /var/lib/kubelet/config.yaml | grep staticPodPath
```

2. **Create a static pod manifest:**

```bash
# Navigate to static pod directory (usually /etc/kubernetes/manifests/)
cd /etc/kubernetes/manifests/

# Create static pod manifest
cat > static-web.yaml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: static-web
  labels:
    role: static-pod
spec:
  containers:
  - name: web
    image: nginx:latest
    ports:
    - containerPort: 80
      protocol: TCP
EOF
```

3. **Verify the static pod:**

```bash
# Wait a few seconds, then check
kubectl get pods -A | grep static-web

# You should see: static-web-<node-name>
```

#### Method 2: Using --pod-manifest-path Flag

```bash
# Create directory for static pod manifests
mkdir -p /etc/static-pods

# Create static pod manifest
cat > /etc/static-pods/static-busybox.yaml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: static-busybox
spec:
  containers:
  - name: busybox
    image: busybox:latest
    command: ['sh', '-c', 'echo Hello Kubernetes! && sleep 3600']
EOF

# Update kubelet with pod-manifest-path (this requires kubelet restart)
# Edit /var/lib/kubelet/config.yaml
staticPodPath: /etc/static-pods

# Restart kubelet
systemctl restart kubelet
```

### Lab 2: Managing Static Pods

#### Update a Static Pod:

```bash
# Edit the static pod manifest file
vim /etc/kubernetes/manifests/static-web.yaml

# Change the image version
# image: nginx:latest → image: nginx:1.25

# Save the file - kubelet will automatically detect and restart the pod
```

#### Delete a Static Pod:

```bash
# Remove the manifest file
rm /etc/kubernetes/manifests/static-web.yaml

# The kubelet will automatically remove the pod
# Verify deletion
kubectl get pods -A | grep static-web
```

### Lab 3: Deploying a Custom Scheduler

#### Step 1: Create Custom Scheduler Deployment

Use the provided YAML file: `custom-scheduler-deployment.yaml`

```bash
kubectl apply -f custom-scheduler-deployment.yaml

# Verify custom scheduler is running
kubectl get pods -n kube-system | grep custom-scheduler
```

#### Step 2: Create a Pod Using Custom Scheduler

Use the provided YAML file: `pod-custom-scheduler.yaml`

```bash
kubectl apply -f pod-custom-scheduler.yaml

# Check which scheduler picked up the pod
kubectl get events --sort-by=.metadata.creationTimestamp | grep scheduled

# Verify pod is running
kubectl get pod custom-scheduled-pod
```

### Lab 4: Comparing Scheduler Behaviors

```bash
# Create pod with default scheduler
kubectl run default-pod --image=nginx

# Create pod with custom scheduler
kubectl apply -f pod-custom-scheduler.yaml

# Compare scheduling events
kubectl describe pod default-pod | grep -A5 Events
kubectl describe pod custom-scheduled-pod | grep -A5 Events

# Check scheduler names
kubectl get pod default-pod -o yaml | grep schedulerName
kubectl get pod custom-scheduled-pod -o yaml | grep schedulerName
```

---

## 🔍 Deep Dive Topics

### Static Pod Manifest Locations

Different Kubernetes distributions use different paths:

| Distribution | Static Pod Path |
|--------------|----------------|
| kubeadm | `/etc/kubernetes/manifests/` |
| minikube | `/etc/kubernetes/manifests/` |
| kind | `/etc/kubernetes/manifests/` |
| k3s | `/var/lib/rancher/k3s/server/manifests/` |
| MicroK8s | `/var/snap/microk8s/current/args/kubelet` |

### Kubelet Configuration for Static Pods

```yaml
# /var/lib/kubelet/config.yaml
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
staticPodPath: /etc/kubernetes/manifests/
staticPodURL: ""  # Alternatively, use URL
fileCheckFrequency: 20s  # How often to check for changes
```

### Custom Scheduler Configuration

```yaml
apiVersion: kubescheduler.config.k8s.io/v1
kind: KubeSchedulerConfiguration
profiles:
- schedulerName: custom-scheduler
  plugins:
    score:
      enabled:
      - name: NodeResourcesFit
      - name: NodeAffinity
      disabled:
      - name: "*"
  pluginConfig:
  - name: NodeResourcesFit
    args:
      scoringStrategy:
        type: MostAllocated
```

### Scheduler Plugin Framework

Modern Kubernetes schedulers use a plugin-based architecture:

1. **Queue Sort**: Determines the order of pods in the scheduling queue
2. **PreFilter**: Checks if pod can be scheduled
3. **Filter**: Filters nodes that cannot run the pod
4. **PostFilter**: Runs when no nodes are found
5. **PreScore**: Preprocessing before scoring
6. **Score**: Ranks remaining nodes
7. **Reserve**: Reserves resources on chosen node
8. **Permit**: Approves or denies the scheduling
9. **PreBind**: Preparation before binding
10. **Bind**: Binds pod to node
11. **PostBind**: Informational, after binding

---

## 💡 Best Practices

### Static Pods:

1. **Use for critical infrastructure**: Only use static pods for essential node-level services
2. **Keep manifests simple**: Avoid complex configurations in static pods
3. **Version control**: Store static pod manifests in version control
4. **Naming convention**: Use descriptive names with node identifiers
5. **Resource limits**: Always set resource requests and limits
6. **Health checks**: Include liveness and readiness probes
7. **Documentation**: Document the purpose and dependencies of each static pod

### Multiple Schedulers:

1. **Clear naming**: Use descriptive scheduler names (e.g., `gpu-scheduler`, `batch-scheduler`)
2. **Monitoring**: Monitor custom scheduler metrics and performance
3. **Fallback**: Always have the default scheduler available
4. **Testing**: Thoroughly test custom scheduling logic before production
5. **Documentation**: Document custom scheduler algorithms and use cases
6. **Version control**: Store scheduler configurations in Git
7. **High availability**: Run multiple replicas of custom schedulers with leader election

### Scheduling Policies:

1. **Start simple**: Begin with the default scheduler, add custom schedulers only when needed
2. **Understand trade-offs**: Custom schedulers add complexity
3. **Test extensively**: Verify scheduling behavior under various conditions
4. **Monitor performance**: Track scheduling latency and pod startup time
5. **Plan for scale**: Ensure schedulers can handle cluster growth

---

## 🎓 Real-World Scenarios

### Scenario 1: Control Plane Deployment

**Problem**: Deploy Kubernetes control plane components as static pods on master nodes.

**Solution**:
```yaml
# /etc/kubernetes/manifests/kube-apiserver.yaml
apiVersion: v1
kind: Pod
metadata:
  name: kube-apiserver
  namespace: kube-system
spec:
  containers:
  - name: kube-apiserver
    image: registry.k8s.io/kube-apiserver:v1.28.0
    command:
    - kube-apiserver
    - --advertise-address=192.168.1.10
    - --allow-privileged=true
    - --authorization-mode=Node,RBAC
    # ... additional flags
    volumeMounts:
    - name: ca-certs
      mountPath: /etc/ssl/certs
  volumes:
  - name: ca-certs
    hostPath:
      path: /etc/ssl/certs
```

### Scenario 2: GPU Workload Scheduler

**Problem**: Schedule machine learning workloads on nodes with GPUs efficiently.

**Solution**: Deploy a custom scheduler that prioritizes GPU availability and consolidates GPU workloads.

```yaml
# Custom scheduler with GPU awareness
apiVersion: v1
kind: Pod
metadata:
  name: ml-training-job
spec:
  schedulerName: gpu-scheduler
  containers:
  - name: training
    image: tensorflow/tensorflow:latest-gpu
    resources:
      limits:
        nvidia.com/gpu: 2
```

### Scenario 3: Multi-Tenant Cluster

**Problem**: Different teams need different scheduling policies (dev team wants speed, prod team wants reliability).

**Solution**: Deploy multiple schedulers with different configurations.

```bash
# Dev scheduler: Fast scheduling, bin packing
# Prod scheduler: Spread pods for HA, resource reservation

# Apply different schedulers per namespace
```

---

## 📊 Comparison Tables

### Static Pods vs DaemonSets vs Deployments

| Feature | Static Pods | DaemonSets | Deployments |
|---------|-------------|------------|-------------|
| Management | Kubelet | Controller | Controller |
| Node binding | Fixed to one node | One per node | Any node |
| API visibility | Mirror pod only | Full | Full |
| Rolling updates | Manual | Automatic | Automatic |
| Replicas | One per node | One per node | Configurable |
| Use case | Control plane | Node agents | Applications |
| Deletion | Remove manifest | Delete DaemonSet | Delete Deployment |
| Scheduling | No scheduler | Scheduler | Scheduler |

### Scheduler Comparison

| Scheduler Type | Complexity | Flexibility | Use Case |
|----------------|------------|-------------|----------|
| Default | Low | Medium | General workloads |
| Custom | High | High | Specialized needs |
| Third-party | Medium | High | Specific features |

---

## 🔗 Additional Resources

- [Kubernetes Documentation: Static Pods](https://kubernetes.io/docs/tasks/configure-pod-container/static-pod/)
- [Kubernetes Documentation: Multiple Schedulers](https://kubernetes.io/docs/tasks/extend-kubernetes/configure-multiple-schedulers/)
- [Scheduler Configuration Reference](https://kubernetes.io/docs/reference/scheduling/config/)
- [Kubelet Configuration](https://kubernetes.io/docs/reference/config-api/kubelet-config.v1beta1/)

---

## 📝 Summary

In this module, you learned:

- Static pods are managed by kubelet directly and are useful for critical infrastructure
- Static pods are defined by manifest files in a specific directory
- Multiple schedulers can run simultaneously in a cluster
- Custom schedulers enable specialized scheduling logic
- Pods can specify which scheduler to use via `schedulerName` field
- Both static pods and custom schedulers require careful planning and testing

Continue to the hands-on exercises and practice creating static pods and deploying custom schedulers!

---

## 🎯 Next Steps

1. Complete all hands-on labs
2. Review the troubleshooting guide
3. Practice with interview questions
4. Explore the command cheatsheet

---

**Happy Learning! 🚀**
