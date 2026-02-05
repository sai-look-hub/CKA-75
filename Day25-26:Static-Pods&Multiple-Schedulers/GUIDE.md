# 📖 GUIDEME: Static Pods & Multiple Schedulers - Step-by-Step Guide

## 🎯 Learning Path

This guide will walk you through a structured learning path for Day 25-26. Follow each section in order for the best learning experience.

---

## ⏱️ Time Allocation (8 hours total)

- **Hour 1-2**: Theory and Concepts
- **Hour 3-4**: Static Pods Hands-on
- **Hour 5-6**: Multiple Schedulers Hands-on
- **Hour 7**: Troubleshooting and Practice
- **Hour 8**: Interview Prep and Review

---

## 📚 Section 1: Understanding Static Pods (2 hours)

### Step 1: Read the Theory (30 minutes)

Start by reading the **Concepts** section in README.md:
- What are static pods?
- How do they differ from regular pods?
- When to use static pods?

### Step 2: Explore Your Cluster (30 minutes)

```bash
# 1. Check if you have any static pods running
kubectl get pods -A -o wide | grep -E "kube-apiserver|kube-controller|kube-scheduler|etcd"

# 2. Find the kubelet configuration
# For minikube
minikube ssh
ps aux | grep kubelet
cat /var/lib/kubelet/config.yaml | grep staticPodPath
exit

# For kind
docker exec kind-control-plane cat /var/lib/kubelet/config.yaml | grep staticPodPath

# 3. List static pod manifests
# For minikube
minikube ssh
sudo ls -la /etc/kubernetes/manifests/
sudo cat /etc/kubernetes/manifests/kube-apiserver.yaml
exit
```

**✅ Checkpoint**: Can you identify the static pod path on your cluster?

### Step 3: Understand Kubelet's Role (30 minutes)

```bash
# 1. Check kubelet service status
# On the node
systemctl status kubelet

# 2. View kubelet logs
journalctl -u kubelet -n 50

# 3. Understand how kubelet watches for changes
# The kubelet checks the static pod directory every 20 seconds (default)
```

**Key Questions to Answer**:
- How does kubelet discover static pods?
- What happens when you modify a static pod manifest?
- What's the difference between a static pod and its mirror pod?

### Step 4: Examine Mirror Pods (30 minutes)

```bash
# 1. Get a static pod
kubectl get pods -n kube-system -o wide | grep apiserver

# 2. Try to delete it (spoiler: you can't directly)
kubectl delete pod kube-apiserver-<node-name> -n kube-system
# Watch it come back!

# 3. Describe the pod
kubectl describe pod kube-apiserver-<node-name> -n kube-system

# 4. Check the owner reference
kubectl get pod kube-apiserver-<node-name> -n kube-system -o yaml | grep -A5 ownerReferences
```

**✅ Checkpoint**: You should see that mirror pods have `kind: Node` as their owner.

---

## 🔨 Section 2: Creating Static Pods (2 hours)

### Lab 1: Create Your First Static Pod (45 minutes)

#### Step 1: Prepare the Environment

```bash
# For minikube
minikube ssh

# For kind (choose your control plane node)
docker exec -it kind-control-plane bash

# Navigate to static pod directory
cd /etc/kubernetes/manifests/
```

#### Step 2: Create a Simple Static Pod

```bash
# Create static-nginx.yaml
cat > static-nginx.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: static-nginx
  labels:
    app: static-web
    type: static-pod
spec:
  containers:
  - name: nginx
    image: nginx:1.25
    ports:
    - containerPort: 80
    resources:
      requests:
        memory: "64Mi"
        cpu: "250m"
      limits:
        memory: "128Mi"
        cpu: "500m"
EOF
```

#### Step 3: Verify Creation

```bash
# Exit the node
exit

# Wait 30 seconds, then check
kubectl get pods -A | grep static-nginx

# Expected output:
# default  static-nginx-<node-name>  1/1  Running  0  30s

# Describe the pod
kubectl describe pod static-nginx-<node-name>
```

**✅ Checkpoint**: Static pod should be running with the node name appended.

#### Step 4: Understand the Mirror Pod

```bash
# Get full pod details
kubectl get pod static-nginx-<node-name> -o yaml > mirror-pod.yaml

# Look at important fields
cat mirror-pod.yaml | grep -A10 metadata
cat mirror-pod.yaml | grep -A5 ownerReferences
cat mirror-pod.yaml | grep annotations -A10
```

