# Day 31-32: Persistent Volumes & PersistentVolumeClaims

## 📋 Overview

Welcome to Day 31-32! Today we dive deep into Kubernetes persistent storage - the foundation of stateful applications. You'll learn about PersistentVolumes (PV), PersistentVolumeClaims (PVC), StorageClasses, and how to run production databases with persistent storage.

### What You'll Learn

- Understanding Kubernetes storage architecture
- Working with PersistentVolumes and PersistentVolumeClaims
- Configuring StorageClasses for dynamic provisioning
- Understanding access modes and reclaim policies
- Deploying databases with persistent storage
- Managing volume lifecycle and troubleshooting

---

## 🎯 Learning Objectives

By the end of this module, you will be able to:

1. Explain the difference between PV and PVC
2. Create and bind PersistentVolumes
3. Configure StorageClasses for dynamic provisioning
4. Understand access modes (RWO, RWX, ROX)
5. Implement appropriate reclaim policies
6. Deploy stateful applications with persistent storage
7. Troubleshoot common PV/PVC issues
8. Apply storage best practices for production

---

## 📚 Core Concepts

### The Problem: emptyDir and hostPath Limitations

**emptyDir:**
```
Pod deleted → Data lost ❌
Can't share across pods ❌
```

**hostPath:**
```
Tied to specific node ❌
Security risks ❌
Manual management ❌
```

**Need:** Durable, portable, managed storage ✅

### The Solution: PersistentVolumes

```
┌──────────────────────────────────────────────────┐
│         Kubernetes Storage Architecture          │
├──────────────────────────────────────────────────┤
│                                                  │
│  Administrator                Developer          │
│       ↓                           ↓              │
│  ┌─────────┐                 ┌────────┐         │
│  │   PV    │←─────binds──────│  PVC   │         │
│  │(Storage)│                 │(Request)│         │
│  └────┬────┘                 └───┬────┘         │
│       │                          │               │
│       └──────────┬───────────────┘               │
│                  ↓                                │
│            ┌─────────┐                           │
│            │   Pod   │                           │
│            └─────────┘                           │
│                                                  │
└──────────────────────────────────────────────────┘
```

---

## 🗄️ PersistentVolume (PV)

### What is a PV?

A **PersistentVolume** is a piece of storage in the cluster that has been provisioned by an administrator or dynamically provisioned using StorageClasses.

**Key Characteristics:**
- Cluster-wide resource (not namespaced)
- Lifecycle independent of pods
- Can be provisioned statically or dynamically
- Represents actual storage backend (NFS, iSCSI, cloud disks)

### PV Lifecycle

```
┌────────────────────────────────────────┐
│         PV Lifecycle States            │
├────────────────────────────────────────┤
│                                        │
│  Available  →  Bound  →  Released     │
│      ↓           ↓          ↓          │
│   (Ready)   (In use)   (PVC deleted)  │
│                            ↓           │
│                     Reclaimed/Deleted  │
│                                        │
└────────────────────────────────────────┘
```

**States:**
- **Available**: Ready to be claimed
- **Bound**: Bound to a PVC
- **Released**: PVC deleted, but not yet reclaimed
- **Failed**: Failed automatic reclamation

### Basic PV Example

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-example
spec:
  capacity:
    storage: 10Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  hostPath:
    path: /mnt/data
```

---

## 📝 PersistentVolumeClaim (PVC)

### What is a PVC?

A **PersistentVolumeClaim** is a request for storage by a user. It's similar to a pod - pods consume node resources, PVCs consume PV resources.

**Key Characteristics:**
- Namespaced resource
- Requests specific size and access modes
- Can request specific StorageClass
- Automatically binds to matching PV

### Basic PVC Example

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-example
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
  storageClassName: manual
```

### PV and PVC Binding

```
┌─────────────────────────────────────────────┐
│            Binding Process                  │
├─────────────────────────────────────────────┤
│                                             │
│  1. User creates PVC                        │
│     ↓                                       │
│  2. Control plane finds matching PV         │
│     - Same/compatible StorageClass          │
│     - Sufficient capacity                   │
│     - Compatible access modes               │
│     ↓                                       │
│  3. PV bound to PVC                         │
│     ↓                                       │
│  4. Pod can use PVC                         │
│                                             │
└─────────────────────────────────────────────┘
```

---

## 🔐 Access Modes

Access modes define how a volume can be mounted.

### Three Access Modes

