# 🔧 Troubleshooting Guide: Kubernetes Volumes

Common issues and solutions for Kubernetes volumes.

---

## 📋 Quick Diagnosis Commands

```bash
# Check pod volumes
kubectl describe pod <pod-name>

# Check volume mounts in container
kubectl exec <pod-name> -- df -h

# Check files in volume
kubectl exec <pod-name> -- ls -la /path/to/mount

# Check pod events
kubectl get events --field-selector involvedObject.name=<pod-name>

# Check logs for volume errors
kubectl logs <pod-name>
```

---

## 🔴 Issue 1: Pod Stuck in ContainerCreating

**Symptoms:**
```bash
kubectl get pods
# NAME        READY   STATUS              AGE
# my-pod      0/1     ContainerCreating   5m
```

**Common Causes:**

**Cause 1: hostPath directory doesn't exist**
```bash
kubectl describe pod my-pod
# MountVolume.SetUp failed: hostPath type check failed
```

**Solution:**
```bash
# Create directory on node
minikube ssh "sudo mkdir -p /mnt/data"
# or for kind
docker exec kind-control-plane mkdir -p /mnt/data

# Or change hostPath type to DirectoryOrCreate
volumes:
- name: host-data
  hostPath:
    path: /mnt/data
    type: DirectoryOrCreate  # Creates if missing
```

**Cause 2: ConfigMap doesn't exist**
```bash
kubectl describe pod my-pod
# configmap "app-config" not found
```

**Solution:**
```bash
# Create the ConfigMap
kubectl create configmap app-config --from-literal=key=value

# Or check spelling
kubectl get configmaps
```

**Cause 3: Secret doesn't exist**
```bash
# Error: secret "app-secrets" not found
```

**Solution:**
```bash
kubectl create secret generic app-secrets --from-literal=password=secret
```

---

## 💾 Issue 2: Volume is Empty or Missing Files

**Symptoms:**
```bash
kubectl exec pod -- ls /config
# Empty directory or missing expected files
```

**Diagnosis:**
```bash
# Check if volume is mounted
kubectl exec pod -- mount | grep /config

# Check volume definition
kubectl get pod pod -o yaml | grep -A20 volumes

# Check if ConfigMap/Secret has data
kubectl get configmap app-config -o yaml
```

**Solutions:**

**For ConfigMap volumes:**
```bash
# Verify ConfigMap has data
kubectl describe configmap app-config

# Check specific key
kubectl get configmap app-config -o jsonpath='{.data.app\.conf}'

# Recreate if empty
kubectl delete configmap app-config
kubectl create configmap app-config --from-file=app.conf
```

**For emptyDir:**
```bash
# emptyDir starts empty - this is normal
# Check if pod wrote to it
kubectl logs pod-name

# Check if init container should have populated it
kubectl describe pod pod-name | grep -A20 "Init Containers"
```

---

## 📝 Issue 3: Permission Denied Writing to Volume

**Symptoms:**
```bash
kubectl logs pod-name
# Error: Permission denied: /data/file.txt
```

**Diagnosis:**
```bash
# Check file permissions
kubectl exec pod -- ls -la /data

# Check process user
kubectl exec pod -- id

# Check volume ownership
kubectl exec pod -- stat /data
```

**Solutions:**

**Solution 1: Use fsGroup**
```yaml
spec:
  securityContext:
    fsGroup: 2000  # Volume owned by group 2000
  containers:
  - name: app
    securityContext:
      runAsUser: 1000  # User 1000 is in group 2000
```

**Solution 2: Use init container to fix permissions**
```yaml
initContainers:
- name: fix-permissions
  image: busybox
  command: ['sh', '-c', 'chmod -R 777 /data && chown -R 1000:1000 /data']
  volumeMounts:
  - name: data
    mountPath: /data
```

**Solution 3: Run as root (not recommended)**
```yaml
securityContext:
  runAsUser: 0
```

---

## 🔒 Issue 4: Cannot Mount Secret - Permission Denied

**Symptoms:**
```bash
kubectl describe pod pod
# Warning: Failed to mount secret volume
```

**Diagnosis:**
```bash
# Check secret exists
kubectl get secret app-secrets

# Check secret has data
kubectl get secret app-secrets -o yaml

# Check defaultMode
kubectl get pod pod -o yaml | grep -A5 defaultMode
```

**Solution:**
```yaml
volumes:
- name: secrets
  secret:
    secretName: app-secrets
    defaultMode: 0400  # Read-only for owner
    # 0444 for read by all
    # 0600 for read-write by owner
```

---

## 💥 Issue 5: Pod Evicted - emptyDir Exceeds Size Limit

**Symptoms:**
```bash
kubectl get pods
# NAME     READY   STATUS    REASON     AGE
# my-pod   0/1     Evicted   Evicted    1m

kubectl describe pod my-pod
# Status: Failed
# Reason: Evicted
# Message: Pod ephemeral local storage usage exceeds limit
```

