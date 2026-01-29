# DaemonSets & StatefulSets - Commands Cheatsheet

## 📋 Quick Reference Guide

---

## DaemonSet Commands

### Create DaemonSets

```bash
# Create DaemonSet from YAML
kubectl apply -f daemonset.yaml

# Create DaemonSet imperatively (not recommended)
kubectl create deployment my-ds --image=nginx --dry-run=client -o yaml > daemonset.yaml
# Then modify kind to DaemonSet

# Create with specific namespace
kubectl apply -f daemonset.yaml -n monitoring
```

### View DaemonSets

```bash
# List all DaemonSets
kubectl get daemonsets
kubectl get ds

# List DaemonSets in all namespaces
kubectl get daemonsets --all-namespaces
kubectl get ds -A

# Detailed view
kubectl describe daemonset <daemonset-name>
kubectl describe ds <name>

# Get YAML definition
kubectl get daemonset <name> -o yaml

# Get JSON definition
kubectl get daemonset <name> -o json

# Custom columns
kubectl get daemonsets -o custom-columns=\
NAME:.metadata.name,\
DESIRED:.status.desiredNumberScheduled,\
CURRENT:.status.currentNumberScheduled,\
READY:.status.numberReady
```

### Update DaemonSets

```bash
# Update image
kubectl set image daemonset/<name> container-name=new-image:tag

# Edit DaemonSet
kubectl edit daemonset <name>

# Apply changes from file
kubectl apply -f daemonset.yaml

# Patch DaemonSet
kubectl patch daemonset <name> -p '{"spec":{"template":{"spec":{"containers":[{"name":"nginx","image":"nginx:1.22"}]}}}}'

# Update with annotation (force rollout)
kubectl annotate daemonset <name> kubernetes.io/change-cause="Updated to version 2.0"
```

### Manage DaemonSet Rollouts

```bash
# Check rollout status
kubectl rollout status daemonset/<name>

# View rollout history
kubectl rollout history daemonset/<name>

# Rollback to previous version
kubectl rollout undo daemonset/<name>

# Rollback to specific revision
kubectl rollout undo daemonset/<name> --to-revision=2

# Pause rollout
kubectl rollout pause daemonset/<name>

# Resume rollout
kubectl rollout resume daemonset/<name>

# Restart DaemonSet
kubectl rollout restart daemonset/<name>
```

### DaemonSet Pods

```bash
# List pods from DaemonSet
kubectl get pods -l app=<label>

# List pods with node information
kubectl get pods -l app=<label> -o wide

# Get pods on specific node
kubectl get pods --all-namespaces -o wide --field-selector spec.nodeName=<node-name>

# Count pods per node
kubectl get pods -l app=<label> -o wide | awk '{print $7}' | sort | uniq -c
```

### Delete DaemonSets

```bash
# Delete DaemonSet
kubectl delete daemonset <name>

# Delete from file
kubectl delete -f daemonset.yaml

# Delete with grace period
kubectl delete daemonset <name> --grace-period=30

# Force delete
kubectl delete daemonset <name> --force --grace-period=0
```

---

## StatefulSet Commands

### Create StatefulSets

```bash
# Create from YAML
kubectl apply -f statefulset.yaml

# Create headless service first
kubectl apply -f headless-service.yaml

# Create with namespace
kubectl apply -f statefulset.yaml -n database
```

### View StatefulSets

```bash
# List StatefulSets
kubectl get statefulsets
kubectl get sts

# List in all namespaces
kubectl get statefulsets --all-namespaces
kubectl get sts -A

# Detailed view
kubectl describe statefulset <name>
kubectl describe sts <name>

# Get YAML
kubectl get statefulset <name> -o yaml

# Custom columns
kubectl get statefulsets -o custom-columns=\
NAME:.metadata.name,\
REPLICAS:.spec.replicas,\
READY:.status.readyReplicas,\
AGE:.metadata.creationTimestamp
```

### Scale StatefulSets

```bash
# Scale up
kubectl scale statefulset <name> --replicas=5

# Scale down
kubectl scale statefulset <name> --replicas=2

# Scale with namespace
kubectl scale statefulset <name> --replicas=3 -n database

# Check scaling status
kubectl get statefulset <name> -w
```

### Update StatefulSets

```bash
# Update image
kubectl set image statefulset/<name> container-name=new-image:tag

# Edit StatefulSet
kubectl edit statefulset <name>

# Apply changes
kubectl apply -f statefulset.yaml

# Patch StatefulSet
kubectl patch statefulset <name> -p '{"spec":{"replicas":5}}'

# Update with partition (canary deployment)
kubectl patch statefulset <name> -p '{"spec":{"updateStrategy":{"rollingUpdate":{"partition":3}}}}'
```