| Mode | Short | Description | Use Case |
|------|-------|-------------|----------|
| **ReadWriteOnce** | RWO | Volume mounted read-write by single node | Databases, single-pod apps |
| **ReadOnlyMany** | ROX | Volume mounted read-only by many nodes | Shared configuration, static content |
| **ReadWriteMany** | RWX | Volume mounted read-write by many nodes | Shared storage, collaborative apps |

### Important Notes

**1. Node-level, not Pod-level:**
```
RWO = One NODE can mount (multiple pods on that node OK)
Not = One POD can mount
```

**2. Storage backend determines support:**
```
AWS EBS:        RWO only
Azure Disk:     RWO only
NFS:            RWO, ROX, RWX
GlusterFS:      RWO, ROX, RWX
```

**3. Access mode in PV and PVC must match:**
```yaml
# PV supports
accessModes:
- ReadWriteOnce
- ReadOnlyMany

# PVC requests
accessModes:
- ReadWriteOnce  # ✅ Match!
```

### Access Mode Examples

**ReadWriteOnce (Most Common):**
```yaml
# MySQL database
accessModes:
- ReadWriteOnce
# One node mounts, multiple pods on that node can access
```

**ReadOnlyMany:**
```yaml
# Static website content
accessModes:
- ReadOnlyMany
# All nodes can read, nobody can write
```

**ReadWriteMany:**
```yaml
# Shared file server
accessModes:
- ReadWriteMany
# All nodes can read and write
```

---

## 🎨 StorageClasses

### What is a StorageClass?

A **StorageClass** provides a way to describe "classes" of storage. Different classes might map to quality-of-service levels, backup policies, or arbitrary policies.

**Purpose:**
- Dynamic volume provisioning
- Abstract storage implementation details
- Define storage tiers (fast SSD, slow HDD, etc.)

### Static vs Dynamic Provisioning

**Static Provisioning:**
```
1. Admin creates PV manually
2. User creates PVC
3. Kubernetes binds PVC to PV
```

**Dynamic Provisioning:**
```
1. User creates PVC with StorageClass
2. StorageClass provisions PV automatically
3. Kubernetes binds PVC to new PV
```

### StorageClass Example

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
provisioner: kubernetes.io/aws-ebs
parameters:
  type: gp3
  iopsPerGB: "50"
  fsType: ext4
