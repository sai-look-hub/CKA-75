# 🔧 Troubleshooting: PersistentVolumes & PVCs

Common issues and solutions for Kubernetes persistent storage.

---

## 🔴 Issue 1: PVC Stuck in Pending

**Symptoms:**
```bash
kubectl get pvc
# NAME      STATUS    VOLUME   CAPACITY   ACCESS MODES
# my-pvc    Pending                                    
```

**Common Causes:**

**Cause 1: No matching PV available**
```bash
kubectl describe pvc my-pvc
# Events: no persistent volumes available
```

**Solution:**
```bash
# Check available PVs
kubectl get pv

# If none, create one:
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-match
spec:
  capacity:
    storage: 10Gi  # Must be >= PVC request
  accessModes:
  - ReadWriteOnce  # Must match PVC
  storageClassName: manual  # Must match PVC
  hostPath:
    path: /mnt/data
EOF
```

**Cause 2: StorageClass doesn't exist**
```bash
kubectl get pvc my-pvc -o yaml | grep storageClassName
# storageClassName: non-existent
```

**Solution:**
```bash
# List available StorageClasses
kubectl get sc

# Fix PVC to use existing StorageClass or create new one
```

**Cause 3: Size mismatch**
```bash
# PVC requests 10Gi
# Available PV only has 5Gi
```

**Solution:**
Create PV with sufficient capacity or reduce PVC request.

**Cause 4: Access mode mismatch**
```bash
# PVC wants ReadWriteMany
# PV only supports ReadWriteOnce
```

**Solution:**
Match access modes or use storage that supports RWX.

---

## 💥 Issue 2: Pod Can't Mount PVC

**Symptoms:**
```bash
kubectl get pods
# NAME    READY   STATUS              AGE
# my-pod  0/1     ContainerCreating   5m

kubectl describe pod my-pod
# MountVolume.SetUp failed: volume not yet bound
```

**Diagnosis:**
```bash
# Check if PVC is bound
kubectl get pvc
# If Pending, see Issue 1

# Check events
kubectl get events --field-selector involvedObject.name=my-pod
```

**Solutions:**

**If WaitForFirstConsumer:**
```bash
# This is normal! Volume binds when pod scheduled
# Wait for binding to complete
kubectl get pvc -w
```

**If permissions issue:**
```bash
# Check pod security context
kubectl get pod my-pod -o yaml | grep -A10 securityContext

# Add fsGroup if needed:
spec:
  securityContext:
    fsGroup: 2000
```

---

## 📝 Issue 3: Permission Denied on Volume

**Symptoms:**
```bash
kubectl logs my-pod
# Error: Permission denied: /data/file.txt
```

**Diagnosis:**
```bash
# Check filesystem permissions
kubectl exec my-pod -- ls -la /data

# Check pod user
kubectl exec my-pod -- id
```

**Solutions:**

**Solution 1: Use fsGroup**
```yaml
spec:
  securityContext:
    fsGroup: 1000
    runAsUser: 1000
```

**Solution 2: Init container fix**
```yaml
initContainers:
- name: fix-perms
  image: busybox
  command: ['sh', '-c', 'chown -R 1000:1000 /data']
  volumeMounts:
  - name: data
    mountPath: /data
```

**Solution 3: For PostgreSQL (common issue)**
```yaml
# PostgreSQL needs specific permissions
spec:
  securityContext:
    fsGroup: 999  # postgres group
  containers:
  - name: postgres
    securityContext:
      runAsUser: 999
```

---

## 🔄 Issue 4: PV Won't Bind to New PVC

**Symptoms:**
```bash
# Old PVC deleted, new PVC won't bind to same PV
kubectl get pv
# NAME     STATUS    CLAIM
# my-pv    Released  old-namespace/old-pvc
```

**Explanation:**
PV with Retain policy stays in "Released" state after PVC deletion.

**Solution:**

**Option 1: Edit PV to remove claimRef**
```bash
kubectl patch pv my-pv -p '{"spec":{"claimRef": null}}'
# PV becomes Available again
```

