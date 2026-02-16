# 📖 GUIDEME: Kubernetes Volumes - Step-by-Step Learning Path

## 🎯 Learning Path Overview

This guide provides a structured 16-hour learning experience across 2 days, taking you from volume basics to building a complete multi-volume application.

---

## ⏱️ Time Allocation (16 hours total)

**Day 1 (8 hours):**
- Hours 1-2: Understanding volume concepts and theory
- Hours 3-4: emptyDir hands-on exercises
- Hours 5-6: hostPath exploration and practice
- Hours 7-8: ConfigMap and Secret volumes

**Day 2 (8 hours):**
- Hours 1-2: Multi-volume pod exercises
- Hours 3-4: Building the project application
- Hours 5-6: Volume troubleshooting
- Hours 7-8: Testing, optimization, and review

---

## 📚 Phase 1: Understanding Volumes (2 hours)

### Step 1: The Problem - Container Ephemeral Storage (30 minutes)

Let's see why we need volumes:

```bash
# Create a pod that writes data
kubectl run test-ephemeral --image=busybox --restart=Never -- \
  sh -c 'echo "Important data" > /tmp/data.txt && cat /tmp/data.txt && sleep 3600'

# Check the data was written
kubectl logs test-ephemeral
# Output: Important data

# Exec into pod and verify file
kubectl exec test-ephemeral -- cat /tmp/data.txt
# Output: Important data

# Now delete and recreate the pod
kubectl delete pod test-ephemeral
kubectl run test-ephemeral --image=busybox --restart=Never -- sleep 3600

# Try to read the file
kubectl exec test-ephemeral -- cat /tmp/data.txt
# Error: No such file or directory
# Data is GONE!

# Cleanup
kubectl delete pod test-ephemeral
```

**💡 Key Insight:** Container filesystems are ephemeral. Data disappears when container is recreated.

---

### Step 2: Basic Volume Concepts (30 minutes)

```bash
# Create a pod with emptyDir volume
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: volume-demo
spec:
  containers:
  - name: writer
    image: busybox
    command: ['sh', '-c', 'echo "Data with volume" > /data/test.txt && sleep 3600']
    volumeMounts:
    - name: demo-volume
      mountPath: /data
  volumes:
  - name: demo-volume
    emptyDir: {}
EOF

# Wait for pod to be ready
kubectl wait --for=condition=ready pod/volume-demo --timeout=60s

# Verify data was written
kubectl exec volume-demo -- cat /data/test.txt
# Output: Data with volume

# Check where the volume is stored on the host
kubectl get pod volume-demo -o yaml | grep uid
# Note the pod UID

# The volume is at: /var/lib/kubelet/pods/<pod-uid>/volumes/kubernetes.io~empty-dir/demo-volume
```

**✅ Checkpoint:** You should see the data persists within the pod.

---

### Step 3: Volume Lifecycle Exploration (60 minutes)

```bash
# Test 1: Container restart (volume persists)
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: restart-test
spec:
  containers:
  - name: app
    image: busybox
    command: ['sh', '-c', 'echo "Created: $(date)" >> /data/log.txt && sleep 10 && exit 1']
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    emptyDir: {}
  restartPolicy: Always
EOF

# Wait and watch restarts
kubectl get pod restart-test -w

# After a few restarts, check the log
kubectl exec restart-test -- cat /data/log.txt
# You'll see multiple timestamps - volume persisted across container restarts!

# Cleanup
kubectl delete pod restart-test

# Test 2: Pod deletion (volume is deleted)
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: deletion-test
spec:
  containers:
  - name: app
    image: busybox
    command: ['sh', '-c', 'echo "Important" > /data/file.txt && sleep 3600']
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    emptyDir: {}
EOF

kubectl wait --for=condition=ready pod/deletion-test --timeout=60s

# Delete and recreate
kubectl delete pod deletion-test
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: deletion-test
spec:
  containers:
  - name: app
    image: busybox
    command: ['sh', '-c', 'sleep 3600']
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    emptyDir: {}
EOF

kubectl exec deletion-test -- ls /data
# Empty! New emptyDir was created

# Cleanup
kubectl delete pod deletion-test volume-demo
```

**✅ Checkpoint:** Understand that volumes persist across container restarts but not pod deletions (for emptyDir).

---

## 📦 Phase 2: emptyDir Mastery (2 hours)

### Step 1: Basic emptyDir Usage (30 minutes)

