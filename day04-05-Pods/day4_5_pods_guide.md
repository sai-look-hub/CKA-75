# Day 4-5: Pods Deep Dive 🚀

## 📋 Overview
Understanding Pods - the smallest deployable unit in Kubernetes. Learn pod lifecycle, multi-container patterns, init containers, and best practices.

**Duration:** 2 Days  
**Difficulty:** Beginner to Intermediate  
**Status:** ✅ Completed

---

## 🎯 What You'll Learn

- Pod lifecycle and phases
- Single vs multi-container pods
- Container patterns (Sidecar, Ambassador, Adapter)
- Init containers
- Pod networking and shared volumes
- Resource requests and limits
- Liveness and readiness probes
- Pod best practices

---

## 🔍 What is a Pod?

A **Pod** is the smallest deployable unit in Kubernetes. Think of it as a wrapper around one or more containers.

```
┌─────────────────────────────────────┐
│           POD                        │
│  ┌──────────────┐  ┌──────────────┐│
│  │  Container 1 │  │  Container 2 ││
│  │   (nginx)    │  │   (logger)   ││
│  └──────────────┘  └──────────────┘│
│                                     │
│  Shared:                            │
│  - Network (localhost)              │
│  - Storage (volumes)                │
│  - IPC namespace                    │
└─────────────────────────────────────┘
```

**Key Characteristics:**
- Pods are ephemeral (temporary)
- Each pod gets unique IP address
- Containers in a pod share network and storage
- Usually run one container per pod (but can run multiple)

---

## 📊 Pod Lifecycle

### Pod Phases

```
Pending → Running → Succeeded/Failed → (Unknown)
```

1. **Pending**: Pod accepted but containers not yet created
2. **Running**: Pod bound to node, at least one container running
3. **Succeeded**: All containers terminated successfully
4. **Failed**: All containers terminated, at least one failed
5. **Unknown**: Pod state cannot be determined

### Container States

- **Waiting**: Container not running (pulling image, waiting for init)
- **Running**: Container executing
- **Terminated**: Container finished execution or failed

---

## 🚀 Hands-On: Single Container Pod

### Create Your First Pod

```bash
# Method 1: Imperative (quick)
kubectl run nginx-pod --image=nginx:1.25

# Method 2: Declarative (preferred)
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: nginx-pod
  labels:
    app: nginx
    env: dev
spec:
  containers:
  - name: nginx
    image: nginx:1.25
    ports:
    - containerPort: 80
EOF
```

### View Pod Details

```bash
# List pods
kubectl get pods

# Detailed view
kubectl get pods -o wide

# Describe pod (shows events, state)
kubectl describe pod nginx-pod

# View logs
kubectl logs nginx-pod

# Execute command inside pod
kubectl exec -it nginx-pod -- bash
```

### Pod YAML Breakdown

```yaml
apiVersion: v1              # API version
kind: Pod                   # Resource type
metadata:
  name: nginx-pod           # Pod name (must be unique)
  labels:                   # Key-value pairs for organization
    app: nginx
    tier: frontend
spec:                       # Pod specification
  containers:               # List of containers
  - name: nginx             # Container name
    image: nginx:1.25       # Container image
    ports:
    - containerPort: 80     # Port exposed by container
```

---

## 🎨 Multi-Container Pods

### Why Multiple Containers in One Pod?

**Use Cases:**
- Sidecar pattern (logging, monitoring)
- Ambassador pattern (proxy)
- Adapter pattern (normalize output)

### Sidecar Pattern Example

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: web-with-sidecar
spec:
  containers:
  # Main application container
  - name: nginx
    image: nginx:1.25
    ports:
    - containerPort: 80
    volumeMounts:
    - name: shared-logs
      mountPath: /var/log/nginx
  
  # Sidecar container (log processor)
  - name: log-sidecar
    image: busybox
    command: ['sh', '-c', 'tail -f /logs/access.log']
    volumeMounts:
    - name: shared-logs
      mountPath: /logs
  
  volumes:
  - name: shared-logs
    emptyDir: {}
```

**Deploy and Test:**

```bash
# Create pod
kubectl apply -f web-with-sidecar.yaml

# Check both containers are running
kubectl get pod web-with-sidecar

# View main container logs
kubectl logs web-with-sidecar -c nginx

# View sidecar logs
kubectl logs web-with-sidecar -c log-sidecar

