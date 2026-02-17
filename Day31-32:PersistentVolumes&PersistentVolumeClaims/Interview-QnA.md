# 🎤 Interview Q&A: PersistentVolumes & PVCs

---

## Q1: What's the difference between PV and PVC?

**Answer:**

**PersistentVolume (PV):**
- Cluster-level resource (not namespaced)
- Represents actual storage
- Created by administrators or dynamic provisioner
- Contains storage implementation details
- Independent lifecycle

**PersistentVolumeClaim (PVC):**
- Namespace-level resource
- Request for storage
- Created by users/developers
- Specifies requirements (size, access mode)
- Bound to a PV

**Analogy:**
- PV = Actual compute node in cluster
- PVC = Pod requesting compute resources
- Pod consumes node resources
- PVC consumes PV storage

**Example:**
```yaml
# Admin creates PV (the storage)
apiVersion: v1
kind: PersistentVolume
spec:
  capacity:
    storage: 10Gi
  hostPath:
    path: /mnt/data

# User creates PVC (the request)
apiVersion: v1
kind: PersistentVolumeClaim
spec:
  resources:
    requests:
      storage: 5Gi
```

---

## Q2: Explain the three access modes and when to use each.

**Answer:**

**1. ReadWriteOnce (RWO)** - Most Common
- Volume mounted read-write by single node
- Multiple pods on same node can use it
- **Use for:** Databases, single-instance apps
- **Supported by:** Almost all storage types

**2. ReadOnlyMany (ROX)**
- Volume mounted read-only by many nodes
- All pods can read, nobody can write
- **Use for:** Static content, shared configuration
- **Supported by:** NFS, some cloud storage

**3. ReadWriteMany (RWX)**
- Volume mounted read-write by many nodes
- All pods can read and write
- **Use for:** Shared file systems, collaborative apps
- **Supported by:** NFS, GlusterFS, CephFS

**Important Note:**
Access mode is node-level, not pod-level!

```
RWO: One NODE can mount (multiple pods OK)
Not: One POD can mount
```

**Storage Support Matrix:**
```
AWS EBS:      RWO only
Azure Disk:   RWO only
GCE PD:       RWO, ROX
NFS:          RWO, ROX, RWX
```

---

## Q3: What are reclaim policies and which should you use in production?

**Answer:**

**Three Reclaim Policies:**

**1. Retain (Recommended for Production)**
```yaml
persistentVolumeReclaimPolicy: Retain
```
- PV enters "Released" state when PVC deleted
- Data preserved on storage
- Admin must manually reclaim
- Safe, prevents accidental data loss

**2. Delete (Good for Dev/Test)**
```yaml
persistentVolumeReclaimPolicy: Delete
```
- PV and underlying storage deleted automatically
- Data lost forever
- Convenient for temporary storage

**3. Recycle (Deprecated)**
- Basic scrub (rm -rf)
- Don't use, deprecated

**Production Recommendation:**
- Critical data: **Retain**
- Temporary data: **Delete**
- Default for production: **Retain**

**Workflow with Retain:**
```bash
1. PVC deleted
2. PV status: Released
3. Admin backs up data if needed
4. Admin cleans PV: kubectl patch pv <name> -p '{"spec":{"claimRef": null}}'
5. PV status: Available (ready for reuse)
```

---

## Q4: Explain static vs dynamic provisioning.

**Answer:**

**Static Provisioning (Old Way)**

**Process:**
1. Admin manually creates PV
2. User creates PVC
3. Kubernetes binds PVC to PV
4. Pod uses PVC

**Pros:**
- Full control over storage
- Good for specific requirements

**Cons:**
- Manual admin work
- Doesn't scale

**Example:**
```yaml
# Admin creates PV
kubectl apply -f pv.yaml

# User creates PVC
kubectl apply -f pvc.yaml
# Kubernetes binds them automatically
```

**Dynamic Provisioning (Modern Way)**

**Process:**
1. Admin creates StorageClass once
2. User creates PVC with StorageClass
3. Provisioner automatically creates PV
4. Kubernetes binds PVC to new PV
5. Pod uses PVC

**Pros:**
- Automated, scales well
- On-demand provisioning
- No admin intervention per volume

**Cons:**
- Requires cloud provider or CSI driver
- Less control

**Example:**
```yaml
# Admin creates StorageClass (once)
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
provisioner: kubernetes.io/aws-ebs
parameters:
  type: gp3

# User creates PVC
apiVersion: v1
kind: PersistentVolumeClaim
spec:
  storageClassName: fast-ssd  # PV created automatically!
  resources:
    requests:
      storage: 10Gi
```

---

## Q5: What is volumeBindingMode and why use WaitForFirstConsumer?

**Answer:**

**Two Modes:**

**1. Immediate (Default)**
```yaml
volumeBindingMode: Immediate
```
- Volume provisioned immediately when PVC created
- Binding happens right away
- **Problem:** May provision in wrong zone/region

