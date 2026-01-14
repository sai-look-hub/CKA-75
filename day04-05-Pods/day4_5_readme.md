# Day 4-5: Pods Deep Dive 🚀

## 📅 Duration: 2 Days
**Status:** ✅ Completed  
**Difficulty:** Beginner to Intermediate

---

## 🎯 Learning Objectives

- [x] Understand pod architecture and lifecycle
- [x] Create single and multi-container pods
- [x] Implement init containers
- [x] Configure shared volumes
- [x] Add resource requests and limits
- [x] Set up health probes (liveness, readiness, startup)
- [x] Learn multi-container patterns (sidecar, ambassador, adapter)
- [x] Apply pod best practices

---

## 📚 What's a Pod?

**Pod** = Smallest deployable unit in Kubernetes

```
┌─────────────────────────────────┐
│          POD                     │
│  ┌─────────┐    ┌─────────┐    │
│  │Container│    │Container│    │
│  │    1    │    │    2    │    │
│  └─────────┘    └─────────┘    │
│                                 │
│  Shared:                        │
│  • Network (localhost)          │
│  • Storage (volumes)            │
│  • Lifecycle                    │
└─────────────────────────────────┘
```

---

## 📂 Repository Structure

```
Day-04-05-Pods/
├── README.md (This file)
├── GUIDE.md (Complete step-by-step guide)
├── yaml-examples/
│   ├── 01-basic-pod.yaml
│   ├── 02-pod-with-resources.yaml
│   ├── 03-pod-with-env.yaml
│   ├── 04-pod-with-probes.yaml
│   ├── 05-sidecar-pattern.yaml
│   ├── 06-init-container.yaml
│   ├── 07-multiple-init-containers.yaml
│   ├── 08-shared-volume.yaml
│   ├── 09-command-args.yaml
│   ├── 10-production-web-app.yaml (Main Project)
│   ├── 11-hostpath-volume.yaml
│   ├── 12-qos-classes.yaml
│   ├── 13-tcp-exec-probes.yaml
│   ├── 14-security-context.yaml
│   └── 15-node-selector.yaml
├── project/
│   ├── README.md (Project details)
│   └── production-web-app.yaml
└── interview-questions.md
```

---

## 🚀 Quick Start

### 1. Setup Cluster

```bash
# Using Minikube
minikube start

# Or using Kind
kind create cluster --name cka-cluster
```

### 2. Create Your First Pod

```bash
# Imperative way (quick)
kubectl run nginx --image=nginx:1.25

# Verify
kubectl get pods
kubectl describe pod nginx

# View logs
kubectl logs nginx

# Access pod
kubectl exec -it nginx -- bash
```

### 3. Declarative Way (Recommended)

```bash
# Create pod from YAML
kubectl apply -f yaml-examples/01-basic-pod.yaml

# View pod
kubectl get pods -o wide

# Delete pod
kubectl delete -f yaml-examples/01-basic-pod.yaml
```

---

## 🎨 Multi-Container Patterns

### 1. Sidecar Pattern

Main container + helper container (logging, monitoring)

```bash
kubectl apply -f yaml-examples/05-sidecar-pattern.yaml

# View both containers
kubectl get pod web-with-sidecar
# Should show 2/2 containers ready

# View logs from specific container
kubectl logs web-with-sidecar -c nginx
kubectl logs web-with-sidecar -c log-processor
```

### 2. Init Container Pattern

Setup tasks run before main app

```bash
kubectl apply -f yaml-examples/06-init-container.yaml

# Watch init container complete
kubectl get pod app-with-init -w

# Check init logs
kubectl logs app-with-init -c init-setup

# Check main container
kubectl logs app-with-init -c app
```

---

## 🎯 Main Project: Production Web App

### Project Overview

Multi-container pod demonstrating real-world patterns:
- **Init Container**: Generates nginx configuration
- **Main Container**: Nginx web server with health checks
- **Sidecar 1**: Log aggregator
- **Sidecar 2**: Metrics exporter

