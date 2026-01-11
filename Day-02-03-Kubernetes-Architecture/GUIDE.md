Day 2-3: Kubernetes Architecture Deep Dive 🚀
📋 Overview
Understanding the core components that make Kubernetes work - from control plane to worker nodes.
Duration: 2 Days
Status: ✅ Completed
Difficulty: Beginner to Intermediate

🎯 What You'll Learn

Kubernetes cluster architecture
Control plane components (API Server, etcd, Scheduler, Controller Manager)
Worker node components (kubelet, kube-proxy, Container Runtime)
How components communicate
etcd backup and restore (Critical for CKA!)


🏗️ Architecture Overview
┌─────────────────────────────────────────────────────────┐
│                  CONTROL PLANE (Master)                  │
│                                                           │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌─────────┐│
│  │   etcd   │  │   API    │  │Controller│  │Scheduler││
│  │          │  │  Server  │  │ Manager  │  │         ││
│  └──────────┘  └──────────┘  └──────────┘  └─────────┘│
└─────────────────────────────────────────────────────────┘
                         │
                         │ Communication
                         │
┌─────────────────────────────────────────────────────────┐
│                    WORKER NODES                          │
│                                                           │
│  ┌────────────────────────────────────────────────┐    │
│  │  Node 1                                         │    │
│  │  ┌──────────┐ ┌──────────┐ ┌────────────────┐ │    │
│  │  │ kubelet  │ │kube-proxy│ │Container Runtime│ │    │
│  │  └──────────┘ └──────────┘ └────────────────┘ │    │
│  │                                                 │    │
│  │  ┌───────────────────────────────────────┐    │    │
│  │  │         PODS (Your Applications)       │    │    │
│  │  └───────────────────────────────────────┘    │    │
│  └────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────┘

🛠️ Step 1: Setup Kubernetes Cluster
You need a cluster to practice. Choose one option below:
Option A: Minikube (Recommended for Beginners)
bash# Start a 2-node cluster
minikube start --nodes 2 --driver=docker

# Verify cluster
kubectl get nodes
kubectl cluster-info
Advantages:

Easy to use
Good for learning
Built-in dashboard

Option B: Kind (Lightweight)
bash# Create cluster config file
cat <<EOF > kind-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: worker
- role: worker
EOF

# Create cluster
kind create cluster --config kind-config.yaml --name cka-cluster

# Verify
kubectl get nodes
Advantages:

Fast startup
Multiple clusters easily
Uses Docker containers as nodes


🔍 Step 2: Explore Control Plane Components
1. View All Control Plane Pods
bashkubectl get pods -n kube-system
You should see:

etcd-*
kube-apiserver-*
kube-scheduler-*
kube-controller-manager-*

2. Explore API Server
bash# View API Server pod
kubectl get pods -n kube-system -l component=kube-apiserver

# Check API Server details
kubectl describe pod -n kube-system -l component=kube-apiserver

# View API versions
kubectl api-versions

# View available resources
kubectl api-resources | head -20
What is API Server?

Front door to Kubernetes
Handles ALL cluster operations
Only component that talks to etcd
Validates and processes requests

3. Explore etcd
bash# View etcd pod
kubectl get pods -n kube-system -l component=etcd

# Check etcd version
kubectl exec -n kube-system etcd-<TAB> -- etcdctl version

# See what etcd stores (peek inside)
kubectl exec -n kube-system etcd-<node-name> -- sh -c \
  "ETCDCTL_API=3 etcdctl get / --prefix --keys-only \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key" | head -20
What is etcd?

Database of Kubernetes
Stores all cluster data
Consistent & highly-available
Uses Raft consensus algorithm

4. Explore Scheduler
bash# View scheduler pod
kubectl get pods -n kube-system -l component=kube-scheduler

# View scheduler logs (last 20 lines)
kubectl logs -n kube-system -l component=kube-scheduler --tail=20
What is Scheduler?

Decides WHERE pods should run
Considers resources, affinity, taints
Can be bypassed with nodeName

5. Explore Controller Manager
bash# View controller manager pod
kubectl get pods -n kube-system -l component=kube-controller-manager

# View logs
kubectl logs -n kube-system -l component=kube-controller-manager --tail=20
What is Controller Manager?

Runs multiple controllers
Node controller, Replication controller, Endpoints controller
Maintains desired state


💻 Step 3: Explore Worker Node Components
1. View Nodes
bash# List all nodes with details
kubectl get nodes -o wide