**2. WaitForFirstConsumer (Recommended)**
```yaml
volumeBindingMode: WaitForFirstConsumer
```
- Delays provisioning until pod using PVC is created
- Considers pod scheduling constraints
- **Benefit:** Ensures volume in correct zone

**Why WaitForFirstConsumer Matters:**

**Problem Scenario (Immediate mode):**
```
1. User creates PVC in us-east-1a
2. Volume provisioned in zone-a
3. Pod scheduled to zone-b
4. Pod can't access volume in zone-a!
5. Pod stuck pending
```

**Solution (WaitForFirstConsumer):**
```
1. User creates PVC
2. PVC stays Pending (normal!)
3. User creates Pod
4. Scheduler picks node in zone-b
5. Volume provisioned in zone-b
6. Binding completes
7. Pod runs successfully
```

**Best Practice:**
Always use WaitForFirstConsumer for:
- Multi-zone clusters
- Cloud environments
- Any topology-aware storage

---

## Q6: How do you deploy a database with persistent storage?

**Answer:**

Use **StatefulSet** with **volumeClaimTemplates**.

**Why StatefulSet?**
- Stable pod identity
- Ordered deployment/termination
- Per-pod PVC (not shared)
- Persistent storage survives restarts

**Complete Example:**
```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
spec:
  serviceName: postgres
  replicas: 3
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:15
        volumeMounts:
        - name: data
          mountPath: /var/lib/postgresql/data
          subPath: postgres  # Important!
  
  volumeClaimTemplates:  # Creates PVC per replica
  - metadata:
      name: data
    spec:
      accessModes:
      - ReadWriteOnce
      resources:
        requests:
          storage: 10Gi
      storageClassName: fast-ssd
```

**Key Points:**

1. **volumeClaimTemplates:** Creates separate PVC per pod
   - postgres-0 gets data-postgres-0
   - postgres-1 gets data-postgres-1
   - postgres-2 gets data-postgres-2

2. **subPath:** PostgreSQL specific
   - PostgreSQL creates pgdata subdirectory
   - Without subPath, conflicts with lost+found

3. **Headless Service:** For stable network identity

4. **Ordered Operations:**
   - Pods created: 0, 1, 2
   - Pods deleted: 2, 1, 0

**Data Persistence:**
- Delete pod → StatefulSet recreates with same PVC
- Scale down → PVCs remain (safe!)
- Scale up → New PVCs created

---

## Q7: What happens when you delete a PVC?

**Answer:**

Depends on **reclaimPolicy** of the bound PV.

**Scenario 1: Retain Policy**
```yaml
persistentVolumeReclaimPolicy: Retain
```

**Timeline:**
```
1. kubectl delete pvc my-pvc
   → PVC deleted from cluster

2. PV status changes:
   Available → Released

3. Data still on disk
   → Nothing deleted automatically

4. Admin must:
   a. Backup data if needed
   b. Clean data manually
   c. Delete PV or clear claimRef:
      kubectl patch pv <name> -p '{"spec":{"claimRef": null}}'
   d. PV becomes Available again
```

**Scenario 2: Delete Policy**
```yaml
persistentVolumeReclaimPolicy: Delete
```

**Timeline:**
```
1. kubectl delete pvc my-pvc
   → PVC deleted

2. PV automatically deleted
   → PV removed from cluster

3. Underlying storage deleted
   → Data GONE FOREVER!

4. No admin action needed
```

**Protection:**
- PVC with `finalizers` won't delete while in use by pod
- Must delete pod first, then PVC

**Best Practices:**
- Production: Use Retain
- Dev/Test: Use Delete
- Always backup before deleting!

---

## Q8: How do you resize a volume?

**Answer:**

**Prerequisites:**
1. StorageClass has `allowVolumeExpansion: true`
2. Storage backend supports expansion
3. File system supports online expansion

**Steps:**

**1. Check if expansion allowed:**
```bash
kubectl get sc <storage-class> -o yaml | grep allowVolumeExpansion
# allowVolumeExpansion: true
```

**2. Edit PVC to request more space:**
```bash
kubectl patch pvc my-pvc -p '{"spec":{"resources":{"requests":{"storage":"20Gi"}}}}'
```

**3. Wait for expansion:**
```bash
kubectl get pvc my-pvc -w
# Capacity increases
```

**4. Some storage requires pod restart:**
```bash
kubectl delete pod my-pod
# Pod recreates, filesystem expands
```

**5. Verify in pod:**
```bash
kubectl exec my-pod -- df -h /data
```

**Important Notes:**
- Can only **grow**, never shrink
- Some storage (AWS EBS) requires pod restart
- Other storage (some CSI) expands online
- File system automatically grows

**Example:**
```yaml
# Before
resources:
  requests:
    storage: 10Gi

# After patch
resources:
  requests:
    storage: 20Gi  # Grows from 10Gi to 20Gi
```

---

More questions available in full guide...
