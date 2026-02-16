# 📋 Command Cheatsheet: Kubernetes Volumes

Quick reference for volume-related commands.

---

## 🔍 Inspection Commands

```bash
# List all volumes in a pod
kubectl get pod <pod> -o jsonpath='{.spec.volumes[*].name}'

# Describe pod volumes
kubectl describe pod <pod> | grep -A20 Volumes

# Show volume mounts
kubectl get pod <pod> -o jsonpath='{.spec.containers[*].volumeMounts}'

# Check mounted filesystems
kubectl exec <pod> -- df -h

# List files in mounted volume
kubectl exec <pod> -- ls -la /path/to/mount

# Check volume usage
kubectl exec <pod> -- du -sh /path/to/mount
```

---

## 📦 emptyDir Commands

```bash
# Create pod with emptyDir
kubectl run test --image=busybox --restart=Never \
  --overrides='{"spec":{"volumes":[{"name":"cache","emptyDir":{}}],"containers":[{"name":"test","image":"busybox","command":["sleep","3600"],"volumeMounts":[{"name":"cache","mountPath":"/cache"}]}]}}'

# Check emptyDir type
kubectl get pod <pod> -o yaml | grep -A5 emptyDir

# Write to emptyDir
kubectl exec <pod> -- sh -c 'echo "test" > /cache/file.txt'

# Read from emptyDir
kubectl exec <pod> -- cat /cache/file.txt

# Check memory-backed emptyDir
kubectl exec <pod> -- df -h /cache | grep tmpfs
```

---

## 🖥️ hostPath Commands

```bash
# Create directory on node (minikube)
minikube ssh "sudo mkdir -p /mnt/data && sudo chmod 777 /mnt/data"

# Create directory on node (kind)
docker exec kind-control-plane mkdir -p /mnt/data

# List hostPath on node
minikube ssh "ls -la /mnt/data"
docker exec kind-control-plane ls -la /mnt/data

# Write to hostPath from pod
kubectl exec <pod> -- sh -c 'echo "data" > /host/file.txt'

# Verify on node
minikube ssh "cat /mnt/data/file.txt"
```

---

## 🔐 ConfigMap Commands

```bash
# Create ConfigMap from literal
kubectl create configmap app-config \
  --from-literal=key1=value1 \
  --from-literal=key2=value2

# Create from file
kubectl create configmap app-config --from-file=config.yaml

# Create from directory
kubectl create configmap app-config --from-file=config-dir/

# View ConfigMap
kubectl get configmap app-config -o yaml

# Edit ConfigMap
kubectl edit configmap app-config

# Delete ConfigMap
kubectl delete configmap app-config

# Read ConfigMap from pod
kubectl exec <pod> -- cat /etc/config/key1
kubectl exec <pod> -- ls /etc/config
```

---

## 🔒 Secret Commands

```bash
# Create secret from literal
kubectl create secret generic app-secrets \
  --from-literal=password=secret123 \
  --from-literal=api-key=abc123

# Create from file
kubectl create secret generic app-secrets --from-file=password.txt

# Create TLS secret
kubectl create secret tls tls-secret \
  --cert=path/to/cert.crt \
  --key=path/to/cert.key

# View secret (base64 encoded)
kubectl get secret app-secrets -o yaml

# Decode secret
kubectl get secret app-secrets -o jsonpath='{.data.password}' | base64 -d

# Read secret from pod
kubectl exec <pod> -- cat /etc/secrets/password

# Check secret permissions
kubectl exec <pod> -- stat /etc/secrets/password
```

---

## 🔧 Volume Management

```bash
# Get pod with volume details
kubectl get pod <pod> -o yaml | grep -A30 volumes

# Check volume source
kubectl describe pod <pod> | grep -A10 "Volumes:"

# List all ConfigMaps used by pods
kubectl get pods -o json | jq '.items[].spec.volumes[] | select(.configMap != null) | .configMap.name'

# List all Secrets used by pods
kubectl get pods -o json | jq '.items[].spec.volumes[] | select(.secret != null) | .secret.secretName'

# Find pods using specific ConfigMap
kubectl get pods -o json | jq -r '.items[] | select(.spec.volumes[]?.configMap.name=="app-config") | .metadata.name'
```

---

## 🧪 Testing Commands

```bash
# Test volume sharing between containers
kubectl exec <pod> -c container1 -- sh -c 'echo "shared" > /shared/test.txt'
kubectl exec <pod> -c container2 -- cat /shared/test.txt

# Test file permissions
kubectl exec <pod> -- touch /data/test.txt
kubectl exec <pod> -- ls -la /data/test.txt

# Test size limits
kubectl exec <pod> -- dd if=/dev/zero of=/cache/bigfile bs=1M count=100

# Test read-only mount
kubectl exec <pod> -- touch /config/test.txt
# Should fail if mounted read-only

# Check if tmpfs (memory)
kubectl exec <pod> -- mount | grep tmpfs
```

---

## 📊 Debugging Commands

```bash
# Check pod events for volume errors
kubectl get events --field-selector involvedObject.name=<pod>

# Check why pod is pending
kubectl describe pod <pod> | grep -A10 Events

# Check volume mount in init container
kubectl logs <pod> -c init-container

# Check all containers in pod
kubectl get pod <pod> -o jsonpath='{.spec.containers[*].name}'

# Exec into specific container
kubectl exec <pod> -c <container> -- sh

# Check filesystem type
kubectl exec <pod> -- df -T /path

# Check inode usage
kubectl exec <pod> -- df -i /path
```

---

## 🎯 Practical Examples

### Create and Use emptyDir
```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: emptydir-test
spec:
  containers:
  - name: test
    image: busybox
    command: ['sleep', '3600']
    volumeMounts:
    - name: cache
      mountPath: /cache
  volumes:
  - name: cache
    emptyDir:
      sizeLimit: 100Mi
EOF

kubectl exec emptydir-test -- sh -c 'echo "test" > /cache/data.txt'
kubectl exec emptydir-test -- cat /cache/data.txt
```

### Mount ConfigMap
```bash
kubectl create configmap my-config --from-literal=app.mode=production
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: config-test
spec:
  containers:
  - name: test
    image: busybox
    command: ['sleep', '3600']
    volumeMounts:
    - name: config
      mountPath: /etc/config
  volumes:
  - name: config
    configMap:
      name: my-config
EOF

kubectl exec config-test -- cat /etc/config/app.mode
```

---

## 🧹 Cleanup Commands

```bash
# Delete pod with volumes
kubectl delete pod <pod>

# Delete ConfigMap
kubectl delete configmap <configmap>

# Delete Secret
kubectl delete secret <secret>

# Delete all test pods
kubectl delete pods -l test=volume

# Clean up node hostPath (minikube)
minikube ssh "sudo rm -rf /mnt/data"

# Clean up node hostPath (kind)
docker exec kind-control-plane rm -rf /mnt/data
```

---

## 💡 Quick Reference

| Task | Command |
|------|---------|
| List volumes | `kubectl get pod <pod> -o jsonpath='{.spec.volumes[*].name}'` |
| Check mounts | `kubectl exec <pod> -- df -h` |
| Read file | `kubectl exec <pod> -- cat /path/file` |
| Write file | `kubectl exec <pod> -- sh -c 'echo "data" > /path/file'` |
| Check permissions | `kubectl exec <pod> -- ls -la /path` |
| View ConfigMap | `kubectl get configmap <name> -o yaml` |
| Decode Secret | `kubectl get secret <name> -o jsonpath='{.data.key}' \| base64 -d` |

---

**Pro Tip:** Use `kubectl explain pod.spec.volumes` to see all volume types!
