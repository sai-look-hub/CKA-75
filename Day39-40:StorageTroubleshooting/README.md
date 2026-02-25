# Day 39-40: Storage Troubleshooting

## 📋 Overview

Welcome to Day 39-40! Today we focus entirely on troubleshooting Kubernetes storage issues - the most common source of production incidents. You'll learn systematic approaches to diagnose and fix storage problems, from stuck PVCs to mysterious mount failures.

### What You'll Learn

- Systematic troubleshooting methodology
- Common storage issue patterns
- Diagnostic commands and tools
- Root cause analysis techniques
- Prevention strategies
- Performance troubleshooting
- Recovery procedures

---

## 🎯 Learning Objectives

By the end of this module, you will be able to:

1. Diagnose storage issues systematically
2. Identify common failure patterns
3. Use diagnostic tools effectively
4. Perform root cause analysis
5. Fix storage problems quickly
6. Prevent common issues
7. Troubleshoot performance problems
8. Document and share solutions

---

## 🔍 Troubleshooting Methodology

### The 5-Step Approach

```
1. IDENTIFY
   ↓
   What is broken?
   When did it break?
   What changed?

2. GATHER
   ↓
   Logs, events, status
   Resource definitions
   Timeline of events

3. ANALYZE
   ↓
   Pattern matching
   Root cause analysis
   Impact assessment

4. FIX
   ↓
   Apply solution
   Verify fix
   Test thoroughly

5. PREVENT
   ↓
   Document issue
   Implement monitoring
   Add automation
```

---

## 🚨 Top 10 Storage Issues

### Issue #1: PVC Stuck in Pending

**Frequency:** Very High (40% of storage issues)

**Symptoms:**
```bash
kubectl get pvc
# NAME     STATUS    VOLUME   CAPACITY
# my-pvc   Pending            
```

**Common Causes:**

1. **No matching PV available**
   - Size mismatch
   - Access mode incompatible
   - StorageClass doesn't exist
   - No PVs in cluster

2. **VolumeBindingMode: WaitForFirstConsumer**
   - No pod using the PVC yet
   - This is NORMAL behavior

3. **Insufficient capacity**
   - Storage quota exceeded
   - No space on nodes (for local storage)

4. **Provisioner issues**
   - CSI driver not running
   - Provisioner crashed
   - Cloud API failures

**Diagnosis Steps:**
```bash
# 1. Check PVC details
kubectl describe pvc <pvc-name>

# Look for:
# - Events (errors)
# - StorageClass name
# - Requested size
# - Access modes

# 2. Check if StorageClass exists
kubectl get sc <storage-class-name>

# 3. Check for matching PVs
kubectl get pv

# 4. Check provisioner logs
kubectl logs -n kube-system <provisioner-pod>

# 5. Check resource quotas
kubectl describe resourcequota
```

**Solutions:**
```bash
# Solution 1: Create matching PV (static provisioning)
kubectl apply -f pv.yaml

# Solution 2: Fix StorageClass
kubectl get sc
kubectl describe sc <name>

# Solution 3: Create pod to trigger binding
kubectl apply -f pod-using-pvc.yaml

# Solution 4: Restart provisioner
kubectl rollout restart deployment -n kube-system <provisioner>

# Solution 5: Check/increase quota
kubectl patch resourcequota <quota> -p '{"spec":{"hard":{"requests.storage":"100Gi"}}}'
```

---

### Issue #2: Pod Stuck in ContainerCreating

**Frequency:** Very High (35% of storage issues)

**Symptoms:**
```bash
kubectl get pods
# NAME     READY   STATUS              AGE
# my-pod   0/1     ContainerCreating   5m
```

**Common Causes:**

1. **Volume mount failed**
   - PVC not bound
   - Mount point doesn't exist
   - Permission denied

2. **Volume already mounted elsewhere (RWO)**
   - Another pod using same PVC
   - Previous pod not fully terminated

3. **Node doesn't have access to volume**
   - Volume in different availability zone
   - Network issue to storage backend

4. **CSI driver issues**
   - Node plugin not running
   - Mount operation failed

