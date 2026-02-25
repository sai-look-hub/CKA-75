# 📋 Command Cheatsheet: Storage Troubleshooting

Quick reference for diagnosing and fixing storage issues.

---

## 🔍 Quick Diagnosis Commands

```bash
# Get comprehensive storage status
kubectl get pv,pvc,sc -A -o wide

# Check recent events (last 30 minutes)
kubectl get events --sort-by=.metadata.creationTimestamp | tail -50

# Find all storage-related events
kubectl get events -A | grep -i "pv\|pvc\|mount\|attach\|provision"

# Watch for new storage events
kubectl get events -w | grep -i storage
```

---

## 📦 PVC Troubleshooting

```bash
# List all PVCs with status
kubectl get pvc -A

# Describe specific PVC
kubectl describe pvc <pvc-name>

# Get PVC in YAML (full details)
kubectl get pvc <pvc-name> -o yaml

# Find PVCs in Pending state
kubectl get pvc -A -o json | \
  jq -r '.items[] | select(.status.phase=="Pending") | "\(.metadata.namespace)/\(.metadata.name)"'

# Find PVCs not bound
kubectl get pvc -A --field-selector=status.phase!=Bound

# Check PVC events
kubectl get events --field-selector involvedObject.name=<pvc-name>

# Find which pod is using a PVC
kubectl get pods -A -o json | \
  jq -r '.items[] | select(.spec.volumes[]?.persistentVolumeClaim.claimName=="<pvc>") | "\(.metadata.namespace)/\(.metadata.name)"'
```

---

## 💿 PV Troubleshooting

```bash
# List all PVs with status
kubectl get pv

# Describe specific PV
kubectl describe pv <pv-name>

# Find Released PVs (can't be reused)
kubectl get pv -o json | \
  jq -r '.items[] | select(.status.phase=="Released") | .metadata.name'

# Find Failed PVs
kubectl get pv --field-selector=status.phase=Failed

# Check PV reclaim policy
kubectl get pv -o custom-columns=\
NAME:.metadata.name,\
RECLAIM:.spec.persistentVolumeReclaimPolicy,\
STATUS:.status.phase

# Remove claimRef to make Released PV Available
kubectl patch pv <pv-name> -p '{"spec":{"claimRef": null}}'
```

---

## 🔌 Pod Mount Troubleshooting

```bash
# Find pods stuck in ContainerCreating
kubectl get pods -A --field-selector=status.phase=Pending

# Describe pod for mount errors
kubectl describe pod <pod-name>

# Check which node pod is on
kubectl get pod <pod-name> -o jsonpath='{.spec.nodeName}'

# Get pod's volume mounts
kubectl get pod <pod-name> -o json | jq '.spec.containers[].volumeMounts'

# Check volume attachment status
kubectl get volumeattachment

# Describe volume attachment
kubectl describe volumeattachment <va-name>

# Find stuck volume attachments
kubectl get volumeattachment -o json | \
  jq -r '.items[] | select(.status.attached==false) | .metadata.name'

# Force delete volume attachment
kubectl delete volumeattachment <va-name> --force --grace-period=0
```

---

## 🔒 Permission Troubleshooting

```bash
# Check file ownership in pod
kubectl exec <pod> -- ls -la /data

# Check what user pod runs as
kubectl exec <pod> -- id

# Check pod security context
kubectl get pod <pod> -o yaml | grep -A10 securityContext

# Check volume permissions
kubectl exec <pod> -- stat /data

# Test write permissions
kubectl exec <pod> -- touch /data/test.txt

# Check for SELinux/AppArmor denials
kubectl exec <pod> -- dmesg | grep -i denied
```

---

## ⚡ Performance Diagnostics

```bash
# Check storage usage
kubectl exec <pod> -- df -h /data

# Test write performance
kubectl exec <pod> -- dd if=/dev/zero of=/data/test bs=1M count=1000 oflag=direct

# Test read performance
kubectl exec <pod> -- dd if=/data/test of=/dev/null bs=1M iflag=direct

# Check I/O stats (if available)
kubectl exec <pod> -- iostat -x 5

# Monitor disk usage
kubectl exec <pod> -- df -h /data
watch kubectl exec <pod> -- df -h /data

# Find large files
kubectl exec <pod> -- du -sh /data/*
```

---

## 🎯 CSI Driver Troubleshooting