```bash
# Apply the basic emptyDir example
kubectl apply -f emptydir-basic.yaml

# Verify pod is running
kubectl get pod emptydir-basic

# Write some data
kubectl exec emptydir-basic -- sh -c 'echo "Test data" > /cache/test.txt'

# Read it back
kubectl exec emptydir-basic -- cat /cache/test.txt

# Check disk usage
kubectl exec emptydir-basic -- df -h /cache

# Cleanup
kubectl delete pod emptydir-basic
```

**✅ Checkpoint:** Basic emptyDir mounted and accessible.

---

### Step 2: Shared emptyDir Between Containers (45 minutes)

```bash
# Apply the multi-container emptyDir example
kubectl apply -f emptydir-shared.yaml

# Wait for pod
kubectl wait --for=condition=ready pod/shared-volume --timeout=60s

# Writer container writes data
kubectl logs shared-volume -c writer

# Reader container reads the same data
kubectl logs shared-volume -c reader

# Verify both containers see the same files
kubectl exec shared-volume -c writer -- ls -la /shared
kubectl exec shared-volume -c reader -- ls -la /shared

# Test live sharing
kubectl exec shared-volume -c writer -- sh -c 'echo "Live data" > /shared/live.txt'
kubectl exec shared-volume -c reader -- cat /shared/live.txt

# Cleanup
kubectl delete pod shared-volume
```

**✅ Checkpoint:** Two containers successfully sharing data via emptyDir.

---

### Step 3: Memory-Backed emptyDir (45 minutes)

```bash
# Apply memory-backed emptyDir
kubectl apply -f emptydir-memory.yaml

# Check that it's using tmpfs
kubectl exec memory-cache -- df -h /cache
# Look for 'tmpfs' filesystem type

# Write some data
kubectl exec memory-cache -- sh -c 'dd if=/dev/zero of=/cache/testfile bs=1M count=100'

# Check memory usage
kubectl exec memory-cache -- free -h

# Check pod resource usage
kubectl top pod memory-cache

# Important: Memory usage counts against container limits!
kubectl get pod memory-cache -o yaml | grep -A10 resources

# Cleanup
kubectl delete pod memory-cache
```

**✅ Checkpoint:** Understand memory-backed emptyDir and its resource implications.

---

## 🖥️ Phase 3: hostPath Exploration (2 hours)

### Step 1: Basic hostPath (30 minutes)

```bash
# First, create a directory on your node
# For minikube:
minikube ssh
sudo mkdir -p /mnt/data
sudo chmod 777 /mnt/data
echo "Host data" | sudo tee /mnt/data/test.txt
exit

# For kind:
docker exec kind-control-plane mkdir -p /mnt/data
docker exec kind-control-plane chmod 777 /mnt/data
docker exec kind-control-plane sh -c 'echo "Host data" > /mnt/data/test.txt'

# Apply hostPath pod
kubectl apply -f hostpath-basic.yaml

# Read the file created on host
kubectl exec hostpath-basic -- cat /host-data/test.txt

# Write from pod
kubectl exec hostpath-basic -- sh -c 'echo "From pod" > /host-data/pod-data.txt'

# Verify on host
minikube ssh
cat /mnt/data/pod-data.txt
exit

# Or for kind:
docker exec kind-control-plane cat /mnt/data/pod-data.txt

# Cleanup
kubectl delete pod hostpath-basic
```

**✅ Checkpoint:** Pod successfully accessing host filesystem.

---

### Step 2: hostPath Types (45 minutes)

```bash
# Test different hostPath types
# DirectoryOrCreate
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: hostpath-dir-create
spec:
  containers:
  - name: test
    image: busybox
    command: ['sleep', '3600']
    volumeMounts:
    - name: host
      mountPath: /data
  volumes:
  - name: host
    hostPath:
      path: /mnt/new-directory
      type: DirectoryOrCreate
EOF

# Check if directory was created on host
minikube ssh "ls -la /mnt/new-directory"
# or
docker exec kind-control-plane ls -la /mnt/new-directory

# Test Directory (must exist)
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: hostpath-dir-exist
spec:
  containers:
  - name: test
    image: busybox
    command: ['sleep', '3600']
    volumeMounts:
    - name: host
      mountPath: /data
  volumes:
  - name: host
    hostPath:
      path: /mnt/nonexistent
      type: Directory
EOF

# This should fail to start
kubectl describe pod hostpath-dir-exist
# Should show error about directory not existing

# Cleanup
kubectl delete pod hostpath-dir-create hostpath-dir-exist
```

