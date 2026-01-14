# Project: Production Web App with Multi-Container Pattern

## 🎯 Project Overview

**Name:** Production-Ready Web Application  
**Type:** Multi-Container Pod  
**Complexity:** Intermediate  
**Real-World Use Case:** Web server with logging and monitoring

---

## 📋 What Does This Project Do?

This project demonstrates a **real-world production pattern** used by companies like Uber, Netflix, and Spotify:

- Main application (Nginx web server)
- Automatic configuration generation (Init container)
- Log aggregation (Sidecar pattern)
- Metrics collection (Sidecar pattern)

**All running in ONE pod!** 🎉

---

## 🏗️ Architecture

```
┌──────────────────────────────────────────────────────────┐
│                  PRODUCTION-WEB-APP POD                   │
│                                                            │
│  STAGE 1: Initialization                                  │
│  ┌────────────────────────────────────────────────┐      │
│  │  Init Container: init-config                    │      │
│  │  • Generates nginx.conf                         │      │
│  │  • Creates initialization log                   │      │
│  │  • Writes to shared volumes                     │      │
│  └────────────────────────────────────────────────┘      │
│                       ↓                                    │
│  STAGE 2: Main Application (All run simultaneously)       │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────┐ │
│  │   Container 1  │  │  Container 2   │  │Container 3 │ │
│  │     Nginx      │  │ Log Aggregator │  │  Metrics   │ │
│  │   (Main App)   │  │   (Sidecar)    │  │ (Sidecar)  │ │
│  │                │  │                │  │            │ │
│  │ • Serves web   │  │ • Reads logs   │  │ • Monitors │ │
│  │ • Writes logs  │  │ • Processes    │  │ • Reports  │ │
│  │ • Health check │  │ • Aggregates   │  │ • Exports  │ │
│  └────────────────┘  └────────────────┘  └────────────┘ │
│         │                    ↑                   ↑        │
│         │                    │                   │        │
│         └────────────────────┴───────────────────┘        │
│                   Shared Volumes                          │
│  ┌────────────────────┐      ┌────────────────────┐      │
│  │  Volume: logs      │      │ Volume: config     │      │
│  │  (emptyDir)        │      │ (emptyDir)         │      │
│  └────────────────────┘      └────────────────────┘      │
└──────────────────────────────────────────────────────────┘
```

---

## 🔧 Components Breakdown

### 1. Init Container: `init-config`

**Purpose:** Setup before main app starts  
**What it does:**
- Generates custom nginx configuration
- Creates initialization timestamp log
- Writes config to shared volume

**Why needed?**
In production, you often need to:
- Generate configs based on environment
- Wait for external dependencies
- Run database migrations
- Download certificates

**Code snippet:**
```yaml
initContainers:
- name: init-config
  image: busybox:1.28
  command:
  - 'sh'
  - '-c'
  - |
    echo "Generating nginx configuration..."
    # Create nginx config file
    cat > /config/nginx.conf <<EOF
    server {
      listen 80;
      location / { ... }
    }
    EOF
```

**Real-world example:**
- Kubernetes Dashboard uses init container to generate TLS certificates
- Istio uses init container to setup network rules

---

### 2. Main Container: `nginx`

**Purpose:** Serve web content  
**What it does:**
- Runs Nginx web server
- Serves HTTP traffic on port 80
- Writes access logs to shared volume
- Reports health status via probes

**Features:**
- **Resource Limits:** Prevents resource hogging
  - Requests: 64Mi memory, 100m CPU
  - Limits: 128Mi memory, 200m CPU

- **Health Checks:**
  - Liveness probe: Checks if nginx is alive
  - Readiness probe: Checks if ready to serve traffic

- **Shared Volume:** Writes logs to `/var/log/nginx`

**Why resource limits?**
Without limits:
- One pod can consume entire node resources
- Other pods get starved
- Node becomes unstable

**Real-world example:**
- Every production deployment needs resource limits
- QoS class determines eviction priority under pressure

---

### 3. Sidecar Container: `log-aggregator`

