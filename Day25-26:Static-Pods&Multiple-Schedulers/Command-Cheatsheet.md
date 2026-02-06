# 📋 Command Cheatsheet: Static Pods & Multiple Schedulers

Quick reference guide for all essential commands related to static pods and multiple schedulers.

---

## 📦 Static Pods Commands

### Finding Static Pod Configuration

```bash
# Find static pod path in kubelet config
cat /var/lib/kubelet/config.yaml | grep staticPodPath

# Alternative: Check kubelet process
ps aux | grep kubelet | grep "pod-manifest-path"

# Check kubelet systemd service
systemctl cat kubelet | grep "pod-manifest-path"

# Common paths by distribution
# kubeadm:     /etc/kubernetes/manifests/
# minikube:    /etc/kubernetes/manifests/
# k3s:         /var/lib/rancher/k3s/server/manifests/
```

### Creating Static Pods

```bash
# Method 1: Create manifest file directly on node
ssh node01
sudo vi /etc/kubernetes/manifests/static-pod.yaml
# Paste pod YAML
# Exit - kubelet will auto-detect and create pod
exit

# Method 2: Generate manifest then copy
kubectl run static-pod --image=nginx --dry-run=client -o yaml > static-pod.yaml
scp static-pod.yaml node01:/tmp/
ssh node01
sudo mv /tmp/static-pod.yaml /etc/kubernetes/manifests/
exit

# Method 3: For kubeadm - use kubectl with node
kubectl run static-pod --image=nginx --dry-run=client -o yaml | \
  ssh node01 "sudo tee /etc/kubernetes/manifests/static-pod.yaml"
```

### Viewing Static Pods

```bash
# List all pods (static pods have node name suffix)
kubectl get pods -A | grep -E "kube-apiserver|kube-controller|kube-scheduler|etcd"

# Get specific static pod
kubectl get pod static-pod-node01

# Describe static pod
kubectl describe pod static-pod-node01

# Get static pod YAML
kubectl get pod static-pod-node01 -o yaml

# Check if pod is a static pod (look for annotations)
kubectl get pod static-pod-node01 -o jsonpath='{.metadata.annotations}'
# Look for: kubernetes.io/config.source: file

# Check owner reference (static pods owned by Node)
kubectl get pod static-pod-node01 -o jsonpath='{.metadata.ownerReferences}'
```

### Updating Static Pods

```bash
# Edit manifest on the node
ssh node01
sudo vi /etc/kubernetes/manifests/static-pod.yaml
# Make changes
# Save - kubelet auto-detects and recreates pod
exit

# Force immediate update
ssh node01
sudo vi /etc/kubernetes/manifests/static-pod.yaml
# Make changes
sudo systemctl restart kubelet
exit

# Verify update
kubectl get pod static-pod-node01 -o yaml | grep image:

# Watch pod recreation
kubectl get pods -w | grep static-pod
```

### Deleting Static Pods

```bash
# WRONG: This doesn't work (pod comes back)
kubectl delete pod static-pod-node01

# CORRECT: Remove manifest file
ssh node01
sudo rm /etc/kubernetes/manifests/static-pod.yaml
exit

# Verify deletion
kubectl get pods -A | grep static-pod

# Alternative: Move manifest (for temporary deletion)
ssh node01
sudo mv /etc/kubernetes/manifests/static-pod.yaml /tmp/
exit
# To restore:
ssh node01
sudo mv /tmp/static-pod.yaml /etc/kubernetes/manifests/
exit
```

### Troubleshooting Static Pods

```bash
# Check kubelet logs
ssh node01
journalctl -u kubelet -n 100 --no-pager
journalctl -u kubelet -f  # Follow logs
exit

# Check container runtime
ssh node01
docker ps -a | grep static-pod
# or
crictl ps -a | grep static-pod

# Check container logs directly
docker logs <container-id>
crictl logs <container-id>

# Check static pod directory
ls -la /etc/kubernetes/manifests/
cat /etc/kubernetes/manifests/static-pod.yaml

# Validate YAML syntax
kubectl create --dry-run=client -f /etc/kubernetes/manifests/static-pod.yaml

# Check file permissions
ls -la /etc/kubernetes/manifests/static-pod.yaml
# Should be readable by kubelet (usually root)
exit

# Check events
kubectl get events --sort-by=.metadata.creationTimestamp | grep static-pod

# Check pod status and events
kubectl describe pod static-pod-node01
```