### Manage StatefulSet Rollouts

```bash
# Check rollout status
kubectl rollout status statefulset/<name>

# View rollout history
kubectl rollout history statefulset/<name>

# Rollback
kubectl rollout undo statefulset/<name>

# Restart StatefulSet
kubectl rollout restart statefulset/<name>
```

### StatefulSet Pods

```bash
# List pods
kubectl get pods -l app=<label>

# List with ordinal index
kubectl get pods -l app=<label> --sort-by=.metadata.name

# Get specific pod
kubectl get pod <statefulset-name>-0
kubectl get pod <statefulset-name>-1

# Exec into pod
kubectl exec -it <statefulset-name>-0 -- bash

# Get logs from specific pod
kubectl logs <statefulset-name>-0

# Follow logs
kubectl logs -f <statefulset-name>-0

# Get previous pod logs
kubectl logs <statefulset-name>-0 --previous
```

### Persistent Volume Claims

```bash
# List PVCs for StatefulSet
kubectl get pvc -l app=<label>

# Describe PVC
kubectl describe pvc <pvc-name>

# Check PVC status
kubectl get pvc -o wide

# List PVs bound to PVCs
kubectl get pv

# Delete PVC (careful!)
kubectl delete pvc <pvc-name>

# Get PVC with custom columns
kubectl get pvc -o custom-columns=\
NAME:.metadata.name,\
STATUS:.status.phase,\
VOLUME:.spec.volumeName,\
CAPACITY:.status.capacity.storage,\
STORAGECLASS:.spec.storageClassName
```

### Headless Services

```bash
# Create headless service
kubectl apply -f headless-service.yaml

# List services
kubectl get svc

# Describe service
kubectl describe svc <service-name>

# Test DNS from pod
kubectl exec <pod-name> -- nslookup <service-name>

# Test individual pod DNS
kubectl exec <pod-name> -- nslookup <pod-name>.<service-name>.<namespace>.svc.cluster.local
```

### Delete StatefulSets

```bash
# Delete StatefulSet (keeps PVCs)
kubectl delete statefulset <name>

# Delete with cascade=false (keeps pods running)
kubectl delete statefulset <name> --cascade=orphan

# Delete StatefulSet and PVCs
kubectl delete statefulset <name>
kubectl delete pvc -l app=<label>

# Force delete
kubectl delete statefulset <name> --force --grace-period=0
```

---

## Storage Commands

### StorageClass

```bash
# List storage classes
kubectl get storageclass
kubectl get sc

# Describe storage class
kubectl describe storageclass <name>

# Set default storage class
kubectl patch storageclass <name> -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

# Create storage class
kubectl apply -f storageclass.yaml
```

### PersistentVolumes

```bash
# List PVs
kubectl get pv

# Describe PV
kubectl describe pv <name>

# Get PV with details
kubectl get pv -o wide

# Delete PV
kubectl delete pv <name>
```

### PersistentVolumeClaims

```bash
# List PVCs
kubectl get pvc

# List in namespace
kubectl get pvc -n <namespace>

# Describe PVC
kubectl describe pvc <name>

# Check binding status
kubectl get pvc -o jsonpath='{.items[*].status.phase}'

# Delete PVC
kubectl delete pvc <name>

# Expand PVC (if storage class allows)
kubectl patch pvc <name> -p '{"spec":{"resources":{"requests":{"storage":"20Gi"}}}}'
```

---

## Node Selection & Scheduling

### Node Selectors

```bash
# Label node
kubectl label nodes <node-name> disktype=ssd

# View node labels
kubectl get nodes --show-labels

# Remove label
kubectl label nodes <node-name> disktype-

# Get nodes with specific label
kubectl get nodes -l disktype=ssd
```

### Taints and Tolerations

```bash
# Add taint to node
kubectl taint nodes <node-name> key=value:NoSchedule

# Remove taint
kubectl taint nodes <node-name> key=value:NoSchedule-

# List node taints
kubectl describe node <node-name> | grep Taints
```

### Affinity Rules

```bash
# Get node with affinity info
kubectl get nodes -o json | jq '.items[] | {name: .metadata.name, labels: .metadata.labels}'
```

---

## Monitoring & Debugging

### Resource Usage

