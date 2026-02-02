Day 19-20: Manual Scheduling & Node Selection
📋 Table of Contents

Overview
What is Node Scheduling?
Scheduling Methods
Prerequisites
Project Structure
Quick Start
Learning Objectives
Real-World Use Cases
Best Practices
Troubleshooting
Additional Resources

📖 Overview
This project demonstrates various methods of controlling pod placement in Kubernetes clusters. You'll learn how to manually schedule pods on specific nodes using nodeName, nodeSelector, and Node Affinity/Anti-Affinity rules.
🎯 What is Node Scheduling?
Node Scheduling is the process of assigning pods to specific nodes in a Kubernetes cluster based on various criteria such as:

Hardware requirements (GPU, SSD, high memory)
Geographic location (regions, availability zones)
Workload isolation (production vs development)
Cost optimization (spot instances, reserved instances)
Compliance requirements (data locality, security zones)

Default Scheduling Behavior
By default, the Kubernetes scheduler automatically assigns pods to nodes based on:

Available resources (CPU, memory)
Node health and status
Quality of Service (QoS) classes
Pod priority and preemption
Topology spread constraints

Manual Scheduling Methods

nodeName: Direct node assignment (simplest, least flexible)
nodeSelector: Label-based node selection (simple, straightforward)
Node Affinity: Advanced rule-based scheduling (most flexible)
Taints and Tolerations: Repel pods from nodes
Pod Affinity/Anti-Affinity: Schedule based on other pods

🔧 Scheduling Methods
1. nodeName (Direct Assignment)
Use Case: When you need to run a pod on a specific node
Pros:

Simple and explicit
Guaranteed placement (if node exists)
No scheduler overhead

Cons:

Node must exist and be available
No fallback mechanism
Bypasses scheduler validation
Hard to maintain

yamlapiVersion: v1
kind: Pod
metadata:
  name: nginx-nodename
spec:
  nodeName: worker-node-1  # Direct node assignment
  containers:
  - name: nginx
    image: nginx:latest
2. nodeSelector (Label-Based)
Use Case: When you need to run pods on nodes with specific characteristics
Pros:

Simple to understand and use
Based on node labels
Works with scheduler
Can target multiple nodes

Cons:

Less flexible than node affinity
Only supports equality-based matching
No fallback options

yamlapiVersion: v1
kind: Pod
metadata:
  name: gpu-pod
spec:
  nodeSelector:
    hardware: gpu
    disktype: ssd
  containers:
  - name: gpu-app
    image: tensorflow/tensorflow:latest-gpu
3. Node Affinity (Rule-Based)
Use Case: When you need complex scheduling rules with preferences and requirements
Pros:

Very flexible
Supports operators (In, NotIn, Exists, DoesNotExist, Gt, Lt)
Can specify preferences vs requirements
Multiple rules support

Cons:

More complex syntax
Can be verbose
Requires understanding of operators

Types:
a) requiredDuringSchedulingIgnoredDuringExecution: Hard requirement (MUST match)
yamlapiVersion: v1
kind: Pod
metadata:
  name: affinity-required
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: kubernetes.io/hostname
            operator: In
            values:
            - worker-node-1
            - worker-node-2
  containers:
  - name: nginx
    image: nginx:latest
b) preferredDuringSchedulingIgnoredDuringExecution: Soft preference (SHOULD match)
yamlapiVersion: v1
kind: Pod
metadata:
  name: affinity-preferred
spec:
  affinity:
    nodeAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 80
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
  - name: nginx
    image: nginx:latest
Comparison Matrix
FeaturenodeNamenodeSelectorNode AffinityComplexityLowLowHighFlexibilityNoneMediumHighOperatorsN/AEquality onlyIn, NotIn, Exists, etc.FallbackNoNoYes (with preferred)Multiple RulesNoYes (AND only)Yes (AND/OR)Weight/PriorityNoNoYesScheduler IntegrationBypassesUsesUses
📋 Prerequisites

Kubernetes cluster (v1.24+)
kubectl configured
Basic understanding of Kubernetes pods and nodes
Node labeling permissions

Verify Your Setup
bash# Check cluster access
kubectl cluster-info

# List nodes
kubectl get nodes

# Check node labels
kubectl get nodes --show-labels

