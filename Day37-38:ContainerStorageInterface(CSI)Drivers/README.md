# Day 37-38: Container Storage Interface (CSI) Drivers

## 📋 Overview

Welcome to Day 37-38! Today we dive deep into the Container Storage Interface (CSI) - the standard that enables Kubernetes to work with any storage system. You'll learn how CSI works, deploy CSI drivers, and understand the architecture that powers persistent storage in Kubernetes.

### What You'll Learn

- Understanding the CSI specification and architecture
- CSI vs in-tree storage plugins
- CSI driver components and their roles
- Deploying and configuring CSI drivers
- Using CSI features (snapshots, cloning, expansion)
- Troubleshooting CSI-related issues
- Building applications with CSI drivers

---

## 🎯 Learning Objectives

By the end of this module, you will be able to:

1. Explain the CSI architecture and its benefits
2. Understand CSI driver components (Controller, Node)
3. Deploy CSI drivers in Kubernetes
4. Configure StorageClasses with CSI parameters
5. Use advanced CSI features (snapshots, volume cloning)
6. Troubleshoot CSI driver issues
7. Choose appropriate CSI drivers for your needs
8. Implement best practices for CSI in production

---

## 🏗️ CSI Architecture

### The Big Picture

```
┌─────────────────────────────────────────────────┐
│              Kubernetes Core                     │
│  ┌────────────────────────────────────────┐    │
│  │     PersistentVolume Controller        │    │
│  │     (Creates PVs from PVCs)            │    │
│  └──────────────┬─────────────────────────┘    │
│                 │                                │
│                 ▼                                │
│  ┌────────────────────────────────────────┐    │
│  │     CSI External Components            │    │
│  │  ┌──────────────┐  ┌─────────────┐    │    │
│  │  │ External     │  │ External    │    │    │
│  │  │ Provisioner  │  │ Attacher    │    │    │
│  │  └──────┬───────┘  └──────┬──────┘    │    │
│  │         │                  │           │    │
│  │  ┌──────▼───────┐  ┌──────▼──────┐    │    │
│  │  │ External     │  │ External    │    │    │
│  │  │ Snapshotter  │  │ Resizer     │    │    │
│  │  └──────┬───────┘  └──────┬──────┘    │    │
│  └─────────┼──────────────────┼───────────┘    │
│            │                  │                 │
└────────────┼──────────────────┼─────────────────┘
             │                  │
             ▼                  ▼
┌─────────────────────────────────────────────────┐
│           CSI Driver (Your Storage)              │
│  ┌────────────────┐      ┌─────────────────┐   │
│  │  CSI Controller│      │   CSI Node      │   │
│  │   (one pod)    │      │  (DaemonSet)    │   │
│  │                │      │                 │   │
│  │  - CreateVol   │      │  - NodeStage    │   │
│  │  - DeleteVol   │      │  - NodePublish  │   │
│  │  - Snapshot    │      │  - Mount to Pod │   │
│  └────────┬───────┘      └────────┬────────┘   │
│           │                       │             │
└───────────┼───────────────────────┼─────────────┘
            │                       │
            ▼                       ▼
┌─────────────────────────────────────────────────┐
│         Storage Backend                          │
│     (AWS EBS, NFS, Ceph, etc.)                  │
└─────────────────────────────────────────────────┘
```

---

## 📚 Core Concepts

### 1. What is CSI?

**Container Storage Interface** is a standard for exposing storage systems to containerized workloads.

**Key Benefits:**
- **Standardization**: One API for all storage providers
- **Portability**: Same interface across orchestrators (K8s, Mesos, etc.)
- **Out-of-tree**: Storage plugins run outside Kubernetes core
- **Vendor Independence**: Easy to switch storage providers

**Before CSI:**
```
Kubernetes Core
    ├─ AWS EBS Plugin (built-in)
    ├─ GCE PD Plugin (built-in)
    ├─ Azure Disk Plugin (built-in)
    └─ 20+ other plugins (all in-tree)
```

**Problems:**
- Kubernetes release cycle delays storage features
- Security concerns (plugins run as part of K8s)
- Maintenance burden on K8s project
- Hard to add new storage providers

**After CSI:**
```
Kubernetes Core
    └─ CSI Interface (standardized)
           ├─ AWS EBS CSI Driver (external)
           ├─ GCE PD CSI Driver (external)
           ├─ Azure Disk CSI Driver (external)
           └─ Any CSI Driver (external)
```

