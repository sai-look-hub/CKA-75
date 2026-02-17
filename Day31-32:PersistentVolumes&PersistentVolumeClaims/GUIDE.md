# 📖 GUIDEME: Persistent Volumes & PVCs - Complete Learning Path

## 🎯 Overview

16-hour structured learning experience across 2 days, from PV/PVC basics to deploying production databases with persistent storage.

---

## ⏱️ Time Allocation

**Day 1 (8 hours):**
- Hours 1-2: Understanding PV/PVC concepts
- Hours 3-4: Static provisioning hands-on
- Hours 5-6: StorageClasses and dynamic provisioning
- Hours 7-8: Access modes and reclaim policies

**Day 2 (8 hours):**
- Hours 1-2: Database deployment project
- Hours 3-4: Advanced scenarios (expansion, snapshots)
- Hours 5-6: Troubleshooting and debugging
- Hours 7-8: Production best practices and review

---

## 📚 Phase 1: Understanding PV/PVC (2 hours)

### Step 1: The Storage Problem (30 minutes)

Let's see why we need persistent storage:

```bash
# Create a pod with emptyDir
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: data-loss-demo
spec:
  containers:
  - name: app
    image: postgres:15-alpine
    env:
    - name: POSTGRES_PASSWORD
      value: testpass
    volumeMounts:
    - name: data
      mountPath: /var/lib/postgresql/data
  volumes:
  - name: data
    emptyDir: {}
EOF

# Wait for it to initialize
kubectl wait --for=condition=ready pod/data-loss-demo --timeout=60s

# Create a database
kubectl exec data-loss-demo -- psql -U postgres -c "CREATE DATABASE testdb;"
kubectl exec data-loss-demo -- psql -U postgres -c "\\l"

# Delete and recreate pod
kubectl delete pod data-loss-demo
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: data-loss-demo
spec:
  containers:
  - name: app
    image: postgres:15-alpine
    env:
    - name: POSTGRES_PASSWORD
      value: testpass
    volumeMounts:
    - name: data
      mountPath: /var/lib/postgresql/data
  volumes:
  - name: data
    emptyDir: {}
EOF

kubectl wait --for=condition=ready pod/data-loss-demo --timeout=60s

# Try to list databases
kubectl exec data-loss-demo -- psql -U postgres -c "\\l"
# testdb is GONE! 😱

kubectl delete pod data-loss-demo
```

**💡 Key Problem**: emptyDir data is lost when pod is deleted. We need persistent storage!

---

### Step 2: PV and PVC Basics (60 minutes)

```bash
# Create a PersistentVolume (admin task)
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-demo
  labels:
    type: local
spec:
  capacity:
    storage: 1Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  hostPath:
    path: /mnt/data
    type: DirectoryOrCreate
EOF

# Check PV status
kubectl get pv
# STATUS should be "Available"

# View PV details
kubectl describe pv pv-demo

# Create a PVC (user task)
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-demo
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 500Mi
  storageClassName: manual
EOF

# Watch the binding happen
kubectl get pvc pvc-demo -w
# STATUS: Pending → Bound

# Check PV is now bound
kubectl get pv pv-demo
# STATUS changed to "Bound"

# Verify binding
kubectl describe pvc pvc-demo | grep "Volume:"
```

**✅ Checkpoint**: PVC successfully bound to PV.

---

### Step 3: Using PVC in a Pod (30 minutes)