reclaimPolicy: Delete
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
```

### Common Provisioners

| Platform | Provisioner |
|----------|-------------|
| AWS | `kubernetes.io/aws-ebs` |
| Azure | `kubernetes.io/azure-disk` |
| GCP | `kubernetes.io/gce-pd` |
| NFS | `kubernetes.io/nfs` |
| Local | `kubernetes.io/no-provisioner` |

---

## 🔄 Reclaim Policies

What happens to PV when PVC is deleted?

### Three Reclaim Policies

**1. Retain (Manual Reclamation)**
```yaml
persistentVolumeReclaimPolicy: Retain
```
- PV becomes "Released" (not "Available")
- Data preserved
- Admin must manually reclaim
- **Use for**: Production data, important databases

**2. Delete (Automatic Deletion)**
```yaml
persistentVolumeReclaimPolicy: Delete
```
- PV and underlying storage deleted automatically
- Data lost!
- **Use for**: Development, temporary storage

**3. Recycle (Deprecated)**
```yaml
persistentVolumeReclaimPolicy: Recycle
```
- Basic scrub (`rm -rf /volume/*`)
- Deprecated, use dynamic provisioning instead

### Reclaim Policy Workflow

**Retain:**
```
PVC deleted → PV status: Released → Data still there
→ Admin manually cleans/deletes PV
→ PV available again
```

**Delete:**
```
PVC deleted → PV automatically deleted → Data gone forever
```

---

## 🗂️ Volume Binding Modes

Controls when volume binding and dynamic provisioning occur.

### Immediate (Default)

```yaml
volumeBindingMode: Immediate
```

**Behavior:**
- Volume provisioned immediately when PVC created
- May not consider pod scheduling constraints
- Volume might be in wrong zone

**Use when:** Storage location doesn't matter

### WaitForFirstConsumer (Recommended)

```yaml
volumeBindingMode: WaitForFirstConsumer
```

**Behavior:**
- Delays binding until pod using PVC is created
- Considers pod scheduling constraints (node affinity, etc.)
- Ensures volume in correct zone/region

**Use when:** Multi-zone clusters, topology awareness needed

---

## 💾 Storage Architecture Layers

```
┌─────────────────────────────────────────────────┐
│              Application Layer                  │
│            ┌────────────────┐                   │
│            │      Pod       │                   │
│            └────────┬───────┘                   │
│                     │ uses                      │
├─────────────────────┼─────────────────────────┤
│     Kubernetes Layer│                           │
│            ┌────────▼───────┐                   │
│            │      PVC       │  requests         │
│            └────────┬───────┘                   │
│                     │ binds to                  │
│            ┌────────▼───────┐                   │
│            │      PV        │  represents       │
│            └────────┬───────┘                   │
│                     │ uses                      │
├─────────────────────┼─────────────────────────┤
│      Storage Layer  │                           │
│            ┌────────▼───────┐                   │
│            │ StorageClass   │  provisions       │
│            └────────┬───────┘                   │
│                     │                           │
│            ┌────────▼───────┐                   │
│            │ Cloud Storage  │                   │
│            │ (EBS, Disk, etc)                   │
│            └────────────────┘                   │
└─────────────────────────────────────────────────┘
```

---

## 🏗️ Database with Persistent Storage

### PostgreSQL Example

```yaml
---
# PVC for database
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-pvc
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  storageClassName: fast-ssd

---
# StatefulSet with PVC
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
spec:
  serviceName: postgres
  replicas: 1
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
        ports:
        - containerPort: 5432
        env:
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: password
        volumeMounts:
        - name: postgres-storage
          mountPath: /var/lib/postgresql/data
          subPath: postgres  # Important for PostgreSQL
  volumeClaimTemplates:
  - metadata:
      name: postgres-storage
    spec:
      accessModes:
      - ReadWriteOnce
      resources:
        requests:
          storage: 10Gi
      storageClassName: fast-ssd
```

---

## 🎯 Best Practices

### 1. Use StorageClasses

```yaml
# Good: Use StorageClass
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-pvc
spec:
  storageClassName: fast-ssd
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
```

### 2. Choose Correct Access Mode

```yaml
# Database: RWO
accessModes:
- ReadWriteOnce

# Shared files: RWX (if backend supports)
accessModes:
- ReadWriteMany

# Static content: ROX
accessModes:
- ReadOnlyMany
```

### 3. Set Appropriate Reclaim Policy

```yaml
# Production data
persistentVolumeReclaimPolicy: Retain

# Dev/test data
persistentVolumeReclaimPolicy: Delete
```

### 4. Enable Volume Expansion

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: expandable-storage
allowVolumeExpansion: true  # Allow growing volumes
```

### 5. Use WaitForFirstConsumer for Multi-Zone

```yaml
volumeBindingMode: WaitForFirstConsumer
# Ensures volume created in same zone as pod
```

---

## 📊 PV/PVC Comparison Matrix

| Aspect | PV | PVC |
|--------|----|----|
| **Scope** | Cluster-wide | Namespaced |
| **Created by** | Admin or dynamic provisioner | User/Application |
| **Represents** | Actual storage | Storage request |
| **Contains** | Storage backend details | Requirements (size, access mode) |
| **Lifecycle** | Independent | Tied to namespace |

---

## 🔍 Common Patterns

### Pattern 1: Static Provisioning

```yaml
# Admin creates PV
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-manual
spec:
  capacity:
    storage: 5Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  hostPath:
    path: /mnt/data

---
# User creates PVC
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-manual
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
  storageClassName: manual
```

### Pattern 2: Dynamic Provisioning

```yaml
# User just creates PVC
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-dynamic
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  storageClassName: fast-ssd  # PV created automatically
```

### Pattern 3: StatefulSet with volumeClaimTemplates

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: web
spec:
  serviceName: web
  replicas: 3
  volumeClaimTemplates:  # PVC per replica
  - metadata:
      name: www
    spec:
      accessModes:
      - ReadWriteOnce
      resources:
        requests:
          storage: 1Gi
```

---

## 🎓 Key Takeaways

✅ **PV** = Actual storage (admin manages)
✅ **PVC** = Storage request (users create)
✅ **StorageClass** = Dynamic provisioning template
✅ **RWO** = Most common access mode
✅ **Retain** = Safe for production
✅ **WaitForFirstConsumer** = Better for multi-zone

**Remember:** PVCs are like "resource requests" for storage, just as CPU/memory requests are for compute!

---

## 📖 Additional Resources

- [Persistent Volumes Documentation](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)
- [Storage Classes](https://kubernetes.io/docs/concepts/storage/storage-classes/)
- [StatefulSets](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/)
- [Volume Snapshots](https://kubernetes.io/docs/concepts/storage/volume-snapshots/)

---

## 🚀 Next Steps

1. Complete hands-on exercises in GUIDEME.md
2. Deploy the database project
3. Practice troubleshooting scenarios
4. Move on to Day 33-34: Storage Classes & Dynamic Provisioning

**Happy Learning! 💾**