**Option 2: Clean and recreate PV**
```bash
# Backup data if needed
# Delete PV
kubectl delete pv my-pv

# Clean data directory on node (optional)
minikube ssh "sudo rm -rf /mnt/data/*"

# Recreate PV
kubectl apply -f my-pv.yaml
```

---

## 💾 Issue 5: Storage Full

**Symptoms:**
```bash
kubectl logs my-pod
# Error: No space left on device

kubectl exec my-pod -- df -h /data
# /dev/sda1  10G  10G  0  100% /data
```

**Solutions:**

**Solution 1: Expand volume (if supported)**
```bash
# Check if expansion allowed
kubectl get sc <storage-class> -o yaml | grep allowVolumeExpansion

# Edit PVC to request more space
kubectl patch pvc my-pvc -p '{"spec":{"resources":{"requests":{"storage":"20Gi"}}}}'

# May need to delete pod to trigger expansion
kubectl delete pod my-pod
```

**Solution 2: Clean up old data**
```bash
kubectl exec my-pod -- sh -c 'rm -rf /data/old-logs/*'
```

**Solution 3: Create new larger PVC**
```bash
# Backup data
kubectl exec my-pod -- tar czf /tmp/backup.tar.gz /data

# Create new PVC with more space
# Copy data to new PVC
# Update deployment to use new PVC
```

---

## 🗄️ Issue 6: Database Won't Start

**Symptoms:**
```bash
kubectl logs postgres-0
# Error: data directory /var/lib/postgresql/data/pgdata has wrong ownership
```

**Common PostgreSQL issues:**

**Issue 1: Directory not empty**
```bash
# PostgreSQL sees files from previous failed init
```

**Solution:**
```bash
# Delete PVC and start fresh
kubectl delete pvc postgres-pvc
kubectl delete pod postgres-0
# StatefulSet recreates with fresh PVC
```

**Issue 2: Permissions wrong**
```bash
# Volume mounted with wrong user/group
```

**Solution:**
```yaml
spec:
  securityContext:
    fsGroup: 999
  initContainers:
  - name: fix-perms
    image: busybox
    command: ['sh', '-c', 'chown -R 999:999 /data && chmod 700 /data']
    volumeMounts:
    - name: data
      mountPath: /data
```

**Issue 3: Using subPath incorrectly**
```yaml
# Wrong
volumeMounts:
- name: data
  mountPath: /var/lib/postgresql/data
  # PostgreSQL creates /var/lib/postgresql/data/pgdata
  # This conflicts!

# Right
volumeMounts:
- name: data
  mountPath: /var/lib/postgresql/data
  subPath: postgres  # PostgreSQL can create pgdata inside
```

---

## 🔍 Debugging Commands

```bash
# Check PV/PVC status
kubectl get pv,pvc -A

# Describe PV
kubectl describe pv <pv-name>

# Describe PVC
kubectl describe pvc <pvc-name>

# Check events
kubectl get events --sort-by=.metadata.creationTimestamp

# Check StorageClasses
kubectl get sc

# Check if PVC bound to correct PV
kubectl get pvc <pvc-name> -o yaml | grep volumeName

# Check actual volume size
kubectl exec <pod> -- df -h /data

# Check volume permissions
kubectl exec <pod> -- ls -la /data

# Check volume ownership
kubectl exec <pod> -- stat /data

# For hostPath, check on node
minikube ssh "ls -la /mnt/data"
```

---

## 📊 Common Error Messages

| Error | Meaning | Solution |
|-------|---------|----------|
| `no persistent volumes available` | No matching PV | Create PV with matching specs |
| `volume not yet bound` | WaitForFirstConsumer | Normal, wait for pod |
| `Permission denied` | Wrong user/permissions | Use fsGroup or init container |
| `No space left` | Volume full | Expand volume or clean data |
| `data directory has wrong ownership` | PostgreSQL permission issue | Fix with fsGroup 999 |
| `ReadOnlyFileSystem` | Volume mounted read-only | Check accessMode |

---

**Remember:** Most PVC issues are binding problems. Check PV capacity, accessModes, and storageClassName first! 🔍
