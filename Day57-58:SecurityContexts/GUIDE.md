# 📖 GUIDEME: Security Contexts - Complete Walkthrough

## 🎯 16-Hour Learning Path

**Day 1:** User/Group IDs, fsGroup, capabilities (8 hours)
**Day 2:** Advanced features, secure deployments (8 hours)

---

## Phase 1: Understanding Default Behavior (1 hour)

### Step 1: Deploy Without Security Context
```bash
kubectl run insecure --image=nginx

# Check user
kubectl exec insecure -- id
# uid=0(root) gid=0(root)

# Check capabilities
kubectl exec insecure -- capsh --print
# Note all the capabilities!

# Check filesystem
kubectl exec insecure -- touch /test-write
# Works (writable filesystem)

kubectl delete pod insecure
```

**Problem:** Running as root with many capabilities!

**✅ Checkpoint:** Understood default insecure behavior.

---

## Phase 2: User and Group IDs (2 hours)

### Test runAsUser
```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: run-as-user-demo
spec:
  securityContext:
    runAsUser: 1000
  containers:
  - name: app
    image: nginx
    command: ['sh', '-c', 'sleep 3600']
EOF

# Verify user
kubectl exec run-as-user-demo -- id
# uid=1000 gid=0(root)

kubectl delete pod run-as-user-demo
```

### Test runAsGroup
```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: run-as-group-demo
spec:
  securityContext:
    runAsUser: 1000
    runAsGroup: 3000
  containers:
  - name: app
    image: nginx
    command: ['sh', '-c', 'sleep 3600']
EOF

# Verify user and group
kubectl exec run-as-group-demo -- id
# uid=1000 gid=3000

kubectl delete pod run-as-group-demo
```

### Test runAsNonRoot
```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: non-root-demo
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
  containers:
  - name: app
    image: nginx
    command: ['sh', '-c', 'sleep 3600']
EOF

# Verify
kubectl get pod non-root-demo
# Should be Running

# Try without runAsUser (should fail)
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: non-root-fail
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: app
    image: nginx
EOF

kubectl get pod non-root-fail
# Error: container has runAsNonRoot and image will run as root

kubectl delete pod non-root-demo non-root-fail
```

**✅ Checkpoint:** User/Group IDs working.

---

## Phase 3: Filesystem Permissions (2 hours)

### Test fsGroup
```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: fsgroup-demo
spec:
  securityContext:
    runAsUser: 1000
    fsGroup: 2000
  containers:
  - name: app
    image: nginx
    command: ['sh', '-c', 'sleep 3600']
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    emptyDir: {}
EOF

# Check volume ownership
kubectl exec fsgroup-demo -- ls -ld /data
# drwxrwsrwx 2 root 2000 ...

# Create file
kubectl exec fsgroup-demo -- touch /data/test

# Check file ownership
kubectl exec fsgroup-demo -- ls -l /data/test
# Group: 2000

kubectl delete pod fsgroup-demo
```

### Test readOnlyRootFilesystem
```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: readonly-demo
spec:
  containers:
  - name: app
    image: nginx
    securityContext:
      readOnlyRootFilesystem: true
    volumeMounts:
    - name: cache
      mountPath: /var/cache/nginx
    - name: run
      mountPath: /var/run
  volumes:
  - name: cache
    emptyDir: {}
  - name: run
    emptyDir: {}
EOF

# Try to write to root
kubectl exec readonly-demo -- touch /test
# Read-only file system error

# Can write to mounted volumes
kubectl exec readonly-demo -- touch /var/cache/nginx/test
# Works!

kubectl delete pod readonly-demo
```

**✅ Checkpoint:** Filesystem permissions configured.

---

## Phase 4: Linux Capabilities (3 hours)

### Check Default Capabilities
```bash
kubectl run caps-test --image=nginx --command -- sleep 3600

kubectl exec caps-test -- capsh --print | grep Current
# See all default capabilities

kubectl delete pod caps-test
```

### Drop All Capabilities
```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: drop-all-caps
spec:
  containers:
  - name: app
    image: nginx
    command: ['sh', '-c', 'sleep 3600']
    securityContext:
      capabilities:
        drop:
        - ALL
EOF

kubectl exec drop-all-caps -- capsh --print
# No capabilities!

# Try to bind to port 80
kubectl exec drop-all-caps -- nc -l -p 80
# Permission denied

kubectl delete pod drop-all-caps
```

### Add Specific Capability
```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: add-net-bind
spec:
  containers:
  - name: app
    image: nginx
    command: ['sh', '-c', 'sleep 3600']
    securityContext:
      capabilities:
        drop:
        - ALL
        add:
        - NET_BIND_SERVICE
EOF

kubectl exec add-net-bind -- capsh --print
# Only NET_BIND_SERVICE

kubectl delete pod add-net-bind
```

**✅ Checkpoint:** Capabilities managed.

---

## Phase 5: Privilege Escalation (1 hour)

