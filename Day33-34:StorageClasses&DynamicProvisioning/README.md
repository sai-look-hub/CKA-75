# Day 33-34: Storage Classes & Dynamic Provisioning

## 📋 Overview

Welcome to Day 33-34! Today we master Kubernetes dynamic storage provisioning - the modern way to manage persistent storage at scale. You'll learn about StorageClasses, different provisioners across cloud providers, and build a multi-tier application with dynamic storage.

### What You'll Learn

- Understanding StorageClass architecture
- Configuring dynamic provisioning
- Working with different cloud provisioners (AWS, Azure, GCP)
- Implementing storage tiers (fast, standard, archive)
- Building multi-tier applications with varied storage needs
- Managing provisioner parameters and features
- Troubleshooting dynamic provisioning issues

---

## 🎯 Learning Objectives

By the end of this module, you will be able to:

1. Explain how dynamic provisioning works
2. Create and configure StorageClasses
3. Use different provisioners for various cloud providers
4. Implement storage tiers for different workloads
5. Configure volume binding modes and reclaim policies
6. Enable and use volume expansion
7. Deploy multi-tier applications with dynamic storage
8. Troubleshoot provisioning issues

---

## 📚 Core Concepts

### The Problem: Static Provisioning at Scale

**Manual PV Creation:**
```
Developer: "Need storage for new microservice"
Admin: Creates PV manually
Developer: Creates PVC
Kubernetes: Binds them
```

**Issues:**
- Doesn't scale (100s of services = 100s of manual PVs)
- Slow (hours of admin work)
- Error-prone (wrong size, access mode, etc.)
- Wasteful (over-provisioning for safety)

### The Solution: Dynamic Provisioning

```
Developer: Creates PVC with StorageClass
Provisioner: Automatically creates PV
Kubernetes: Binds them automatically
```

**Benefits:**
- Self-service for developers
- Scales to thousands of volumes
- Instant provisioning (seconds, not hours)
- Exact sizes (no over-provisioning)
- Consistent configuration

---

## 🏗️ StorageClass Architecture

```
┌─────────────────────────────────────────────────────┐
│         Dynamic Provisioning Flow                   │
├─────────────────────────────────────────────────────┤
│                                                     │
│  1. Developer creates PVC                           │
│     storageClassName: fast-ssd                      │
│              ↓                                      │
│  2. Controller sees new PVC                         │
│              ↓                                      │
│  3. Finds matching StorageClass                     │
│     provisioner: kubernetes.io/aws-ebs              │
│              ↓                                      │
│  4. Provisioner creates actual storage              │
│     (AWS EBS volume created)                        │
│              ↓                                      │
│  5. Provisioner creates PV in Kubernetes            │
│              ↓                                      │
│  6. Kubernetes binds PVC to new PV                  │
│              ↓                                      │
│  7. Pod can use PVC                                 │
│                                                     │
└─────────────────────────────────────────────────────┘
```

---

## 🎨 StorageClass Components

### Basic StorageClass

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
provisioner: kubernetes.io/aws-ebs
parameters:
  type: gp3
  iopsPerGB: "50"
  encrypted: "true"
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
reclaimPolicy: Delete
```

### Component Breakdown

**1. Provisioner** (Required)
- Determines which plugin provisions volumes
- Each cloud provider has specific provisioners
- Examples: `kubernetes.io/aws-ebs`, `kubernetes.io/azure-disk`

**2. Parameters** (Optional)
- Provisioner-specific settings
- Storage type, IOPS, encryption, etc.
- Varies by provisioner

**3. Volume Binding Mode**
- `Immediate`: Provision immediately
- `WaitForFirstConsumer`: Wait for pod scheduling (recommended)

**4. Allow Volume Expansion**
- `true`: PVCs can be expanded
- `false`: Size is fixed

**5. Reclaim Policy**
- `Delete`: Delete PV when PVC deleted (default)
- `Retain`: Keep PV for manual cleanup

---

## ☁️ Cloud Provider Provisioners

### AWS (Elastic Block Store)

**In-Tree Provisioner (Deprecated):**
```yaml
provisioner: kubernetes.io/aws-ebs
```

**CSI Driver (Recommended):**
```yaml
provisioner: ebs.csi.aws.com
```

**Volume Types:**
- `gp3`: General Purpose SSD (recommended)
- `gp2`: General Purpose SSD (older)
- `io2`: Provisioned IOPS SSD (high performance)
- `io1`: Provisioned IOPS SSD (older)
- `st1`: Throughput Optimized HDD
- `sc1`: Cold HDD (archive)

**Example:**
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: aws-fast
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  iopsPerGB: "50"
  encrypted: "true"
  fsType: ext4
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
```

---

### Azure (Disk Storage)