**✅ Checkpoint:** Understanding different hostPath types and their behaviors.

---

### Step 3: hostPath for Log Access (45 minutes)

```bash
# Deploy a pod that accesses node logs
kubectl apply -f hostpath-logs.yaml

# View node logs from within pod
kubectl exec log-viewer -- ls /var/log

# View specific log file
kubectl exec log-viewer -- tail /var/log/syslog
# or
kubectl exec log-viewer -- tail /var/log/messages

# This is how monitoring tools like Fluentd access logs
# Cleanup
kubectl delete pod log-viewer
```

**✅ Checkpoint:** Accessing node-level logs via hostPath.

---

## 🔐 Phase 4: ConfigMap and Secret Volumes (2 hours)

### Step 1: ConfigMap as Volume (45 minutes)

```bash
# Create a ConfigMap
kubectl create configmap app-config --from-literal=database.url=postgresql://db:5432/mydb \
  --from-literal=app.mode=production

# Or from file
cat > app.properties <<EOF
database.url=postgresql://db:5432/mydb
app.mode=production
cache.enabled=true
cache.ttl=3600
EOF

kubectl create configmap app-config-file --from-file=app.properties

# Apply pod using ConfigMap volume
kubectl apply -f configmap-volume.yaml

# Verify files are mounted
kubectl exec configmap-pod -- ls /etc/config

# Read configuration
kubectl exec configmap-pod -- cat /etc/config/database.url
kubectl exec configmap-pod -- cat /etc/config/app.mode

# Or if created from file:
kubectl exec configmap-pod -- cat /etc/config/app.properties

# Update ConfigMap and see it reflect
kubectl create configmap app-config --from-literal=database.url=postgresql://newdb:5432/mydb --dry-run=client -o yaml | kubectl apply -f -

# Wait a bit (ConfigMap updates are eventually consistent)
sleep 30

# Check updated value
kubectl exec configmap-pod -- cat /etc/config/database.url

# Cleanup
kubectl delete pod configmap-pod
kubectl delete configmap app-config app-config-file
rm app.properties
```

**✅ Checkpoint:** ConfigMaps mounted as volumes and updated dynamically.

---

### Step 2: Secret as Volume (45 minutes)

```bash
# Create secrets
kubectl create secret generic db-credentials \
  --from-literal=username=admin \
  --from-literal=password=secretpassword

# Apply pod using Secret volume
kubectl apply -f secret-volume.yaml

# Verify secrets are mounted
kubectl exec secret-pod -- ls -la /etc/secrets

# Read secrets (note the permissions)
kubectl exec secret-pod -- cat /etc/secrets/username
kubectl exec secret-pod -- cat /etc/secrets/password

# Check file permissions (should be 0400 or similar)
kubectl exec secret-pod -- stat /etc/secrets/username

# Secrets are mounted as tmpfs (memory)
kubectl exec secret-pod -- df -h /etc/secrets
# Should show tmpfs

# Cleanup
kubectl delete pod secret-pod
kubectl delete secret db-credentials
```

**✅ Checkpoint:** Secrets securely mounted with appropriate permissions.

---

### Step 3: Combining ConfigMap and Secret (30 minutes)

```bash
# Create both ConfigMap and Secret
kubectl create configmap app-settings \
  --from-literal=log.level=debug \
  --from-literal=feature.flag=enabled

kubectl create secret generic api-keys \
  --from-literal=api.key=12345-secret-key \
  --from-literal=jwt.secret=my-jwt-secret

# Apply pod with both
kubectl apply -f config-secret-combined.yaml

# Verify both are mounted
kubectl exec combined-pod -- ls /etc/config
kubectl exec combined-pod -- ls /etc/secrets

# Application can read config and secrets
kubectl exec combined-pod -- cat /etc/config/log.level
kubectl exec combined-pod -- cat /etc/secrets/api.key

# Cleanup
kubectl delete pod combined-pod
kubectl delete configmap app-settings
kubectl delete secret api-keys
```

**✅ Checkpoint:** Successfully using multiple volume types in one pod.

---

## 🏗️ Phase 5: Multi-Volume Application Project (4 hours)

### Step 1: Application Architecture (30 minutes)

We'll build a complete web application with:
- nginx frontend
- Node.js backend
- Shared cache
- Configuration from ConfigMap
- Credentials from Secret
- Logs written to emptyDir