### Static Pod Manifest Examples

```bash
# Generate basic static pod manifest
kubectl run static-nginx --image=nginx --dry-run=client -o yaml > static-pod.yaml

# Generate with resource limits
kubectl run static-app --image=busybox \
  --dry-run=client -o yaml \
  --requests='cpu=100m,memory=128Mi' \
  --limits='cpu=200m,memory=256Mi' \
  --command -- sleep infinity > static-pod.yaml

# Generate with port
kubectl run static-web --image=nginx --port=80 \
  --dry-run=client -o yaml > static-pod.yaml

# Generate with environment variables
kubectl run static-env --image=nginx \
  --dry-run=client -o yaml \
  --env="ENV_VAR=value" > static-pod.yaml
```

---

## 🔀 Multiple Schedulers Commands

### Checking Schedulers

```bash
# List all scheduler pods
kubectl get pods -n kube-system | grep scheduler

# Get default scheduler
kubectl get pods -n kube-system -l component=kube-scheduler

# Get custom schedulers
kubectl get pods -n kube-system -l app=custom-scheduler

# Check scheduler status
kubectl get pods -n kube-system kube-scheduler-master -o wide

# Describe scheduler pod
kubectl describe pod kube-scheduler-master -n kube-system

# Get scheduler configuration
kubectl get pod kube-scheduler-master -n kube-system -o yaml
```

### Deploying Custom Scheduler

```bash
# Create ServiceAccount
kubectl create serviceaccount custom-scheduler -n kube-system

# Create ClusterRole (from file)
kubectl apply -f custom-scheduler-rbac.yaml

# Create ConfigMap for scheduler config
kubectl create configmap custom-scheduler-config \
  --from-file=scheduler-config.yaml \
  -n kube-system

# Deploy scheduler
kubectl apply -f custom-scheduler-deployment.yaml

# Wait for scheduler to be ready
kubectl wait --for=condition=ready pod \
  -l component=custom-scheduler \
  -n kube-system --timeout=60s

# Verify deployment
kubectl get deployment custom-scheduler -n kube-system
kubectl get pods -n kube-system -l component=custom-scheduler
```

### Managing Custom Schedulers

```bash
# Scale scheduler replicas
kubectl scale deployment custom-scheduler --replicas=2 -n kube-system

# Update scheduler configuration
kubectl edit configmap custom-scheduler-config -n kube-system

# Restart scheduler to apply config changes
kubectl rollout restart deployment custom-scheduler -n kube-system

# Check rollout status
kubectl rollout status deployment custom-scheduler -n kube-system

# View scheduler logs
kubectl logs -n kube-system -l component=custom-scheduler

# Follow scheduler logs
kubectl logs -n kube-system -l component=custom-scheduler -f

# View logs from all scheduler replicas
kubectl logs -n kube-system -l component=custom-scheduler --all-containers=true

# View previous logs (if pod restarted)
kubectl logs -n kube-system -l component=custom-scheduler --previous
```

### Using Custom Schedulers

```bash
# Create pod with custom scheduler
kubectl run custom-pod --image=nginx --dry-run=client -o yaml | \
  sed '/spec:/a\  schedulerName: custom-scheduler' | \
  kubectl apply -f -

# Or using YAML
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: custom-scheduled-pod
spec:
  schedulerName: custom-scheduler
  containers:
  - name: nginx
    image: nginx
EOF

# Create deployment with custom scheduler
kubectl create deployment custom-deploy --image=nginx --dry-run=client -o yaml | \
  sed '/spec:/a\      schedulerName: custom-scheduler' | \
  kubectl apply -f -

# Check which scheduler a pod uses
kubectl get pod <pod-name> -o jsonpath='{.spec.schedulerName}'

# Check which scheduler scheduled a pod (from events)
kubectl get events --field-selector involvedObject.name=<pod-name> \
  --sort-by=.metadata.creationTimestamp | grep Scheduled
```

