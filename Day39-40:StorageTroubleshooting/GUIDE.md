# 📖 GUIDEME: Storage Troubleshooting - Complete Walkthrough

## 🎯 Learning Path Overview

16-hour hands-on troubleshooting bootcamp across 2 days.

---

## ⏱️ Time Allocation

**Day 1 (8 hours):**
- Hours 1-2: Setup and methodology
- Hours 3-4: PVC troubleshooting scenarios
- Hours 5-6: Mount failure scenarios
- Hours 7-8: Permission issues

**Day 2 (8 hours):**
- Hours 1-2: Performance troubleshooting
- Hours 3-4: Advanced scenarios
- Hours 5-6: Recovery procedures
- Hours 7-8: Building runbooks

---

## 📚 Phase 1: Setup & Methodology (2 hours)

### Step 1: Create Troubleshooting Environment (30 minutes)

```bash
# Create namespace for testing
kubectl create namespace storage-debug

# Deploy monitoring tools
kubectl apply -f troubleshooting-setup.yaml

# Verify setup
kubectl get pods -n storage-debug
```

---

### Step 2: Learn the Methodology (30 minutes)

**The IGARRR Method:**
- **I**dentify: What's broken?
- **G**ather: Collect information
- **A**nalyze: Find root cause
- **R**esolve: Apply fix
- **R**ecover: Verify solution
- **R**ecord: Document for future

**Practice scenario:**
```bash
# Simulated issue
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: broken-pvc
  namespace: storage-debug
spec:
  accessModes:
  - ReadWriteOnce
  storageClassName: non-existent-class
  resources:
    requests:
      storage: 1Gi
EOF

# Identify
kubectl get pvc -n storage-debug broken-pvc
# STATUS: Pending

# Gather
kubectl describe pvc -n storage-debug broken-pvc

# Analyze
# Events show: "storageclass.storage.k8s.io \"non-existent-class\" not found"

# Resolve
kubectl patch pvc -n storage-debug broken-pvc \
  -p '{"spec":{"storageClassName":"standard"}}'

# Recover
kubectl get pvc -n storage-debug broken-pvc
# STATUS: Bound

# Record
echo "Issue: Wrong StorageClass name" >> troubleshooting-log.md
echo "Fix: Updated to 'standard'" >> troubleshooting-log.md
```

---

### Step 3: Essential Diagnostic Commands (60 minutes)

```bash
# Create reference card
cat > diagnostic-commands.sh << 'EOF'
#!/bin/bash
# Storage Diagnostic Commands

# === Quick Status ===
alias pvc-status='kubectl get pvc -A'
alias pv-status='kubectl get pv'
alias sc-status='kubectl get sc'

# === Detailed Info ===
function diagnose-pvc() {
  kubectl describe pvc $1
  kubectl get events --field-selector involvedObject.name=$1
}

function diagnose-pv() {
  kubectl describe pv $1
}

# === Find Resources ===
function find-pvc-pods() {
  kubectl get pods -A -o json | \
    jq -r ".items[] | 
      select(.spec.volumes[]?.persistentVolumeClaim.claimName==\"$1\") | 
      \"\(.metadata.namespace)/\(.metadata.name)\""
}

# === Volume Attachments ===
function check-attachments() {
  kubectl get volumeattachment
  kubectl get volumeattachment -o json | \
    jq -r '.items[] | 
      "\(.metadata.name): attached=\(.status.attached), node=\(.spec.nodeName)"'
}

EOF

chmod +x diagnostic-commands.sh
source diagnostic-commands.sh
```

**✅ Checkpoint:** Diagnostic tools ready.

---

## 🔴 Phase 2: PVC Pending Scenarios (2 hours)

### Scenario 1: StorageClass Not Found (30 minutes)

```bash
# Create broken PVC
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: sc-notfound
  namespace: storage-debug
spec:
  accessModes:
  - ReadWriteOnce
  storageClassName: missing-class
  resources:
    requests:
      storage: 1Gi
EOF

# Troubleshoot
kubectl get pvc -n storage-debug sc-notfound
# STATUS: Pending

kubectl describe pvc -n storage-debug sc-notfound
# Event: storageclass.storage.k8s.io "missing-class" not found

# Check available StorageClasses
kubectl get sc

# Fix
kubectl patch pvc -n storage-debug sc-notfound \
  -p '{"spec":{"storageClassName":"local-path"}}'

# Verify
kubectl get pvc -n storage-debug sc-notfound -w
```