# Generate some traffic
kubectl exec web-with-sidecar -c nginx -- curl localhost
```

---

## 🔧 Init Containers

**Init containers** run before app containers and must complete successfully.

### Use Cases:
- Wait for services to be ready
- Clone git repository
- Generate configuration files
- Database migrations

### Example: Wait for Service

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: myapp-pod
spec:
  # Init containers run first (in order)
  initContainers:
  - name: init-db-check
    image: busybox:1.28
    command: ['sh', '-c', 'until nslookup mydb-service; do echo waiting for db; sleep 2; done']
  
  - name: init-config
    image: busybox:1.28
    command: ['sh', '-c', 'echo "Config generated" > /config/app.conf']
    volumeMounts:
    - name: config-volume
      mountPath: /config
  
  # Main application container runs after init containers succeed
  containers:
  - name: myapp
    image: nginx:1.25
    volumeMounts:
    - name: config-volume
      mountPath: /etc/config
  
  volumes:
  - name: config-volume
    emptyDir: {}
```

**Deploy and Watch:**

```bash
# Apply pod
kubectl apply -f myapp-pod.yaml

# Watch init containers complete
kubectl get pod myapp-pod -w

# Check init container logs
kubectl logs myapp-pod -c init-db-check
kubectl logs myapp-pod -c init-config

# Once init completes, check main container
kubectl logs myapp-pod -c myapp
```

---

## 📦 Shared Volumes Between Containers

### emptyDir Volume

Temporary directory that exists as long as pod is running.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: shared-volume-pod
spec:
  containers:
  - name: writer
    image: busybox
    command: ['sh', '-c', 'while true; do echo "$(date)" >> /data/log.txt; sleep 5; done']
    volumeMounts:
    - name: shared-data
      mountPath: /data
  
  - name: reader
    image: busybox
    command: ['sh', '-c', 'tail -f /data/log.txt']
    volumeMounts:
    - name: shared-data
      mountPath: /data
  
  volumes:
  - name: shared-data
    emptyDir: {}
```

**Test:**

```bash
# Create pod
kubectl apply -f shared-volume-pod.yaml

# View writer logs
kubectl logs shared-volume-pod -c writer

# View reader logs (should show same data)
kubectl logs shared-volume-pod -c reader -f
```

---

## 🎯 Day 4-5 Project: Real-World Multi-Container Application

### Project: Web App with Logging and Monitoring

**Components:**
1. **Main container**: Nginx web server
2. **Sidecar 1**: Log aggregator (Fluentd simulator)
3. **Sidecar 2**: Metrics exporter (simulated)
4. **Init container**: Configuration generator

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: production-web-app
  labels:
    app: web
    tier: frontend
    environment: production
spec:
  # Init container - runs first
  initContainers:
  - name: init-setup
    image: busybox:1.28
    command: 
    - 'sh'
    - '-c'
    - |
      echo "Initializing application..."
      echo "server { listen 80; location / { root /usr/share/nginx/html; } }" > /config/nginx.conf
      echo "App initialized at $(date)" > /shared/init.log
    volumeMounts:
    - name: config-volume
      mountPath: /config
    - name: shared-logs
      mountPath: /shared

  # Main application container
  containers:
  - name: nginx
    image: nginx:1.25
    ports:
    - containerPort: 80
      name: http
    resources:
      requests:
        memory: "64Mi"
        cpu: "100m"
      limits:
        memory: "128Mi"
        cpu: "200m"
    volumeMounts:
    - name: shared-logs
      mountPath: /var/log/nginx
    - name: config-volume
      mountPath: /etc/nginx/conf.d
    livenessProbe:
      httpGet:
        path: /
        port: 80
      initialDelaySeconds: 10
      periodSeconds: 5
    readinessProbe:
      httpGet:
        path: /
        port: 80
      initialDelaySeconds: 5
      periodSeconds: 3

  # Sidecar 1: Log aggregator
  - name: log-aggregator
    image: busybox:1.28
    command:
    - 'sh'
    - '-c'
    - |
      echo "Log aggregator started"
      while true; do
        if [ -f /logs/access.log ]; then
          tail -n 5 /logs/access.log
        fi
        echo "---"
        sleep 10
      done
    volumeMounts:
    - name: shared-logs
      mountPath: /logs

  # Sidecar 2: Metrics exporter (simulated)
  - name: metrics-exporter
    image: busybox:1.28
    command:
    - 'sh'
    - '-c'
    - |
      echo "Metrics exporter started"
      while true; do
        echo "Timestamp: $(date)"
        echo "Memory usage: $(free -m | awk 'NR==2{printf \"%.2f%%\", $3*100/$2 }')"
        echo "---"
        sleep 15
      done
    resources:
      requests:
        memory: "32Mi"
        cpu: "50m"
      limits:
        memory: "64Mi"
        cpu: "100m"

  # Shared volumes
  volumes:
  - name: shared-logs
    emptyDir: {}
  - name: config-volume
    emptyDir: {}
```

### Deploy and Test the Project