```bash
# Review the project architecture
cat project-architecture.yaml

# Understand each volume:
# 1. shared-cache: emptyDir for app cache
# 2. app-config: ConfigMap for settings
# 3. app-secrets: Secret for credentials
# 4. logs: emptyDir for application logs
# 5. nginx-config: ConfigMap for nginx.conf
```

---

### Step 2: Create Configuration Resources (45 minutes)

```bash
# Create application ConfigMap
cat > app-config.yaml <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  app.json: |
    {
      "port": 3000,
      "cacheEnabled": true,
      "cacheTTL": 3600,
      "logLevel": "info"
    }
EOF

kubectl apply -f app-config.yaml

# Create nginx ConfigMap
cat > nginx-config.yaml <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-config
data:
  nginx.conf: |
    events {
      worker_connections 1024;
    }
    http {
      server {
        listen 80;
        location / {
          proxy_pass http://localhost:3000;
        }
        location /cache {
          alias /cache;
          autoindex on;
        }
      }
    }
EOF

kubectl apply -f nginx-config.yaml

# Create secrets
kubectl create secret generic app-secrets \
  --from-literal=db.password=production-password \
  --from-literal=api.key=prod-api-key-12345

# Verify resources
kubectl get configmaps
kubectl get secrets
```

**✅ Checkpoint:** All configuration resources created.

---

### Step 3: Deploy the Application (90 minutes)

```bash
# Apply the complete application
kubectl apply -f multi-volume-app.yaml

# Wait for pod to be ready
kubectl wait --for=condition=ready pod/multi-volume-app --timeout=120s

# Verify all volumes are mounted
kubectl exec multi-volume-app -c backend -- df -h

# Check each mount point
kubectl exec multi-volume-app -c backend -- ls /app/config
kubectl exec multi-volume-app -c backend -- ls /app/secrets
kubectl exec multi-volume-app -c backend -- ls /cache
kubectl exec multi-volume-app -c backend -- ls /logs

# Test the application
kubectl port-forward pod/multi-volume-app 8080:80 &

# In another terminal:
curl http://localhost:8080
curl http://localhost:8080/cache

# Check logs
kubectl logs multi-volume-app -c backend
kubectl logs multi-volume-app -c nginx

# Check shared cache
kubectl exec multi-volume-app -c backend -- ls -la /cache
kubectl exec multi-volume-app -c nginx -- ls -la /cache

# Kill port-forward
pkill -f "port-forward"
```

**✅ Checkpoint:** Complete multi-volume application running.

---

### Step 4: Testing Volume Functionality (60 minutes)

```bash
# Test 1: Shared volume between containers
kubectl exec multi-volume-app -c backend -- sh -c 'echo "Backend cache" > /cache/backend.txt'
kubectl exec multi-volume-app -c nginx -- cat /cache/backend.txt
# Should see "Backend cache"

# Test 2: Configuration updates
kubectl edit configmap app-config
# Change logLevel to "debug"

# Wait for update to propagate (can take up to 60s)
sleep 65

kubectl exec multi-volume-app -c backend -- cat /app/config/app.json
# Should show updated config

# Restart container to pick up new config
kubectl delete pod multi-volume-app
kubectl apply -f multi-volume-app.yaml

# Test 3: Log persistence across container restarts
kubectl exec multi-volume-app -c backend -- sh -c 'echo "Log entry 1" >> /logs/app.log'

# Cause container restart (kill process)
kubectl exec multi-volume-app -c backend -- kill 1

# Wait for restart
kubectl wait --for=condition=ready pod/multi-volume-app --timeout=60s

# Check log still exists
kubectl exec multi-volume-app -c backend -- cat /logs/app.log
# Should still see "Log entry 1"
```

**✅ Checkpoint:** All volume types working correctly.

---

## 🔧 Phase 6: Advanced Scenarios (2 hours)

### Exercise 1: Init Container Preparing Volumes (30 minutes)

```bash
# Apply pod with init container
kubectl apply -f init-container-volume.yaml

# Watch the init container prepare the volume
kubectl get pod volume-init -w

# Once running, check prepared files
kubectl exec volume-init -- ls -la /data
kubectl exec volume-init -- cat /data/initialized.txt

# Cleanup
kubectl delete pod volume-init
```

---

### Exercise 2: SubPath Mounting (30 minutes)

```bash
# Apply subPath example
kubectl apply -f subpath-example.yaml

# Verify subPath mounting
kubectl exec subpath-pod -- ls /app/config
kubectl exec subpath-pod -- ls /app/secrets

# Each mount gets only specific files, not the entire ConfigMap
kubectl exec subpath-pod -- cat /app/config/database.conf
kubectl exec subpath-pod -- cat /app/secrets/api.key

# Cleanup
kubectl delete pod subpath-pod
```