# Check kubectl version
kubectl version --short
📁 Project Structure
day19-20-node-scheduling/
├── README.md
├── GUIDEME.md
├── examples/
│   ├── 01-nodename/
│   │   ├── pod-nodename.yaml
│   │   └── deployment-nodename.yaml
│   ├── 02-nodeselector/
│   │   ├── label-nodes.sh
│   │   ├── pod-nodeselector.yaml
│   │   └── deployment-nodeselector.yaml
│   ├── 03-node-affinity/
│   │   ├── pod-affinity-required.yaml
│   │   ├── pod-affinity-preferred.yaml
│   │   ├── pod-affinity-combined.yaml
│   │   └── deployment-affinity.yaml
│   ├── 04-anti-affinity/
│   │   ├── pod-anti-affinity.yaml
│   │   └── deployment-spread.yaml
│   ├── 05-real-world/
│   │   ├── gpu-workload.yaml
│   │   ├── database-ssd.yaml
│   │   ├── regional-deployment.yaml
│   │   └── multi-tier-app.yaml
│   └── 06-advanced/
│       ├── combined-constraints.yaml
│       ├── topology-spread.yaml
│       └── pod-priority.yaml
├── troubleshooting/
│   ├── debug-guide.md
│   └── common-issues.yaml
├── INTERVIEW-QA.md
├── COMMAND-CHEATSHEET.md
├── TROUBLESHOOTING.md
└── linkedin-posts.md
🚀 Quick Start
Step 1: Label Your Nodes
bash# Label nodes with environment
kubectl label node worker-node-1 environment=production
kubectl label node worker-node-2 environment=staging
kubectl label node worker-node-3 environment=development

# Label nodes with hardware capabilities
kubectl label node worker-node-1 hardware=gpu disktype=ssd
kubectl label node worker-node-2 hardware=cpu disktype=hdd
kubectl label node worker-node-3 hardware=cpu disktype=ssd

# Label nodes with regions
kubectl label node worker-node-1 region=us-west zone=us-west-1a
kubectl label node worker-node-2 region=us-west zone=us-west-1b
kubectl label node worker-node-3 region=us-east zone=us-east-1a

# Verify labels
kubectl get nodes --show-labels
Step 2: Deploy Examples
bash# Clone the repository
git clone <your-repo-url>
cd day19-20-node-scheduling

# Test nodeName scheduling
kubectl apply -f examples/01-nodename/pod-nodename.yaml
kubectl get pod nginx-nodename -o wide

# Test nodeSelector
kubectl apply -f examples/02-nodeselector/pod-nodeselector.yaml
kubectl get pod gpu-pod -o wide

# Test node affinity (required)
kubectl apply -f examples/03-node-affinity/pod-affinity-required.yaml
kubectl get pod affinity-required -o wide

# Test node affinity (preferred)
kubectl apply -f examples/03-node-affinity/pod-affinity-preferred.yaml
kubectl get pod affinity-preferred -o wide

# View pod placement
kubectl get pods -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName,STATUS:.status.phase
Step 3: Verify Node Assignment
bash# Check where pods are scheduled
kubectl get pods -o wide

# Describe pod to see scheduling decisions
kubectl describe pod <pod-name>

# Check node events
kubectl get events --sort-by='.lastTimestamp'

# View scheduler logs (if needed)
kubectl logs -n kube-system -l component=kube-scheduler
🎓 Learning Objectives
By the end of this project, you will:

✅ Understand different pod scheduling mechanisms in Kubernetes
✅ Know when to use nodeName vs nodeSelector vs Node Affinity
✅ Be able to label nodes appropriately for scheduling
✅ Implement complex scheduling rules with node affinity
✅ Use anti-affinity to spread pods across nodes
✅ Troubleshoot common scheduling issues
✅ Apply scheduling best practices in production environments
✅ Optimize resource utilization through proper scheduling

🌍 Real-World Use Cases
Use Case 1: GPU Workloads
Schedule machine learning/AI workloads on GPU nodes:
yamlapiVersion: v1
kind: Pod
metadata:
  name: ml-training
spec:
  nodeSelector:
    hardware: gpu
  containers:
  - name: tensorflow
    image: tensorflow/tensorflow:latest-gpu
    resources:
      limits:
        nvidia.com/gpu: 1
Use Case 2: Database on SSD Nodes
Run databases on nodes with SSD storage:
yamlapiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
spec:
  serviceName: postgres
  replicas: 3
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
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
      - name: postgres
        image: postgres:14