### Deploy Project

```bash
# Deploy the production app
kubectl apply -f yaml-examples/10-production-web-app.yaml

# Watch pod creation
kubectl get pod production-web-app -w

# Check all containers are running
kubectl get pod production-web-app
# Should show: 3/3 containers ready

# View init container logs
kubectl logs production-web-app -c init-config

# View main app logs
kubectl logs production-web-app -c nginx

# View sidecar logs
kubectl logs production-web-app -c log-aggregator -f
kubectl logs production-web-app -c metrics-exporter -f
```

### Test the Application

```bash
# Port forward to access locally
kubectl port-forward pod/production-web-app 8080:80

# In another terminal, test health endpoint
curl http://localhost:8080/health

# Generate traffic to create logs
for i in {1..10}; do curl http://localhost:8080; done

# Watch logs being processed
kubectl logs production-web-app -c log-aggregator -f
```

### Understand Resource Usage

```bash
# View resource consumption
kubectl top pod production-web-app --containers

# Describe pod (see resource requests/limits)
kubectl describe pod production-web-app

# Check QoS class
kubectl get pod production-web-app -o jsonpath='{.status.qosClass}'
```

---

## 🏥 Health Checks

### Liveness Probe

Restarts container if check fails

```bash
# Deploy pod with probes
kubectl apply -f yaml-examples/04-pod-with-probes.yaml

# Watch pod status
kubectl get pod healthy-app -w

# Describe to see probe configuration
kubectl describe pod healthy-app | grep -A 5 Liveness

# Check events
kubectl get events --field-selector involvedObject.name=healthy-app
```

### Readiness Probe

Removes pod from service if not ready

```bash
# Check readiness status
kubectl get pod healthy-app -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}'

# Describe shows readiness state
kubectl describe pod healthy-app | grep -A 5 Readiness
```

---

## 💾 Shared Volumes

### Example: Writer/Reader Pattern

```bash
# Deploy shared volume demo
kubectl apply -f yaml-examples/08-shared-volume.yaml

# View writer logs (writing data)
kubectl logs shared-volume-demo -c writer

# View reader logs (reading same data)
kubectl logs shared-volume-demo -c reader -f

# Both containers see same data!
```

---

## 📊 Resource Management

### QoS Classes

```bash
# Deploy pods with different QoS
kubectl apply -f yaml-examples/12-qos-classes.yaml

# Check QoS class for each
kubectl get pod guaranteed-qos -o jsonpath='{.status.qosClass}'
kubectl get pod burstable-qos -o jsonpath='{.status.qosClass}'
kubectl get pod besteffort-qos -o jsonpath='{.status.qosClass}'
```

**Output:**
- `guaranteed-qos`: Guaranteed (highest priority)
- `burstable-qos`: Burstable (medium priority)
- `besteffort-qos`: BestEffort (lowest priority)

---

## 🎓 Key Learnings

### 1. Pod Basics
- Pods are ephemeral (temporary)
- Each pod gets unique IP
- Containers share network namespace (can use localhost)
- Usually one container per pod, but can have multiple

### 2. Multi-Container Use Cases
- **Sidecar**: Logging, monitoring, proxies
- **Ambassador**: Proxy to external services
- **Adapter**: Normalize/transform output

### 3. Init Containers
- Run before app containers
- Run sequentially (one after another)
- Must complete successfully
- Used for: DB migrations, config generation, waiting for dependencies

### 4. Health Probes
- **Liveness**: Is container alive? (restart if fails)
- **Readiness**: Can it serve traffic? (remove from endpoints if fails)
- **Startup**: For slow-starting apps (disables other probes until ready)

### 5. Resource Management
- Always set resource requests and limits
- QoS classes determine eviction priority
- Guaranteed > Burstable > BestEffort

---

## ✅ Best Practices Checklist

