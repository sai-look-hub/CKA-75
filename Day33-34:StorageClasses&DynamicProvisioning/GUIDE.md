# 📖 GUIDEME: StorageClasses & Dynamic Provisioning

## 🎯 Overview

16-hour structured learning path mastering dynamic storage provisioning across cloud providers and deploying a complete multi-tier application.

---

## ⏱️ Time Allocation

**Day 1 (8 hours):**
- Hours 1-2: StorageClass fundamentals
- Hours 3-4: Cloud provider provisioners
- Hours 5-6: Storage tiers implementation
- Hours 7-8: Volume binding and expansion

**Day 2 (8 hours):**
- Hours 1-3: Multi-tier application project
- Hours 4-5: Advanced configurations
- Hours 6-7: Troubleshooting and optimization
- Hour 8: Production best practices and review

---

## 📚 Phase 1: StorageClass Fundamentals (2 hours)

### Step 1: Understanding the Problem (30 minutes)

```bash
# Simulate manual provisioning pain
echo "Admin Task: Create 10 PVs for new project"
for i in {1..10}; do
  cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: manual-pv-$i
spec:
  capacity:
    storage: ${i}Gi
  accessModes:
  - ReadWriteOnce
  hostPath:
    path: /mnt/data-$i
  storageClassName: manual
EOF
done

# Time: ~10 minutes for 10 PVs
# Scale: What about 100? 1000?
# Errors: Wrong size, access mode, forgotten PVs

kubectl get pv
# Cleanup
kubectl delete pv -l manual
```

**💡 Key Insight**: Manual provisioning doesn't scale!

---

### Step 2: First StorageClass (30 minutes)

```bash
# Create a basic StorageClass
kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-dynamic
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
EOF

# Check it was created
kubectl get storageclass

# Describe it
kubectl describe sc local-dynamic

# Create PVC using this StorageClass
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
  storageClassName: local-dynamic
EOF

# Check status (will be Pending - no-provisioner doesn't auto-create)
kubectl get pvc dynamic-pvc

# For local, we still need to create PV, but shows the concept
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: local-pv-1
spec:
  capacity:
    storage: 10Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Delete
  storageClassName: local-dynamic
  local:
    path: /mnt/disks/vol1
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - $(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
EOF

# Now PVC binds when pod created (WaitForFirstConsumer)
```

**✅ Checkpoint**: Understanding StorageClass basic structure.

---

### Step 3: Default StorageClass (30 minutes)

```bash
# Create default StorageClass
kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: standard
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
EOF

# Check which is default
kubectl get sc
# Look for (default) marker

# Create PVC without specifying storageClassName
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: default-pvc
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 3Gi
  # No storageClassName - uses default!
EOF

# Verify it's using standard class
kubectl get pvc default-pvc -o yaml | grep storageClassName

# Change default
kubectl patch sc local-dynamic -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
kubectl patch sc standard -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'

kubectl get sc
```

**✅ Checkpoint**: Default StorageClass configured.

---

## ☁️ Phase 2: Cloud Provider Provisioners (2 hours)

### Step 1: AWS StorageClasses (45 minutes)

```bash
# Note: These require actual AWS cluster with EBS CSI driver
# For learning, we'll create the definitions

# Apply all AWS StorageClasses
kubectl apply -f storageclass-aws.yaml

# Check created classes
kubectl get sc | grep aws

# Examine gp3 class
kubectl describe sc aws-gp3

# Test with PVC (will fail without AWS)
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: aws-test
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  storageClassName: aws-gp3
EOF

# Check events
kubectl describe pvc aws-test
# Will show provisioning attempts or errors

# If on AWS:
# - PV created automatically
# - EBS volume created in AWS
# - PVC binds when pod created (WaitForFirstConsumer)
```

**✅ Checkpoint**: Understanding AWS EBS provisioning.

---

### Step 2: Azure StorageClasses (45 minutes)

```bash
# Apply Azure StorageClasses
kubectl apply -f storageclass-azure.yaml

# Check created classes
kubectl get sc | grep azure

# Examine Premium SSD class
kubectl describe sc azure-premium-ssd

# Compare different tiers
kubectl get sc -o custom-columns=NAME:.metadata.name,PROVISIONER:.provisioner,PARAMETERS:.parameters
```

