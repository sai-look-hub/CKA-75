# 🔧 Troubleshooting: CSI Drivers

---

## 🔴 Issue 1: PVC Stuck in Pending

**Symptoms:**
```bash
kubectl get pvc
# NAME     STATUS    VOLUME
# my-pvc   Pending
```

**Common Causes:**

**Cause 1: CSI driver not installed**
```bash
kubectl get csidrivers
# No drivers listed

# Solution: Install CSI driver
```

**Cause 2: Wrong provisioner in StorageClass**
```bash
kubectl describe sc my-storage-class
# Provisioner: wrong-driver.csi.k8s.io (doesn't exist)

# Solution: Fix provisioner name
kubectl get csidrivers  # See available drivers
```

**Cause 3: CSI controller not running**
```bash
kubectl get pods -n kube-system | grep csi

# No controller pods running

# Solution: Check controller deployment
kubectl get deployment -n kube-system -l app=csi-controller
kubectl logs -n kube-system <csi-controller-pod>
```

**Cause 4: WaitForFirstConsumer and no pod**
```bash
kubectl get sc -o custom-columns=NAME:.metadata.name,BINDING:.volumeBindingMode
# Shows: WaitForFirstConsumer

# Solution: Create pod using the PVC
```

---

## 💥 Issue 2: CSI Controller Pod CrashLooping

**Symptoms:**
```bash
kubectl get pods -n kube-system | grep csi-controller
# csi-controller-xxx   2/5   CrashLoopBackOff
```

**Diagnosis:**
```bash
# Check all container logs
kubectl logs -n kube-system <csi-controller-pod> -c csi-provisioner
kubectl logs -n kube-system <csi-controller-pod> -c csi-attacher
kubectl logs -n kube-system <csi-controller-pod> -c driver

# Check events
kubectl describe pod -n kube-system <csi-controller-pod>
```

**Common Issues:**

**Issue 1: Missing RBAC permissions**
```bash
# Error in logs: "forbidden: User cannot create persistentvolumes"

# Solution: Verify ServiceAccount and RBAC
kubectl get serviceaccount -n kube-system csi-controller
kubectl get clusterrole csi-controller-role
kubectl get clusterrolebinding csi-controller-binding
```

**Issue 2: Missing secrets**
```bash
# Error: "secret not found"

# Solution: Create required secrets
# Example for Ceph:
kubectl create secret generic csi-rbd-secret \
  --from-literal=userID=admin \
  --from-literal=userKey=<key>
```

---

## 🖥️ Issue 3: CSI Node Plugin Issues

**Symptoms:**
```bash
# Pod stuck in ContainerCreating
kubectl get pods
# my-pod   0/1   ContainerCreating
```

**Diagnosis:**
```bash
kubectl describe pod my-pod
# Events: FailedMount: MountVolume.MountDevice failed

# Check CSI node plugin
kubectl get pods -n kube-system -l app=csi-node

# Check logs
kubectl logs -n kube-system <csi-node-pod> -c driver
```

**Common Issues:**

**Issue 1: Node plugin not running on node**
```bash
# Check DaemonSet
kubectl get daemonset -n kube-system csi-node

# Check if pod on specific node
kubectl get pods -n kube-system -l app=csi-node -o wide

# Solution: Ensure DaemonSet tolerates node taints
```

**Issue 2: Mount propagation not enabled**
```bash
# Error in logs: "mount propagation is not enabled"

# Solution: Enable in kubelet
# Edit /var/lib/kubelet/config.yaml
# Set: featureGates.MountPropagation: true
# Restart kubelet
```

---

## 📸 Issue 4: Volume Snapshot Fails

**Symptoms:**
```bash
kubectl get volumesnapshot my-snapshot
# READYTOUSE: false
```

**Diagnosis:**
```bash
kubectl describe volumesnapshot my-snapshot
# Check Status.Error

# Check snapshotter logs
kubectl logs -n kube-system <csi-controller-pod> -c csi-snapshotter
```

**Common Issues:**

**Issue 1: Driver doesn't support snapshots**
```bash
# Check driver capabilities
kubectl get csidriver <driver> -o yaml
# Look for volumeSnapshotSupport or similar

# Solution: Use different driver or disable snapshots
```

**Issue 2: VolumeSnapshotClass missing**
```bash
kubectl get volumesnapshotclass
# No resources found

# Solution: Create VolumeSnapshotClass
```

---

## 🔍 Debugging Commands

```bash
# Check CSI drivers
kubectl get csidrivers
kubectl describe csidriver <driver-name>

# Check CSI pods
kubectl get pods -n kube-system | grep csi
kubectl logs -n kube-system <pod> -c <container>

# Check StorageClass
kubectl get sc
kubectl describe sc <sc-name>

# Check PVC/PV binding
kubectl get pvc
kubectl get pv
kubectl describe pv <pv-name> | grep -A10 Source

# Check volume attachment (for troubleshooting attach issues)
kubectl get volumeattachment
kubectl describe volumeattachment <name>

# Check events
kubectl get events --sort-by=.metadata.creationTimestamp

# Check CSI sidecar versions
kubectl get pod -n kube-system <csi-controller> -o yaml | grep image:
```

---

## 📊 Common Error Messages

| Error | Meaning | Solution |
|-------|---------|----------|
| `driver not found` | CSI driver not registered | Install/restart CSI driver |
| `volume not attached` | Attach step failed | Check external-attacher logs |
| `mount failed` | Node plugin mount error | Check CSI node pod logs |
| `snapshot not ready` | Snapshot creation failed | Check snapshotter logs |
| `expansion not supported` | Driver doesn't support resize | Use driver that supports expansion |
| `forbidden: User cannot create` | RBAC issue | Fix ServiceAccount permissions |

---

**Pro Tip:** Always check CSI driver logs for detailed error messages! 🔍