### Monitoring Schedulers

```bash
# Check scheduler health
kubectl get --raw /healthz --server=<scheduler-endpoint>

# Get scheduler metrics (if metrics-server installed)
kubectl top pod -n kube-system -l component=custom-scheduler

# Port-forward to scheduler metrics
kubectl port-forward -n kube-system <scheduler-pod> 10259:10259
# Then: curl -k https://localhost:10259/metrics

# Check leader election (for HA schedulers)
kubectl get lease -n kube-system | grep scheduler
kubectl describe lease custom-scheduler -n kube-system

# View scheduler configuration
kubectl get configmap custom-scheduler-config -n kube-system -o yaml

# Check scheduler RBAC
kubectl get clusterrole custom-scheduler -o yaml
kubectl get clusterrolebinding custom-scheduler -o yaml
kubectl get serviceaccount custom-scheduler -n kube-system

# Verify scheduler permissions
kubectl auth can-i list pods \
  --as=system:serviceaccount:kube-system:custom-scheduler

kubectl auth can-i create bindings \
  --as=system:serviceaccount:kube-system:custom-scheduler
```

### Debugging Scheduler Issues

```bash
# Check if pod is being scheduled
kubectl get pod <pod-name> -o wide

# View scheduling events
kubectl describe pod <pod-name> | grep -A10 Events

# Get all events sorted by time
kubectl get events --sort-by=.metadata.creationTimestamp | tail -20

# Check events for specific namespace
kubectl get events -n <namespace> --sort-by=.metadata.creationTimestamp

# Find pending pods
kubectl get pods --field-selector=status.phase=Pending -A

# Find pods using specific scheduler
kubectl get pods -A -o json | \
  jq -r '.items[] | select(.spec.schedulerName=="custom-scheduler") | .metadata.name'

# Compare schedulers
kubectl get pods -A -o custom-columns=\
NAME:.metadata.name,\
NAMESPACE:.metadata.namespace,\
SCHEDULER:.spec.schedulerName,\
NODE:.spec.nodeName,\
STATUS:.status.phase

# Check node resources
kubectl describe nodes | grep -A5 "Allocated resources"

# Check node taints
kubectl describe nodes | grep -A5 "Taints"

# Enable verbose logging on scheduler
kubectl edit deployment custom-scheduler -n kube-system
# Add: --v=5 to command args
```

### Deleting Custom Schedulers

```bash
# Delete scheduler deployment
kubectl delete deployment custom-scheduler -n kube-system

# Delete scheduler config
kubectl delete configmap custom-scheduler-config -n kube-system

# Delete RBAC resources
kubectl delete clusterrolebinding custom-scheduler
kubectl delete clusterrole custom-scheduler
kubectl delete serviceaccount custom-scheduler -n kube-system

# Delete leader election lease
kubectl delete lease custom-scheduler -n kube-system

# Verify all resources deleted
kubectl get all,cm,sa -n kube-system | grep custom-scheduler
```

---

## 🔍 Combined Troubleshooting Commands

### Pod Scheduling Issues

```bash
# Quick diagnosis
kubectl get pod <pod-name> -o wide
kubectl describe pod <pod-name>
kubectl get events --field-selector involvedObject.name=<pod-name>

# Check scheduler name
kubectl get pod <pod-name> -o jsonpath='{.spec.schedulerName}'

# Verify scheduler exists
kubectl get pods -n kube-system | grep <scheduler-name>

# Check node availability
kubectl get nodes
kubectl describe node <node-name>

# Check resource availability
kubectl top nodes
kubectl describe nodes | grep -A10 "Allocated resources"

# Check taints and tolerations
kubectl describe nodes | grep -A5 Taints
kubectl get pod <pod-name> -o jsonpath='{.spec.tolerations}'

# Check node selectors and affinity
kubectl get pod <pod-name> -o jsonpath='{.spec.nodeSelector}'
kubectl get pod <pod-name> -o jsonpath='{.spec.affinity}'
```