**✅ Checkpoint**: Understanding Azure Disk provisioning.

---

### Step 3: GCP StorageClasses (30 minutes)

```bash
# Apply GCP StorageClasses
kubectl apply -f storageclass-gcp.yaml

# Check created classes
kubectl get sc | grep gcp

# Examine regional PD class
kubectl describe sc gcp-regional-pd

# Note regional vs zonal differences
```

**✅ Checkpoint**: Understanding GCP PD provisioning.

---

## 🗂️ Phase 3: Storage Tiers (2 hours)

### Step 1: Define Tier Strategy (30 minutes)

```bash
# Create three-tier storage strategy
kubectl apply -f - <<EOF
---
# Tier 1: Performance (for databases)
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: performance
  labels:
    tier: performance
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
---
# Tier 2: Standard (for applications)
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: standard
  labels:
    tier: standard
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
---
# Tier 3: Archive (for backups)
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: archive
  labels:
    tier: archive
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
EOF

# List tiers
kubectl get sc -L tier

# Test each tier
for tier in performance standard archive; do
  kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ${tier}-pvc
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
  storageClassName: ${tier}
EOF
done

kubectl get pvc
```

**✅ Checkpoint**: Multi-tier storage strategy implemented.

---

### Step 2: Workload-to-Tier Mapping (45 minutes)

```bash
# Create PVCs for different workload types
# Database - Performance tier
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-data
  labels:
    app: database
    tier: performance
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 20Gi
  storageClassName: performance
EOF

# Application - Standard tier
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: app-logs
  labels:
    app: backend
    tier: standard
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  storageClassName: standard
EOF

# Backup - Archive tier
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: backup-storage
  labels:
    app: backup
    tier: archive
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 100Gi
  storageClassName: archive
EOF

# View by tier
kubectl get pvc -L tier
```

**✅ Checkpoint**: Workloads mapped to appropriate tiers.

---

### Step 3: Cost Analysis (45 minutes)

```bash
# Calculate storage costs by tier
cat > analyze-storage-cost.sh << 'SCRIPT'
#!/bin/bash
echo "Storage Cost Analysis"
echo "===================="

for tier in performance standard archive; do
  total=$(kubectl get pvc -l tier=$tier -o json | \
    jq -r '[.items[].spec.resources.requests.storage | 
    rtrimstr("Gi") | tonumber] | add // 0')
  
  # Simulated costs ($/GB/month)
  case $tier in
    performance) cost=0.10 ;;
    standard) cost=0.05 ;;
    archive) cost=0.01 ;;
  esac
  
  monthly=$(echo "$total * $cost" | bc)
  echo "$tier: ${total}Gi @ \$${cost}/GB = \$${monthly}/month"
done
SCRIPT

chmod +x analyze-storage-cost.sh
./analyze-storage-cost.sh
```

**✅ Checkpoint**: Understanding cost implications of tier selection.

---

## 🔄 Phase 4: Volume Binding and Expansion (2 hours)

### Step 1: WaitForFirstConsumer Testing (45 minutes)

```bash
# Create PVC with WaitForFirstConsumer
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: wait-pvc
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
  storageClassName: standard
EOF

# PVC stays Pending
kubectl get pvc wait-pvc
# STATUS: Pending (this is normal!)

# Create matching PV for binding
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: wait-pv
spec:
  capacity:
    storage: 10Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Delete
  storageClassName: standard
  hostPath:
    path: /mnt/wait
    type: DirectoryOrCreate
EOF

# Still Pending - waiting for consumer!
kubectl get pvc wait-pvc

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
    command: ['sh', '-c', 'echo "Consumer started" && sleep 3600']
    volumeMounts:
    - name: storage
      mountPath: /data
  volumes:
  - name: storage
    persistentVolumeClaim:
      claimName: wait-pvc
EOF

# NOW it binds!
kubectl get pvc wait-pvc -w
# Watch it go from Pending → Bound

# Verify pod started
kubectl get pod consumer-pod
```