**✅ Checkpoint:** Fixed StorageClass issue.

---

### Scenario 2: No Matching PV Available (45 minutes)

```bash
# Create PVC requesting specific size
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: no-matching-pv
  namespace: storage-debug
spec:
  accessModes:
  - ReadWriteOnce
  storageClassName: manual
  resources:
    requests:
      storage: 50Gi  # Huge size
EOF

# Troubleshoot
kubectl describe pvc -n storage-debug no-matching-pv
# Event: waiting for a volume to be created

# Check available PVs
kubectl get pv

# Create matching PV
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: manual-pv-50g
spec:
  capacity:
    storage: 50Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  hostPath:
    path: /mnt/data-50g
EOF

# PVC should bind now
kubectl get pvc -n storage-debug no-matching-pv -w
```

**✅ Checkpoint:** Understood static provisioning binding.

---

### Scenario 3: WaitForFirstConsumer Confusion (45 minutes)

```bash
# Create PVC with WaitForFirstConsumer
kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: wait-for-pod
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: waiting-pvc
  namespace: storage-debug
spec:
  accessModes:
  - ReadWriteOnce
  storageClassName: wait-for-pod
  resources:
    requests:
      storage: 1Gi
EOF

# PVC stays Pending (NORMAL!)
kubectl get pvc -n storage-debug waiting-pvc
# STATUS: Pending

# This is expected! Check StorageClass
kubectl get sc wait-for-pod -o yaml | grep volumeBindingMode
# volumeBindingMode: WaitForFirstConsumer

# Create pod to trigger binding
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: trigger-binding
  namespace: storage-debug
spec:
  containers:
  - name: app
    image: busybox
    command: ['sleep', '3600']
    volumeMounts:
    - name: storage
      mountPath: /data
  volumes:
  - name: storage
    persistentVolumeClaim:
      claimName: waiting-pvc
EOF

# Now PVC binds!
kubectl get pvc -n storage-debug waiting-pvc -w
```

**✅ Checkpoint:** Understood WaitForFirstConsumer behavior.

---

## 🔧 Phase 3: ContainerCreating Issues (2 hours)

### Scenario 1: PVC Not Bound (30 minutes)

```bash
# Create pod with non-existent PVC
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: missing-pvc-pod
  namespace: storage-debug
spec:
  containers:
  - name: app
    image: nginx
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: does-not-exist
EOF

# Pod stuck in ContainerCreating
kubectl get pod -n storage-debug missing-pvc-pod

# Diagnose
kubectl describe pod -n storage-debug missing-pvc-pod
# Event: persistentvolumeclaim "does-not-exist" not found

# Fix: Create the PVC
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: does-not-exist
  namespace: storage-debug
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
EOF

# Pod should start
kubectl get pod -n storage-debug missing-pvc-pod -w
```

**✅ Checkpoint:** Fixed missing PVC issue.

---

### Scenario 2: Multi-Attach Error (45 minutes)

```bash
# Create RWO PVC
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: rwo-pvc
  namespace: storage-debug
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
EOF

# Create first pod
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: pod-1
  namespace: storage-debug
spec:
  containers:
  - name: app
    image: busybox
    command: ['sleep', '3600']
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: rwo-pvc
  nodeSelector:
    kubernetes.io/hostname: node-1  # Force to node-1
EOF

# Wait for it to run
kubectl wait --for=condition=ready pod/pod-1 -n storage-debug --timeout=60s

# Try to create second pod on DIFFERENT node
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: pod-2
  namespace: storage-debug
spec:
  containers:
  - name: app
    image: busybox
    command: ['sleep', '3600']
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: rwo-pvc
  nodeSelector:
    kubernetes.io/hostname: node-2  # Different node!
EOF

# Pod-2 stuck with multi-attach error
kubectl describe pod -n storage-debug pod-2
# Event: Multi-Attach error

# Solutions:
# Option 1: Delete pod-1 first
kubectl delete pod -n storage-debug pod-1

# Option 2: Use pod affinity (same node)
# Option 3: Use ReadWriteMany if storage supports it

# Cleanup
kubectl delete pod -n storage-debug pod-2
```