### Cluster-Wide Scheduler Status

```bash
# List all schedulers
kubectl get pods -n kube-system -o wide | grep scheduler

# Count pods per scheduler
kubectl get pods -A -o jsonpath='{.items[*].spec.schedulerName}' | \
  tr ' ' '\n' | sort | uniq -c

# Find pods without assigned nodes
kubectl get pods -A --field-selector spec.nodeName=

# Find pods in pending state
kubectl get pods -A --field-selector status.phase=Pending

# Recent scheduling events
kubectl get events -A --sort-by=.metadata.creationTimestamp | \
  grep -i schedul | tail -20

# Check all scheduler logs
kubectl logs -n kube-system -l tier=control-plane,component=kube-scheduler --tail=50
```

---

## 💡 Useful One-Liners

### Static Pods

```bash
# Find all static pods in cluster
kubectl get pods -A -o json | \
  jq -r '.items[] | select(.metadata.annotations."kubernetes.io/config.source" == "file") | .metadata.name'

# List static pod manifests on node
ssh node01 "sudo ls -la /etc/kubernetes/manifests/"

# Quick create static pod
kubectl run my-static-pod --image=nginx --dry-run=client -o yaml | \
  ssh node01 "sudo tee /etc/kubernetes/manifests/my-static-pod.yaml"

# Backup all static pod manifests
ssh node01 "sudo tar -czf /tmp/static-pods-backup.tar.gz /etc/kubernetes/manifests/" && \
  scp node01:/tmp/static-pods-backup.tar.gz ./

# Check which nodes have static pods
kubectl get pods -A -o wide | grep -E "\-node\d+"
```

### Schedulers

```bash
# Get scheduler names in use
kubectl get pods -A -o jsonpath='{.items[*].spec.schedulerName}' | \
  tr ' ' '\n' | sort -u

# Count pods per scheduler
kubectl get pods -A -o json | \
  jq -r '.items[].spec.schedulerName' | sort | uniq -c

# Find pods stuck in pending for >5 minutes
kubectl get pods -A --field-selector=status.phase=Pending -o json | \
  jq -r '.items[] | select((now - (.metadata.creationTimestamp | fromdateiso8601)) > 300) | .metadata.name'

# Check scheduler is scheduling pods
kubectl get events --all-namespaces --sort-by=.lastTimestamp | \
  grep -E "Scheduled.*custom-scheduler" | tail -5

# Quick scheduler health check
kubectl get pods -n kube-system -l component=kube-scheduler && \
  kubectl get pods -n kube-system -l component=custom-scheduler
```

### Debugging

```bash
# Full pod diagnosis
kubectl get pod <pod> -o yaml && \
  kubectl describe pod <pod> && \
  kubectl logs <pod> && \
  kubectl get events --field-selector involvedObject.name=<pod>

# Node capacity summary
kubectl get nodes -o custom-columns=\
NAME:.metadata.name,\
CPU-CAPACITY:.status.capacity.cpu,\
MEM-CAPACITY:.status.capacity.memory,\
CPU-ALLOC:.status.allocatable.cpu,\
MEM-ALLOC:.status.allocatable.memory

# Check if specific scheduler is working
kubectl run test-$RANDOM --image=nginx --rm -it --restart=Never \
  --overrides='{"spec":{"schedulerName":"custom-scheduler"}}' -- echo "Scheduler works!"
```

---

## 📚 Configuration File Locations

### Kubelet

```bash
# Kubelet configuration
/var/lib/kubelet/config.yaml

# Kubelet kubeconfig
/etc/kubernetes/kubelet.conf

# Kubelet systemd service
/etc/systemd/system/kubelet.service.d/10-kubeadm.conf

# Static pod manifests directory
/etc/kubernetes/manifests/  # Most distributions

# Check current config
ps aux | grep kubelet
systemctl cat kubelet
```

