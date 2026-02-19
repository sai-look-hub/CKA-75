# 📋 Command Cheatsheet: StorageClasses

## Viewing

```bash
# List all StorageClasses
kubectl get sc

# Show default
kubectl get sc | grep default

# Describe StorageClass
kubectl describe sc <name>

# Get with custom columns
kubectl get sc -o custom-columns=NAME:.metadata.name,PROVISIONER:.provisioner,RECLAIM:.reclaimPolicy,EXPANSION:.allowVolumeExpansion
```

## Creating

```bash
# Apply from file
kubectl apply -f storageclass.yaml

# Create inline
kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
EOF
```

## Modifying

```bash
# Set as default
kubectl patch sc standard -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

# Remove default
kubectl patch sc old -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'

# Edit
kubectl edit sc <name>
```

## Testing

```bash
# Create test PVC
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test
spec:
  storageClassName: fast
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 1Gi
EOF

# Check binding
kubectl get pvc test -w
```

## Analysis

```bash
# Count PVCs per StorageClass
kubectl get pvc -A -o json | jq -r '.items[].spec.storageClassName' | sort | uniq -c

# Total storage by class
kubectl get pvc -A -o json | jq -r '.items[] | "\(.spec.storageClassName) \(.spec.resources.requests.storage)"' | awk '{sum[$1]+=$2} END {for (i in sum) print i, sum[i]}'

# Find PVCs using class
kubectl get pvc -A -o json | jq -r '.items[] | select(.spec.storageClassName=="fast") | "\(.metadata.namespace)/\(.metadata.name)"'
```
