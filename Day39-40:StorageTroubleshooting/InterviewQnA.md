# 🎤 Interview Q&A: Storage Troubleshooting

---

## Q1: Walk me through how you would troubleshoot a PVC stuck in Pending state.

**Answer:**

I use a systematic **5-step approach**:

**Step 1: Identify the Problem**
```bash
kubectl get pvc <pvc-name>
# STATUS: Pending - confirmed
```

**Step 2: Gather Information**
```bash
kubectl describe pvc <pvc-name>
```

Look for:
- **Events** section (key errors here)
- **StorageClass** name
- **Requested size** and **access modes**
- **Status messages**

**Step 3: Analyze - Check 4 Common Causes**

**Cause 1: StorageClass doesn't exist**
```bash
kubectl get sc <storage-class-name>
# If not found → Create SC or fix PVC
```

**Cause 2: No matching PV (static provisioning)**
```bash
kubectl get pv
# Check: Size, Access mode, StorageClass
# If no match → Create PV or wait for provisioning
```

**Cause 3: VolumeBindingMode: WaitForFirstConsumer**
```bash
kubectl get sc <sc> -o jsonpath='{.volumeBindingMode}'
# If WaitForFirstConsumer → This is NORMAL
# PVC binds when pod is created
```

**Cause 4: Provisioner issues**
```bash
# Check CSI driver
kubectl get pods -n kube-system | grep csi-controller
kubectl logs -n kube-system <csi-controller> -c csi-provisioner
# Look for errors
```

**Step 4: Resolve**

Based on root cause:
- **Wrong SC**: Patch PVC or create SC
- **No PV**: Create PV or wait for dynamic provisioning
- **WaitForFirstConsumer**: Create pod using the PVC
- **Provisioner error**: Fix IAM permissions, restart provisioner

**Step 5: Verify**
```bash
kubectl get pvc <pvc-name> -w
# Wait for STATUS: Bound
```

**Example Timeline:**
```
2:00 PM - PVC created, stuck Pending
2:01 PM - kubectl describe shows "StorageClass not found"
2:02 PM - kubectl get sc confirms SC missing
2:03 PM - Created correct StorageClass
2:04 PM - PVC automatically bound
Total time: 4 minutes
```

---

## Q2: A pod is stuck in ContainerCreating for 10 minutes. How do you diagnose this?

**Answer:**

**Step 1: Confirm the Issue**
```bash
kubectl get pod <pod>
# STATUS: ContainerCreating for 10m
```

**Step 2: Check Pod Events**
```bash
kubectl describe pod <pod>
```

Look for events like:
- "MountVolume.SetUp failed"
- "Unable to attach or mount volumes"
- "persistentvolumeclaim not found"
- "Multi-Attach error"

**Step 3: Diagnose Based on Error**

**Scenario A: PVC not found**
```bash
# Event: persistentvolumeclaim "my-pvc" not found
kubectl get pvc <pvc-name>
# Solution: Create the PVC
```

**Scenario B: PVC not bound**
```bash
kubectl get pvc <pvc-name>
# STATUS: Pending
# Solution: Fix PVC binding issue first
```

**Scenario C: Multi-Attach error**
```bash
# Event: Volume already attached to another node

# Find other pods using same PVC
kubectl get pods -A -o json | \
  jq -r '.items[] | 
    select(.spec.volumes[]?.persistentVolumeClaim.claimName=="<pvc>") | 
    "\(.metadata.namespace)/\(.metadata.name) on \(.spec.nodeName)"'

# If two pods on different nodes with RWO volume:
# Solution: Delete one pod or use RWX
```

**Scenario D: CSI node plugin not running**
```bash
# Check CSI node plugin on the pod's node
NODE=$(kubectl get pod <pod> -o jsonpath='{.spec.nodeName}')
kubectl get pods -n kube-system -o wide | grep csi | grep $NODE

# If missing:
# Solution: Restart CSI DaemonSet or check tolerations
```

**Scenario E: Permission to attach/mount denied**
```bash
# Check CSI driver logs
kubectl logs -n kube-system <csi-node-pod> -c driver
# Look for permission errors

# Common: Cloud IAM permissions missing
# Solution: Add required IAM policies
```

**Step 4: Common Quick Fixes**

