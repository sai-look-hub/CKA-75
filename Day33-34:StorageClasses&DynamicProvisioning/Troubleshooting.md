# 🔧 Troubleshooting: StorageClasses & Dynamic Provisioning

## Issue 1: PVC Stays Pending with Dynamic Provisioning

**Symptoms:**
```bash
kubectl get pvc
# NAME    STATUS    VOLUME   AGE
# my-pvc  Pending            5m
```

**Diagnosis:**
```bash
kubectl describe pvc my-pvc
# Common messages:
# - "waiting for first consumer"
# - "no volume plugin matched"
# - "failed to provision volume"
```

**Solutions:**

**If WaitForFirstConsumer:**
```bash
# This is normal! Create pod to trigger binding
kubectl run test --image=nginx --overrides='...'
```

**If provisioner not available:**
```bash
# Check provisioner exists
kubectl get sc my-class -o yaml | grep provisioner

# Check CSI driver installed
kubectl get csidriver
kubectl get pods -n kube-system | grep csi
```

**If cloud permissions issue:**
```bash
# Check node/pod IAM permissions (AWS)
# Check service principal (Azure)
# Check service account (GCP)
```

---

## Issue 2: Volume Expansion Fails

**Symptoms:**
```bash
kubectl patch pvc my-pvc -p '{"spec":{"resources":{"requests":{"storage":"20Gi"}}}}'
# Error or PVC stuck in resizing
```

**Solutions:**

**Check if expansion allowed:**
```bash
kubectl get sc <class> -o yaml | grep allowVolumeExpansion
# Must be true
```

**Delete and recreate pod:**
```bash
kubectl delete pod <pod-using-pvc>
# Some storage requires pod restart for FS expansion
```

---

## Issue 3: Wrong Storage Class Used

**Symptoms:**
```bash
# Expected performance, got standard
kubectl get pvc my-pvc -o yaml | grep storageClassName
```

**Solutions:**

**Explicitly specify class:**
```yaml
spec:
  storageClassName: performance  # Don't rely on default
```

**Check default class:**
```bash
kubectl get sc | grep default
```

---

## Quick Fixes

```bash
# Force delete stuck PVC
kubectl patch pvc <name> -p '{"metadata":{"finalizers":null}}'

# Change default StorageClass
kubectl patch sc old -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
kubectl patch sc new -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

# Check provisioner logs
kubectl logs -n kube-system -l app=ebs-csi-controller
```