**✅ Checkpoint:** Understood RWO limitations.

---

### Scenario 3: Node Plugin Not Running (45 minutes)

```bash
# Simulate CSI node plugin issue
# (In real scenario, check if csi-node pods running)

# Check CSI node pods
kubectl get pods -n kube-system -l app=csi-node

# If missing on a node, pods can't mount volumes

# Check specific node
NODE=<your-node-name>
kubectl get pods -n kube-system -o wide | grep $NODE | grep csi

# Check DaemonSet
kubectl get daemonset -n kube-system csi-node

# If pod missing, check tolerations
kubectl describe daemonset -n kube-system csi-node | grep -A5 Tolerations

# Manually restart CSI node pod
kubectl delete pod -n kube-system <csi-node-pod-on-problem-node>
```

**✅ Checkpoint:** Verified CSI node plugin health.

---

## 🔒 Phase 4: Permission Issues (2 hours)

### Scenario 1: Volume Owned by Root (60 minutes)

```bash
# Create PVC and pod
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: perm-test
  namespace: storage-debug
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
---
apiVersion: v1
kind: Pod
metadata:
  name: perm-denied
  namespace: storage-debug
spec:
  securityContext:
    runAsUser: 1000  # Non-root user
  containers:
  - name: app
    image: busybox
    command: ['sh', '-c', 'touch /data/test.txt']  # This will fail!
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: perm-test
EOF

# Check pod logs
kubectl logs -n storage-debug perm-denied
# Error: touch: /data/test.txt: Permission denied

# Diagnose ownership
kubectl exec -n storage-debug perm-denied -- ls -la /data
# drwxr-xr-x  root root

# Who is the app running as?
kubectl exec -n storage-debug perm-denied -- id
# uid=1000 gid=1000  # Not root!

# Fix with fsGroup
kubectl delete pod -n storage-debug perm-denied
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: perm-fixed
  namespace: storage-debug
spec:
  securityContext:
    fsGroup: 1000  # Volume owned by this group
    runAsUser: 1000
  containers:
  - name: app
    image: busybox
    command: ['sh', '-c', 'touch /data/test.txt && ls -la /data/']
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: perm-test
EOF

# Check logs - should work!
kubectl logs -n storage-debug perm-fixed
```

**✅ Checkpoint:** Fixed permissions with fsGroup.

---

### Scenario 2: Init Container Permission Fix (60 minutes)

```bash
# Alternative: Use init container
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: init-perm-fix
  namespace: storage-debug
spec:
  initContainers:
  - name: fix-perms
    image: busybox
    command: ['sh', '-c', 'chown -R 1000:1000 /data && chmod -R 755 /data']
    volumeMounts:
    - name: data
      mountPath: /data
    securityContext:
      runAsUser: 0  # Init runs as root
  containers:
  - name: app
    image: busybox
    command: ['sh', '-c', 'echo "Success!" > /data/success.txt && cat /data/success.txt']
    volumeMounts:
    - name: data
      mountPath: /data
    securityContext:
      runAsUser: 1000  # App runs as non-root
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: perm-test
EOF

kubectl logs -n storage-debug init-perm-fix
```

**✅ Checkpoint:** Used init container for permissions.

---

## ⚡ Phase 5: Performance Troubleshooting (2 hours)

### Test I/O Performance (60 minutes)