```bash
# Force delete and recreate pod
kubectl delete pod <pod> --force --grace-period=0

# Delete stuck VolumeAttachment
kubectl get volumeattachment
kubectl delete volumeattachment <va-name>

# Restart CSI node plugin
kubectl delete pod -n kube-system <csi-node-pod>
```

---

## Q3: Users report that data is being lost when pods restart. How do you investigate?

**Answer:**

**Step 1: Reproduce the Issue**
```bash
# Check current pod
kubectl exec <pod> -- ls -la /data

# Note what files exist
# Restart pod
kubectl delete pod <pod>

# Wait for new pod
kubectl wait --for=condition=ready pod/<pod>

# Check data
kubectl exec <pod> -- ls -la /data
# Is data still there?
```

**Step 2: Check Volume Type**
```bash
kubectl get pod <pod> -o yaml | grep -A10 volumes:
```

**Red Flag #1: emptyDir**
```yaml
volumes:
- name: data
  emptyDir: {}  # ← PROBLEM!
```

**Why bad:** emptyDir is ephemeral
- Created when pod starts
- Deleted when pod stops
- **NO persistence**

**Solution:** Use PVC instead

**Red Flag #2: No volume at all**
```yaml
# Data written to container filesystem
# Lost on every restart
```

**Solution:** Add PVC

**Step 3: Check if Using PVC**
```bash
kubectl get pod <pod> -o json | \
  jq '.spec.volumes[] | select(.persistentVolumeClaim)'
```

If using PVC, check:

**Check A: Is PVC bound?**
```bash
kubectl get pvc <pvc>
# STATUS must be: Bound
```

**Check B: Wrong mount path?**
```bash
# App writes to: /var/lib/data
# Volume mounted at: /data
# Data goes to container filesystem (lost!)

kubectl get pod <pod> -o json | \
  jq '.spec.containers[].volumeMounts'
```

**Check C: Using Deployment instead of StatefulSet?**
```bash
kubectl get deployment <n>
```

**Problem:** Deployment with PVC
- Pod deleted → New pod created
- New pod can't bind to same PVC (already bound)
- New pod stuck

**Solution:** Use StatefulSet with volumeClaimTemplates

**Check D: Reclaim policy is Delete?**
```bash
kubectl get pv -o custom-columns=\
NAME:.metadata.name,\
RECLAIM:.spec.persistentVolumeReclaimPolicy
```

If `Delete`:
- PVC deleted → PV deleted → Data gone

**Solution:** Change to `Retain` for production

**Step 4: Implement Fix**

For databases/stateful apps:
```yaml
apiVersion: apps/v1
kind: StatefulSet
spec:
  serviceName: mysql
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: [ReadWriteOnce]
      resources:
        requests:
          storage: 10Gi
```

Benefits:
- Each pod gets its own PVC
- PVC survives pod deletion
- Pod reattaches to same PVC on restart

---

## Q4: How do you troubleshoot permission denied errors when writing to a PVC?

**Answer:**

**Step 1: Verify the Error**
```bash
kubectl logs <pod>
# Error: Permission denied: /data/file.txt
# Or: mkdir: cannot create directory '/data': Permission denied
```

**Step 2: Check Current Permissions**
```bash
# Who owns the volume?
kubectl exec <pod> -- ls -la /data
# Output: drwxr-xr-x 2 root root

# Who is the app running as?
kubectl exec <pod> -- id
# Output: uid=1000(app) gid=1000(app)

# Problem: Volume owned by root (uid=0)
# App runs as uid=1000
# → Permission denied!
```

**Step 3: Check Security Context**
```bash
kubectl get pod <pod> -o yaml | grep -A10 securityContext
```

**Step 4: Apply Fix**

**Solution 1: fsGroup (Recommended)**
```yaml
spec:
  securityContext:
    fsGroup: 1000  # Volume owned by group 1000
  containers:
  - name: app
    securityContext:
      runAsUser: 1000  # App runs as user 1000
      runAsGroup: 1000  # App in group 1000
```

**How it works:**
- K8s changes volume ownership to `fsGroup`
- User 1000 in group 1000 can write
- Clean, declarative solution

**Solution 2: Init Container**
```yaml
initContainers:
- name: fix-perms
  image: busybox
  command: ['sh', '-c', 'chown -R 1000:1000 /data && chmod -R 755 /data']
  volumeMounts:
  - name: data
    mountPath: /data
  securityContext:
    runAsUser: 0  # Init runs as root
```