```bash
# Top pods
kubectl top pods

# Top nodes
kubectl top nodes

# Top pods in namespace
kubectl top pods -n <namespace>

# Top pods with labels
kubectl top pods -l app=<label>
```

### Logs

```bash
# Get logs
kubectl logs <pod-name>

# Follow logs
kubectl logs -f <pod-name>

# Logs from previous container
kubectl logs <pod-name> --previous

# Logs from specific container
kubectl logs <pod-name> -c <container-name>

# Logs from all pods with label
kubectl logs -l app=<label> --all-containers=true
```

### Events

```bash
# Get events
kubectl get events

# Sort by timestamp
kubectl get events --sort-by='.lastTimestamp'

# Watch events
kubectl get events -w

# Events for specific resource
kubectl describe <resource-type> <n> | grep -A 10 Events
```

---

## Complete Workflow Examples

### Deploy DaemonSet Monitoring Stack

```bash
# 1. Create namespace
kubectl create namespace monitoring

# 2. Deploy Node Exporter
kubectl apply -f node-exporter-daemonset.yaml

# 3. Verify deployment
kubectl get daemonsets -n monitoring
kubectl get pods -n monitoring -o wide

# 4. Check logs
kubectl logs -n monitoring -l app=node-exporter --tail=50

# 5. Test metrics endpoint
kubectl exec -n monitoring <pod-name> -- curl localhost:9100/metrics
```

### Deploy StatefulSet Database

```bash
# 1. Create namespace
kubectl create namespace database

# 2. Create storage class
kubectl apply -f storageclass.yaml

# 3. Create secrets
kubectl create secret generic db-secret \
  --from-literal=username=admin \
  --from-literal=password=secret \
  -n database

# 4. Create headless service
kubectl apply -f headless-service.yaml

# 5. Deploy StatefulSet
kubectl apply -f statefulset.yaml

# 6. Wait for pods
kubectl wait --for=condition=ready pod -l app=mongodb -n database --timeout=300s

# 7. Verify
kubectl get statefulset,pods,pvc -n database

# 8. Initialize database (if needed)
kubectl exec -it mongodb-0 -n database -- mongo
```

---

## Troubleshooting Commands

### DaemonSet Issues

```bash
# Check if pods on all nodes
kubectl get pods -o wide -l app=<label> | awk '{print $7}' | sort | uniq -c

# Check node taints preventing scheduling
kubectl describe nodes | grep -A 5 Taints

# Check DaemonSet events
kubectl describe daemonset <n> | grep -A 10 Events

# Check pod failures
kubectl get pods -l app=<label> | grep -v Running
```

### StatefulSet Issues

```bash
# Check pod order
kubectl get pods -l app=<label> --sort-by=.metadata.creationTimestamp

# Check PVC binding
kubectl get pvc -l app=<label> -o wide

# Check storage provisioner
kubectl get storageclass

# Describe failed pod
kubectl describe pod <pod-name>

# Check for pending PVCs
kubectl get pvc --field-selector=status.phase=Pending
```

---

## Quick Tips

### One-Liners

```bash
# Count DaemonSet pods per node
kubectl get pods -l app=node-exporter -o json | jq -r '.items[] | .spec.nodeName' | sort | uniq -c

# Get all StatefulSet pod names
kubectl get pods -l app=mongodb -o name

# Check StatefulSet scale
kubectl get sts -o custom-columns=NAME:.metadata.name,REPLICAS:.spec.replicas,READY:.status.readyReplicas

# Find unbound PVCs
kubectl get pvc --all-namespaces -o json | jq -r '.items[] | select(.status.phase=="Pending") | "\(.metadata.namespace)/\(.metadata.name)"'

# Get pod age
kubectl get pods -o custom-columns=NAME:.metadata.name,AGE:.metadata.creationTimestamp
```

---

## Aliases (Add to ~/.bashrc or ~/.zshrc)

```bash
alias k='kubectl'
alias kgd='kubectl get daemonsets'
alias kgs='kubectl get statefulsets'
alias kgp='kubectl get pods'
alias kgpvc='kubectl get pvc'
alias kdesc='kubectl describe'
alias klogs='kubectl logs'
alias kexec='kubectl exec -it'
alias kget='kubectl get -o wide'
```

---

**Pro Tip**: Use `-o yaml` or `-o json` with `kubectl get` to see complete resource definitions, then use tools like `jq` or `yq` to filter specific fields.

**Quick Reference**: Save this cheatsheet and use `grep` to quickly find commands:
```bash
grep -i "scale" cheatsheet.md
grep -i "logs" cheatsheet.md
```
