# 📖 GUIDEME: CSI Drivers - Complete Walkthrough

## 🎯 Learning Path Overview

16-hour structured learning experience across 2 days, from CSI basics to deploying production applications.

---

## ⏱️ Time Allocation

**Day 1 (8 hours):**
- Hours 1-2: CSI architecture and concepts
- Hours 3-4: Installing CSI driver
- Hours 5-6: Dynamic provisioning with CSI
- Hours 7-8: Testing CSI features

**Day 2 (8 hours):**
- Hours 1-2: Volume snapshots with CSI
- Hours 3-4: Volume cloning and expansion
- Hours 5-6: Multi-driver application deployment
- Hours 7-8: Troubleshooting and best practices

---

## 📚 Phase 1: Understanding CSI (2 hours)

### Step 1: Explore Existing Storage (30 minutes)

```bash
# Check current StorageClasses
kubectl get storageclass

# Check which provisioner is used
kubectl get sc -o custom-columns=\
NAME:.metadata.name,\
PROVISIONER:.provisioner

# For minikube (usually has standard class)
kubectl describe sc standard

# Check if it's CSI-based
kubectl get sc standard -o yaml | grep provisioner
# If it shows "k8s.io/minikube-hostpath", it's in-tree
# If it shows "*.csi.k8s.io", it's CSI

# Check existing CSI drivers
kubectl get csidrivers
```

**✅ Checkpoint:** Understand current storage setup.

---

### Step 2: CSI Architecture Exploration (60 minutes)

```bash
# If you have CSI drivers installed, examine components

# For cloud providers (EKS, GKE, AKS), drivers are pre-installed
# Check CSI driver pods
kubectl get pods -n kube-system | grep csi

# Typical components you'll see:
# - csi-***-controller (StatefulSet/Deployment)
# - csi-***-node (DaemonSet)

# Example for AWS EBS CSI driver on EKS:
kubectl get pods -n kube-system -l app=ebs-csi-controller
kubectl get pods -n kube-system -l app=ebs-csi-node

# Examine controller pod
kubectl describe pod -n kube-system <csi-controller-pod>

# Look for containers:
# - csi-provisioner (external-provisioner sidecar)
# - csi-attacher (external-attacher sidecar)
# - csi-snapshotter (external-snapshotter sidecar)
# - csi-resizer (external-resizer sidecar)
# - ebs-plugin (actual driver)
# - liveness-probe

# Examine node pod (DaemonSet)
kubectl describe pod -n kube-system <csi-node-pod>

# Look for containers:
# - node-driver-registrar
# - ebs-plugin
# - liveness-probe
```

**Key observations:**
- Controller: Single pod with multiple sidecars
- Node: DaemonSet (one per node)
- Each sidecar has specific responsibility

**✅ Checkpoint:** Understanding CSI component architecture.

---

### Step 3: CSI Driver Registration (30 minutes)

```bash
# CSI drivers register with kubelet
# Check registered drivers

# On each node, kubelet knows about CSI drivers
# Check CSIDriver resource
kubectl get csidrivers

# Describe a CSI driver
kubectl describe csidriver <driver-name>

# Key fields:
# - spec.attachRequired: Does volume need attach step?
# - spec.podInfoOnMount: Pass pod info to driver?
# - spec.volumeLifecycleModes: Persistent, Ephemeral, both?

# Example CSIDriver object
kubectl get csidriver <name> -o yaml
```

**✅ Checkpoint:** Understanding CSI driver registration.

---

## 🔧 Phase 2: Installing CSI Driver (2 hours)

### Step 1: Install Local Path Provisioner (45 minutes)

We'll use Rancher's Local Path Provisioner - a simple CSI driver for local storage.

```bash
# Install local-path-provisioner
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml

# Watch deployment
kubectl get pods -n local-path-storage -w

# Should see:
# local-path-provisioner-xxx   Running

# Verify CSI driver registered
kubectl get csidrivers
# Should include: rancher.io/local-path

# Check StorageClass created
kubectl get sc local-path
```

**✅ Checkpoint:** Local Path Provisioner installed.

---

### Step 2: Examine Driver Components (45 minutes)

```bash
# Get provisioner pod
kubectl get pods -n local-path-storage

POD=$(kubectl get pod -n local-path-storage -l app=local-path-provisioner -o jsonpath='{.items[0].metadata.name}')

# Examine pod spec
kubectl describe pod -n local-path-storage $POD

# Check containers
kubectl get pod -n local-path-storage $POD -o jsonpath='{.spec.containers[*].name}'

# View logs
kubectl logs -n local-path-storage $POD

# Check what it's watching
# Should show: Watching for PVCs with storageClass: local-path

# Examine DaemonSet (note: local-path-provisioner uses Deployment, not DaemonSet)
# But in real CSI drivers, you'd check:
# kubectl get daemonset -n <namespace>
```

**✅ Checkpoint:** Understanding driver internals.

---

### Step 3: Configure Custom StorageClass (30 minutes)