```bash
# 1. Create the pod
kubectl apply -f production-web-app.yaml

# 2. Watch pod creation (see init container first)
kubectl get pod production-web-app -w

# 3. Check init container logs
kubectl logs production-web-app -c init-setup

# 4. Check all containers are running
kubectl get pod production-web-app
# Should show 3/3 containers ready

# 5. View main app logs
kubectl logs production-web-app -c nginx

# 6. View sidecar logs
kubectl logs production-web-app -c log-aggregator -f
kubectl logs production-web-app -c metrics-exporter -f

# 7. Generate traffic to create logs
kubectl exec production-web-app -c nginx -- curl localhost

# 8. Port forward to access from local machine
kubectl port-forward pod/production-web-app 8080:80

# 9. Access in browser: http://localhost:8080

# 10. Check resource usage
kubectl top pod production-web-app --containers
```

### Project Explanation

**What This Demonstrates:**

1. **Init Container** (`init-setup`):
   - Runs before main containers
   - Generates configuration files
   - Writes to shared volume

2. **Main Container** (`nginx`):
   - Serves web content
   - Writes logs to shared volume
   - Has health checks (liveness/readiness probes)
   - Resource limits defined

3. **Sidecar 1** (`log-aggregator`):
   - Reads logs from shared volume
   - Processes/aggregates logs
   - Runs alongside main container

4. **Sidecar 2** (`metrics-exporter`):
   - Monitors resource usage
   - Exports metrics
   - Independent of main app

**Real-World Usage:**
- Web applications with centralized logging (Fluentd/Logstash)
- Apps with Prometheus metrics exporters
- Microservices with service mesh sidecars (Istio/Linkerd)

---

## 🔍 Resource Management

### Resource Requests and Limits

```yaml
resources:
  requests:        # Minimum guaranteed
    memory: "64Mi"
    cpu: "100m"    # 0.1 CPU
  limits:          # Maximum allowed
    memory: "128Mi"
    cpu: "200m"    # 0.2 CPU
```

**Why It Matters:**
- **Requests**: Scheduler uses this for placement
- **Limits**: Prevents container from consuming too much

**Quality of Service (QoS) Classes:**
1. **Guaranteed**: requests = limits (highest priority)
2. **Burstable**: requests < limits (medium priority)
3. **BestEffort**: no requests/limits (lowest priority)

### Example: Different QoS Classes

```yaml
# Guaranteed QoS
apiVersion: v1
kind: Pod
metadata:
  name: guaranteed-pod
spec:
  containers:
  - name: app
    image: nginx
    resources:
      requests:
        memory: "100Mi"
        cpu: "100m"
      limits:
        memory: "100Mi"  # Same as requests
        cpu: "100m"      # Same as requests

---
# Burstable QoS
apiVersion: v1
kind: Pod
metadata:
  name: burstable-pod
spec:
  containers:
  - name: app
    image: nginx
    resources:
      requests:
        memory: "50Mi"
        cpu: "50m"
      limits:
        memory: "200Mi"  # Higher than requests
        cpu: "200m"

---
# BestEffort QoS
apiVersion: v1
kind: Pod
metadata:
  name: besteffort-pod
spec:
  containers:
  - name: app
    image: nginx
    # No resources defined
```

---

## 🏥 Health Checks

### Liveness Probe

Checks if container is alive. If fails, kubelet kills and restarts container.

```yaml
livenessProbe:
  httpGet:
    path: /healthz
    port: 8080
  initialDelaySeconds: 10  # Wait before first check
  periodSeconds: 5         # Check every 5 seconds
  timeoutSeconds: 3        # Timeout after 3 seconds
  failureThreshold: 3      # Restart after 3 failures
```

### Readiness Probe

Checks if container is ready to accept traffic. If fails, removes from service endpoints.

```yaml
readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 3
```

### Startup Probe

For slow-starting containers. Disables liveness/readiness until app starts.

```yaml
startupProbe:
  httpGet:
    path: /startup
    port: 8080
  failureThreshold: 30     # 30 * 10 = 300 seconds max startup time
  periodSeconds: 10
```

### Complete Health Check Example

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: healthy-pod
spec:
  containers:
  - name: app
    image: nginx:1.25
    ports:
    - containerPort: 80
    
    # Startup probe (runs first)
    startupProbe:
      httpGet:
        path: /
        port: 80
      failureThreshold: 30
      periodSeconds: 10
    
    # Liveness probe (is app alive?)
    livenessProbe:
      httpGet:
        path: /
        port: 80
      initialDelaySeconds: 10
      periodSeconds: 5
      failureThreshold: 3
    
    # Readiness probe (can accept traffic?)
    readinessProbe:
      httpGet:
        path: /
        port: 80
      initialDelaySeconds: 5
      periodSeconds: 3
      failureThreshold: 2
