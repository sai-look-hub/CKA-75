# csi-examples.yaml
# CSI driver examples and configurations

---
# 1. StorageClass for AWS EBS CSI Driver
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ebs-sc-gp3
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  iopsPerGB: "10"
  throughput: "125"
  encrypted: "true"
  kmsKeyId: "arn:aws:kms:us-east-1:123456789012:key/abcd-1234"
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
reclaimPolicy: Delete

---
# 2. StorageClass for GCE Persistent Disk
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gce-pd-ssd
provisioner: pd.csi.storage.gke.io
parameters:
  type: pd-ssd
  replication-type: regional-pd
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
allowedTopologies:
- matchLabelExpressions:
  - key: topology.gke.io/zone
    values:
    - us-central1-a
    - us-central1-b

---
# 3. StorageClass for Ceph RBD
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ceph-rbd
provisioner: rbd.csi.ceph.com
parameters:
  clusterID: rook-ceph
  pool: kubernetes
  imageFormat: "2"
  imageFeatures: layering
  csi.storage.k8s.io/provisioner-secret-name: rook-csi-rbd-provisioner
  csi.storage.k8s.io/provisioner-secret-namespace: rook-ceph
  csi.storage.k8s.io/node-stage-secret-name: rook-csi-rbd-node
  csi.storage.k8s.io/node-stage-secret-namespace: rook-ceph
  csi.storage.k8s.io/controller-expand-secret-name: rook-csi-rbd-provisioner
  csi.storage.k8s.io/controller-expand-secret-namespace: rook-ceph
volumeBindingMode: Immediate
reclaimPolicy: Delete
allowVolumeExpansion: true

---
# 4. StorageClass for Local Path Provisioner
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-path
provisioner: rancher.io/local-path
parameters:
  nodePath: /opt/local-path-provisioner
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete

---
# 5. VolumeSnapshotClass for CSI Driver
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotClass
metadata:
  name: csi-snapclass
driver: ebs.csi.aws.com
deletionPolicy: Delete
parameters:
  tagSpecification_1: "Name=SnapshotCreatedBy,Value=CSI"

---
# 6. Sample PVC using CSI StorageClass
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: csi-pvc-example
spec:
  accessModes:
  - ReadWriteOnce
  storageClassName: ebs-sc-gp3
  resources:
    requests:
      storage: 10Gi

---
# 7. Pod using CSI Volume
apiVersion: v1
kind: Pod
metadata:
  name: csi-app-pod
spec:
  containers:
  - name: app
    image: nginx
    volumeMounts:
    - name: csi-volume
      mountPath: /usr/share/nginx/html
  volumes:
  - name: csi-volume
    persistentVolumeClaim:
      claimName: csi-pvc-example

---
# 8. StatefulSet with CSI volumeClaimTemplates
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: web
spec:
  serviceName: web
  replicas: 3
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: nginx
        image: nginx
        volumeMounts:
        - name: www
          mountPath: /usr/share/nginx/html
  volumeClaimTemplates:
  - metadata:
      name: www
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: ebs-sc-gp3
      resources:
        requests:
          storage: 5Gi

---
# Usage:
# 1. Choose appropriate StorageClass for your environment
# 2. Create PVC using the StorageClass
# 3. Deploy pod/StatefulSet using the PVC
# 4. Verify CSI operations:
#    kubectl get pvc
#    kubectl get pv
#    kubectl describe pv <pv-name>