# Describe a node (shows kubelet, kube-proxy info)
kubectl describe node <node-name>
2. Check kube-proxy
bash# View kube-proxy pods (one per node)
kubectl get pods -n kube-system -l k8s-app=kube-proxy

# View kube-proxy mode (iptables or ipvs)
kubectl logs -n kube-system kube-proxy-<TAB> | grep "Using"
What is kube-proxy?

Network proxy on each node
Implements Kubernetes Services
Manages network rules (iptables/IPVS)

3. Check Container Runtime
bash# View container runtime from node info
kubectl get nodes -o wide | grep CONTAINER-RUNTIME

# Or get detailed info
kubectl get nodes -o json | grep -A 5 "containerRuntimeVersion"

🎯 Step 4: Hands-On Project - Deploy and Trace
Create a Deployment
bash# Create deployment
kubectl create deployment nginx-demo \
  --image=nginx:1.25 \
  --replicas=3

# Watch pods being created
kubectl get pods -w
Trace the Complete Flow
bash# 1. Check events (shows scheduler decisions)
kubectl get events --sort-by=.metadata.creationTimestamp

# 2. See which nodes pods are on
kubectl get pods -o wide

# 3. Describe a pod (full lifecycle)
kubectl describe pod nginx-demo-<TAB>
Create a Service
bash# Expose deployment
kubectl expose deployment nginx-demo --port=80 --type=NodePort

# View service
kubectl get svc nginx-demo

# Check endpoints (populated by endpoints controller)
kubectl get endpoints nginx-demo
Test the Flow
bash# Delete one pod - watch controller recreate it!
kubectl delete pod nginx-demo-<TAB>

# Watch in real-time
kubectl get pods -w

# See the events
kubectl get events --sort-by=.metadata.creationTimestamp | tail -5
What Just Happened?

You deleted a pod
ReplicaSet controller noticed (desired 3, actual 2)
Controller created new pod
Scheduler assigned it to a node
kubelet on that node created container
Pod is running again!


🔐 Step 5: etcd Backup & Restore (CKA Critical!)
Create a Backup
bash# Find etcd pod name
ETCD_POD=$(kubectl get pods -n kube-system -l component=etcd -o jsonpath='{.items[0].metadata.name}')

# Create backup
kubectl exec -n kube-system $ETCD_POD -- sh -c \
  "ETCDCTL_API=3 etcdctl snapshot save /tmp/etcd-backup.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key"

# Copy backup to local machine
kubectl cp -n kube-system $ETCD_POD:/tmp/etcd-backup.db ./etcd-backup.db

echo "✅ Backup saved to ./etcd-backup.db"
Verify Backup
bash# Copy backup back to pod for verification
kubectl cp ./etcd-backup.db -n kube-system $ETCD_POD:/tmp/etcd-backup.db

# Check backup status
kubectl exec -n kube-system $ETCD_POD -- sh -c \
  "ETCDCTL_API=3 etcdctl snapshot status /tmp/etcd-backup.db \
  --write-out=table"
CKA Exam Command (MEMORIZE!)
bash# This is what you'll use in the exam
ETCDCTL_API=3 etcdctl snapshot save /backup/etcd-snapshot.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# Verify
ETCDCTL_API=3 etcdctl snapshot status /backup/etcd-snapshot.db
💡 Pro Tip: The exam will give you the etcd certificate paths. Just know the command structure!

📊 Component Communication Flow
User runs: kubectl create deployment nginx --replicas=3
    │
    ↓
1. kubectl sends request to API Server
    │
    ↓
2. API Server authenticates, authorizes, validates
    │
    ↓
3. API Server writes to etcd (desired state: 3 nginx pods)
    │
    ↓
4. Deployment Controller watches etcd, creates ReplicaSet
    │
    ↓
5. ReplicaSet Controller creates 3 Pod objects
    │
    ↓
6. Scheduler watches for unscheduled pods, assigns to nodes
    │
    ↓
7. kubelet on each node watches API Server, sees new pods
    │
    ↓
8. kubelet tells Container Runtime to pull image & start container
    │
    ↓
9. kubelet reports status back to API Server
    │
    ↓
10. API Server updates etcd with actual state
    │
    ↓
✅ PODS RUNNING!

🧪 Experiment: Break Things to Learn!
Experiment 1: What if Scheduler Crashes?
bash# Delete scheduler pod
kubectl delete pod -n kube-system -l component=kube-scheduler