```

**Test Health Checks:**

```bash
# Deploy pod
kubectl apply -f healthy-pod.yaml

# Watch pod status
kubectl get pod healthy-pod -w

# Describe pod (see probe results)
kubectl describe pod healthy-pod

# View events
kubectl get events --sort-by=.metadata.creationTimestamp | grep healthy-pod
```

---

## 📚 Pod Best Practices

### 1. Always Define Resource Limits

```yaml
✅ Good:
resources:
  requests:
    memory: "64Mi"
    cpu: "100m"
  limits:
    memory: "128Mi"
    cpu: "200m"

❌ Bad:
# No resource limits defined
```

### 2. Use Liveness and Readiness Probes

```yaml
✅ Good:
livenessProbe:
  httpGet:
    path: /healthz
    port: 8080

❌ Bad:
# No health checks
```

### 3. One Main Process Per Container

```yaml
✅ Good:
containers:
- name: nginx
  image: nginx
- name: logger
  image: fluentd

❌ Bad:
containers:
- name: app
  command: ['sh', '-c', 'nginx && fluentd']  # Multiple processes
```

### 4. Use Specific Image Tags

```yaml
✅ Good:
image: nginx:1.25.3

❌ Bad:
image: nginx:latest  # Unpredictable
```

### 5. Add Labels for Organization

```yaml
✅ Good:
metadata:
  labels:
    app: web
    tier: frontend
    environment: production
    version: "1.0"
```

### 6. Use Init Containers for Setup

```yaml
✅ Good:
initContainers:
- name: init-config
  image: busybox
  command: ['sh', '-c', 'setup.sh']

❌ Bad:
containers:
- name: app
  command: ['sh', '-c', 'setup.sh && run-app']  # Mixed concerns
```

---

## 🧪 Common Pod Patterns

### 1. Sidecar Pattern

```
┌─────────────────────────┐
│         POD             │
│  ┌────────┐  ┌────────┐│
│  │  Main  │  │Sidecar ││
│  │  App   │→ │Logger  ││
│  └────────┘  └────────┘│
└─────────────────────────┘
```

### 2. Ambassador Pattern

```
┌─────────────────────────┐
│         POD             │
│  ┌────────┐  ┌────────┐│
│  │  Main  │→ │Ambass- ││→ External Service
│  │  App   │  │ador    ││
│  └────────┘  └────────┘│
└─────────────────────────┘
```

### 3. Adapter Pattern

```
┌─────────────────────────┐
│         POD             │
│  ┌────────┐  ┌────────┐│
│  │  Main  │→ │Adapter ││→ Standardized Output
│  │  App   │  │        ││
│  └────────┘  └────────┘│
└─────────────────────────┘
```

---


## ✅ Day 4-5 Checklist

- [ ] Created single-container pod
- [ ] Created multi-container pod with sidecar
- [ ] Implemented init containers
- [ ] Used shared volumes between containers
- [ ] Added resource requests and limits
- [ ] Configured health probes
- [ ] Completed production web app project
- [ ] Tested all pod patterns
- [ ] Reviewed best practices

---

## 🔗 Useful Commands Cheatsheet

```bash
# Create pod
kubectl run nginx --image=nginx
kubectl apply -f pod.yaml

# View pods
kubectl get pods
kubectl get pods -o wide
kubectl get pods --show-labels

# Describe pod
kubectl describe pod <pod-name>

# Logs
kubectl logs <pod-name>
kubectl logs <pod-name> -c <container-name>  # Multi-container
kubectl logs <pod-name> -f                   # Follow logs

# Execute commands
kubectl exec -it <pod-name> -- bash
kubectl exec <pod-name> -c <container> -- cmd

# Port forwarding
kubectl port-forward pod/<pod-name> 8080:80

# Delete pod
kubectl delete pod <pod-name>
kubectl delete pod <pod-name> --force --grace-period=0

# Get pod YAML
kubectl get pod <pod-name> -o yaml

# Edit pod
kubectl edit pod <pod-name>

# Watch pods
kubectl get pods -w
```

---

## 📖 Additional Resources

- [Kubernetes Pods Documentation](https://kubernetes.io/docs/concepts/workloads/pods/)
- [Pod Lifecycle](https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/)
- [Init Containers](https://kubernetes.io/docs/concepts/workloads/pods/init-containers/)
- [Multi-Container Patterns](https://kubernetes.io/blog/2015/06/the-distributed-system-toolkit-patterns/)

---

**Next:** Day 6-7: ReplicaSets & Deployments 🚀

#CKA #Kubernetes #Pods #DevOps #CloudNative