```bash
# Create performance test pod
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: io-test
  namespace: storage-debug
spec:
  containers:
  - name: test
    image: ubuntu
    command: ['sh', '-c', 'apt-get update && apt-get install -y fio && sleep 3600']
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: perf-test-pvc
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: perf-test-pvc
  namespace: storage-debug
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
EOF

kubectl wait --for=condition=ready pod/io-test -n storage-debug --timeout=300s

# Test write performance
kubectl exec -n storage-debug io-test -- \
  dd if=/dev/zero of=/data/testfile bs=1M count=1000 oflag=direct

# Test read performance
kubectl exec -n storage-debug io-test -- \
  dd if=/data/testfile of=/dev/null bs=1M count=1000 iflag=direct

# Advanced testing with fio
kubectl exec -n storage-debug io-test -- \
  fio --name=randwrite --ioengine=libaio --iodepth=16 \
      --rw=randwrite --bs=4k --direct=1 --size=1G \
      --numjobs=4 --runtime=60 --group_reporting \
      --filename=/data/fio-test
```

**✅ Checkpoint:** Measured storage performance.

---

### Diagnose Slow Performance (60 minutes)

```bash
# Check if issue is storage or application
# 1. Check PV type
kubectl get pv -o custom-columns=\
NAME:.metadata.name,\
TYPE:.spec.hostPath,\
CSI:.spec.csi.driver

# 2. For cloud storage, check provisioned IOPS
kubectl get sc -o yaml

# 3. Monitor real-time I/O
kubectl exec -n storage-debug io-test -- iostat -x 5

# 4. Check for other pods using same volume
find-pvc-pods perf-test-pvc

# 5. Identify bottleneck
# - Network latency to storage backend
# - IOPS/throughput limits
# - Noisy neighbors
```

**✅ Checkpoint:** Diagnosed performance issues.

---

## 🆘 Phase 6: Recovery Procedures (2 hours)

### Recover from PV/PVC Deletion (60 minutes)

```bash
# Simulate accidental PVC deletion
kubectl delete pvc -n storage-debug perm-test

# Check PV status
kubectl get pv
# STATUS: Released (with Retain policy)

# PV exists but can't be reused!

# Solution: Remove claimRef
PV_NAME=$(kubectl get pv -o json | \
  jq -r '.items[] | select(.spec.claimRef.name=="perm-test") | .metadata.name')

kubectl patch pv $PV_NAME -p '{"spec":{"claimRef": null}}'

# PV now Available
kubectl get pv $PV_NAME

# Create new PVC to claim it
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: perm-test-recovered
  namespace: storage-debug
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  volumeName: $PV_NAME  # Specific PV
EOF
```

**✅ Checkpoint:** Recovered from accidental deletion.

---

### Force Delete Stuck Resources (60 minutes)

```bash
# Stuck PVC (won't delete)
kubectl delete pvc stuck-pvc -n storage-debug
# Hangs...

# Check finalizers
kubectl get pvc stuck-pvc -n storage-debug -o yaml | grep finalizers

# Force delete by removing finalizers
kubectl patch pvc stuck-pvc -n storage-debug \
  -p '{"metadata":{"finalizers":null}}' --type=merge

kubectl delete pvc stuck-pvc -n storage-debug

# Stuck VolumeAttachment
kubectl get volumeattachment
kubectl delete volumeattachment <va-name> --force --grace-period=0
```

**✅ Checkpoint:** Handled stuck resources.

---

## ✅ Final Validation

### Complete Troubleshooting Checklist

Test each scenario:
- [ ] PVC stuck in Pending (StorageClass not found)
- [ ] PVC stuck in Pending (No matching PV)
- [ ] PVC stuck in Pending (WaitForFirstConsumer)
- [ ] Pod ContainerCreating (PVC not bound)
- [ ] Pod ContainerCreating (Multi-attach error)
- [ ] Permission denied (fsGroup solution)
- [ ] Permission denied (init container solution)
- [ ] Performance testing and diagnosis
- [ ] Recovery from PVC deletion
- [ ] Force delete stuck resources

---

## 🎓 Key Learnings

**Methodology:**
- Always check events first
- Systematic IGARRR approach
- Document everything

**Common Patterns:**
- Pending PVC → Check SC, PV, Provisioner
- ContainerCreating → Check PVC status, attachments
- Permission issues → Use fsGroup or init containers
- Performance → Test, measure, analyze

**Prevention:**
- Monitoring and alerts
- Resource quotas
- Documentation
- Regular testing

---

**Congratulations! You're now a storage troubleshooting expert! 🔧🚀**