# Try creating a pod
kubectl run test-pod --image=nginx

# Check pod status
kubectl get pods
# Result: Pod stuck in "Pending" - no scheduler to assign it!

# Wait 30 seconds - scheduler pod auto-restarts
kubectl get pods -n kube-system -l component=kube-scheduler

# Now check your test pod
kubectl get pods
# Result: Pod is now Running!

# Cleanup
kubectl delete pod test-pod
Experiment 2: Manual Scheduling (Bypass Scheduler)
bash# Create pod with nodeName (bypasses scheduler)
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: manual-scheduled-pod
spec:
  nodeName: cka-cluster-worker  # Change to your worker node name
  containers:
  - name: nginx
    image: nginx
EOF

# Check - pod scheduled immediately!
kubectl get pods -o wide

# Cleanup
kubectl delete pod manual-scheduled-pod
Experiment 3: Controller Reconciliation
bash# Create deployment
kubectl create deployment test-deployment --image=nginx --replicas=3

# Delete a pod manually
kubectl delete pod -l app=test-deployment --force --grace-period=0

# Watch controller recreate it
kubectl get pods -w
# Result: Controller maintains 3 replicas!

# Cleanup
kubectl delete deployment test-deployment

🎓 Interview Questions & Answers
Q1: What happens when you run kubectl create deployment?
Answer:

kubectl sends request to API Server
API Server authenticates, authorizes, and validates
API Server writes Deployment object to etcd
Deployment Controller detects new Deployment
Controller creates ReplicaSet
ReplicaSet Controller creates Pod objects
Scheduler assigns Pods to nodes
kubelet on nodes creates containers
Status updates flow back through API Server to etcd

Q2: Can Kubernetes work without the API Server?
Answer: No. API Server is the only component that talks to etcd. Without it:

No new pods can be scheduled
kubectl commands won't work
Controllers can't make changes
However, existing pods keep running because kubelet manages them independently

Q3: What's stored in etcd?
Answer:

Cluster configuration
All Kubernetes objects (Pods, Services, Deployments, etc.)
Secrets and ConfigMaps
Node information
Network policies
Basically, all cluster state

Q4: How does the Scheduler decide where to place a pod?
Answer:

Filtering: Removes nodes that don't meet requirements (resources, taints, node selectors)
Scoring: Ranks remaining nodes based on:

Available resources
Pod affinity/anti-affinity
Data locality
Spreading pods across nodes


Binding: Assigns pod to highest-scoring node

Q5: What's the difference between kubelet and kube-proxy?
Answer:

kubelet: Manages pod lifecycle on a node (create, monitor, report status)
kube-proxy: Manages network rules for Services (load balancing, routing)


📚 Key Takeaways
Control Plane Components:

API Server = Front door (all communication goes through it)
etcd = Database (source of truth, backup regularly!)
Scheduler = Matchmaker (assigns pods to nodes)
Controller Manager = Autopilot (maintains desired state)

Worker Node Components:

kubelet = Node agent (manages pods)
kube-proxy = Network manager (handles services)
Container Runtime = Container executor (runs containers)

Critical for CKA:

✅ Know etcd backup command by heart
✅ Understand component communication flow
✅ Can troubleshoot component failures
✅ Know how to bypass scheduler (nodeName)


🔗 Useful Commands Cheatsheet
bash# View all control plane components
kubectl get pods -n kube-system

# Check cluster info
kubectl cluster-info

# View component logs
kubectl logs -n kube-system <component-pod>

# View events (great for troubleshooting)
kubectl get events --sort-by=.metadata.creationTimestamp

# Describe node (shows kubelet, kube-proxy)
kubectl describe node <node-name>

# View API resources
kubectl api-resources

# etcd backup (CRITICAL!)
ETCDCTL_API=3 etcdctl snapshot save /backup/etcd.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

📖 Additional Resources

Official Kubernetes Architecture
etcd Documentation
Kubernetes Components
CKA Curriculum


✅ Completion Checklist

 Setup cluster (Minikube or Kind)
 Explored all control plane components
 Explored worker node components
 Deployed test application
 Traced complete request flow
 Practiced etcd backup/restore
 Ran break-and-fix experiments
 Reviewed interview questions
 Can explain architecture to someone else


🎯 Next Steps
Day 4-5: Pods Deep Dive - Understanding the smallest deployable unit in Kubernetes

Questions? Open an issue!
Found this helpful? Star the repo! ⭐
#CKA #Kubernetes #DevOps #CloudNative