**Key Observations**:
- `kubernetes.io/config.source: file`
- `kubernetes.io/config.mirror: <node-annotation>`
- `ownerReferences` points to the Node

### Lab 2: Manage Static Pod Lifecycle (45 minutes)

#### Update the Static Pod

```bash
# Access the node again
minikube ssh
# or
docker exec -it kind-control-plane bash

cd /etc/kubernetes/manifests/

# Update the image version
sed -i 's/nginx:1.25/nginx:1.26/g' static-nginx.yaml

# Exit and wait
exit

# Watch the pod restart
kubectl get pods -w | grep static-nginx

# Verify the new image
kubectl describe pod static-nginx-<node-name> | grep Image:
```

**✅ Checkpoint**: Pod should automatically restart with new image.

#### Add Resource Changes

```bash
# Access node
minikube ssh

cd /etc/kubernetes/manifests/

# Edit the pod to add environment variables
cat >> static-nginx.yaml <<'EOF'
    env:
    - name: DEMO_ENV
      value: "static-pod-demo"
EOF

exit

# Verify the change
kubectl exec static-nginx-<node-name> -- env | grep DEMO_ENV
```

#### Delete the Static Pod

```bash
# Try deleting via kubectl (won't work permanently)
kubectl delete pod static-nginx-<node-name>
# Watch it come back!

# The right way: remove the manifest
minikube ssh
sudo rm /etc/kubernetes/manifests/static-nginx.yaml
exit

# Verify deletion
kubectl get pods -A | grep static-nginx
# Should return nothing
```

**✅ Checkpoint**: Pod should be gone after removing the manifest file.

### Lab 3: Advanced Static Pod (30 minutes)

Create a static pod with more features:

```bash
# Access node
minikube ssh

cd /etc/kubernetes/manifests/

# Create advanced static pod
cat > static-redis.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: static-redis
  labels:
    app: redis
    type: static-pod
spec:
  containers:
  - name: redis
    image: redis:7-alpine
    ports:
    - containerPort: 6379
      name: redis
    volumeMounts:
    - name: redis-data
      mountPath: /data
    - name: config
      mountPath: /usr/local/etc/redis
    livenessProbe:
      tcpSocket:
        port: 6379
      initialDelaySeconds: 30
      periodSeconds: 10
    readinessProbe:
      exec:
        command:
        - redis-cli
        - ping
      initialDelaySeconds: 5
      periodSeconds: 5
    resources:
      requests:
        memory: "128Mi"
        cpu: "250m"
      limits:
        memory: "256Mi"
        cpu: "500m"
  volumes:
  - name: redis-data
    hostPath:
      path: /var/lib/redis-data
      type: DirectoryOrCreate
  - name: config
    emptyDir: {}
EOF

exit

# Verify
kubectl get pod static-redis-<node-name>
kubectl describe pod static-redis-<node-name>
```

**✅ Checkpoint**: Redis static pod with probes and volumes should be running.

---

## 🔀 Section 3: Multiple Schedulers (2 hours)

### Step 1: Understand Scheduler Basics (30 minutes)

```bash
# 1. Check default scheduler
kubectl get pods -n kube-system | grep scheduler

# 2. View default scheduler configuration
kubectl get pod kube-scheduler-<node> -n kube-system -o yaml

# 3. Create a test pod and watch scheduling
kubectl run test-pod --image=nginx
kubectl get events --sort-by=.metadata.creationTimestamp | tail -10

# 4. Check which scheduler scheduled it
kubectl get pod test-pod -o jsonpath='{.spec.schedulerName}'
# Should output: default-scheduler

# Cleanup
kubectl delete pod test-pod
```

**Key Concepts**:
- Default scheduler name is `default-scheduler`
- Scheduler binding is recorded in events
- `schedulerName` field determines which scheduler is used

### Step 2: Deploy Custom Scheduler (45 minutes)

#### Create Custom Scheduler Configuration

```bash
# Apply the custom scheduler deployment
kubectl apply -f custom-scheduler-deployment.yaml

# Wait for it to be ready
kubectl get pods -n kube-system | grep custom-scheduler
kubectl wait --for=condition=ready pod -l component=custom-scheduler -n kube-system --timeout=60s

# Check logs
kubectl logs -n kube-system -l component=custom-scheduler
```

**Expected Output**: Scheduler should start and begin watching for pods.

#### Verify Multiple Schedulers

