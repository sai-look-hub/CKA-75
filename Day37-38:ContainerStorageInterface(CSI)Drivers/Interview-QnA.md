# 🎤 Interview Q&A: CSI Drivers

---

## Q1: What is CSI and why was it introduced?

**Answer:**

**CSI = Container Storage Interface**

A **standard specification** for exposing block and file storage systems to containerized workloads across different container orchestrators.

**Why it was introduced:**

**Before CSI (in-tree plugins):**
```
Kubernetes Core Code
├─ AWS EBS Plugin
├─ GCE Persistent Disk Plugin
├─ Azure Disk Plugin
├─ NFS Plugin
├─ 20+ other storage plugins
```

**Problems:**
1. **Kubernetes release dependency**: Storage features tied to K8s release cycle
2. **Maintenance burden**: K8s maintainers had to support all plugins
3. **Security concerns**: Storage code ran as part of kube-controller-manager
4. **Limited extensibility**: Adding new storage required K8s code changes
5. **Quality inconsistency**: Different plugins, different quality levels

**After CSI (out-of-tree plugins):**
```
Kubernetes ← CSI Interface → CSI Drivers (external)
                              ├─ AWS EBS CSI
                              ├─ GCE PD CSI
                              ├─ Azure Disk CSI
                              └─ Any vendor's driver
```

**Benefits:**
1. **Independence**: Drivers developed/released separately from K8s
2. **Standardization**: One API works across K8s, Mesos, Cloud Foundry
3. **Better security**: Drivers run in separate pods with limited privileges
4. **Faster innovation**: No waiting for K8s releases
5. **Vendor flexibility**: Anyone can write CSI driver

**Analogy:**
CSI is like USB for storage - one interface, any device!

---

## Q2: Explain the CSI driver architecture with its main components.

**Answer:**

CSI drivers have **two main components**:

**1. Controller Plugin (Cluster-level operations)**

**Runs as:** StatefulSet or Deployment (usually 1 replica, can be HA)

**Responsibilities:**
- **CreateVolume**: Provision new volumes
- **DeleteVolume**: Delete volumes
- **ControllerPublishVolume**: Attach volume to node
- **ControllerUnpublishVolume**: Detach volume from node
- **CreateSnapshot**: Create volume snapshots
- **DeleteSnapshot**: Delete snapshots
- **ControllerExpandVolume**: Expand volume size

**Contains:**
```
┌──────────────────────────────────────┐
│  CSI Controller Pod                  │
├──────────────────────────────────────┤
│  Sidecars (from K8s):                │
│  - external-provisioner              │
│  - external-attacher                 │
│  - external-snapshotter              │
│  - external-resizer                  │
│  - liveness-probe                    │
│                                      │
│  Driver Container:                   │
│  - Actual storage driver code        │
│  - Implements CSI RPCs               │
│  - Talks to storage backend          │
└──────────────────────────────────────┘
```

**2. Node Plugin (Node-level operations)**

**Runs as:** DaemonSet (one pod per node)

**Responsibilities:**
- **NodeStageVolume**: Format and stage volume on node
- **NodeUnstageVolume**: Unstage volume from node
- **NodePublishVolume**: Mount volume to pod directory
- **NodeUnpublishVolume**: Unmount volume from pod
- **NodeGetVolumeStats**: Get volume usage statistics
- **NodeGetCapabilities**: Report node capabilities

**Contains:**
```
┌──────────────────────────────────────┐
│  CSI Node Pod (DaemonSet)            │
├──────────────────────────────────────┤
│  Sidecars:                           │
│  - node-driver-registrar             │
│  - liveness-probe                    │
│                                      │
│  Driver Container:                   │
│  - Mount/unmount operations          │
│  - File system operations            │
│  - Volume statistics                 │
└──────────────────────────────────────┘
```

**Communication Flow:**
```
kubectl create pvc
    ↓
External-Provisioner (sidecar)
    ↓ gRPC call
CSI Controller (CreateVolume)
    ↓ API call
Storage Backend (create volume)
    ↓ return volume-id
External-Provisioner creates PV
```

**Key Points:**
- Controller: 1 pod for cluster
- Node: 1 pod per node
- Sidecars: Provided by K8s (reusable)
- Driver: Vendor-specific code

---

## Q3: What are CSI sidecars and what role do they play?

**Answer:**

CSI sidecars are **helper containers** provided by Kubernetes that handle standard operations, so each CSI driver doesn't need to implement them.

**Major Sidecars:**

**1. external-provisioner**
- **Watches:** PersistentVolumeClaims
- **Does:** Calls CreateVolume on CSI driver, creates PV
- **Why needed:** Handles PVC → PV binding logic

**2. external-attacher**
- **Watches:** VolumeAttachment objects
- **Does:** Calls ControllerPublish/Unpublish
- **Why needed:** Manages attach/detach lifecycle

**3. external-snapshotter**
- **Watches:** VolumeSnapshot objects
- **Does:** Calls CreateSnapshot, creates VolumeSnapshotContent
- **Why needed:** Handles snapshot operations

**4. external-resizer**
- **Watches:** PVC resize requests
- **Does:** Calls ControllerExpandVolume
- **Why needed:** Handles volume expansion

**5. node-driver-registrar**
- **Runs:** On each node (DaemonSet)
- **Does:** Registers CSI driver with kubelet
- **Why needed:** Tells kubelet which drivers are available

**6. livenessprobe**
- **Does:** Health checks via /healthz endpoint
- **Why needed:** Restarts driver if unhealthy

**Benefits of Sidecars:**

1. **Reusability**: Same sidecars work with any CSI driver
2. **Separation of concerns**: Driver focuses on storage, sidecars handle K8s integration
3. **Maintainability**: K8s team maintains sidecars, vendors maintain drivers
4. **Consistency**: All drivers behave similarly

**Example Pod:**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: csi-controller
spec:
  containers:
  # Sidecars from K8s
  - name: csi-provisioner
    image: registry.k8s.io/sig-storage/csi-provisioner:v3.5.0
  - name: csi-attacher
    image: registry.k8s.io/sig-storage/csi-attacher:v4.3.0
  - name: csi-snapshotter
    image: registry.k8s.io/sig-storage/csi-snapshotter:v6.2.0
  - name: csi-resizer
    image: registry.k8s.io/sig-storage/csi-resizer:v1.8.0
  
  # Vendor's driver
  - name: ebs-plugin
    image: amazon/aws-ebs-csi-driver:v1.19.0
```

---

Continue with more questions...