Use Case 3: Multi-Region Deployment
Deploy application across multiple regions:
yamlapiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-global
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
        nodeAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 50
            preference:
              matchExpressions:
              - key: region
                operator: In
                values:
                - us-west
          - weight: 30
            preference:
              matchExpressions:
              - key: region
                operator: In
                values:
                - us-east
          - weight: 20
            preference:
              matchExpressions:
              - key: region
                operator: In
                values:
                - eu-west
      containers:
      - name: webapp
        image: nginx:latest
Use Case 4: Environment Isolation
Separate production, staging, and development workloads:
yamlapiVersion: apps/v1
kind: Deployment
metadata:
  name: api-production
spec:
  replicas: 5
  selector:
    matchLabels:
      app: api
      env: production
  template:
    metadata:
      labels:
        app: api
        env: production
    spec:
      nodeSelector:
        environment: production
      containers:
      - name: api
        image: api:v1.0.0
Use Case 5: Cost Optimization
Use spot instances for non-critical workloads:
yamlapiVersion: batch/v1
kind: Job
metadata:
  name: batch-processing
spec:
  template:
    spec:
      affinity:
        nodeAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            preference:
              matchExpressions:
              - key: node.kubernetes.io/instance-type
                operator: In
                values:
                - spot
      containers:
      - name: processor
        image: batch-processor:latest
      restartPolicy: Never
✅ Best Practices
1. Labeling Strategy
bash# Use consistent naming conventions
kubectl label node <node> tier=frontend
kubectl label node <node> tier=backend
kubectl label node <node> tier=database

# Use hierarchical labels
kubectl label node <node> region=us-west
kubectl label node <node> zone=us-west-1a
kubectl label node <node> rack=rack-1

# Use purpose-based labels
kubectl label node <node> workload-type=compute-intensive
kubectl label node <node> workload-type=memory-intensive
kubectl label node <node> workload-type=io-intensive
2. Scheduling Rules
✅ DO:

Use nodeSelector for simple, straightforward requirements
Use node affinity for complex scheduling logic
Combine required and preferred affinity for flexibility
Test scheduling rules in staging before production
Document your labeling and scheduling strategy
Use anti-affinity to ensure high availability
Consider topology spread constraints for even distribution

❌ DON'T:

Use nodeName in production (too rigid)
Over-label nodes (keep it simple and meaningful)
Ignore resource requests/limits
Forget to update labels when hardware changes
Create circular dependencies with affinity rules
Use hard requirements when soft preferences would work

3. High Availability
yaml# Spread pods across zones for HA
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ha-webapp
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
              matchExpressions:
              - key: app
                operator: In
                values:
                - webapp
            topologyKey: topology.kubernetes.io/zone
      containers:
      - name: webapp
        image: nginx:latest
4. Resource Management
yaml# Always specify resource requests and limits
spec:
  containers:
  - name: app
    image: myapp:latest
    resources:
      requests:
        cpu: "500m"
        memory: "512Mi"
      limits:
        cpu: "1000m"
        memory: "1Gi"
  nodeSelector:
    node-size: large
5. Monitoring and Validation
bash# Check scheduling decisions
kubectl describe pod <pod-name> | grep -A 10 Events

# Monitor node resource usage
kubectl top nodes

# View pod distribution
kubectl get pods -o wide --all-namespaces | grep <node-name>

# Check unschedulable pods
kubectl get pods --field-selector=status.phase=Pending
🔧 Troubleshooting
Common Issues

Pod Stuck in Pending

Check node labels match nodeSelector
Verify node has sufficient resources
Check for node taints


Pod Scheduled to Wrong Node

Review affinity rules
Check scheduling policy priorities
Verify label syntax


No Nodes Available

Relax required affinity to preferred
Check if nodes exist with required labels
Review resource requirements



See TROUBLESHOOTING.md for detailed solutions.
📚 Additional Resources
Official Documentation

Kubernetes Scheduling
Assigning Pods to Nodes
Node Affinity
Taints and Tolerations

Tools

kube-scheduler
kubectl cheat sheet

Learning Resources

Command Cheatsheet: COMMAND-CHEATSHEET.md
Interview Questions: INTERVIEW-QA.md
Step-by-Step Guide: GUIDEME.md


🤝 Contributing
Feel free to submit issues and enhancement requests!
📝 License
This project is licensed under the MIT License.
👨‍💻 Author
Your Name

GitHub: https://github.com/sai-look-hub/CKA-75/
LinkedIn: [Your Profile](https://www.linkedin.com/in/saikumara/)


Happy Learning! 🚀
Master Kubernetes node scheduling and take control of your pod placement!