**Benefits:**
- Drivers developed independently
- Faster feature releases
- Better security (separate processes)
- Easy to add new drivers

---

### 2. CSI Driver Components

#### Controller Plugin (StatefulSet/Deployment)

**Responsibilities:**
- Create/delete volumes
- Attach/detach volumes to/from nodes
- Create/delete snapshots
- Expand volumes
- List volumes/snapshots

**Runs as:** Single pod (or HA deployment)

**Example operations:**
```go
CreateVolume()    // Provision new volume
DeleteVolume()    // Delete volume
ControllerPublishVolume()   // Attach to node
ControllerUnpublishVolume() // Detach from node
CreateSnapshot()  // Create volume snapshot
```

---

#### Node Plugin (DaemonSet)

**Responsibilities:**
- Mount volume to specific path on node
- Unmount volume from node
- Get volume statistics
- Publish volume to pod

**Runs as:** DaemonSet (one pod per node)

**Example operations:**
```go
NodeStageVolume()      // Format and stage volume
NodeUnstageVolume()    // Unstage volume
NodePublishVolume()    // Mount to pod directory
NodeUnpublishVolume()  // Unmount from pod
NodeGetVolumeStats()   // Get usage statistics
```

---

### 3. CSI Sidecars (External Components)

These are provided by Kubernetes and work with any CSI driver:

**External-Provisioner:**
- Watches for PVCs
- Calls CreateVolume on CSI driver
- Creates PV objects

**External-Attacher:**
- Watches for VolumeAttachment objects
- Calls ControllerPublish/Unpublish
- Manages attachment state

**External-Snapshotter:**
- Watches for VolumeSnapshot objects
- Calls CreateSnapshot on CSI driver
- Creates VolumeSnapshotContent

**External-Resizer:**
- Watches for PVC resize requests
- Calls ControllerExpandVolume
- Updates PV size

**Node-Driver-Registrar:**
- Registers CSI driver with kubelet
- Runs as sidecar on each node

**Livenessprobe:**
- Monitors CSI driver health
- Restarts driver if unhealthy

---

## 🔄 Volume Lifecycle with CSI

### 1. Volume Creation (Dynamic Provisioning)

```
User creates PVC
    ↓
External-Provisioner watches PVC
    ↓
Calls CreateVolume() on CSI Controller
    ↓
CSI Driver creates volume on backend
    ↓
External-Provisioner creates PV
    ↓
PV binds to PVC
```

**Code flow:**
```yaml
# User creates PVC
apiVersion: v1
kind: PersistentVolumeClaim
spec:
  storageClassName: csi-driver-sc

# External-Provisioner calls:
CreateVolumeRequest {
  name: "pvc-12345"
  capacity_range: {required_bytes: 10Gi}
  volume_capabilities: [{access_mode: SINGLE_NODE_WRITER}]
  parameters: {type: "gp3", iops: "3000"}
}

# CSI Driver returns:
CreateVolumeResponse {
  volume: {
    volume_id: "vol-abcdef123"
    capacity_bytes: 10737418240
  }
}

# Provisioner creates PV with volume_id
```

---

### 2. Volume Attachment (Pod Scheduling)

```
Pod scheduled to Node-1
    ↓
External-Attacher creates VolumeAttachment
    ↓
Calls ControllerPublishVolume() on CSI Controller
    ↓
CSI Driver attaches volume to Node-1
    ↓
Volume available on node (as block device)
```

---

### 3. Volume Mounting (Pod Startup)

```
Kubelet starts pod
    ↓
Calls NodeStageVolume() on Node Plugin
    ↓
CSI Driver formats and stages volume
    ↓
Kubelet calls NodePublishVolume()
    ↓
CSI Driver mounts to pod directory
    ↓
Pod can access volume
```

**Two-stage mount:**
```
NodeStageVolume()
  - Format volume (if needed)
  - Mount to staging path: /var/lib/kubelet/plugins/.../globalmount

NodePublishVolume()
  - Bind mount from staging path to pod path
  - Pod path: /var/lib/kubelet/pods/<pod-id>/volumes/...
```

**Why two stages?**
- **Efficiency**: Format once, bind mount for each pod
- **Shared volumes**: Multiple pods can use same staged volume

---

## 🎨 Popular CSI Drivers

### Cloud Provider Drivers

**AWS EBS CSI Driver:**
```yaml
driver: ebs.csi.aws.com
parameters:
  type: gp3
  iopsPerGB: "10"
  encrypted: "true"
```