**Diagnosis Steps:**
```bash
# 1. Describe pod for events
kubectl describe pod <pod-name>

# Look for:
# - "MountVolume.SetUp failed"
# - "Unable to attach or mount volumes"
# - Specific error messages

# 2. Check PVC status
kubectl get pvc
kubectl describe pvc <pvc-name>

# 3. Check if another pod using same PVC
kubectl get pods -o json | \
  jq '.items[] | select(.spec.volumes[]?.persistentVolumeClaim.claimName=="<pvc>") | .metadata.name'

# 4. Check CSI node plugin on the specific node
NODE=$(kubectl get pod <pod> -o jsonpath='{.spec.nodeName}')
kubectl get pods -n kube-system -o wide | grep $NODE | grep csi

# 5. Check node plugin logs
kubectl logs -n kube-system <csi-node-pod> -c driver
```

**Solutions:**
```bash
# Solution 1: Wait for PVC to bind
kubectl get pvc -w

# Solution 2: Delete conflicting pod
kubectl delete pod <other-pod>
# Wait for termination
kubectl wait --for=delete pod/<other-pod> --timeout=120s

# Solution 3: Force delete stuck pod
kubectl delete pod <stuck-pod> --force --grace-period=0

# Solution 4: Restart CSI node plugin
kubectl delete pod -n kube-system <csi-node-pod>

# Solution 5: Check volume attachment
kubectl get volumeattachment
kubectl delete volumeattachment <va-name>  # If stuck
```

---

### Issue #3: Data Not Persisting

**Frequency:** Medium (15% of storage issues)

**Symptoms:**
- Data present, pod restarts, data gone
- Files disappear after pod deletion

**Common Causes:**

1. **Using emptyDir instead of PVC**
   - emptyDir is ephemeral
   - Deleted when pod is deleted

2. **Wrong mount path**
   - App writes to different path
   - Volume mounted to wrong location

3. **PV reclaim policy is Delete**
   - PVC deleted → PV deleted → data gone

4. **Not using StatefulSet**
   - Deployment with PVC reference
   - Pod deleted → new pod can't access same PVC

**Diagnosis Steps:**
```bash
# 1. Check volume type
kubectl get pod <pod> -o yaml | grep -A10 volumes:

# If shows emptyDir → That's the problem!

# 2. Check where data is written
kubectl exec <pod> -- ls -la /data

# 3. Check PV reclaim policy
kubectl get pv -o custom-columns=\
NAME:.metadata.name,\
RECLAIM:.spec.persistentVolumeReclaimPolicy

# 4. Check if StatefulSet
kubectl get statefulset
```

**Solutions:**
```bash
# Solution 1: Use PVC instead of emptyDir
# Change pod spec:
volumes:
- name: data
  persistentVolumeClaim:
    claimName: my-pvc  # Not emptyDir!

# Solution 2: Use StatefulSet with volumeClaimTemplates
# For databases and stateful apps

# Solution 3: Change reclaim policy to Retain
kubectl patch pv <pv> -p '{"spec":{"persistentVolumeReclaimPolicy":"Retain"}}'

# Solution 4: Backup before deletion
kubectl exec <pod> -- tar czf /backup/data.tar.gz /data
```

---

### Issue #4: Permission Denied Errors

**Frequency:** High (20% of storage issues)

**Symptoms:**
```bash
# In pod logs:
Permission denied: /data/file.txt
mkdir: cannot create directory '/data/app': Permission denied
```

**Common Causes:**

1. **Volume owned by root, app runs as non-root**
2. **fsGroup not set**
3. **Read-only volume mount**
4. **SELinux/AppArmor restrictions**

**Diagnosis Steps:**
```bash
# 1. Check who owns the volume
kubectl exec <pod> -- ls -la /data

# 2. Check what user app runs as
kubectl exec <pod> -- id

# 3. Check pod security context
kubectl get pod <pod> -o yaml | grep -A10 securityContext

# 4. Try writing as root
kubectl exec <pod> -- sh -c 'touch /data/test.txt'
```

**Solutions:**
```bash
# Solution 1: Set fsGroup (recommended)
spec:
  securityContext:
    fsGroup: 1000  # Group ID
  containers:
  - name: app
    securityContext:
      runAsUser: 1000
      runAsGroup: 1000

# Solution 2: Init container to fix permissions
initContainers:
- name: fix-perms
  image: busybox
  command: ['sh', '-c', 'chown -R 1000:1000 /data']
  volumeMounts:
  - name: data
    mountPath: /data

# Solution 3: Make volume writable
volumeMounts:
- name: data
  mountPath: /data
  # Remove readOnly: true if present

# Solution 4: Run as root (not recommended)
securityContext:
  runAsUser: 0
```

---

### Issue #5: Volume Already Mounted (Multi-Attach Error)

**Frequency:** Medium (12% of storage issues)