**Purpose:** Process and aggregate logs  
**What it does:**
- Reads logs from shared volume
- Tails access.log file
- Processes log entries (in real-world: sends to Elasticsearch/Splunk)

**Pattern:** Sidecar (helper container alongside main app)

**Why separate container?**
- Main app focuses on serving requests
- Log processing is independent concern
- Can be scaled/updated separately
- Different resource requirements

**Real-world implementations:**
- **Fluentd sidecar:** Collects logs, sends to central logging
- **Filebeat sidecar:** Forwards logs to Elasticsearch
- **CloudWatch agent:** Pushes logs to AWS CloudWatch

**Code snippet:**
```yaml
- name: log-aggregator
  image: busybox:1.28
  command: ['sh', '-c', 'tail -f /logs/access.log']
  volumeMounts:
  - name: shared-logs
    mountPath: /logs  # Same volume as nginx!
```

---

### 4. Sidecar Container: `metrics-exporter`

**Purpose:** Monitor and export metrics  
**What it does:**
- Monitors resource usage (CPU, memory, uptime)
- Exports metrics every 15 seconds
- In real-world: Exposes Prometheus metrics

**Pattern:** Sidecar (observability)

**Why needed?**
- Monitor application health
- Track performance metrics
- Alert on anomalies
- Capacity planning

**Real-world implementations:**
- **Prometheus exporter:** Scrapes metrics from main app
- **Datadog agent:** Collects APM metrics
- **New Relic sidecar:** Application monitoring

**Code snippet:**
```yaml
- name: metrics-exporter
  image: busybox:1.28
  command:
  - 'sh'
  - '-c'
  - |
    while true; do
      echo "Timestamp: $(date)"
      echo "Memory usage: ..."
      sleep 15
    done
```

---

## 🔄 Workflow: How It All Works Together

### Step 1: Pod Creation
```bash
kubectl apply -f production-web-app.yaml
```

### Step 2: Init Container Runs (Sequential)
1. `init-config` starts
2. Generates nginx.conf
3. Writes to shared volume
4. Completes successfully
5. **Only then** main containers start

### Step 3: Main Containers Start (Parallel)
All three containers start simultaneously:
- Nginx reads config from shared volume
- Nginx starts serving on port 80
- Log aggregator starts tailing logs
- Metrics exporter starts monitoring

### Step 4: Runtime Operation
```
User Request → Nginx (serves content)
              ↓
         Writes to /var/log/nginx/access.log
              ↓
         Log Aggregator (reads same file)
              ↓
         Processes & forwards logs

Simultaneously:
         Metrics Exporter → Monitors everything
```

### Step 5: Health Monitoring
```
Every 5 seconds:
  Liveness probe checks → http://localhost/health
  If fails 3 times → Restart container

Every 3 seconds:
  Readiness probe checks → http://localhost/health
  If fails → Remove from Service endpoints
```

---

## 🧪 How to Deploy and Test

### Deploy the Application

```bash
# 1. Apply the pod
kubectl apply -f yaml-examples/10-production-web-app.yaml

# 2. Watch it start (see init container first)
kubectl get pod production-web-app -w

# Output will show:
# production-web-app   0/3   Init:0/1   0   0s
# production-web-app   0/3   Init:0/1   0   2s
# production-web-app   0/3   PodInitializing   0   5s
# production-web-app   3/3   Running   0   8s
```

### Verify All Components

```bash
# Check all containers are running
kubectl get pod production-web-app
# Should show: 3/3 READY

# View init container logs
kubectl logs production-web-app -c init-config

# View main app logs
kubectl logs production-web-app -c nginx

# View sidecar logs
kubectl logs production-web-app -c log-aggregator -f
kubectl logs production-web-app -c metrics-exporter -f
```

### Test the Web Server

```bash
# Port forward to local machine
kubectl port-forward pod/production-web-app 8080:80

# In another terminal, test health endpoint
curl http://localhost:8080/health
# Output: healthy

# Generate traffic
for i in {1..10}; do 
  curl http://localhost:8080
  sleep 1
done

# Watch log aggregator process these requests
kubectl logs production-web-app -c log-aggregator -f
```