**Features:**
- ✅ Dynamic provisioning
- ✅ Volume snapshots
- ✅ Volume cloning
- ✅ Volume expansion
- ❌ ReadWriteMany (EBS is block storage)

---

**GCE Persistent Disk CSI Driver:**
```yaml
driver: pd.csi.storage.gke.io
parameters:
  type: pd-ssd
  replication-type: regional-pd
```

**Features:**
- ✅ Dynamic provisioning
- ✅ Volume snapshots
- ✅ Volume expansion
- ✅ Multi-zone volumes (regional PD)
- ❌ ReadWriteMany (for most types)

---

**Azure Disk CSI Driver:**
```yaml
driver: disk.csi.azure.com
parameters:
  storageaccounttype: Premium_LRS
  kind: Managed
```

**Features:**
- ✅ Dynamic provisioning
- ✅ Volume snapshots
- ✅ Volume expansion
- ❌ ReadWriteMany

---

### Open Source Drivers

**Ceph CSI (RBD):**
```yaml
driver: rbd.csi.ceph.com
parameters:
  clusterID: rook-ceph
  pool: kubernetes
```

**Features:**
- ✅ Dynamic provisioning
- ✅ Volume snapshots
- ✅ Volume cloning
- ✅ High availability
- ✅ ReadWriteOnce
- ✅ ReadOnlyMany (with RBD)

---

**Ceph CSI (CephFS):**
```yaml
driver: cephfs.csi.ceph.com
parameters:
  clusterID: rook-ceph
  fsName: myfs
```

**Features:**
- ✅ ReadWriteMany (shared filesystem!)
- ✅ Dynamic provisioning
- ✅ Volume snapshots
- Perfect for shared storage needs

---

**NFS CSI Driver:**
```yaml
driver: nfs.csi.k8s.io
parameters:
  server: nfs-server.example.com
  share: /exports/data
```

**Features:**
- ✅ ReadWriteMany
- ✅ Simple setup
- ❌ No snapshots (usually)
- ❌ Single point of failure

---

**Longhorn (by Rancher):**
```yaml
driver: driver.longhorn.io
parameters:
  numberOfReplicas: "3"
  staleReplicaTimeout: "30"
```

**Features:**
- ✅ Distributed block storage
- ✅ Built-in replication
- ✅ Volume snapshots
- ✅ Backup to S3/NFS
- ✅ Web UI
- Good for on-premises K8s

---

**Local Path Provisioner:**
```yaml
driver: rancher.io/local-path
parameters:
  nodePath: /mnt/local-path-provisioner
```

**Features:**
- ✅ Simple local storage
- ✅ Dynamic provisioning
- ❌ Node-specific (not portable)
- ❌ No replication
- Good for development/testing

---

## 🔧 CSI Driver Installation

### Generic Installation Pattern

**1. Install CRDs (if needed):**
```bash
kubectl apply -f csi-driver-crds.yaml
```

**2. Create Namespace:**
```bash
kubectl create namespace csi-driver
```

**3. Deploy Driver:**
```bash
# Controller Plugin
kubectl apply -f csi-controller.yaml

# Node Plugin
kubectl apply -f csi-node-daemonset.yaml
```

**4. Create StorageClass:**
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: csi-storage
provisioner: <driver-name>.csi.k8s.io
parameters:
  # Driver-specific parameters
```

---

### Example: Local Path Provisioner

**Full deployment:**
```bash
# Install using manifest
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml

# Verify deployment
kubectl get pods -n local-path-storage

# Check CSI driver
kubectl get csidrivers
```

---

## 📊 CSI Features Comparison

| Feature | AWS EBS | GCE PD | Azure Disk | Ceph RBD | CephFS | NFS | Longhorn |
|---------|---------|--------|------------|----------|--------|-----|----------|
| Dynamic Provisioning | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Volume Snapshots | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ |
| Volume Cloning | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ✅ |
| Volume Expansion | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ |
| RWO | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| ROX | ❌ | ✅ | ❌ | ✅ | ✅ | ✅ | ❌ |
| RWX | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ | ❌ |
| Encryption | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ |

---

## 🎯 CSI in Practice

### StorageClass Configuration

**Basic StorageClass:**
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  iopsPerGB: "10"
  encrypted: "true"
  kmsKeyId: arn:aws:kms:us-east-1:123456789012:key/12345
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
reclaimPolicy: Delete
```