```bash
# Create pod using the PVC
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: pvc-pod
spec:
  containers:
  - name: app
    image: busybox
    command: ['sh', '-c', 'echo "Persistent data: $(date)" >> /data/log.txt && cat /data/log.txt && sleep 3600']
    volumeMounts:
    - name: storage
      mountPath: /data
  volumes:
  - name: storage
    persistentVolumeClaim:
      claimName: pvc-demo
EOF

kubectl wait --for=condition=ready pod/pvc-pod --timeout=60s

# Check the data
kubectl logs pvc-pod

# Write more data
kubectl exec pvc-pod -- sh -c 'echo "Additional data" >> /data/log.txt'

# Delete and recreate pod
kubectl delete pod pvc-pod

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: pvc-pod
spec:
  containers:
  - name: app
    image: busybox
    command: ['sh', '-c', 'cat /data/log.txt && sleep 3600']
    volumeMounts:
    - name: storage
      mountPath: /data
  volumes:
  - name: storage
    persistentVolumeClaim:
      claimName: pvc-demo
EOF

kubectl wait --for=condition=ready pod/pvc-pod --timeout=60s

# Data persists!
kubectl logs pvc-pod
```

**✅ Checkpoint**: Data survives pod deletion!

---

## 🔧 Phase 2: Static Provisioning (2 hours)

### Step 1: Multiple PVs and PVCs (45 minutes)

```bash
# Create directory on node for hostPath
# For minikube
minikube ssh "sudo mkdir -p /mnt/disks/vol1 /mnt/disks/vol2 /mnt/disks/vol3"

# For kind
docker exec kind-control-plane mkdir -p /mnt/disks/vol1 /mnt/disks/vol2 /mnt/disks/vol3

# Create multiple PVs
kubectl apply -f pv-static-multiple.yaml

# Check all PVs
kubectl get pv

# Create PVCs with different requirements
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: small-pvc
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: manual
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: medium-pvc
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 3Gi
  storageClassName: manual
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: large-pvc
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 8Gi
  storageClassName: manual
EOF

# Watch binding
kubectl get pvc -w

# See which PV each PVC got
kubectl get pvc
kubectl get pv
```

**✅ Checkpoint**: Multiple PVCs bound to appropriate PVs.

---

### Step 2: Access Modes Testing (45 minutes)

```bash
# Test ReadWriteOnce
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-rwo
spec:
  capacity:
    storage: 1Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  hostPath:
    path: /mnt/rwo
    type: DirectoryOrCreate
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-rwo
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: manual
EOF

# Deploy pod using RWO volume
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: pod-rwo-1
spec:
  containers:
  - name: app
    image: busybox
    command: ['sh', '-c', 'while true; do echo "Pod 1: $(date)" >> /data/log.txt; sleep 5; done']
    volumeMounts:
    - name: storage
      mountPath: /data
  volumes:
  - name: storage
    persistentVolumeClaim:
      claimName: pvc-rwo
EOF

# Try to create second pod on different node (if multi-node)
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: pod-rwo-2
spec:
  containers:
  - name: app
    image: busybox
    command: ['sh', '-c', 'cat /data/log.txt']
    volumeMounts:
    - name: storage
      mountPath: /data
  volumes:
  - name: storage
    persistentVolumeClaim:
      claimName: pvc-rwo
  nodeSelector:
    # Try to force different node
    kubernetes.io/hostname: different-node
EOF

# Check pod status
kubectl get pods -o wide

# For single-node cluster, both pods can use same PVC
# For multi-node, second pod may be pending
```

**✅ Checkpoint**: Understanding RWO behavior.

---

### Step 3: Reclaim Policy Testing (30 minutes)

```bash
# Create PV with Retain policy
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-retain
spec:
  capacity:
    storage: 1Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  hostPath:
    path: /mnt/retain-test
    type: DirectoryOrCreate
EOF

# Create PVC and pod
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-retain
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: manual
---
apiVersion: v1
kind: Pod
metadata:
  name: pod-retain
spec:
  containers:
  - name: app
    image: busybox
    command: ['sh', '-c', 'echo "Important data" > /data/important.txt && sleep 3600']
    volumeMounts:
    - name: storage
      mountPath: /data
  volumes:
  - name: storage
    persistentVolumeClaim:
      claimName: pvc-retain
EOF

kubectl wait --for=condition=ready pod/pod-retain --timeout=60s

# Verify data written
kubectl exec pod-retain -- cat /data/important.txt

# Delete PVC
kubectl delete pvc pvc-retain

# Check PV status
kubectl get pv pv-retain
# STATUS: Released (not Available!)

# Data still on disk
minikube ssh "cat /mnt/retain-test/important.txt"
# or
docker exec kind-control-plane cat /mnt/retain-test/important.txt

# Cleanup (admin must manually clean)
kubectl delete pv pv-retain
```