```bash
# List CSI drivers
kubectl get csidrivers

# Check CSI controller pods
kubectl get pods -n kube-system -l app=csi-controller

# Check CSI node pods
kubectl get pods -n kube-system -l app=csi-node

# Check CSI node pods on specific node
kubectl get pods -n kube-system -o wide | grep csi | grep <node-name>

# Check CSI provisioner logs
kubectl logs -n kube-system <csi-controller-pod> -c csi-provisioner

# Check CSI attacher logs
kubectl logs -n kube-system <csi-controller-pod> -c csi-attacher

# Check CSI driver logs
kubectl logs -n kube-system <csi-controller-pod> -c driver

# Check CSI node driver logs
kubectl logs -n kube-system <csi-node-pod> -c driver

# Restart CSI controller
kubectl rollout restart deployment -n kube-system <csi-controller>

# Restart CSI node plugin
kubectl delete pod -n kube-system <csi-node-pod>
```

---

## 🔄 Recovery Commands

```bash
# Force delete stuck PVC
kubectl patch pvc <pvc> -p '{"metadata":{"finalizers":null}}' --type=merge
kubectl delete pvc <pvc>

# Force delete stuck pod
kubectl delete pod <pod> --force --grace-period=0

# Force delete stuck PV
kubectl patch pv <pv> -p '{"metadata":{"finalizers":null}}' --type=merge
kubectl delete pv <pv>

# Recover from accidental PVC deletion (Retain policy)
# 1. Find the Released PV
kubectl get pv -o json | jq -r '.items[] | select(.spec.claimRef.name=="<pvc>") | .metadata.name'
# 2. Remove claimRef
kubectl patch pv <pv> -p '{"spec":{"claimRef": null}}'
# 3. Create new PVC with same specs
```

---

## 📊 Monitoring & Alerts

```bash
# Check resource quotas
kubectl get resourcequota -A
kubectl describe resourcequota <quota>

# Get storage usage across all PVCs
kubectl get pvc -A -o json | \
  jq -r '.items[] | "\(.metadata.namespace)/\(.metadata.name): \(.status.capacity.storage)"'

# Total storage used
kubectl get pvc -A -o json | \
  jq -r '[.items[].status.capacity.storage] | map(rtrimstr("Gi")|tonumber) | add'

# Find PVCs using specific StorageClass
kubectl get pvc -A -o json | \
  jq -r '.items[] | select(.spec.storageClassName=="<sc>") | "\(.metadata.namespace)/\(.metadata.name)"'

# Count PVCs per StorageClass
kubectl get pvc -A -o json | \
  jq -r '.items[].spec.storageClassName' | sort | uniq -c
```

---

## 🛠️ Advanced Diagnostics

```bash
# Create debug pod with PVC
kubectl run -it --rm debug --image=busybox --restart=Never \
  --overrides='
{
  "spec": {
    "containers": [{
      "name": "debug",
      "image": "busybox",
      "stdin": true,
      "tty": true,
      "volumeMounts": [{
        "name": "data",
        "mountPath": "/data"
      }]
    }],
    "volumes": [{
      "name": "data",
      "persistentVolumeClaim": {
        "claimName": "<pvc-name>"
      }
    }]
  }
}'

# Check kubelet logs for mount issues
# (on the node where pod is scheduled)
journalctl -u kubelet | grep -i mount

# Check system logs for storage errors
# (on the node)
journalctl -xe | grep -i storage

# Verify CSI socket exists
# (on the node)
ls -la /var/lib/kubelet/plugins/*/csi.sock
```

---

## 💡 One-Liner Helpers

```bash
# Find all unbound PVCs
kubectl get pvc -A --field-selector=status.phase!=Bound -o custom-columns=\
NAMESPACE:.metadata.namespace,\
NAME:.metadata.name,\
STATUS:.status.phase

# Find all pods with PVC issues
kubectl get pods -A -o json | \
  jq -r '.items[] | select(.status.conditions[]? | select(.type=="PodScheduled" and .reason=="Unschedulable")) | "\(.metadata.namespace)/\(.metadata.name)"'

# Map PVC to PV
kubectl get pvc -A -o json | \
  jq -r '.items[] | "\(.metadata.namespace)/\(.metadata.name) → \(.spec.volumeName)"'

# Find orphaned PVs (no PVC)
kubectl get pv -o json | \
  jq -r '.items[] | select(.spec.claimRef==null) | .metadata.name'

# Storage class usage report
kubectl get pvc -A -o json | \
  jq -r '.items | group_by(.spec.storageClassName) | .[] | "\(.[0].spec.storageClassName): \(length) PVCs"'
```

---

**Pro Tip:** Create shell aliases for frequently used commands!

```bash
# Add to ~/.bashrc or ~/.zshrc
alias k-pvc='kubectl get pvc -A'
alias k-pv='kubectl get pv'
alias k-sc='kubectl get sc'
alias k-storage='kubectl get pv,pvc,sc -A -o wide'
alias k-events='kubectl get events --sort-by=.metadata.creationTimestamp'
```