**Symptoms:**
```bash
# Pod events:
Multi-Attach error for volume
Volume is already exclusively attached to one node and can't be attached to another
```

**Common Causes:**

1. **Using ReadWriteOnce with multiple pods**
   - RWO = one node, not one pod
   - Pods on different nodes can't share

2. **Previous pod not fully terminated**
   - VolumeAttachment still exists
   - Detach operation stuck

3. **Node failure**
   - Node died with volume attached
   - Volume not detached properly

**Diagnosis Steps:**
```bash
# 1. Check access mode
kubectl get pvc <pvc> -o jsonpath='{.spec.accessModes}'

# 2. Find all pods using this PVC
kubectl get pods -A -o json | \
  jq -r '.items[] | 
    select(.spec.volumes[]?.persistentVolumeClaim.claimName=="<pvc>") | 
    "\(.metadata.namespace)/\(.metadata.name) on node \(.spec.nodeName)"'

# 3. Check VolumeAttachments
kubectl get volumeattachment
kubectl describe volumeattachment <va>

# 4. Check if node is down
kubectl get nodes
```

**Solutions:**
```bash
# Solution 1: Use ReadWriteMany if needed
spec:
  accessModes:
  - ReadWriteMany  # Requires NFS, CephFS, etc.

# Solution 2: Delete old pod first
kubectl delete pod <old-pod>
kubectl wait --for=delete pod/<old-pod> --timeout=120s

# Solution 3: Force delete stuck pod
kubectl delete pod <stuck-pod> --force --grace-period=0

# Solution 4: Delete VolumeAttachment
kubectl get volumeattachment
kubectl delete volumeattachment <va-name>

# Solution 5: Use pod affinity (keep pods on same node)
affinity:
  podAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
    - labelSelector:
        matchLabels:
          app: myapp
      topologyKey: kubernetes.io/hostname
```

---

### Issue #6: Storage Quota Exceeded

**Frequency:** Medium (10% of storage issues)

**Symptoms:**
```bash
# PVC creation fails:
Error: exceeded quota: storage-quota
persistentvolumeclaims "my-pvc" is forbidden: exceeded quota
```

**Diagnosis Steps:**
```bash
# 1. Check ResourceQuota
kubectl get resourcequota
kubectl describe resourcequota <quota>

# 2. See current usage
kubectl get resourcequota <quota> -o yaml

# 3. List all PVCs and their sizes
kubectl get pvc -o custom-columns=\
NAME:.metadata.name,\
SIZE:.spec.resources.requests.storage
```

**Solutions:**
```bash
# Solution 1: Delete unused PVCs
kubectl get pvc
kubectl delete pvc <unused-pvc>

# Solution 2: Increase quota
kubectl patch resourcequota <quota> \
  -p '{"spec":{"hard":{"requests.storage":"200Gi","persistentvolumeclaims":"20"}}}'

# Solution 3: Request smaller volume
# In PVC spec:
resources:
  requests:
    storage: 5Gi  # Instead of 100Gi
```

---

### Issue #7: Snapshot Creation Fails

**Frequency:** Low (5% of storage issues)

**Symptoms:**
```bash
kubectl get volumesnapshot
# NAME         READYTOUSE   AGE
# my-snapshot  false        5m
```

**Common Causes:**

1. **CSI driver doesn't support snapshots**
2. **VolumeSnapshotClass missing**
3. **Source PVC not found**
4. **Backend storage error**

**Diagnosis Steps:**
```bash
# 1. Check VolumeSnapshot status
kubectl describe volumesnapshot <snapshot>

# 2. Check if driver supports snapshots
kubectl get csidriver <driver> -o yaml

# 3. Check VolumeSnapshotClass
kubectl get volumesnapshotclass

# 4. Check CSI snapshotter logs
kubectl logs -n kube-system <csi-controller> -c csi-snapshotter
```

**Solutions:**
```bash
# Solution 1: Create VolumeSnapshotClass
kubectl apply -f volumesnapshotclass.yaml

# Solution 2: Use driver that supports snapshots
# AWS EBS CSI, GCE PD CSI, etc.

# Solution 3: Verify source PVC exists
kubectl get pvc <source-pvc>

# Solution 4: Check backend storage
# Cloud console, storage array logs
```

---

## 🔧 Diagnostic Tools

### Essential Commands

