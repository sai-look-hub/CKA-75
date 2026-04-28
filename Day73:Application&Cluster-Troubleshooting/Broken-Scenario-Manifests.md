# ============================================================
# Day 73 — Broken Scenario Manifests
# Apply with: kubectl apply -f manifests/ -n debug-lab
# These are INTENTIONALLY broken for troubleshooting practice
# ============================================================

---
# 01 — CrashLoopBackOff: bad command exits immediately
apiVersion: v1
kind: Pod
metadata:
  name: crashloop-demo
  labels:
    app: crashloop-demo
    day: "73"
spec:
  containers:
  - name: demo-container
    image: busybox:1.35
    command: ["sh", "-c", "echo 'Starting...' && exit 1"]  # ← exits immediately
    resources:
      requests:
        memory: "32Mi"
        cpu: "50m"
      limits:
        memory: "64Mi"
        cpu: "100m"
  restartPolicy: Always

---
# 02 — OOMKilled: memory limit too low for workload
apiVersion: v1
kind: Pod
metadata:
  name: oom-demo
  labels:
    app: oom-demo
    day: "73"
spec:
  containers:
  - name: memory-hog
    image: busybox:1.35
    command: ["sh", "-c", "dd if=/dev/zero bs=1M count=200 | tail"]
    resources:
      requests:
        memory: "16Mi"
        cpu: "50m"
      limits:
        memory: "30Mi"   # ← WAY too low — process needs ~200Mi
        cpu: "100m"
  restartPolicy: Always

---
# 03 — ImagePullBackOff: nonexistent image tag
apiVersion: v1
kind: Pod
metadata:
  name: imagepull-demo
  labels:
    app: imagepull-demo
    day: "73"
spec:
  containers:
  - name: demo-container
    image: nginx:nonexistent-tag-99999   # ← this tag does not exist
    resources:
      requests:
        memory: "32Mi"
        cpu: "50m"
      limits:
        memory: "64Mi"
        cpu: "100m"
  restartPolicy: Always

---
# 04 — Pending: resource request exceeds any node capacity
apiVersion: v1
kind: Pod
metadata:
  name: pending-demo
  labels:
    app: pending-demo
    day: "73"
spec:
  containers:
  - name: demo-container
    image: nginx:1.25
    resources:
      requests:
        memory: "999Gi"    # ← no node has 999Gi RAM
        cpu: "64"          # ← no node has 64 cores
      limits:
        memory: "999Gi"
        cpu: "64"
  restartPolicy: Always

---
# 05 — Service with wrong selector (no endpoints will be created)
apiVersion: v1
kind: Pod
metadata:
  name: web-pod
  labels:
    app: web          # ← Pod label is "web"
    day: "73"
spec:
  containers:
  - name: nginx
    image: nginx:1.25
    ports:
    - containerPort: 80
    resources:
      requests:
        memory: "32Mi"
        cpu: "50m"
      limits:
        memory: "64Mi"
        cpu: "100m"
---
apiVersion: v1
kind: Service
metadata:
  name: broken-svc
  labels:
    day: "73"
spec:
  selector:
    app: frontend     # ← Wrong! Pod has "app: web", not "app: frontend"
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP

---
# 06 — Service with port mismatch
apiVersion: v1
kind: Pod
metadata:
  name: port-mismatch-pod
  labels:
    app: portmismatch
    day: "73"
spec:
  containers:
  - name: nginx
    image: nginx:1.25
    ports:
    - containerPort: 80    # ← Pod listens on 80
    resources:
      requests:
        memory: "32Mi"
        cpu: "50m"
      limits:
        memory: "64Mi"
        cpu: "100m"
---
apiVersion: v1
kind: Service
metadata:
  name: port-mismatch-svc
  labels:
    day: "73"
spec:
  selector:
    app: portmismatch
  ports:
  - port: 80
    targetPort: 8080   # ← Wrong! Pod listens on 80, not 8080
  type: ClusterIP

---
# 07 — ResourceQuota that blocks pod creation
apiVersion: v1
kind: ResourceQuota
metadata:
  name: tight-quota
  labels:
    day: "73"
spec:
  hard:
    requests.cpu: "100m"       # ← Very tight quota
    requests.memory: "100Mi"
    limits.cpu: "200m"
    limits.memory: "200Mi"
    pods: "3"                  # ← Max 3 pods only

---
# 08 — Debug tools pod (use this to test connectivity inside cluster)
apiVersion: v1
kind: Pod
metadata:
  name: debug-tools
  labels:
    app: debug-tools
    day: "73"
spec:
  containers:
  - name: debug
    image: nicolaka/netshoot   # ← Full network debug toolkit
    command: ["sleep", "infinity"]
    resources:
      requests:
        memory: "64Mi"
        cpu: "50m"
      limits:
        memory: "128Mi"
        cpu: "200m"
  restartPolicy: Always

---
# 09 — Fixed versions of the broken pods (apply after debugging)
apiVersion: v1
kind: Pod
metadata:
  name: crashloop-fixed
  labels:
    app: crashloop-fixed
    day: "73"
spec:
  containers:
  - name: demo-container
    image: busybox:1.35
    command: ["sh", "-c", "echo 'Running correctly' && sleep 3600"]  # ← Fixed
    resources:
      requests:
        memory: "32Mi"
        cpu: "50m"
      limits:
        memory: "64Mi"
        cpu: "100m"
  restartPolicy: Always

---
apiVersion: v1
kind: Pod
metadata:
  name: oom-fixed
  labels:
    app: oom-fixed
    day: "73"
spec:
  containers:
  - name: memory-safe
    image: nginx:1.25
    resources:
      requests:
        memory: "64Mi"    # ← Appropriate requests
        cpu: "50m"
      limits:
        memory: "256Mi"   # ← Adequate limit
        cpu: "100m"
  restartPolicy: Always

---
apiVersion: v1
kind: Service
metadata:
  name: fixed-svc
  labels:
    day: "73"
spec:
  selector:
    app: web        # ← Now matches the web-pod label
  ports:
  - port: 80
    targetPort: 80  # ← Now matches the container port
  type: ClusterIP