**In-Tree Provisioner (Deprecated):**
```yaml
provisioner: kubernetes.io/azure-disk
```

**CSI Driver (Recommended):**
```yaml
provisioner: disk.csi.azure.com
```

**Storage Account Types:**
- `Premium_LRS`: Premium SSD
- `StandardSSD_LRS`: Standard SSD
- `Standard_LRS`: Standard HDD
- `UltraSSD_LRS`: Ultra Disk (highest performance)

**Example:**
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: azure-premium
provisioner: disk.csi.azure.com
parameters:
  skuName: Premium_LRS
  location: eastus
  cachingmode: ReadOnly
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
```

---

### GCP (Persistent Disk)

**In-Tree Provisioner (Deprecated):**
```yaml
provisioner: kubernetes.io/gce-pd
```

**CSI Driver (Recommended):**
```yaml
provisioner: pd.csi.storage.gke.io
```

**Disk Types:**
- `pd-standard`: Standard persistent disk
- `pd-balanced`: Balanced persistent disk
- `pd-ssd`: SSD persistent disk
- `pd-extreme`: Extreme persistent disk

**Example:**
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gcp-ssd
provisioner: pd.csi.storage.gke.io
parameters:
  type: pd-ssd
  replication-type: regional-pd
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
```

---

## 🗂️ Storage Tiers Strategy

### Three-Tier Approach

**Tier 1: Performance (SSD)**
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: performance
  annotations:
    storageclass.kubernetes.io/is-default-class: "false"
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  iopsPerGB: "50"
  throughput: "250"
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
```

**Use Cases:**
- Production databases
- High-traffic applications
- Low-latency requirements

---

**Tier 2: Standard (Balanced)**
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: standard
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"  # Default
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  iopsPerGB: "3"
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
```

**Use Cases:**
- General applications
- Dev/test environments
- Non-critical workloads

---

**Tier 3: Archive (HDD)**
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: archive
provisioner: ebs.csi.aws.com
parameters:
  type: sc1  # Cold HDD
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
```

**Use Cases:**
- Backups
- Log archives
- Infrequent access data

---

## 🔄 Volume Binding Modes

### Immediate vs WaitForFirstConsumer

**Immediate Mode:**
```yaml
volumeBindingMode: Immediate
```

**Behavior:**
- Volume provisioned immediately when PVC created
- Binding happens right away
- May provision in wrong availability zone

**Problem Scenario:**
```
1. PVC created
2. Volume provisioned in zone-a
3. Pod scheduled to zone-b
4. Pod can't access volume in zone-a
5. Pod stuck pending!
```

---

**WaitForFirstConsumer Mode (Recommended):**
```yaml
volumeBindingMode: WaitForFirstConsumer
```

**Behavior:**
- Delays provisioning until pod created
- Considers pod's scheduling constraints
- Ensures volume in correct zone

**Success Scenario:**
```
1. PVC created (stays Pending)
2. Pod created
3. Scheduler picks node in zone-b
4. Volume provisioned in zone-b
5. PVC binds to PV
6. Pod starts successfully
```

---

## 📈 Volume Expansion

### Enabling Expansion

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: expandable
provisioner: ebs.csi.aws.com
allowVolumeExpansion: true  # Enable expansion
```

### Expansion Process

**1. Edit PVC:**
```bash
kubectl patch pvc my-pvc -p '{"spec":{"resources":{"requests":{"storage":"20Gi"}}}}'
```

**2. Automatic Expansion:**
- Controller detects size change
- Provisioner expands underlying storage
- File system grows automatically (most cases)

**3. Pod Restart (Sometimes Required):**
```bash
kubectl delete pod my-pod
# StatefulSet/Deployment recreates pod
# File system expansion completes
```

---

## 🎯 Default StorageClass

### Setting Default

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: standard
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: ebs.csi.aws.com
```

**Behavior:**
- PVCs without `storageClassName` use default
- Only one default per cluster
- Simplifies PVC creation

**Usage:**
```yaml
# No storageClassName specified
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-pvc
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
# Uses default StorageClass automatically
```

---

## 🏢 Multi-Tier Application Example

### Application Architecture

```
┌──────────────────────────────────────────┐
│         Multi-Tier Application           │
├──────────────────────────────────────────┤
│                                          │
│  Frontend (Nginx)                        │
│  └─ Storage: standard (static files)     │
│                                          │
│  Backend API (Node.js)                   │
│  └─ Storage: standard (logs)             │
│                                          │
│  Database (PostgreSQL)                   │
│  └─ Storage: performance (data)          │
│                                          │
│  Cache (Redis)                           │
│  └─ Storage: performance (persistence)   │
│                                          │
│  Backup Service                          │
│  └─ Storage: archive (backups)           │
│                                          │
└──────────────────────────────────────────┘
```

### Storage Class Selection

| Component | StorageClass | Reason |
|-----------|--------------|--------|
| Frontend | standard | Static files, moderate I/O |
| Backend | standard | Logs, moderate write |
| Database | performance | High I/O, low latency |
| Cache | performance | High I/O, critical |
| Backups | archive | Large size, low cost |

---

## 🔐 Advanced Parameters

### Encryption

**AWS:**
```yaml
parameters:
  encrypted: "true"
  kmsKeyId: "arn:aws:kms:us-east-1:123456789:key/abc-123"