---

### Exercise 3: Volume Permissions and Ownership (60 minutes)

```bash
# Test different permission scenarios
kubectl apply -f volume-permissions.yaml

# Check default permissions
kubectl exec permission-test -- ls -la /data

# Check who owns the files
kubectl exec permission-test -- stat /data

# Test fsGroup
kubectl exec permission-test -- id
# Should show groups including fsGroup

# Write as non-root user
kubectl exec permission-test -- sh -c 'echo "test" > /data/userfile.txt'
kubectl exec permission-test -- ls -la /data/userfile.txt

# Cleanup
kubectl delete pod permission-test
```

**✅ Checkpoint:** Understanding volume permissions and ownership.

---

## 🧪 Phase 7: Testing and Validation (2 hours)

### Test Suite 1: Volume Persistence

```bash
# Create test pod
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: persistence-test
spec:
  containers:
  - name: app
    image: busybox
    command: ['sh', '-c', 'while true; do date >> /data/dates.log; sleep 5; done']
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    emptyDir: {}
EOF

# Let it run and collect data
sleep 30

# Check accumulated data
kubectl exec persistence-test -- cat /data/dates.log

# Crash the container
kubectl exec persistence-test -- kill 1

# Wait for restart
sleep 10

# Data should still be there
kubectl exec persistence-test -- cat /data/dates.log

# Delete pod - data will be lost
kubectl delete pod persistence-test
```

---

### Test Suite 2: Resource Limits

```bash
# Test emptyDir size limit
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: size-limit-test
spec:
  containers:
  - name: app
    image: busybox
    command: ['sh', '-c', 'sleep 3600']
    volumeMounts:
    - name: limited
      mountPath: /data
  volumes:
  - name: limited
    emptyDir:
      sizeLimit: 100Mi
EOF

# Try to exceed limit
kubectl exec size-limit-test -- dd if=/dev/zero of=/data/bigfile bs=1M count=150
# Should fail or pod should be evicted

# Check events
kubectl describe pod size-limit-test

# Cleanup
kubectl delete pod size-limit-test
```

---

## ✅ Final Validation Checklist

Before completing this module, verify you can:

### emptyDir
- [ ] Create basic emptyDir volume
- [ ] Share emptyDir between containers
- [ ] Create memory-backed emptyDir
- [ ] Set and test size limits
- [ ] Understand persistence scope

### hostPath
- [ ] Mount host directory
- [ ] Use different hostPath types
- [ ] Understand security implications
- [ ] Access node logs via hostPath
- [ ] Know when to avoid hostPath

### ConfigMap & Secret
- [ ] Mount ConfigMap as volume
- [ ] Mount Secret as volume
- [ ] Use subPath for specific files
- [ ] Understand update propagation
- [ ] Set appropriate permissions

### Multi-Volume Applications
- [ ] Combine multiple volume types
- [ ] Use init containers with volumes
- [ ] Configure volume permissions
- [ ] Test volume sharing
- [ ] Troubleshoot volume issues

---

## 🎓 Key Learnings Summary

**emptyDir:**
- Temporary storage within pod lifecycle
- Great for cache and scratch space
- Can be memory-backed for performance
- Always set sizeLimit

**hostPath:**
- Access node filesystem
- Use sparingly in production
- Understand security risks
- Perfect for DaemonSets

**ConfigMap/Secret:**
- Inject configuration as files
- Updates propagate to pods
- Secrets mounted as tmpfs
- Use appropriate permissions

**Best Practices:**
- Choose right volume type for use case
- Always set resource limits
- Use read-only mounts when possible
- Understand data persistence requirements
- Test volume behavior thoroughly

---

## 🚀 Next Steps

1. Review troubleshooting guide for common issues
2. Practice interview questions
3. Clean up all test resources:

```bash
# Comprehensive cleanup
kubectl delete pods --all
kubectl delete configmaps --all
kubectl delete secrets --all

# For minikube
minikube ssh "sudo rm -rf /mnt/data /mnt/new-directory"

# For kind
docker exec kind-control-plane rm -rf /mnt/data /mnt/new-directory
```

4. Move on to Day 31-32: PersistentVolumes and PersistentVolumeClaims

**Congratulations! You've mastered Kubernetes volumes! 📦**