**✅ Checkpoint**: WaitForFirstConsumer behavior understood.

---

### Step 2: Volume Expansion (45 minutes)

```bash
# Create expandable PVC
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: expandable-pvc
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
  storageClassName: standard  # Must allow expansion
EOF

# Create pod using it
kubectl run expand-test --image=nginx --overrides='
{
  "spec": {
    "volumes": [{
      "name": "data",
      "persistentVolumeClaim": {"claimName": "expandable-pvc"}
    }],
    "containers": [{
      "name": "expand-test",
      "image": "nginx",
      "volumeMounts": [{"name": "data", "mountPath": "/data"}]
    }]
  }
}'

# Check current size
kubectl exec expand-test -- df -h /data

# Expand the PVC
kubectl patch pvc expandable-pvc -p '{"spec":{"resources":{"requests":{"storage":"10Gi"}}}}'

# Watch expansion
kubectl get pvc expandable-pvc -w

# May need to delete pod for filesystem expansion
kubectl delete pod expand-test
kubectl run expand-test --image=nginx --overrides='...'  # Same as before

# Verify new size
kubectl exec expand-test -- df -h /data
```

**✅ Checkpoint**: Volume expansion working.

---

### Step 3: Expansion Limitations (30 minutes)

```bash
# Try to shrink (will fail)
kubectl patch pvc expandable-pvc -p '{"spec":{"resources":{"requests":{"storage":"5Gi"}}}}'
# Error: volume size cannot be decreased

# Try expansion without allowVolumeExpansion
kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: no-expand
provisioner: kubernetes.io/no-provisioner
allowVolumeExpansion: false  # Expansion disabled
EOF

kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: no-expand-pvc
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
  storageClassName: no-expand
EOF

# Try to expand (will fail)
kubectl patch pvc no-expand-pvc -p '{"spec":{"resources":{"requests":{"storage":"10Gi"}}}}'
# Error: storageclass does not allow expansion
```

**✅ Checkpoint**: Understanding expansion constraints.

---

## 🏗️ Phase 5: Multi-Tier Application Project (3 hours)

### Step 1: Architecture Design (30 minutes)

```bash
# Review multi-tier-app.yaml architecture
cat multi-tier-app.yaml

# Components:
# 1. Frontend (Nginx) - standard storage
# 2. Backend API (Node.js) - standard storage
# 3. Database (PostgreSQL) - performance storage
# 4. Cache (Redis) - performance storage
# 5. Backup job - archive storage

# Create namespace
kubectl create namespace multi-tier

# Apply all StorageClasses
kubectl apply -f multi-tier-storageclasses.yaml
```

**✅ Checkpoint**: Architecture understood.

---

### Step 2: Deploy Database Tier (45 minutes)

```bash
# Deploy PostgreSQL with performance storage
kubectl apply -f multi-tier-app.yaml -l component=database

# Wait for database
kubectl wait --for=condition=ready pod/postgres-0 -n multi-tier --timeout=120s

# Check PVC
kubectl get pvc -n multi-tier -l component=database

# Verify storage class used
kubectl get pvc -n multi-tier postgres-data -o jsonpath='{.spec.storageClassName}'
# Should be: performance

# Check actual size
kubectl exec -n multi-tier postgres-0 -- df -h /var/lib/postgresql/data

# Create test database
kubectl exec -n multi-tier postgres-0 -- psql -U postgres -c "CREATE DATABASE testdb;"
```

**✅ Checkpoint**: Database deployed with performance storage.

---

### Step 3: Deploy Application Tier (45 minutes)

```bash
# Deploy backend API
kubectl apply -f multi-tier-app.yaml -l component=backend

# Wait for backend
kubectl wait --for=condition=ready pod -l component=backend -n multi-tier --timeout=60s

# Deploy frontend
kubectl apply -f multi-tier-app.yaml -l component=frontend

# Wait for frontend
kubectl wait --for=condition=ready pod -l component=frontend -n multi-tier --timeout=60s

# Check all PVCs
kubectl get pvc -n multi-tier

# Access application
kubectl port-forward -n multi-tier svc/frontend 8080:80 &
curl http://localhost:8080
```