```bash
# List all scheduler pods
kubectl get pods -n kube-system | grep scheduler

# You should see:
# - kube-scheduler-<node> (default)
# - custom-scheduler-<hash> (custom)

# Check both are running
kubectl get pods -n kube-system -l component=kube-scheduler
kubectl get pods -n kube-system -l component=custom-scheduler
```

**✅ Checkpoint**: Both schedulers should be running.

### Step 3: Schedule Pods with Custom Scheduler (45 minutes)

#### Test 1: Default Scheduler

```bash
# Create pod without specifying scheduler
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: default-scheduled-pod
spec:
  containers:
  - name: nginx
    image: nginx
EOF

# Check which scheduler was used
kubectl get pod default-scheduled-pod -o yaml | grep schedulerName
# Output: schedulerName: default-scheduler

# Check events
kubectl get events --field-selector involvedObject.name=default-scheduled-pod --sort-by=.metadata.creationTimestamp
```

#### Test 2: Custom Scheduler

```bash
# Apply pod with custom scheduler
kubectl apply -f pod-custom-scheduler.yaml

# Check which scheduler was used
kubectl get pod custom-scheduled-pod -o yaml | grep schedulerName
# Output: schedulerName: custom-scheduler

# Check events
kubectl get events --field-selector involvedObject.name=custom-scheduled-pod --sort-by=.metadata.creationTimestamp
```

#### Test 3: Compare Scheduling

```bash
# Create multiple pods with different schedulers
for i in {1..3}; do
  kubectl run default-pod-$i --image=nginx
done

for i in {1..3}; do
  cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: custom-pod-$i
spec:
  schedulerName: custom-scheduler
  containers:
  - name: nginx
    image: nginx
EOF
done

# Compare scheduling times
kubectl get events --sort-by=.metadata.creationTimestamp | grep -E "default-pod|custom-pod" | grep Scheduled

# Cleanup
kubectl delete pods default-pod-{1..3} custom-pod-{1..3}
```

**✅ Checkpoint**: You should see different schedulers handling different pods.

---

## 🔧 Section 4: Troubleshooting Practice (1 hour)

### Exercise 1: Static Pod Not Starting

```bash
# Create a broken static pod
minikube ssh

cat > /etc/kubernetes/manifests/broken-pod.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: broken-pod
spec:
  containers:
  - name: nginx
    image: nginx:nonexistent-tag
    ports:
    - containerPort: 80
EOF

exit

# Troubleshoot
kubectl get pods -A | grep broken-pod
kubectl describe pod broken-pod-<node-name>
kubectl get events --sort-by=.metadata.creationTimestamp | tail -20

# Fix it
minikube ssh
sed -i 's/nginx:nonexistent-tag/nginx:latest/g' /etc/kubernetes/manifests/broken-pod.yaml
exit

# Verify fix
kubectl get pod broken-pod-<node-name>

# Cleanup
minikube ssh
rm /etc/kubernetes/manifests/broken-pod.yaml
exit
```

### Exercise 2: Scheduler Not Picking Up Pods

```bash
# Create pod with non-existent scheduler
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: orphan-pod
spec:
  schedulerName: non-existent-scheduler
  containers:
  - name: nginx
    image: nginx
EOF

# Check status
kubectl get pod orphan-pod
# Should be in Pending state

# Check events
kubectl describe pod orphan-pod

# Fix by changing scheduler
kubectl delete pod orphan-pod
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: orphan-pod
spec:
  schedulerName: default-scheduler
  containers:
  - name: nginx
    image: nginx
EOF

# Verify
kubectl get pod orphan-pod
```

### Exercise 3: Custom Scheduler Issues

```bash
# Check if custom scheduler is running
kubectl get pods -n kube-system | grep custom-scheduler

# If not running, check logs
kubectl logs -n kube-system -l component=custom-scheduler --previous

# Check for RBAC issues
kubectl get clusterrolebinding | grep scheduler

# Redeploy if needed
kubectl delete -f custom-scheduler-deployment.yaml
kubectl apply -f custom-scheduler-deployment.yaml
```

**✅ Checkpoint**: You should be comfortable troubleshooting common issues.

---

## 📝 Section 5: Practice Scenarios (1 hour)

### Scenario 1: Deploy Monitoring Agent as Static Pod

**Task**: Deploy a node-exporter as a static pod for Prometheus monitoring.