**Diagnosis:**
```bash
# Check emptyDir size limit
kubectl get pod my-pod -o yaml | grep -A5 sizeLimit

# Check actual usage (before eviction)
kubectl exec pod -- du -sh /cache
```

**Solution:**
```yaml
volumes:
- name: cache
  emptyDir:
    sizeLimit: 2Gi  # Increase limit
```

---

## 🔄 Issue 6: ConfigMap Updates Not Reflected

**Symptoms:**
```bash
# Updated ConfigMap but pod still sees old values
kubectl edit configmap app-config
# Made changes...

kubectl exec pod -- cat /etc/config/app.conf
# Still shows old values!
```

**Explanation:**
ConfigMap updates can take up to 60 seconds to propagate to mounted volumes.

**Solutions:**

**Solution 1: Wait**
```bash
# Wait for propagation (up to 60 seconds)
sleep 65
kubectl exec pod -- cat /etc/config/app.conf
```

**Solution 2: Restart pod**
```bash
kubectl delete pod pod-name
# New pod will get updated ConfigMap immediately
```

**Solution 3: Use subPath (WARNING: no updates)**
```yaml
# subPath mounts don't get updates!
volumeMounts:
- name: config
  mountPath: /app/config.yaml
  subPath: config.yaml  # This won't update!
```

---

## 🖥️ Issue 7: hostPath Pod Stuck on Specific Node

**Symptoms:**
```bash
# Pod always schedules on same node
kubectl get pod pod -o wide
# Always on node1
```

**Explanation:**
hostPath volumes tie pods to specific nodes.

**Solutions:**

**Solution 1: Accept the limitation**
```bash
# This is expected behavior with hostPath
# Data is on specific node, pod must run there
```

**Solution 2: Use persistent volumes instead**
```yaml
# Use PVC instead of hostPath
volumes:
- name: data
  persistentVolumeClaim:
    claimName: my-pvc
```

**Solution 3: Use DaemonSet**
```yaml
# If you need pod on every node
apiVersion: apps/v1
kind: DaemonSet
# One pod per node, each with local hostPath
```

---

## 🧮 Issue 8: Memory emptyDir Causing OOM

**Symptoms:**
```bash
kubectl get pods
# NAME     READY   STATUS      RESTARTS   AGE
# my-pod   0/1     OOMKilled   5          2m
```

**Diagnosis:**
```bash
# Check if using memory-backed emptyDir
kubectl get pod pod -o yaml | grep -A5 "medium: Memory"

# Check memory limits
kubectl get pod pod -o yaml | grep -A10 resources
```

**Explanation:**
Memory-backed emptyDir counts against container memory limits!

**Solution:**
```yaml
volumes:
- name: cache
  emptyDir:
    medium: Memory
    sizeLimit: 100Mi  # Limit memory usage

containers:
- name: app
  resources:
    limits:
      memory: "512Mi"  # Must be > sizeLimit + app memory
```

---

## 🔍 Debugging Workflow

### Step 1: Check Pod Status
```bash
kubectl get pod pod-name
kubectl describe pod pod-name
```

### Step 2: Check Events
```bash
kubectl get events --sort-by=.metadata.creationTimestamp | tail -20
```

### Step 3: Check Volume Mounts
```bash
kubectl exec pod-name -- mount | grep /data
kubectl exec pod-name -- df -h
```

### Step 4: Check Permissions
```bash
kubectl exec pod-name -- ls -la /data
kubectl exec pod-name -- id
```

### Step 5: Check Volume Sources
```bash
# For ConfigMap
kubectl get configmap name -o yaml

# For Secret
kubectl get secret name -o yaml

# For hostPath (on node)
minikube ssh "ls -la /path"
```

---

## 💡 Common Error Messages

| Error | Meaning | Solution |
|-------|---------|----------|
| `hostPath type check failed` | Directory doesn't exist | Create dir or use DirectoryOrCreate |
| `configmap not found` | ConfigMap doesn't exist | Create ConfigMap |
| `permission denied` | Wrong user/group | Use fsGroup or init container |
| `volume exceeds size limit` | emptyDir too large | Increase sizeLimit |
| `OOMKilled` | Memory emptyDir too large | Reduce sizeLimit or increase memory limits |
| `read-only file system` | Mounted read-only | Remove readOnly or expect read-only |

---

## 🎯 Prevention Best Practices

```yaml
# 1. Always set size limits
volumes:
- name: cache
  emptyDir:
    sizeLimit: 1Gi

# 2. Use appropriate permissions
volumes:
- name: secrets
  secret:
    secretName: app-secrets
    defaultMode: 0400

# 3. Use fsGroup for consistent permissions
securityContext:
  fsGroup: 2000

# 4. Use DirectoryOrCreate for hostPath
hostPath:
  path: /data
  type: DirectoryOrCreate

# 5. Document volume requirements
metadata:
  annotations:
    description: "Requires /data directory on node"
```

---

**Remember**: Most volume issues are permission or existence problems. Always check basics first! 🔍