**✅ Checkpoint**: Application tier deployed.

---

### Step 4: Deploy Cache and Backup (60 minutes)

```bash
# Deploy Redis cache with performance storage
kubectl apply -f multi-tier-app.yaml -l component=cache

# Deploy backup job with archive storage
kubectl apply -f multi-tier-app.yaml -l component=backup

# Check all components
kubectl get all,pvc -n multi-tier

# Verify storage classes
kubectl get pvc -n multi-tier -o custom-columns=\
NAME:.metadata.name,\
STORAGECLASS:.spec.storageClassName,\
SIZE:.spec.resources.requests.storage,\
COMPONENT:.metadata.labels.component
```

**✅ Checkpoint**: Complete application deployed.

---

### Step 5: Test and Validate (30 minutes)

```bash
# Test database persistence
kubectl exec -n multi-tier postgres-0 -- psql -U postgres -d testdb -c \
  "CREATE TABLE users (id SERIAL, name VARCHAR(50)); 
   INSERT INTO users (name) VALUES ('Alice'), ('Bob');"

# Delete pod
kubectl delete pod postgres-0 -n multi-tier

# Wait for recreation
kubectl wait --for=condition=ready pod/postgres-0 -n multi-tier --timeout=120s

# Data should persist
kubectl exec -n multi-tier postgres-0 -- psql -U postgres -d testdb -c \
  "SELECT * FROM users;"

# Test backup job
kubectl create job backup-now --from=cronjob/backup-job -n multi-tier
kubectl logs -n multi-tier job/backup-now
```

**✅ Checkpoint**: Application fully functional with persistent storage.

---

## 🔬 Phase 6: Advanced Scenarios (2 hours)

### Exercise 1: Storage Migration (45 minutes)

```bash
# Migrate from standard to performance storage
# 1. Create new PVC with performance class
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-data-new
  namespace: multi-tier
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 20Gi
  storageClassName: performance
EOF

# 2. Scale down database
kubectl scale statefulset postgres -n multi-tier --replicas=0

# 3. Copy data using job
kubectl apply -f - <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: data-migration
  namespace: multi-tier
spec:
  template:
    spec:
      containers:
      - name: copy
        image: busybox
        command: ['sh', '-c', 'cp -r /old/* /new/']
        volumeMounts:
        - name: old-data
          mountPath: /old
        - name: new-data
          mountPath: /new
      restartPolicy: Never
      volumes:
      - name: old-data
        persistentVolumeClaim:
          claimName: postgres-data
      - name: new-data
        persistentVolumeClaim:
          claimName: postgres-data-new
EOF

# 4. Update StatefulSet to use new PVC
# 5. Scale back up
```

---

### Exercise 2: Multi-Zone Deployment (45 minutes)

```bash
# Create topology-aware StorageClass
kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: multi-zone
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
allowedTopologies:
- matchLabelExpressions:
  - key: topology.kubernetes.io/zone
    values:
    - zone-a
    - zone-b
    - zone-c
EOF

# Deploy across zones
kubectl apply -f multi-zone-deployment.yaml
```

---

### Exercise 3: Cost Optimization (30 minutes)

```bash
# Analyze current storage usage
kubectl get pvc -A -o json | jq -r '
.items[] | 
"\(.metadata.namespace)/\(.metadata.name): \
\(.spec.storageClassName) - \(.spec.resources.requests.storage)"
'

# Identify optimization opportunities
# - Move non-critical to lower tiers
# - Remove unused PVCs
# - Rightsize oversized volumes
```

**✅ Checkpoint**: Advanced scenarios mastered.

---

## ✅ Final Validation Checklist

- [ ] Create StorageClasses for different tiers
- [ ] Configure default StorageClass
- [ ] Enable volume expansion
- [ ] Use WaitForFirstConsumer binding mode
- [ ] Deploy multi-tier application
- [ ] Test data persistence
- [ ] Perform volume expansion
- [ ] Analyze and optimize costs

**Congratulations! You've mastered Kubernetes dynamic storage provisioning! 🎯**