```bash
# Create custom StorageClass
kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-path-custom
provisioner: rancher.io/local-path
parameters:
  # Custom path on nodes
  nodePath: /opt/local-path-provisioner
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
allowVolumeExpansion: false
EOF

# Verify
kubectl get sc local-path-custom
kubectl describe sc local-path-custom
```

**✅ Checkpoint:** Custom StorageClass created.

---

## 📦 Phase 3: Dynamic Provisioning (2 hours)

### Step 1: Create PVC with CSI (30 minutes)

```bash
# Create PVC using local-path StorageClass
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: csi-pvc
spec:
  accessModes:
  - ReadWriteOnce
  storageClassName: local-path
  resources:
    requests:
      storage: 1Gi
EOF

# Watch PVC status
kubectl get pvc csi-pvc -w

# Initially Pending (WaitForFirstConsumer)
# STATUS: Pending

# PV not created yet
kubectl get pv
```

**Why Pending?**
- VolumeBindingMode: WaitForFirstConsumer
- Waits for pod to be scheduled

**✅ Checkpoint:** PVC created in Pending state.

---

### Step 2: Deploy Pod Using CSI Volume (45 minutes)

```bash
# Create pod using the PVC
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: csi-app
spec:
  containers:
  - name: app
    image: busybox
    command: ['sh', '-c', 'echo "CSI Volume Data: $(date)" > /data/test.txt && sleep 3600']
    volumeMounts:
    - name: csi-storage
      mountPath: /data
  volumes:
  - name: csi-storage
    persistentVolumeClaim:
      claimName: csi-pvc
EOF

# Watch pod creation
kubectl get pod csi-app -w

# Now PVC should bind
kubectl get pvc csi-pvc
# STATUS: Bound

# PV created automatically
kubectl get pv

# Examine PV
PV=$(kubectl get pvc csi-pvc -o jsonpath='{.spec.volumeName}')
kubectl describe pv $PV

# Key fields:
# Source.CSI.Driver: rancher.io/local-path
# Source.CSI.VolumeHandle: <unique-id>
```

**✅ Checkpoint:** Dynamic provisioning working!

---

### Step 3: Verify Data and CSI Operations (45 minutes)

```bash
# Check data in pod
kubectl exec csi-app -- cat /data/test.txt

# Check where data is stored on node
# For minikube:
minikube ssh

# Look for volume
sudo find /opt/local-path-provisioner -name "*" -type f
# or
sudo ls -R /opt/local-path-provisioner

exit

# For kind:
docker exec kind-control-plane find /opt/local-path-provisioner -type f

# Add more data
kubectl exec csi-app -- sh -c 'echo "More data" >> /data/test.txt'

# Delete pod
kubectl delete pod csi-app

# PVC still bound
kubectl get pvc csi-pvc

# Recreate pod
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: csi-app-2
spec:
  containers:
  - name: app
    image: busybox
    command: ['sleep', '3600']
    volumeMounts:
    - name: csi-storage
      mountPath: /data
  volumes:
  - name: csi-storage
    persistentVolumeClaim:
      claimName: csi-pvc
EOF

# Data persists!
kubectl exec csi-app-2 -- cat /data/test.txt
```

**✅ Checkpoint:** Data persistence verified.

---

## 📸 Phase 4: CSI Snapshots (2 hours)

### Step 1: Install Snapshot CRDs (if not installed) (30 minutes)

```bash
# Check if VolumeSnapshot CRDs exist
kubectl get crd | grep snapshot

# If not present, install
kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/client/config/crd/snapshot.storage.k8s.io_volumesnapshotclasses.yaml

kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/client/config/crd/snapshot.storage.k8s.io_volumesnapshotcontents.yaml

kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/client/config/crd/snapshot.storage.k8s.io_volumesnapshots.yaml

# Verify
kubectl get crd | grep snapshot
```

**Note:** Local Path Provisioner doesn't support snapshots.
For snapshot testing, you'd need a CSI driver that supports it (like hostpath driver).

---

### Step 2: Install CSI Hostpath Driver (for snapshot testing) (60 minutes)

```bash
# Clone the repo
git clone https://github.com/kubernetes-csi/csi-driver-host-path.git
cd csi-driver-host-path

# Deploy
./deploy/kubernetes-latest/deploy.sh

# Verify deployment
kubectl get pods -n default | grep csi-hostpath

# Should see:
# csi-hostpath-plugin-0 (controller)
# csi-hostpathplugin-xxx (node - DaemonSet)

# Check CSI driver
kubectl get csidriver hostpath.csi.k8s.io

# Get the default StorageClass
kubectl get sc csi-hostpath-sc
```

**✅ Checkpoint:** Snapshot-capable driver installed.

---

### Step 3: Test Snapshots (30 minutes)