**Advanced with Topology:**
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: regional-storage
provisioner: pd.csi.storage.gke.io
parameters:
  type: pd-ssd
  replication-type: regional-pd
allowedTopologies:
- matchLabelExpressions:
  - key: topology.gke.io/zone
    values:
    - us-central1-a
    - us-central1-b
```

---

### Using CSI Snapshots

**VolumeSnapshotClass:**
```yaml
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotClass
metadata:
  name: csi-snapclass
driver: ebs.csi.aws.com
deletionPolicy: Delete
parameters:
  # Driver-specific snapshot parameters
```

**Creating Snapshot:**
```yaml
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: my-snapshot
spec:
  volumeSnapshotClassName: csi-snapclass
  source:
    persistentVolumeClaimName: my-pvc
```

---

## 🔒 Security Considerations

### 1. RBAC for CSI Components

```yaml
# CSI Controller needs cluster-wide permissions
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: csi-controller-role
rules:
- apiGroups: [""]
  resources: ["persistentvolumes"]
  verbs: ["create", "delete", "get", "list", "watch", "update", "patch"]
- apiGroups: [""]
  resources: ["persistentvolumeclaims"]
  verbs: ["get", "list", "watch", "update"]
# ... more permissions
```

---

### 2. Pod Security

```yaml
# CSI Node plugin needs privileged access
securityContext:
  privileged: true
  capabilities:
    add: ["SYS_ADMIN"]
  allowPrivilegeEscalation: true
```

**Why privileged?**
- Needs to mount volumes
- Access to host filesystem
- Execute mount commands

**Mitigation:**
- Run CSI in dedicated namespace
- Use Pod Security Standards
- Regular security audits

---

### 3. Encryption

**At-rest encryption:**
```yaml
parameters:
  encrypted: "true"
  kmsKeyId: arn:aws:kms:...
```

**In-transit encryption:**
- Depends on storage backend
- Some drivers support TLS

---

## 📖 Best Practices

### 1. Use Specific CSI Driver Versions

```yaml
# Bad: Latest tag
image: registry.k8s.io/sig-storage/csi-provisioner:latest

# Good: Specific version
image: registry.k8s.io/sig-storage/csi-provisioner:v3.5.0
```

---

### 2. Set Resource Limits

```yaml
containers:
- name: csi-provisioner
  resources:
    requests:
      memory: "128Mi"
      cpu: "100m"
    limits:
      memory: "256Mi"
      cpu: "200m"
```

---

### 3. Configure Health Probes

```yaml
livenessProbe:
  httpGet:
    path: /healthz
    port: 9808
  initialDelaySeconds: 10
  periodSeconds: 10
```

---

### 4. Use VolumeBindingMode Wisely

```yaml
# For topology-aware provisioning
volumeBindingMode: WaitForFirstConsumer

# For pre-provisioned volumes
volumeBindingMode: Immediate
```

---

## 🚀 Project: Deploy Multi-Driver Application

For this module's project, you'll:

1. **Install CSI Driver** (local-path-provisioner for testing)
2. **Create StorageClasses** with different configurations
3. **Deploy Application** using CSI volumes
4. **Test CSI Features**:
   - Dynamic provisioning
   - Volume snapshots
   - Volume cloning
   - Volume expansion
5. **Monitor CSI Components**
6. **Troubleshoot Issues**

---

## 📖 Key Takeaways

✅ CSI is the standard interface for storage in Kubernetes
✅ CSI drivers run out-of-tree (separate from K8s core)
✅ Two main components: Controller and Node plugins
✅ External sidecars provide standard functionality
✅ CSI enables advanced features (snapshots, cloning, expansion)
✅ Choose driver based on storage backend and requirements
✅ Always use specific versions in production
✅ Security considerations for privileged CSI pods

---

## 🔗 Additional Resources

- [CSI Specification](https://github.com/container-storage-interface/spec)
- [Kubernetes CSI Documentation](https://kubernetes-csi.github.io/docs/)
- [CSI Drivers List](https://kubernetes-csi.github.io/docs/drivers.html)
- [CSI Developer Guide](https://kubernetes-csi.github.io/docs/developing.html)

---

## 🚀 Next Steps

1. Complete hands-on exercises in GUIDEME.md
2. Deploy CSI driver and test features
3. Understand driver architecture
4. Review troubleshooting guide
5. Move to Day 39-40: Storage Troubleshooting

**Happy Learning! 🔌💾**