### Monitor Resources

```bash
# View resource usage
kubectl top pod production-web-app --containers

# Output shows CPU/Memory for each container:
# POD                    NAME              CPU   MEMORY
# production-web-app     nginx             5m    32Mi
# production-web-app     log-aggregator    2m    16Mi
# production-web-app     metrics-exporter  1m    12Mi

# Check QoS class
kubectl get pod production-web-app -o jsonpath='{.status.qosClass}'
# Output: Burstable (because requests < limits)
```

### Test Health Checks

```bash
# Describe pod to see probe results
kubectl describe pod production-web-app

# Look for:
# Liveness:   http-get http://:80/health
# Readiness:  http-get http://:80/health

# View recent events
kubectl get events | grep production-web-app
```

---

## 💡 Key Learnings from This Project

### 1. Init Container Pattern
✅ **Use for:** Setup tasks that must complete before app starts  
✅ **Examples:** Config generation, DB migrations, wait-for-dependency  
✅ **Benefit:** Separates setup from runtime concerns

### 2. Sidecar Pattern
✅ **Use for:** Helper functionality alongside main app  
✅ **Examples:** Logging, monitoring, proxies, service mesh  
✅ **Benefit:** Modular, can update independently

### 3. Shared Volumes
✅ **emptyDir:** Temporary storage, exists as long as pod lives  
✅ **Use for:** Sharing data between containers  
✅ **Benefit:** Simple inter-container communication

### 4. Resource Management
✅ **Requests:** Minimum guaranteed (used for scheduling)  
✅ **Limits:** Maximum allowed (prevents resource hogging)  
✅ **QoS Classes:** Determines eviction priority

### 5. Health Checks
✅ **Liveness:** Auto-restart unhealthy containers  
✅ **Readiness:** Don't send traffic to unready containers  
✅ **Startup:** For slow-starting apps

---

## 🌟 Real-World Applications

### This Pattern is Used By:

**1. Service Mesh (Istio/Linkerd)**
```
Pod:
  - Main app container
  - Envoy proxy sidecar (routes traffic)
  - Init container (sets up iptables)
```

**2. Logging Solutions (Fluentd/Filebeat)**
```
Pod:
  - Application container
  - Fluentd sidecar (collects & forwards logs)
```

**3. Monitoring (Prometheus)**
```
Pod:
  - Application container
  - Metrics exporter sidecar
```

**4. Security (Vault Agent)**
```
Pod:
  - Application container
  - Vault agent sidecar (manages secrets)
  - Init container (fetches initial secrets)
```

---

## 🎯 CKA Exam Relevance

### What You Need to Know:

✅ **How to create multi-container pods**  
✅ **How to share volumes between containers**  
✅ **How to configure init containers**  
✅ **How to view logs from specific containers**  
✅ **How to set resource requests/limits**  
✅ **How to configure health probes**

### Common Exam Questions:

1. "Create a pod with two containers sharing a volume"
2. "Add an init container that waits for a service"
3. "Configure liveness and readiness probes"
4. "Set resource limits on containers"
5. "Troubleshoot a pod with failing init container"

---

## 📝 Project Summary

**What We Built:**
Production-grade web application demonstrating:
- Multi-container coordination
- Shared storage
- Configuration management
- Health monitoring
- Resource management
- Real-world patterns

**Why It Matters:**
This is exactly how modern cloud-native applications work in production!

**Skills Gained:**
- Multi-container pod design
- Init container usage
- Sidecar pattern implementation
- Volume sharing
- Health check configuration
- Resource management

---

## 🚀 Next Steps

1. **Modify the project:**
   - Add another sidecar container
   - Change health check endpoints
   - Adjust resource limits

2. **Break things:**
   - Remove init container, see what happens
   - Set wrong resource limits
   - Make health check fail

3. **Extend functionality:**
   - Add environment variables
   - Mount ConfigMap
   - Add security context

---

**Questions about the project? Open an issue!**  
**Want to share your implementation? Tag #CKA75Challenge**

#CKA #Kubernetes #Pods #DevOps #ProjectBasedLearning