- [ ] Always set resource limits
- [ ] Use specific image tags (not `latest`)
- [ ] Add liveness and readiness probes
- [ ] One main process per container
- [ ] Use init containers for setup tasks
- [ ] Add meaningful labels
- [ ] Use declarative YAML (not imperative commands)
- [ ] Set security context (run as non-root)
- [ ] Use shared volumes for multi-container communication
- [ ] Test pod thoroughly before production

---

## 🔧 Useful Commands

```bash
# Create pod (imperative)
kubectl run <name> --image=<image>

# Create pod (declarative)
kubectl apply -f pod.yaml

# List pods
kubectl get pods
kubectl get pods -o wide
kubectl get pods --show-labels

# Describe pod
kubectl describe pod <name>

# View logs
kubectl logs <pod-name>
kubectl logs <pod-name> -c <container-name>
kubectl logs <pod-name> -f  # Follow logs

# Execute commands
kubectl exec -it <pod-name> -- bash
kubectl exec <pod-name> -c <container> -- <command>

# Port forwarding
kubectl port-forward pod/<name> 8080:80

# Delete pod
kubectl delete pod <name>
kubectl delete -f pod.yaml

# Get pod YAML
kubectl get pod <name> -o yaml

# Generate YAML (dry-run)
kubectl run nginx --image=nginx --dry-run=client -o yaml > pod.yaml

# Watch pods
kubectl get pods -w

# Check resource usage
kubectl top pod <name>
kubectl top pod <name> --containers
```

---

## 🎯 CKA Exam Tips

### Must Know Commands

```bash
# Generate pod YAML quickly
kubectl run nginx --image=nginx --dry-run=client -o yaml > pod.yaml

# Create pod and expose port
kubectl run nginx --image=nginx --port=80

# Execute command in pod
kubectl exec -it nginx -- sh

# View logs from specific container
kubectl logs <pod> -c <container>
```

### Common Exam Tasks

1. **Create pod with specific resource limits**
2. **Add liveness and readiness probes**
3. **Create multi-container pod with shared volume**
4. **Troubleshoot failing pods**
5. **Create init container to wait for service**

### Time-Saving Tips

- Use `kubectl run` with `--dry-run=client -o yaml` to generate YAML quickly
- Know how to add containers to existing YAML
- Practice multi-container scenarios
- Memorize probe syntax

---

## 📝 Interview Questions

See [interview-questions.md](./interview-questions.md) for comprehensive Q&A.

**Quick Questions:**

1. **What is a Pod?**
   - Smallest deployable unit, wraps one or more containers

2. **Why multiple containers in one pod?**
   - Tightly coupled containers that need to share resources

3. **Liveness vs Readiness probe?**
   - Liveness: restart if fails | Readiness: remove from service if fails

4. **When to use init containers?**
   - Setup tasks, waiting for dependencies, DB migrations

5. **What are QoS classes?**
   - Guaranteed, Burstable, BestEffort (eviction priority)

---

## 📖 Additional Resources

- [Kubernetes Pods Documentation](https://kubernetes.io/docs/concepts/workloads/pods/)
- [Pod Lifecycle](https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/)
- [Init Containers](https://kubernetes.io/docs/concepts/workloads/pods/init-containers/)
- [Configure Liveness, Readiness Probes](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/)
- [Multi-Container Design Patterns](https://kubernetes.io/blog/2015/06/the-distributed-system-toolkit-patterns/)

---

## 🎓 What's Next?

**Day 6-7:** ReplicaSets & Deployments - Managing multiple pod replicas and rolling updates 🚀

---

## 💬 Questions or Issues?

- Open an issue on GitHub
- Tag me on LinkedIn with #CKA75Challenge
- Check [GUIDE.md](./GUIDE.md) for detailed explanations

---

**⭐ Found this helpful? Star the repo!**  
**📢 Share with others preparing for CKA!**

#CKA #Kubernetes #Pods #DevOps #CloudNative