# 🔧 Troubleshooting Guide: Static Pods & Multiple Schedulers

This guide covers common issues, their symptoms, root causes, and solutions for static pods and multiple schedulers.

---

## 📋 Table of Contents

1. [Static Pod Issues](#static-pod-issues)
2. [Scheduler Issues](#scheduler-issues)
3. [General Troubleshooting Workflow](#general-troubleshooting-workflow)
4. [Debugging Tools & Commands](#debugging-tools--commands)
5. [Common Error Messages](#common-error-messages)

---

## 🔴 Static Pod Issues

### Issue 1: Static Pod Not Created

**Symptoms:**
```bash
# No mirror pod appears in API server
kubectl get pods -A | grep static-pod-name
# Returns nothing
```

**Possible Causes & Solutions:**

#### Cause 1: Wrong Manifest Directory

```bash
# Check kubelet configuration for static pod path
# On the node:
cat /var/lib/kubelet/config.yaml | grep staticPodPath

# Common paths by distribution:
# - kubeadm: /etc/kubernetes/manifests/
# - k3s: /var/lib/rancher/k3s/server/manifests/
# - microk8s: check /var/snap/microk8s/current/args/kubelet
```

**Solution:**
```bash
# Move manifest to correct directory
sudo mv static-pod.yaml /etc/kubernetes/manifests/

# Or update kubelet config
sudo vi /var/lib/kubelet/config.yaml
# Set: staticPodPath: /your/custom/path
sudo systemctl restart kubelet
```

#### Cause 2: Invalid YAML Syntax

```bash
# Check for YAML errors
yamllint /etc/kubernetes/manifests/static-pod.yaml

# Or manually validate
kubectl create --dry-run=client -f /etc/kubernetes/manifests/static-pod.yaml
```

**Solution:**
```bash
# Fix YAML syntax errors
# Common issues:
# - Incorrect indentation (use spaces, not tabs)
# - Missing quotes around special characters
# - Invalid field names
```

#### Cause 3: Kubelet Not Watching Directory

```bash
# Check kubelet logs
journalctl -u kubelet -n 100 --no-pager | grep -i "static pod"

# Check if kubelet is running
systemctl status kubelet
```

**Solution:**
```bash
# Restart kubelet to reload configuration
sudo systemctl restart kubelet

# Verify kubelet is watching the directory
journalctl -u kubelet -f | grep -i "static\|manifest"
```

#### Cause 4: File Permissions

```bash
# Check file permissions
ls -la /etc/kubernetes/manifests/
# Should be readable by kubelet user (usually root)
```

**Solution:**
```bash
# Fix permissions
sudo chmod 644 /etc/kubernetes/manifests/static-pod.yaml
sudo chown root:root /etc/kubernetes/manifests/static-pod.yaml
```

---

### Issue 2: Static Pod in CrashLoopBackOff

**Symptoms:**
```bash
kubectl get pod static-pod-<node-name>
# NAME                    READY   STATUS             RESTARTS   AGE
# static-pod-node01       0/1     CrashLoopBackOff   5          3m
```

**Diagnosis:**

```bash
# Check pod status and events
kubectl describe pod static-pod-<node-name>

# Check container logs
kubectl logs static-pod-<node-name>
kubectl logs static-pod-<node-name> --previous  # Previous container instance

# On the node, check kubelet logs
journalctl -u kubelet -n 50 | grep static-pod
```

**Common Causes & Solutions:**

#### Cause 1: Image Pull Error

```bash
# Symptoms in events:
# Failed to pull image "nonexistent:tag": rpc error: code = NotFound
```

**Solution:**
```bash
# Update to correct image
sudo vi /etc/kubernetes/manifests/static-pod.yaml
# Change: image: nginx:nonexistent → image: nginx:latest

# The pod will automatically restart
```

#### Cause 2: Command/Args Error

```bash
# Container exits immediately with error
kubectl logs static-pod-<node-name>
# Error: command not found or exits with non-zero code
```

**Solution:**
```bash
# Fix command in manifest
sudo vi /etc/kubernetes/manifests/static-pod.yaml

# Example fix:
# command: ["sleep", "infinity"]  # Correct
# command: ["slep", "infinity"]   # Wrong - typo
```

#### Cause 3: Missing Volume or ConfigMap

```bash
# Error in logs:
# Error: failed to create containerd container: error mounting volume
```

**Solution:**
```bash
# Ensure hostPath exists
sudo mkdir -p /path/to/host/directory

# Or remove volume mount if not needed
sudo vi /etc/kubernetes/manifests/static-pod.yaml
```

#### Cause 4: Resource Limits Too Low

```bash
# OOMKilled status
kubectl describe pod static-pod-<node-name>
# Last State: Terminated
# Reason: OOMKilled
```

**Solution:**
```bash
# Increase memory limits
sudo vi /etc/kubernetes/manifests/static-pod.yaml
# limits:
#   memory: "256Mi"  # Increased from 128Mi
```

---

### Issue 3: Cannot Delete Static Pod

**Symptoms:**
```bash
kubectl delete pod static-pod-<node-name>
# pod "static-pod-node01" deleted

# But it comes back immediately
kubectl get pods | grep static-pod
# static-pod-node01   1/1   Running   0   5s
```

**Explanation:**
This is expected behavior! Static pods are managed by kubelet, not the API server.

**Solution:**
```bash
# The correct way to delete a static pod:
# 1. SSH to the node
ssh node01

# 2. Remove the manifest file
sudo rm /etc/kubernetes/manifests/static-pod.yaml

# 3. Exit the node
exit

# 4. Verify deletion
kubectl get pods -A | grep static-pod
# Should return nothing
```

---

### Issue 4: Static Pod Changes Not Applied

**Symptoms:**
```bash
# You edit the manifest but pod doesn't update
sudo vi /etc/kubernetes/manifests/static-pod.yaml
# Made changes, but pod still shows old configuration
```

**Diagnosis:**
```bash
# Check file modification time
ls -l /etc/kubernetes/manifests/static-pod.yaml

# Check kubelet logs for file watch events
journalctl -u kubelet -f
```

**Possible Causes & Solutions:**

#### Cause 1: Kubelet File Check Frequency

The kubelet checks for changes every 20 seconds by default.

**Solution:**
```bash
# Wait 30-60 seconds for kubelet to detect changes
sleep 60

# Or restart kubelet for immediate update
sudo systemctl restart kubelet
```

#### Cause 2: Cached File System

```bash
# File system caching issues
```

**Solution:**
```bash
# Force file system sync
sync

# Restart kubelet
sudo systemctl restart kubelet
```

#### Cause 3: Editing Wrong File

```bash
# Verify you're editing the file in the correct directory
cat /etc/kubernetes/manifests/static-pod.yaml
# vs
cat /tmp/static-pod.yaml  # Wrong location!
```

**Solution:**
```bash
# Copy to correct location
sudo cp static-pod.yaml /etc/kubernetes/manifests/
```

---

### Issue 5: Mirror Pod Not Visible in API Server

**Symptoms:**
```bash
# Pod is running on the node but not visible via kubectl
# On node:
docker ps | grep static-pod  # Container exists

# From master:
kubectl get pods -A | grep static-pod  # Nothing
```

**Diagnosis:**
```bash
# Check if API server is reachable from the node
# On the node:
curl -k https://kubernetes.default.svc

# Check kubelet logs for API server communication
journalctl -u kubelet | grep -i "api\|server"
```

**Possible Causes & Solutions:**

#### Cause 1: Kubelet Not Registered

```bash
# Check if node is registered
kubectl get nodes
```

**Solution:**
```bash
# Restart kubelet on the node
sudo systemctl restart kubelet

# Check kubelet status
systemctl status kubelet
```

#### Cause 2: API Server Unreachable

```bash
# Network connectivity issue
```

**Solution:**
```bash
# Check kubelet configuration
cat /var/lib/kubelet/kubeconfig

# Verify network connectivity
ping <api-server-ip>

# Check firewall rules
sudo iptables -L -n | grep <api-server-port>
```

#### Cause 3: Certificate Issues

```bash
# Check kubelet logs for auth errors
journalctl -u kubelet | grep -i "certificate\|auth\|permission"
```

**Solution:**
```bash
# Regenerate kubelet certificates
# (Method varies by installation - consult your distribution docs)

# For kubeadm:
sudo kubeadm upgrade node phase kubelet-config
sudo systemctl restart kubelet
```

---

## 🔵 Scheduler Issues

### Issue 6: Custom Scheduler Not Running

**Symptoms:**
```bash
kubectl get pods -n kube-system | grep custom-scheduler
# Nothing returned, or pod is in CrashLoopBackOff
```

**Diagnosis:**

```bash
# Check deployment status
kubectl get deployment custom-scheduler -n kube-system

# Check pod status
kubectl get pods -n kube-system -l component=custom-scheduler

# Check logs
kubectl logs -n kube-system -l component=custom-scheduler
```

**Common Causes & Solutions:**

#### Cause 1: RBAC Permissions Missing

```bash
# Error in logs:
# Error: forbidden: User "system:serviceaccount:kube-system:custom-scheduler" cannot list resource "pods"
```

**Solution:**
```bash
# Verify RBAC resources exist
kubectl get clusterrole custom-scheduler
kubectl get clusterrolebinding custom-scheduler
kubectl get serviceaccount custom-scheduler -n kube-system

# If missing, reapply
kubectl apply -f custom-scheduler-deployment.yaml

# Verify permissions
kubectl auth can-i list pods --as=system:serviceaccount:kube-system:custom-scheduler
```

#### Cause 2: Invalid Configuration

```bash
# Error in logs:
# Error: failed to create scheduler: unable to decode configuration
```

**Solution:**
```bash
# Validate scheduler configuration
kubectl get configmap custom-scheduler-config -n kube-system -o yaml

# Check configuration syntax
kubectl get configmap custom-scheduler-config -n kube-system -o jsonpath='{.data.scheduler-config\.yaml}' | kubectl create --dry-run=client -f -

# Fix and update
kubectl edit configmap custom-scheduler-config -n kube-system
kubectl rollout restart deployment custom-scheduler -n kube-system
```

#### Cause 3: Image Not Available

```bash
# Error: ImagePullBackOff
kubectl describe pod <custom-scheduler-pod> -n kube-system
```

**Solution:**
```bash
# Use correct image version
kubectl edit deployment custom-scheduler -n kube-system
# Update image to available version

# Or pull image manually on nodes
docker pull registry.k8s.io/kube-scheduler:v1.28.0
```

---

### Issue 7: Pods Not Being Scheduled by Custom Scheduler

**Symptoms:**
```bash
kubectl get pods
# NAME                READY   STATUS    AGE
# custom-pod          0/1     Pending   5m

kubectl get events --sort-by=.metadata.creationTimestamp | tail
# No scheduling events for the pod
```

**Diagnosis:**

```bash
# Check pod's scheduler name
kubectl get pod custom-pod -o jsonpath='{.spec.schedulerName}'

# Check scheduler logs
kubectl logs -n kube-system -l component=custom-scheduler -f

# Check pod events
kubectl describe pod custom-pod
```

**Common Causes & Solutions:**

#### Cause 1: Scheduler Name Mismatch

```bash
# Pod specifies: schedulerName: my-scheduler
# But deployed scheduler is: custom-scheduler
```

**Solution:**
```bash
# Option 1: Update pod to match scheduler name
kubectl delete pod custom-pod
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: custom-pod
spec:
  schedulerName: custom-scheduler  # Match deployed scheduler
  containers:
  - name: nginx
    image: nginx
EOF

# Option 2: Update scheduler name in deployment
kubectl edit deployment custom-scheduler -n kube-system
# Update --scheduler-name flag
```

#### Cause 2: Scheduler Not Running

```bash
# Custom scheduler pod is not running
kubectl get pods -n kube-system | grep custom-scheduler
```

**Solution:**
```bash
# Start the scheduler
kubectl apply -f custom-scheduler-deployment.yaml

# Wait for it to be ready
kubectl wait --for=condition=ready pod -l component=custom-scheduler -n kube-system --timeout=60s
```

#### Cause 3: No Suitable Nodes

```bash
# Scheduler is running but can't find nodes that match requirements
# Check scheduler logs:
kubectl logs -n kube-system -l component=custom-scheduler | grep -i "predicate\|fit\|filter"
```

**Solution:**
```bash
# Relax pod constraints
kubectl delete pod custom-pod

# Create with fewer constraints
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
    resources:
      requests:
        memory: "64Mi"  # Reduced from 4Gi
        cpu: "100m"     # Reduced from 2
EOF
```

#### Cause 4: Leader Election Issue

```bash
# Multiple scheduler instances, leader election not working
kubectl logs -n kube-system -l component=custom-scheduler | grep -i "leader"
```

**Solution:**
```bash
# Check leader election configuration
kubectl get configmap custom-scheduler-config -n kube-system -o yaml | grep -i leader

# Verify lease
kubectl get lease custom-scheduler -n kube-system

# Restart scheduler to retry election
kubectl rollout restart deployment custom-scheduler -n kube-system
```

---

### Issue 8: Default Scheduler Scheduling Pods Intended for Custom Scheduler

**Symptoms:**
```bash
# Pod gets scheduled even though you wanted custom scheduler
kubectl get pod my-pod -o jsonpath='{.spec.schedulerName}'
# Output: default-scheduler
# Expected: custom-scheduler
```

**Root Cause:**
Forgot to specify `schedulerName` in pod spec, so default scheduler picked it up.

**Solution:**

```bash
# Always explicitly set schedulerName
kubectl delete pod my-pod

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: my-pod
spec:
  schedulerName: custom-scheduler  # Must be specified!
  containers:
  - name: nginx
    image: nginx
EOF
```

**Prevention:**
```bash
# Use a template or validation webhook to enforce schedulerName
# Or set namespace-level default via admission controller
```

---

### Issue 9: Scheduler Metrics Not Available

**Symptoms:**
```bash
# Cannot access scheduler metrics endpoint
kubectl get --raw /apis/metrics.k8s.io/v1beta1/namespaces/kube-system/pods/custom-scheduler-xxx
# Error: not found
```

**Diagnosis:**

```bash
# Check if metrics server is installed
kubectl get deployment metrics-server -n kube-system

# Check scheduler pod for metrics port
kubectl get pod -n kube-system -l component=custom-scheduler -o yaml | grep -A5 ports
```

**Solution:**

```bash
# Install metrics server if missing
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Verify scheduler exposes metrics
kubectl logs -n kube-system -l component=custom-scheduler | grep metrics

# Access metrics directly
kubectl port-forward -n kube-system deployment/custom-scheduler 10259:10259
curl -k https://localhost:10259/metrics
```

---

## 🔄 General Troubleshooting Workflow

### Step-by-Step Debugging Process

```bash
# 1. Identify the problem
kubectl get pods -A -o wide
kubectl get events --sort-by=.metadata.creationTimestamp | tail -20

# 2. Get detailed pod information
kubectl describe pod <pod-name>

# 3. Check logs
kubectl logs <pod-name>
kubectl logs <pod-name> --previous  # If pod restarted

# 4. For static pods, check on the node
ssh <node>
journalctl -u kubelet -n 100
docker ps -a | grep <pod-name>
exit

# 5. For scheduler issues, check scheduler logs
kubectl logs -n kube-system -l component=<scheduler-name>

# 6. Verify configuration files
cat /etc/kubernetes/manifests/<static-pod>.yaml
kubectl get configmap <scheduler-config> -n kube-system -o yaml

# 7. Check RBAC and permissions
kubectl auth can-i <verb> <resource> --as=<user>

# 8. Verify network connectivity
kubectl run test-pod --rm -it --image=busybox -- sh
# Inside pod: wget, curl, nslookup tests

# 9. Check resource availability
kubectl top nodes
kubectl describe node <node-name>

# 10. Review recent changes
kubectl rollout history deployment/<name>
git log (for manifest files)
```

---

## 🛠️ Debugging Tools & Commands

### Essential Commands

```bash
# Get comprehensive pod information
kubectl get pod <pod-name> -o yaml

# Watch pod status in real-time
kubectl get pods -w

# Get events for specific object
kubectl get events --field-selector involvedObject.name=<pod-name>

# Describe all objects of a type
kubectl describe pods -A | grep -A10 "^Name:"

# Execute command in container
kubectl exec -it <pod-name> -- sh

# Copy files to/from container
kubectl cp <pod-name>:/path/to/file ./local-file
kubectl cp ./local-file <pod-name>:/path/to/file

# Port forwarding for debugging
kubectl port-forward <pod-name> 8080:80

# Get resource usage
kubectl top pod <pod-name>
kubectl top node <node-name>

# Check API server version compatibility
kubectl version

# Validate YAML before applying
kubectl apply --dry-run=client -f manifest.yaml
kubectl apply --dry-run=server -f manifest.yaml  # Server-side validation
```

### Node-Level Debugging

```bash
# SSH to node
ssh <node>

# Check kubelet status
systemctl status kubelet
journalctl -u kubelet -f

# Check container runtime
docker ps  # or crictl ps
docker logs <container-id>

# Check static pod manifests
ls -la /etc/kubernetes/manifests/
cat /etc/kubernetes/manifests/<pod>.yaml

# Check kubelet config
cat /var/lib/kubelet/config.yaml
ps aux | grep kubelet

# Check node resources
free -h
df -h
top

# Check network
netstat -tlnp
iptables -L -n

# Exit node
exit
```

### Scheduler-Specific Debugging

```bash
# Check all schedulers in cluster
kubectl get pods -n kube-system | grep scheduler

# Get scheduler configuration
kubectl get configmap <scheduler-config> -n kube-system -o yaml

# Check scheduler events
kubectl get events -n kube-system --sort-by=.metadata.creationTimestamp | grep scheduler

# Verify RBAC for scheduler
kubectl get clusterrole <scheduler-name>
kubectl get clusterrolebinding <scheduler-name>

# Check leader election
kubectl get lease -n kube-system | grep scheduler
kubectl describe lease <scheduler-name> -n kube-system

# View scheduler metrics (if available)
kubectl port-forward -n kube-system <scheduler-pod> 10259:10259
curl -k https://localhost:10259/metrics
```

---

## 📝 Common Error Messages

### Static Pod Errors

| Error Message | Cause | Solution |
|---------------|-------|----------|
| `Error: failed to create containerd container` | Image doesn't exist or can't be pulled | Check image name and version |
| `Error: no matching manifest for linux/amd64` | Architecture mismatch | Use multi-arch image or specify platform |
| `Back-off restarting failed container` | Container exits immediately | Check logs for application errors |
| `Error: Error response from daemon: OCI runtime create failed` | Resource constraints or security issues | Check limits, security context |
| `MountVolume.SetUp failed` | Volume path doesn't exist | Create directory or fix path |

### Scheduler Errors

| Error Message | Cause | Solution |
|---------------|-------|----------|
| `0/3 nodes are available: 3 Insufficient cpu` | Not enough CPU on any node | Reduce resource requests or add nodes |
| `no nodes available to schedule pods` | All nodes tainted or unschedulable | Check node taints and conditions |
| `failed to fit in any node` | Pod requirements can't be met | Relax constraints or fix node labels |
| `scheduler <name> not found` | Scheduler with that name doesn't exist | Deploy scheduler or fix schedulerName |
| `error when evicting pods` | PodDisruptionBudget constraint | Adjust PDB or wait |

---

## 🎯 Quick Reference: Common Fixes

```bash
# Static Pod not appearing
sudo systemctl restart kubelet

# Static Pod won't delete
sudo rm /etc/kubernetes/manifests/<pod>.yaml

# Static Pod not updating
sudo systemctl restart kubelet

# Custom scheduler not running
kubectl apply -f custom-scheduler-deployment.yaml

# Pod not being scheduled
kubectl get pod <pod> -o jsonpath='{.spec.schedulerName}'
# Verify scheduler name matches

# Check why pod is pending
kubectl describe pod <pod> | grep -A10 Events

# Fix image pull errors
# Update image tag in manifest file

# Fix resource issues
kubectl describe nodes | grep -A5 "Allocated resources"

# Reset everything
kubectl delete -f custom-scheduler-deployment.yaml
sudo rm /etc/kubernetes/manifests/static-*
kubectl delete pods --all
```

---

## 📊 Troubleshooting Decision Tree

```
Pod Issue?
├── Static Pod?
│   ├── Not created?
│   │   ├── Check: manifest directory
│   │   ├── Check: YAML syntax
│   │   ├── Check: kubelet status
│   │   └── Check: file permissions
│   ├── CrashLoopBackOff?
│   │   ├── Check: logs
│   │   ├── Check: image
│   │   ├── Check: command/args
│   │   └── Check: resources
│   └── Won't delete?
│       └── Remove manifest file from node
└── Scheduled Pod?
    ├── Pending?
    │   ├── Check: schedulerName
    │   ├── Check: scheduler running
    │   ├── Check: node resources
    │   └── Check: taints/tolerations
    └── Scheduler issue?
        ├── Check: RBAC permissions
        ├── Check: scheduler logs
        ├── Check: configuration
        └── Check: leader election
```

---

## 💡 Pro Tips

1. **Always check logs first** - Most issues are revealed in pod or kubelet logs
2. **Use describe liberally** - `kubectl describe` shows events and detailed status
3. **Validate before deploying** - Use `--dry-run=client` to catch syntax errors
4. **Keep backups** - Save working manifests before making changes
5. **Test in isolation** - Create simple test pods to verify scheduler/kubelet functionality
6. **Monitor continuously** - Set up logging and alerting for production clusters
7. **Document custom configurations** - Especially important for custom schedulers
8. **Version control** - Keep all manifest files in Git

---

**Remember: Most issues are configuration errors. Always double-check your YAML! 🔍**
