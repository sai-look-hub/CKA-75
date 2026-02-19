# 🎤 Interview Q&A: StorageClasses & Dynamic Provisioning

## Q1: Explain how dynamic provisioning works in Kubernetes.

**Answer:**

Dynamic provisioning automatically creates PersistentVolumes when PersistentVolumeClaims are created, eliminating manual PV creation.

**Process:**
1. Admin creates StorageClass with provisioner
2. User creates PVC referencing StorageClass
3. Controller detects new PVC
4. Provisioner plugin provisions actual storage (AWS EBS, etc.)
5. Provisioner creates PV in Kubernetes
6. Kubernetes binds PVC to PV
7. Pod uses PVC

**Example:**
```yaml
# Admin: Create StorageClass (once)
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
provisioner: ebs.csi.aws.com
parameters:
  type: gp3

# User: Create PVC (auto-provisions)
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-data
spec:
  storageClassName: fast-ssd
  resources:
    requests:
      storage: 10Gi
# PV created automatically!
```

---

## Q2: What's the difference between in-tree and CSI provisioners?

**Answer:**

**In-Tree Provisioners (Deprecated):**
- Built into Kubernetes core
- Examples: `kubernetes.io/aws-ebs`, `kubernetes.io/gce-pd`
- Updates require Kubernetes release
- Being phased out

**CSI Drivers (Current Standard):**
- Container Storage Interface standard
- Plugin architecture, external to Kubernetes
- Examples: `ebs.csi.aws.com`, `pd.csi.storage.gke.io`
- Independent updates from Kubernetes
- More features, better maintained

**Migration:**
```yaml
# Old (deprecated)
provisioner: kubernetes.io/aws-ebs

# New (recommended)
provisioner: ebs.csi.aws.com
```

---

## Q3: Why use WaitForFirstConsumer volume binding mode?

**Answer:**

**Problem with Immediate Mode:**
```
1. PVC created
2. Volume provisioned in zone-a (random)
3. Pod scheduled to zone-b (node affinity)
4. Volume and pod in different zones
5. Pod can't access volume → Stuck!
```

**Solution with WaitForFirstConsumer:**
```
1. PVC created (stays Pending)
2. Pod created
3. Scheduler selects node in zone-b
4. Volume provisioned in same zone-b
5. PVC binds
6. Pod starts successfully
```

**Configuration:**
```yaml
volumeBindingMode: WaitForFirstConsumer
```

**Best for:** Multi-zone clusters, topology-aware storage

---

## Q4: How do you implement storage tiers?

**Answer:**

Create multiple StorageClasses for different performance/cost needs:

**Tier 1: Performance**
```yaml
name: performance
provisioner: ebs.csi.aws.com
parameters:
  type: io2  # High IOPS
  iopsPerGB: "50"
# Use for: Databases, critical apps
# Cost: $$$
```

**Tier 2: Standard**
```yaml
name: standard
provisioner: ebs.csi.aws.com
parameters:
  type: gp3  # General purpose
# Use for: Most applications
# Cost: $$
```

**Tier 3: Archive**
```yaml
name: archive
provisioner: ebs.csi.aws.com
parameters:
  type: sc1  # Cold HDD
# Use for: Backups, logs
# Cost: $
```

**Selection:**
```yaml
# Database
storageClassName: performance

# Application
storageClassName: standard

# Backups
storageClassName: archive
```

---

## Q5: What parameters are important in a StorageClass?

**Answer:**

**Core Parameters:**

**1. Provisioner** (Required)
```yaml
provisioner: ebs.csi.aws.com
```

**2. Volume Binding Mode**
```yaml
volumeBindingMode: WaitForFirstConsumer  # Recommended
```

**3. Allow Volume Expansion**
```yaml
allowVolumeExpansion: true  # Enable growing
```

**4. Reclaim Policy**
```yaml
reclaimPolicy: Delete  # or Retain for production
```

**Provider-Specific Parameters:**

**AWS:**
```yaml
parameters:
  type: gp3
  iopsPerGB: "50"
  encrypted: "true"
  fsType: ext4
```

**Azure:**
```yaml
parameters:
  skuName: Premium_LRS
  cachingmode: ReadOnly
```

**GCP:**
```yaml
parameters:
  type: pd-ssd
  replication-type: regional-pd
```

---

## Q6: How do you handle storage expansion?

**Answer:**

**Prerequisites:**
- StorageClass has `allowVolumeExpansion: true`
- Storage backend supports expansion

**Process:**
```bash
# 1. Edit PVC
kubectl patch pvc my-pvc -p '{"spec":{"resources":{"requests":{"storage":"20Gi"}}}}'

# 2. Controller expands volume
# (automatic in background)

# 3. Delete pod (if needed for FS expansion)
kubectl delete pod my-pod

# 4. Pod recreates, uses larger volume
```

**Limitations:**
- Can only grow, never shrink
- Some storage requires pod restart
- File system must support online expansion

---

More questions in full guide...