**When to use:**
- Need specific permissions (777, etc.)
- fsGroup not sufficient
- Complex permission requirements

**Solution 3: Run as Root (Not Recommended)**
```yaml
securityContext:
  runAsUser: 0  # Run as root
```

**Why avoid:**
- Security risk
- Against best practices
- May violate Pod Security Standards

**Step 5: Verify Fix**
```bash
kubectl delete pod <pod>  # Recreate with new config
kubectl wait --for=condition=ready pod/<pod>

# Check permissions
kubectl exec <pod> -- ls -la /data
# Should now show correct ownership

# Test write
kubectl exec <pod> -- touch /data/test.txt
# Should succeed
```

**Common Gotcha: Read-Only Volume**
```yaml
volumeMounts:
- name: data
  mountPath: /data
  readOnly: true  # ← Can't write!
```

Solution: Remove `readOnly: true`

---

## Q5: Describe your approach to troubleshooting poor storage performance.

**Answer:**

**Step 1: Define "Poor Performance"**
- What is slow? (Read? Write? Both?)
- Expected vs actual throughput/IOPS
- Baseline metrics

**Step 2: Isolate the Problem**

**Test A: Is it the storage or the application?**
```bash
# Direct I/O test (bypasses cache)
kubectl exec <pod> -- dd if=/dev/zero of=/data/test bs=1M count=1000 oflag=direct
# Measures: Write speed

kubectl exec <pod> -- dd if=/data/test of=/dev/null bs=1M iflag=direct
# Measures: Read speed
```

**Test B: Compare against baseline**
```
Expected (AWS gp3): ~125 MB/s
Actual: 10 MB/s
→ Storage issue confirmed
```

**Step 3: Check Storage Configuration**

**Check A: StorageClass parameters**
```bash
kubectl get sc <sc> -o yaml
```

For AWS EBS:
```yaml
parameters:
  type: gp2  # ← Older generation
  # vs
  type: gp3  # ← Newer, better performance
```

**Check B: Volume size (affects IOPS)**
```bash
kubectl get pvc <pvc> -o jsonpath='{.spec.resources.requests.storage}'
```

For AWS EBS gp2:
- 1 GB = 3 IOPS
- 100 GB = 300 IOPS
- Small volumes = Low IOPS!

**Check C: Provisioned IOPS/throughput**
```yaml
# For gp3, can customize
parameters:
  type: gp3
  iopsPerGB: "50"  # Higher IOPS
  throughput: "500"  # Higher MB/s
```

**Step 4: Check for Bottlenecks**

**Bottleneck 1: Network latency**
```bash
# For cloud storage
# Check if volume in same AZ as pod
kubectl get pod <pod> -o jsonpath='{.spec.nodeName}'
kubectl get node <node> -o jsonpath='{.metadata.labels.topology\.kubernetes\.io/zone}'

# Check PV zone
kubectl get pv <pv> -o yaml | grep zone
```

**Bottleneck 2: Noisy neighbors**
```bash
# Other pods on same node using storage
kubectl get pods -o wide | grep <node-name>

# Check their I/O
# If possible, move workloads to different nodes
```

**Bottleneck 3: Application inefficiency**
```bash
# Check application logs
# Is app doing many small I/O operations?
# Solution: Batch operations, use caching
```

**Step 5: Apply Solutions**

**Solution 1: Upgrade storage tier**
```yaml
# From standard to SSD
storageClassName: fast-ssd  # gp3, pd-ssd, Premium_LRS
```

**Solution 2: Increase IOPS/throughput**
```yaml
parameters:
  type: io2  # AWS provisioned IOPS
  iops: "10000"
```

**Solution 3: Use local storage (extreme performance)**
```yaml
storageClassName: local-path  # Local SSDs
```

**Solution 4: Optimize application**
- Implement caching layer (Redis)
- Batch writes
- Use async I/O

**Step 6: Measure Improvement**
```bash
# Re-run performance tests
# Compare before/after metrics
# Verify meets requirements
```

**Example Case:**
```
Before:
- Type: gp2
- Size: 10 GB
- IOPS: 30 (3 per GB)
- Throughput: ~20 MB/s

After:
- Type: gp3
- Size: 50 GB
- IOPS: 3000 (base)
- Throughput: 125 MB/s

Result: 6x improvement!
```

---

**Pro Tip:** Always document your troubleshooting process and share learnings with the team!