```

**Azure:**
```yaml
parameters:
  skuName: Premium_LRS
  encryption: "true"
```

**GCP:**
```yaml
parameters:
  type: pd-ssd
  disk-encryption-kms-key: "projects/KEY_PROJECT_ID/locations/LOCATION/keyRings/RING_NAME/cryptoKeys/KEY_NAME"
```

---

### Topology and Zones

**AWS Multi-AZ:**
```yaml
allowedTopologies:
- matchLabelExpressions:
  - key: topology.ebs.csi.aws.com/zone
    values:
    - us-east-1a
    - us-east-1b
    - us-east-1c
```

**GCP Regional:**
```yaml
parameters:
  replication-type: regional-pd
```

---

## 📊 Provisioner Comparison

| Feature | AWS EBS | Azure Disk | GCP PD | NFS |
|---------|---------|------------|--------|-----|
| **Access Mode** | RWO | RWO | RWO | RWO, RWX |
| **Dynamic** | ✅ | ✅ | ✅ | ⚠️ |
| **Expansion** | ✅ | ✅ | ✅ | ✅ |
| **Snapshots** | ✅ | ✅ | ✅ | ❌ |
| **Encryption** | ✅ | ✅ | ✅ | Manual |
| **Multi-Zone** | ❌ | ❌ | ✅ (regional) | ✅ |
| **Cost** | $$ | $$ | $$ | $ |

---

## 🎓 Best Practices

### 1. Use CSI Drivers

```yaml
# ❌ Old (deprecated)
provisioner: kubernetes.io/aws-ebs

# ✅ New (recommended)
provisioner: ebs.csi.aws.com
```

### 2. Always Use WaitForFirstConsumer

```yaml
volumeBindingMode: WaitForFirstConsumer
```

### 3. Enable Volume Expansion

```yaml
allowVolumeExpansion: true
```

### 4. Set One Default StorageClass

```yaml
storageclass.kubernetes.io/is-default-class: "true"
```

### 5. Use Descriptive Names

```yaml
# ✅ Clear purpose
name: aws-gp3-encrypted-expandable

# ❌ Unclear
name: sc1
```

### 6. Tag Resources

```yaml
parameters:
  tagSpecification_1: "Name=k8s-dynamic-pv"
  tagSpecification_2: "Environment=production"
```

---

## 🔍 Monitoring and Observability

### Key Metrics

**Volume Provisioning:**
```promql
# Provisioning time
storage_operation_duration_seconds
{operation_name="provision"}

# Failed provisions
storage_operation_errors_total
{operation_name="provision"}
```

**Volume Usage:**
```promql
# Storage capacity
kubelet_volume_stats_capacity_bytes

# Storage usage
kubelet_volume_stats_used_bytes

# Usage percentage
(kubelet_volume_stats_used_bytes / 
 kubelet_volume_stats_capacity_bytes) * 100
```

---

## 📝 Key Takeaways

✅ **Dynamic provisioning** automates PV creation
✅ **StorageClass** defines provisioning template
✅ **Provisioners** are cloud/storage-specific
✅ **WaitForFirstConsumer** prevents zone issues
✅ **Volume expansion** allows growing storage
✅ **Multiple tiers** optimize cost and performance
✅ **CSI drivers** are the modern standard

**Remember:** StorageClasses are the key to self-service, scalable storage in Kubernetes!

---

## 📖 Additional Resources

- [StorageClass Documentation](https://kubernetes.io/docs/concepts/storage/storage-classes/)
- [CSI Drivers List](https://kubernetes-csi.github.io/docs/drivers.html)
- [AWS EBS CSI Driver](https://github.com/kubernetes-sigs/aws-ebs-csi-driver)
- [Azure Disk CSI Driver](https://github.com/kubernetes-sigs/azuredisk-csi-driver)
- [GCP PD CSI Driver](https://github.com/kubernetes-sigs/gcp-compute-persistent-disk-csi-driver)

---

## 🚀 Next Steps

1. Complete hands-on exercises in GUIDEME.md
2. Deploy multi-tier application project
3. Practice with different provisioners
4. Move on to Day 35-36: Volume Snapshot & Cloning
**Happy Learning! 🎯**
