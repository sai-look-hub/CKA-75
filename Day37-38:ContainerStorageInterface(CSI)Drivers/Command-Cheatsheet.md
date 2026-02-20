# 📋 Command Cheatsheet: CSI Drivers

---

## 🔍 Inspection Commands

```bash
# List CSI drivers
kubectl get csidrivers
kubectl get csidriver -o wide

# Describe CSI driver
kubectl describe csidriver <driver-name>

# Get CSI driver in YAML
kubectl get csidriver <driver-name> -o yaml

# List StorageClasses
kubectl get sc
kubectl get storageclass

# Show provisioner for each StorageClass
kubectl get sc -o custom-columns=\
NAME:.metadata.name,\
PROVISIONER:.provisioner,\
RECLAIM:.reclaimPolicy

# Check if StorageClass uses CSI
kubectl get sc <sc-name> -o jsonpath='{.provisioner}'
# If ends with .csi.k8s.io or .csi.*, it's CSI

# List CSI pods
kubectl get pods -n kube-system | grep csi
kubectl get pods -A -l app.kubernetes.io/name=csi-driver
```

---

## 🔧 CSI Driver Management

```bash
# Check CSI controller pods
kubectl get pods -n kube-system -l app=csi-controller
kubectl get deployment -n kube-system -l app=csi-controller

# Check CSI node pods
kubectl get pods -n kube-system -l app=csi-node
kubectl get daemonset -n kube-system -l app=csi-node

# Check CSI driver logs
kubectl logs -n kube-system <csi-controller-pod> -c csi-provisioner
kubectl logs -n kube-system <csi-controller-pod> -c csi-attacher
kubectl logs -n kube-system <csi-controller-pod> -c driver

# Check node plugin logs
kubectl logs -n kube-system <csi-node-pod> -c node-driver-registrar
kubectl logs -n kube-system <csi-node-pod> -c driver

# Restart CSI controller
kubectl rollout restart deployment -n kube-system <csi-controller>

# Restart CSI node plugin
kubectl rollout restart daemonset -n kube-system <csi-node>
```

---

## 📦 StorageClass Operations

```bash
# Create StorageClass
kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: csi-storage
provisioner: <driver>.csi.k8s.io
parameters:
  # Driver-specific parameters
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
reclaimPolicy: Delete
EOF

# Set default StorageClass
kubectl patch storageclass <sc-name> \
  -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

# Remove default annotation
kubectl patch storageclass <sc-name> \
  -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'

# Get default StorageClass
kubectl get sc -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}'
```

---

## 🗂️ Volume Operations

```bash
# Create PVC with CSI StorageClass
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: csi-pvc
spec:
  accessModes:
  - ReadWriteOnce
  storageClassName: csi-storage
  resources:
    requests:
      storage: 10Gi
EOF

# Check PVC provisioned by CSI
kubectl get pvc
kubectl describe pvc <pvc-name>

# Check which CSI driver provisioned PV
kubectl get pv <pv-name> -o jsonpath='{.spec.csi.driver}'

# Check CSI volume handle
kubectl get pv <pv-name> -o jsonpath='{.spec.csi.volumeHandle}'

# Get all PVs using specific CSI driver
kubectl get pv -o json | \
  jq -r '.items[] | select(.spec.csi.driver=="<driver>") | .metadata.name'
```

---

## 🔗 VolumeAttachment Commands

```bash
# List volume attachments
kubectl get volumeattachment
kubectl get volumeattachment -o wide

# Describe volume attachment
kubectl describe volumeattachment <va-name>

# Get volume attachments for specific node
kubectl get volumeattachment -o json | \
  jq -r '.items[] | select(.spec.nodeName=="<node>") | .metadata.name'

# Check if volume is attached
kubectl get volumeattachment <va-name> -o jsonpath='{.status.attached}'
```

---

## 📸 Snapshot Commands

```bash
# Create VolumeSnapshotClass
kubectl apply -f - <<EOF
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotClass
metadata:
  name: csi-snapclass
driver: <driver>.csi.k8s.io
deletionPolicy: Delete
EOF

# Create VolumeSnapshot
kubectl apply -f - <<EOF
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: my-snapshot
spec:
  volumeSnapshotClassName: csi-snapclass
  source:
    persistentVolumeClaimName: my-pvc
EOF

# List snapshots
kubectl get volumesnapshot
kubectl get volumesnapshotcontent

# Check snapshot readiness
kubectl get volumesnapshot <snap> -o jsonpath='{.status.readyToUse}'

# Restore from snapshot
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: restored-pvc
spec:
  dataSource:
    name: my-snapshot
    kind: VolumeSnapshot
    apiGroup: snapshot.storage.k8s.io
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
EOF
```

---

## 🧪 Testing Commands

```bash
# Test CSI provisioning
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: csi-storage
  resources:
    requests:
      storage: 1Gi
---
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
spec:
  containers:
  - name: test
    image: busybox
    command: ['sh', '-c', 'echo "CSI test" > /data/test.txt && sleep 3600']
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: test-pvc
EOF

# Verify
kubectl exec test-pod -- cat /data/test.txt

# Test volume expansion (if supported)
kubectl patch pvc test-pvc -p '{"spec":{"resources":{"requests":{"storage":"2Gi"}}}}'

# Cleanup
kubectl delete pod test-pod
kubectl delete pvc test-pvc
```

---

## 💡 Useful One-Liners

```bash
# List all CSI drivers and their versions
kubectl get pods -n kube-system -o json | \
  jq -r '.items[] | select(.metadata.name | contains("csi")) | 
    "\(.metadata.name): \(.spec.containers[].image)"'

# Find which driver provisioned a PVC
kubectl get pvc <pvc> -o jsonpath='{.metadata.annotations.volume\.kubernetes\.io/storage-provisioner}'

# Count PVCs per StorageClass
kubectl get pvc -A -o json | \
  jq -r '.items[] | .spec.storageClassName' | \
  sort | uniq -c

# List PVs with CSI driver and volume handle
kubectl get pv -o custom-columns=\
NAME:.metadata.name,\
DRIVER:.spec.csi.driver,\
HANDLE:.spec.csi.volumeHandle

# Check CSI driver capabilities
kubectl get csidriver -o json | \
  jq -r '.items[] | "\(.metadata.name): 
    attachRequired=\(.spec.attachRequired), 
    podInfoOnMount=\(.spec.podInfoOnMount)"'
```

---

**Pro Tip:** Create aliases for frequently used CSI commands! 🚀