```bash
# Get comprehensive status
kubectl get pv,pvc,sc -o wide

# Check events (last hour)
kubectl get events --sort-by=.metadata.creationTimestamp

# Find all resources related to storage
kubectl api-resources | grep storage

# Check storage usage in pod
kubectl exec <pod> -- df -h

# Debug with temporary pod
kubectl run -it --rm debug --image=busybox --restart=Never -- sh
```

### Advanced Diagnostics

```bash
# Check volume mounts in running pods
kubectl get pods -o json | \
  jq -r '.items[] | 
    "\(.metadata.name): \(.spec.volumes | length) volumes"'

# Find PVCs not bound
kubectl get pvc -A -o json | \
  jq -r '.items[] | 
    select(.status.phase!="Bound") | 
    "\(.metadata.namespace)/\(.metadata.name): \(.status.phase)"'

# Check for stuck volume attachments
kubectl get volumeattachment -o json | \
  jq -r '.items[] | 
    select(.status.attached==false) | 
    .metadata.name'

# Monitor storage provisioning
kubectl get events -w | grep -i "provision\|mount\|attach"
```

---

## 📊 Performance Troubleshooting

### Slow I/O Performance

**Symptoms:**
- Application slow
- High latency
- Low throughput

**Diagnosis:**
```bash
# 1. Check IOPS limits
# For AWS EBS gp3: 3000 IOPS base
# For Azure Premium: Depends on size

# 2. Test read performance
kubectl exec <pod> -- dd if=/data/testfile of=/dev/null bs=1M count=1000

# 3. Test write performance
kubectl exec <pod> -- dd if=/dev/zero of=/data/testfile bs=1M count=1000

# 4. Check storage backend metrics
# CloudWatch (AWS), Cloud Monitoring (GCP), Azure Monitor

# 5. Check for noisy neighbors
# Other pods on same node using storage
```

**Solutions:**
```bash
# Solution 1: Upgrade to faster storage class
# gp2 → gp3 (AWS)
# Standard → SSD (GCP)

# Solution 2: Increase IOPS/throughput
# For AWS EBS gp3:
parameters:
  type: gp3
  iopsPerGB: "50"  # Higher IOPS
  throughput: "500"  # Higher MB/s

# Solution 3: Use local SSD
# For extreme performance
storageClassName: local-path

# Solution 4: Optimize application
# Batch writes, use caching
```

---

## 🛡️ Prevention Strategies

### 1. Monitoring

```yaml
# Prometheus alerts
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: storage-alerts
spec:
  groups:
  - name: storage
    rules:
    - alert: PVCNotBound
      expr: kube_persistentvolumeclaim_status_phase{phase="Pending"} > 0
      for: 5m
      annotations:
        summary: "PVC stuck in Pending for 5+ minutes"
    
    - alert: StorageSpaceLow
      expr: kubelet_volume_stats_available_bytes / kubelet_volume_stats_capacity_bytes < 0.1
      for: 5m
      annotations:
        summary: "Volume less than 10% free space"
```

### 2. Resource Quotas

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: storage-quota
spec:
  hard:
    requests.storage: "100Gi"
    persistentvolumeclaims: "10"
    <storage-class-name>.storageclass.storage.k8s.io/requests.storage: "50Gi"
```

### 3. Best Practices

- ✅ Always set `volumeBindingMode: WaitForFirstConsumer`
- ✅ Use `fsGroup` for consistent permissions
- ✅ Set `reclaimPolicy: Retain` for production
- ✅ Enable volume snapshots for backups
- ✅ Monitor storage usage and set alerts
- ✅ Document storage requirements
- ✅ Test disaster recovery procedures

---

## 📖 Key Takeaways

✅ Use systematic troubleshooting methodology
✅ Check events first (kubectl describe, kubectl get events)
✅ Verify PVC → PV → StorageClass chain
✅ Common issues: Pending PVC, ContainerCreating, Permissions
✅ Monitor storage proactively
✅ Document solutions for future reference
✅ Test backups and recovery procedures

---

## 🔗 Additional Resources

- [Kubernetes Storage Troubleshooting](https://kubernetes.io/docs/tasks/debug-application-cluster/debug-stateful-set/)
- [CSI Troubleshooting Guide](https://kubernetes-csi.github.io/docs/troubleshooting.html)

---

## 🚀 Next Steps

1. Complete hands-on exercises in GUIDEME.md
2. Practice with troubleshooting scenarios
3. Build your troubleshooting runbook
4. Review command cheatsheet
5. Move to Day 41-42: Week Review & Project 

**Happy Troubleshooting! 🔧**