```bash
# Create PVC with hostpath driver
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: snapshot-test-pvc
spec:
  accessModes:
  - ReadWriteOnce
  storageClassName: csi-hostpath-sc
  resources:
    requests:
      storage: 1Gi
EOF

# Create pod with data
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: snapshot-app
spec:
  containers:
  - name: app
    image: busybox
    command: ['sh', '-c', 'echo "Original data" > /data/file.txt && sleep 3600']
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: snapshot-test-pvc
EOF

kubectl wait --for=condition=ready pod/snapshot-app --timeout=60s

# Create VolumeSnapshotClass
kubectl apply -f - <<EOF
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotClass
metadata:
  name: csi-hostpath-snapclass
driver: hostpath.csi.k8s.io
deletionPolicy: Delete
EOF

# Create snapshot
kubectl apply -f - <<EOF
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: test-snapshot
spec:
  volumeSnapshotClassName: csi-hostpath-snapclass
  source:
    persistentVolumeClaimName: snapshot-test-pvc
EOF

# Wait for snapshot
kubectl wait --for=jsonpath='{.status.readyToUse}'=true \
  volumesnapshot/test-snapshot --timeout=60s

# Verify
kubectl get volumesnapshot test-snapshot
```

**✅ Checkpoint:** CSI snapshots working!

---

## 🧬 Phase 5: Volume Cloning and Expansion (2 hours)

### Step 1: Test Volume Cloning (60 minutes)

```bash
# Clone PVC
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: cloned-pvc
spec:
  dataSource:
    name: snapshot-test-pvc
    kind: PersistentVolumeClaim
  accessModes:
  - ReadWriteOnce
  storageClassName: csi-hostpath-sc
  resources:
    requests:
      storage: 1Gi
EOF

# Create pod with cloned PVC
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: cloned-app
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
      claimName: cloned-pvc
EOF

kubectl wait --for=condition=ready pod/cloned-app --timeout=60s

# Verify data was cloned
kubectl exec cloned-app -- cat /data/file.txt
# Should show: Original data
```

**✅ Checkpoint:** Volume cloning working!

---

### Step 2: Test Volume Expansion (60 minutes)

```bash
# Check if StorageClass allows expansion
kubectl get sc csi-hostpath-sc -o yaml | grep allowVolumeExpansion

# If false, patch it
kubectl patch sc csi-hostpath-sc -p '{"allowVolumeExpansion":true}'

# Expand PVC
kubectl patch pvc snapshot-test-pvc -p '{"spec":{"resources":{"requests":{"storage":"2Gi"}}}}'

# Watch for expansion
kubectl get pvc snapshot-test-pvc -w

# Check expanded size
kubectl exec snapshot-app -- df -h /data
```

**✅ Checkpoint:** Volume expansion tested.

---

## 🚀 Phase 6: Multi-Driver Application (3 hours)

See the `csi-application.yaml` file for complete deployment.

### Deploy Complete Stack (90 minutes)

```bash
# Deploy application with multiple CSI features
kubectl apply -f csi-application.yaml

# Watch deployment
kubectl get pods -w

# Verify all components
kubectl get pvc
kubectl get pods
kubectl get volumesnapshots
```

---

### Test All Features (90 minutes)

```bash
# Test dynamic provisioning
kubectl exec <app-pod> -- df -h /data

# Test snapshots
kubectl get volumesnapshot

# Test cloning
kubectl get pvc cloned-*

# Test expansion
kubectl patch pvc <pvc> -p '{"spec":{"resources":{"requests":{"storage":"5Gi"}}}}'
```

---

## ✅ Final Validation Checklist

### CSI Basics
- [ ] Understand CSI architecture
- [ ] Identify CSI components (Controller, Node)
- [ ] Recognize external sidecars
- [ ] Explain CSI vs in-tree plugins

### Driver Installation
- [ ] Install CSI driver
- [ ] Verify driver registration
- [ ] Create StorageClass
- [ ] Configure driver parameters

### Features
- [ ] Dynamic provisioning
- [ ] Volume snapshots
- [ ] Volume cloning
- [ ] Volume expansion
- [ ] Topology awareness

### Production Readiness
- [ ] Resource limits set
- [ ] Health probes configured
- [ ] RBAC properly configured
- [ ] Monitoring in place

---

## 🧹 Cleanup

```bash
# Delete all test resources
kubectl delete pod csi-app csi-app-2 snapshot-app cloned-app
kubectl delete pvc csi-pvc snapshot-test-pvc cloned-pvc
kubectl delete volumesnapshot test-snapshot

# Uninstall hostpath driver (if installed)
cd csi-driver-host-path
./deploy/kubernetes-latest/destroy.sh

# Uninstall local-path-provisioner
kubectl delete -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml
```

---

## 🎓 Key Learnings

**CSI Architecture:**
- Controller: Cluster-level operations (create, attach, snapshot)
- Node: Node-level operations (mount, unmount, stats)
- Sidecars: Standard functionality across all drivers

**CSI Benefits:**
- Out-of-tree (separate from K8s core)
- Vendor independence
- Faster feature releases
- Better security

**CSI Features:**
- Dynamic provisioning (automatic PV creation)
- Snapshots (point-in-time backups)
- Cloning (copy existing volumes)
- Expansion (resize volumes online)
- Topology (zone/region awareness)

**Best Practices:**
- Use specific driver versions
- Set resource limits
- Configure health probes
- Use WaitForFirstConsumer binding
- Monitor driver health
- Test in non-production first

---

**Congratulations! You've mastered CSI drivers! 🔌🚀**