### Scheduler

```bash
# Default scheduler manifest (kubeadm)
/etc/kubernetes/manifests/kube-scheduler.yaml

# Scheduler configuration
# Usually in ConfigMap: kube-scheduler-config

# Custom scheduler
# Deployment: custom-scheduler (kube-system namespace)
# ConfigMap: custom-scheduler-config (kube-system namespace)
```

---

## 🎯 Quick Reference Tables

### Static Pod Commands Summary

| Task | Command |
|------|---------|
| Find path | `cat /var/lib/kubelet/config.yaml \| grep staticPodPath` |
| Create | `sudo cp pod.yaml /etc/kubernetes/manifests/` |
| Update | `sudo vi /etc/kubernetes/manifests/pod.yaml` |
| Delete | `sudo rm /etc/kubernetes/manifests/pod.yaml` |
| List | `kubectl get pods -A \| grep -E "\-node"` |
| View | `kubectl describe pod static-pod-node01` |
| Logs | `kubectl logs static-pod-node01` |
| Kubelet logs | `ssh node "journalctl -u kubelet -n 100"` |

### Scheduler Commands Summary

| Task | Command |
|------|---------|
| List schedulers | `kubectl get pods -n kube-system \| grep scheduler` |
| Deploy | `kubectl apply -f custom-scheduler.yaml` |
| Check status | `kubectl get pods -n kube-system -l component=custom-scheduler` |
| View logs | `kubectl logs -n kube-system -l component=custom-scheduler` |
| Check config | `kubectl get cm custom-scheduler-config -n kube-system -o yaml` |
| Use scheduler | `spec.schedulerName: custom-scheduler` |
| Check pod scheduler | `kubectl get pod <pod> -o jsonpath='{.spec.schedulerName}'` |
| Delete | `kubectl delete deployment custom-scheduler -n kube-system` |

---

## 🔐 RBAC Commands for Schedulers

```bash
# Create ServiceAccount
kubectl create sa custom-scheduler -n kube-system

# Create ClusterRole
kubectl create clusterrole custom-scheduler \
  --verb=get,list,watch \
  --resource=nodes,pods \
  --verb=create \
  --resource=bindings,pods/binding

# Create ClusterRoleBinding
kubectl create clusterrolebinding custom-scheduler \
  --clusterrole=custom-scheduler \
  --serviceaccount=kube-system:custom-scheduler

# Check permissions
kubectl auth can-i list pods \
  --as=system:serviceaccount:kube-system:custom-scheduler

kubectl auth can-i create bindings \
  --as=system:serviceaccount:kube-system:custom-scheduler

# View role
kubectl describe clusterrole custom-scheduler

# View binding
kubectl describe clusterrolebinding custom-scheduler
```

---

## 🚀 Pro Tips

```bash
# Auto-completion (add to ~/.bashrc)
source <(kubectl completion bash)
alias k=kubectl
complete -F __start_kubectl k

# Watch pods in real-time
watch -n 1 kubectl get pods -A

# Kubectl output formats
kubectl get pods -o wide
kubectl get pods -o yaml
kubectl get pods -o json
kubectl get pods -o jsonpath='{.items[*].metadata.name}'
kubectl get pods -o custom-columns=NAME:.metadata.name,STATUS:.status.phase

# Set default namespace
kubectl config set-context --current --namespace=kube-system

# Quick pod creation for testing
kubectl run test-$RANDOM --image=nginx --rm -it --restart=Never -- sh

# Dry-run for YAML generation
kubectl run mypod --image=nginx --dry-run=client -o yaml > pod.yaml

# Server-side dry-run (validates against cluster)
kubectl apply -f pod.yaml --dry-run=server

# Force delete stuck pod
kubectl delete pod <pod> --grace-period=0 --force
```

---

**Remember:** Practice these commands regularly for better retention! 🎓