```bash
minikube ssh

cat > /etc/kubernetes/manifests/node-exporter.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: node-exporter
  namespace: kube-system
  labels:
    app: node-exporter
spec:
  hostNetwork: true
  hostPID: true
  containers:
  - name: node-exporter
    image: prom/node-exporter:latest
    ports:
    - containerPort: 9100
      hostPort: 9100
    volumeMounts:
    - name: proc
      mountPath: /host/proc
      readOnly: true
    - name: sys
      mountPath: /host/sys
      readOnly: true
  volumes:
  - name: proc
    hostPath:
      path: /proc
  - name: sys
    hostPath:
      path: /sys
EOF

exit

kubectl get pods -n kube-system | grep node-exporter
```

### Scenario 2: High-Priority Custom Scheduler

**Task**: Create a scheduler for high-priority workloads that prefers nodes with more available memory.

```bash
# Use the custom scheduler but mark pods as high priority
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: high-priority-app
spec:
  schedulerName: custom-scheduler
  priorityClassName: system-node-critical
  containers:
  - name: app
    image: nginx
    resources:
      requests:
        memory: "1Gi"
        cpu: "500m"
EOF
```

### Scenario 3: Multi-Scheduler Environment

**Task**: Create an environment where different namespaces use different schedulers by default.

```bash
# Create namespaces
kubectl create namespace team-a
kubectl create namespace team-b

# Team A uses default scheduler (batch workloads)
kubectl run batch-job -n team-a --image=busybox -- sleep 3600

# Team B uses custom scheduler (real-time workloads)
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: realtime-app
  namespace: team-b
spec:
  schedulerName: custom-scheduler
  containers:
  - name: app
    image: nginx
EOF

# Verify
kubectl get pods -A -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,SCHEDULER:.spec.schedulerName
```

**✅ Checkpoint**: You should understand how to use static pods and schedulers in real scenarios.

---

## 🎓 Section 6: Interview Preparation (1 hour)

### Step 1: Review Key Concepts (20 minutes)

Read through:
- `INTERVIEW-QNA.md` - All questions and answers
- Focus on "why" and "how" questions
- Understand trade-offs and use cases

### Step 2: Practice Explaining (20 minutes)

Practice explaining these concepts out loud:
1. What are static pods and when would you use them?
2. How does the kubelet manage static pods?
3. Why would you need multiple schedulers?
4. How do you troubleshoot a pod that's not being scheduled?

### Step 3: Hands-On Quiz (20 minutes)

Answer these without looking at documentation:

```bash
# Q1: Create a static pod running Redis
# Q2: Deploy a custom scheduler
# Q3: Schedule a pod with your custom scheduler
# Q4: Update a static pod's image version
# Q5: Delete a static pod
```

Check your answers against the documentation and labs.

---

## ✅ Final Checklist

Before moving to the next module, ensure you can:

- [ ] Explain what static pods are and their use cases
- [ ] Create static pods using manifest files
- [ ] Find and modify static pod configuration paths
- [ ] Understand the difference between static pods and mirror pods
- [ ] Update and delete static pods correctly
- [ ] Deploy a custom scheduler
- [ ] Configure pods to use specific schedulers
- [ ] Troubleshoot static pod and scheduler issues
- [ ] Compare default and custom scheduler behaviors
- [ ] Apply best practices for both static pods and schedulers

---

## 🎯 Next Steps

1. Complete the troubleshooting exercises in `TROUBLESHOOTING.md`
2. Review all YAML files and understand each field
3. Practice the commands in `COMMAND-CHEATSHEET.md`
4. Attempt the interview questions without looking at answers
5. Clean up your practice resources:

```bash
# Clean up static pods
minikube ssh
sudo rm /etc/kubernetes/manifests/static-*
sudo rm /etc/kubernetes/manifests/node-exporter.yaml
exit

# Clean up custom scheduler
kubectl delete -f custom-scheduler-deployment.yaml
kubectl delete pods --all -n team-a
kubectl delete pods --all -n team-b
kubectl delete namespace team-a team-b

# Clean up any test pods
kubectl delete pods --all
```

---

## 📚 Additional Practice

If you want more practice:

1. **Advanced Static Pods**: Create static pods with init containers, sidecars, and complex volume mounts
2. **Scheduler Extenders**: Research and implement webhook-based scheduler extenders
3. **Real Cluster**: Practice on a multi-node cluster (not just minikube)
4. **Production Scenarios**: Study how major Kubernetes components use static pods
5. **Performance Testing**: Compare scheduling performance between default and custom schedulers

---