**✅ Checkpoint**: Understand Retain policy preserves data.

---

## 🚀 Phase 3: Dynamic Provisioning (2 hours)

### Step 1: Create StorageClass (30 minutes)

```bash
# For local testing, create local storage class
kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-storage
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
EOF

# View available storage classes
kubectl get storageclass

# For cloud providers, you might see:
# kubectl get sc
# NAME            PROVISIONER
# gp2             kubernetes.io/aws-ebs
# standard        kubernetes.io/gce-pd
# managed-csi     disk.csi.azure.com

# Set default storage class (optional)
kubectl patch storageclass local-storage -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

**✅ Checkpoint**: StorageClass created.

---

### Step 2: Dynamic PVC Creation (45 minutes)

```bash
# Create PVC without pre-creating PV
# (For local, we still need to create PV manually as no-provisioner doesn't auto-create)
# But the concept is important for cloud environments

# In cloud environment, this would auto-provision:
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: dynamic-pvc
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
  storageClassName: standard  # Use your cloud's default
EOF

# For local testing, simulate dynamic provisioning:
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-dynamic-1
spec:
  capacity:
    storage: 5Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Delete
  storageClassName: local-storage
  local:
    path: /mnt/disks/dynamic1
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - $(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: dynamic-pvc
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
  storageClassName: local-storage
EOF

# Check binding
kubectl get pvc dynamic-pvc
kubectl get pv pv-dynamic-1
```

**✅ Checkpoint**: Dynamic provisioning workflow understood.

---

### Step 3: Volume Binding Modes (45 minutes)

```bash
# Create StorageClass with WaitForFirstConsumer
kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: wait-for-consumer
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
EOF

# Create PVC
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-wait
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: wait-for-consumer
EOF

# PVC stays Pending (no PV yet)
kubectl get pvc pvc-wait
# STATUS: Pending

# Create PV
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-wait
spec:
  capacity:
    storage: 1Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Delete
  storageClassName: wait-for-consumer
  hostPath:
    path: /mnt/wait
    type: DirectoryOrCreate
EOF

# PVC still Pending (waiting for consumer)
kubectl get pvc pvc-wait

# Create pod using PVC
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: consumer-pod
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
      claimName: pvc-wait
EOF

# Now it binds!
kubectl get pvc pvc-wait
# STATUS: Bound
```

**✅ Checkpoint**: WaitForFirstConsumer behavior demonstrated.

---

## 💾 Phase 4: Database Project (4 hours)

### Step 1: Setup Storage for PostgreSQL (60 minutes)

```bash
# Create namespace
kubectl create namespace database

# Create secret for password
kubectl create secret generic postgres-secret \
  --from-literal=password=supersecret \
  -n database

# Create PVC
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-pvc
  namespace: database
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  storageClassName: local-storage
EOF

# For local testing, create matching PV
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: postgres-pv
spec:
  capacity:
    storage: 10Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-storage
  hostPath:
    path: /mnt/postgres-data
    type: DirectoryOrCreate
EOF

# Verify binding
kubectl get pvc -n database
```

**✅ Checkpoint**: Storage ready for database.

---

### Step 2: Deploy PostgreSQL (90 minutes)

```bash
# Deploy PostgreSQL StatefulSet
kubectl apply -f postgres-statefulset.yaml

# Wait for pod to be ready
kubectl wait --for=condition=ready pod/postgres-0 -n database --timeout=120s

# Check pod status
kubectl get pods -n database

# Check logs
kubectl logs postgres-0 -n database

# Connect to database
kubectl exec -it postgres-0 -n database -- psql -U postgres

# Inside psql:
CREATE DATABASE testdb;
CREATE TABLE users (id SERIAL PRIMARY KEY, name VARCHAR(50));
INSERT INTO users (name) VALUES ('Alice'), ('Bob'), ('Charlie');
SELECT * FROM users;
\q
```

**✅ Checkpoint**: Database running with persistent storage.

---

### Step 3: Test Data Persistence (60 minutes)

```bash
# Insert more data
kubectl exec -it postgres-0 -n database -- psql -U postgres -d testdb -c \
  "INSERT INTO users (name) VALUES ('Dave'), ('Eve');"

# Query data
kubectl exec -it postgres-0 -n database -- psql -U postgres -d testdb -c \
  "SELECT * FROM users;"

# Delete the pod (not the PVC!)
kubectl delete pod postgres-0 -n database

# Wait for StatefulSet to recreate it
kubectl wait --for=condition=ready pod/postgres-0 -n database --timeout=120s

# Data should still be there!
kubectl exec -it postgres-0 -n database -- psql -U postgres -d testdb -c \
  "SELECT * FROM users;"

# Check the data on host (optional)
minikube ssh "sudo ls -la /mnt/postgres-data/pgdata/"
```

**✅ Checkpoint**: Data persists across pod restarts!

---

### Step 4: Deploy Application Using Database (30 minutes)

```bash
# Deploy a simple app that uses the database
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: db-client
  namespace: database
spec:
  containers:
  - name: client
    image: postgres:15-alpine
    command:
    - sh
    - -c
    - |
      while true; do
        echo "Querying database..."
        psql -h postgres -U postgres -d testdb -c "SELECT COUNT(*) FROM users;"
        sleep 10
      done
    env:
    - name: PGPASSWORD
      valueFrom:
        secretKeyRef:
          name: postgres-secret
          key: password
EOF

# Watch the logs
kubectl logs -f db-client -n database

# Clean up client
kubectl delete pod db-client -n database
```

**✅ Checkpoint**: Application successfully uses persistent database.

---

## 🔬 Phase 5: Advanced Topics (2 hours)

### Exercise 1: Volume Expansion (45 minutes)

```bash
# Check if StorageClass allows expansion
kubectl get sc local-storage -o yaml | grep allowVolumeExpansion

# If not enabled, update it
kubectl patch sc local-storage -p '{"allowVolumeExpansion": true}'

# Expand existing PVC
kubectl patch pvc postgres-pvc -n database -p '{"spec":{"resources":{"requests":{"storage":"20Gi"}}}}'

# Check expansion status
kubectl get pvc postgres-pvc -n database -w

# For some storage types, may need to restart pod
kubectl delete pod postgres-0 -n database

# Verify new size
kubectl exec postgres-0 -n database -- df -h /var/lib/postgresql/data
```

---

### Exercise 2: Cloning Volumes (30 minutes)

```bash
# Create a PVC from existing PVC
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-clone
  namespace: database
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  storageClassName: local-storage
  dataSource:
    kind: PersistentVolumeClaim
    name: postgres-pvc
EOF

# This creates a copy of the data
# Useful for testing, staging, etc.
```

---

### Exercise 3: Volume Snapshots (45 minutes)

```bash
# Note: Requires VolumeSnapshot CRDs and CSI driver
# This is a conceptual example

# Create VolumeSnapshot
kubectl apply -f - <<EOF
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: postgres-snapshot
  namespace: database
spec:
  volumeSnapshotClassName: csi-hostpath-snapclass
  source:
    persistentVolumeClaimName: postgres-pvc
EOF

# Restore from snapshot
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-restored
  namespace: database
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  storageClassName: local-storage
  dataSource:
    kind: VolumeSnapshot
    apiGroup: snapshot.storage.k8s.io
    name: postgres-snapshot
EOF
```

---

## 🧪 Phase 6: Testing & Validation (2 hours)

### Test Suite 1: PV/PVC Lifecycle

```bash
# Create test script
cat > test-pv-lifecycle.sh << 'SCRIPT'
#!/bin/bash
set -e

echo "1. Creating PV..."
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: test-pv
spec:
  capacity:
    storage: 1Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  hostPath:
    path: /mnt/test-pv
    type: DirectoryOrCreate
EOF

echo "2. PV should be Available..."
kubectl wait --for=jsonpath='{.status.phase}'=Available pv/test-pv --timeout=30s

echo "3. Creating PVC..."
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: manual
EOF

echo "4. PVC should bind..."
kubectl wait --for=jsonpath='{.status.phase}'=Bound pvc/test-pvc --timeout=30s

echo "5. PV should be Bound..."
kubectl get pv test-pv -o jsonpath='{.status.phase}'

echo "6. Creating pod..."
kubectl run test-pod --image=busybox --command -- sh -c "echo test > /data/file.txt && sleep 3600" --overrides='{"spec":{"volumes":[{"name":"storage","persistentVolumeClaim":{"claimName":"test-pvc"}}],"containers":[{"name":"test-pod","image":"busybox","command":["sh","-c","echo test > /data/file.txt && sleep 3600"],"volumeMounts":[{"name":"storage","mountPath":"/data"}]}]}}'

echo "7. Waiting for pod..."
kubectl wait --for=condition=ready pod/test-pod --timeout=60s

echo "8. Deleting pod..."
kubectl delete pod test-pod

echo "9. Deleting PVC..."
kubectl delete pvc test-pvc

echo "10. PV should be Released..."
kubectl get pv test-pv -o jsonpath='{.status.phase}'

echo "11. Cleanup..."
kubectl delete pv test-pv

echo "✅ All tests passed!"
SCRIPT

chmod +x test-pv-lifecycle.sh
./test-pv-lifecycle.sh
```

---

## ✅ Final Validation Checklist

Before completing this module, verify:

### PersistentVolumes
- [ ] Create PV manually
- [ ] Understand PV states (Available, Bound, Released)
- [ ] Configure reclaim policies
- [ ] Set access modes correctly

### PersistentVolumeClaims
- [ ] Create PVC
- [ ] Understand PVC binding
- [ ] Request appropriate storage size
- [ ] Use PVC in pods

### StorageClasses
- [ ] Create StorageClass
- [ ] Understand dynamic provisioning
- [ ] Configure volume binding modes
- [ ] Enable volume expansion

### Database Deployment
- [ ] Deploy database with PVC
- [ ] Test data persistence
- [ ] Perform backup/restore
- [ ] Scale database properly

### Troubleshooting
- [ ] Debug pending PVCs
- [ ] Fix binding issues
- [ ] Resolve permission problems
- [ ] Handle storage exhaustion

---

## 🎓 Key Learnings

**PV/PVC Relationship:**
- PV = Cluster resource (admin creates)
- PVC = Namespace resource (user creates)
- Binding happens automatically

**Access Modes:**
- RWO: Most common, single node
- ROX: Read-only, multiple nodes
- RWX: Read-write, multiple nodes (needs special storage)

**Reclaim Policies:**
- Retain: Safe, manual cleanup
- Delete: Automatic, data lost
- Recycle: Deprecated

**Best Practices:**
- Use StorageClasses
- Enable volume expansion
- Set appropriate reclaim policies
- Use WaitForFirstConsumer for multi-zone

---

## 🧹 Cleanup

```bash
# Delete all test resources
kubectl delete namespace database
kubectl delete pvc --all
kubectl delete pv --all
kubectl delete sc local-storage wait-for-consumer

# Clean up node directories
minikube ssh "sudo rm -rf /mnt/*"
# or
docker exec kind-control-plane rm -rf /mnt/*
```

---

**Congratulations! You've mastered Kubernetes persistent storage! 💾**