### Test allowPrivilegeEscalation
```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: no-escalation
spec:
  containers:
  - name: app
    image: nginx
    command: ['sh', '-c', 'sleep 3600']
    securityContext:
      allowPrivilegeEscalation: false
EOF

# Check
kubectl exec no-escalation -- grep NoNewPrivs /proc/1/status
# NoNewPrivs: 1 (enabled)

kubectl delete pod no-escalation
```

**✅ Checkpoint:** Privilege escalation prevented.

---

## Phase 6: Complete Secure Pod (2 hours)

### Deploy Production-Ready Secure Pod
```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: secure-nginx
spec:
  securityContext:
    runAsUser: 1000
    runAsGroup: 3000
    runAsNonRoot: true
    fsGroup: 2000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: nginx
    image: nginx:1.21
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop:
        - ALL
        add:
        - NET_BIND_SERVICE
    ports:
    - containerPort: 8080
    volumeMounts:
    - name: cache
      mountPath: /var/cache/nginx
    - name: run
      mountPath: /var/run
    - name: nginx-conf
      mountPath: /etc/nginx/nginx.conf
      subPath: nginx.conf
  volumes:
  - name: cache
    emptyDir: {}
  - name: run
    emptyDir: {}
  - name: nginx-conf
    configMap:
      name: nginx-config
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-config
data:
  nginx.conf: |
    events {}
    http {
      server {
        listen 8080;
        location / {
          root /usr/share/nginx/html;
        }
      }
    }
EOF

# Verify all security settings
kubectl get pod secure-nginx -o jsonpath='{.spec.securityContext}' | jq
kubectl get pod secure-nginx -o jsonpath='{.spec.containers[0].securityContext}' | jq

# Test
kubectl port-forward secure-nginx 8080:8080 &
curl http://localhost:8080

kubectl delete pod secure-nginx
kubectl delete configmap nginx-config
```

**✅ Checkpoint:** Secure pod deployed successfully.

---

## Phase 7: Security Context Patterns (3 hours)

### Pattern 1: Batch Job Security
```bash
kubectl apply -f - <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: secure-job
spec:
  template:
    spec:
      securityContext:
        runAsUser: 1000
        runAsNonRoot: true
        fsGroup: 2000
      containers:
      - name: job
        image: busybox
        command: ['sh', '-c', 'echo "Secure job executed" && sleep 10']
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop:
            - ALL
      restartPolicy: Never
EOF

kubectl logs job/secure-job
kubectl delete job secure-job
```

### Pattern 2: StatefulSet with Volumes
```bash
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: secure-statefulset
spec:
  serviceName: secure
  replicas: 2
  selector:
    matchLabels:
      app: secure
  template:
    metadata:
      labels:
        app: secure
    spec:
      securityContext:
        runAsUser: 1000
        fsGroup: 2000
      containers:
      - name: app
        image: nginx
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop:
            - ALL
        volumeMounts:
        - name: data
          mountPath: /data
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 1Gi
EOF

# Check pods
kubectl get pods -l app=secure

# Verify security
kubectl exec secure-statefulset-0 -- id
kubectl exec secure-statefulset-0 -- ls -ld /data

kubectl delete statefulset secure-statefulset
kubectl delete pvc data-secure-statefulset-0 data-secure-statefulset-1
```

**✅ Checkpoint:** Security patterns implemented.

---

## Phase 8: Testing & Validation (2 hours)

### Security Audit Script
```bash
cat > audit-security.sh << 'SCRIPT'
#!/bin/bash
echo "=== Security Context Audit ==="

# Check pods running as root
echo "Pods running as root:"
kubectl get pods -A -o json | \
  jq -r '.items[] | select(.spec.securityContext.runAsUser == null or .spec.securityContext.runAsUser == 0) | 
    "\(.metadata.namespace)/\(.metadata.name)"'

# Check pods without security contexts
echo -e "\nPods without security contexts:"
kubectl get pods -A -o json | \
  jq -r '.items[] | select(.spec.securityContext == null) | 
    "\(.metadata.namespace)/\(.metadata.name)"'

# Check privileged containers
echo -e "\nPrivileged containers:"
kubectl get pods -A -o json | \
  jq -r '.items[] | select(.spec.containers[].securityContext.privileged == true) | 
    "\(.metadata.namespace)/\(.metadata.name)"'

echo -e "\n=== Audit Complete ==="
SCRIPT

chmod +x audit-security.sh
./audit-security.sh
```

**✅ Checkpoint:** Security validated.

---

## ✅ Final Validation Checklist

- [ ] Tested runAsUser (non-root)
- [ ] Tested runAsGroup
- [ ] Tested runAsNonRoot enforcement
- [ ] Tested fsGroup for volumes
- [ ] Tested readOnlyRootFilesystem
- [ ] Dropped ALL capabilities
- [ ] Added specific capabilities
- [ ] Tested allowPrivilegeEscalation: false
- [ ] Deployed complete secure pod
- [ ] Created security patterns
- [ ] Audited security contexts

---

**Congratulations! You've mastered Security Contexts! 🔒🚀**
