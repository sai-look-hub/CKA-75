# GUIDEME — Day 72: Kubernetes Monitoring & Logging

> Step-by-step hands-on walkthrough. Follow in order. Each phase builds on the previous.

---

## Prerequisites

```bash
# Verify cluster is running
kubectl cluster-info
kubectl get nodes

# Ensure you have a working namespace
kubectl create namespace monitoring
kubectl create namespace demo
```

---

## Phase 1: Deploy Metrics Server

### Step 1.1 — Apply Metrics Server

```bash
kubectl apply -f metrics-server-Day72.yaml
```

### Step 1.2 — Verify Metrics Server is Running

```bash
# Wait for metrics server pod to be ready
kubectl rollout status deployment/metrics-server -n kube-system

# Confirm metrics API is registered
kubectl get apiservice v1beta1.metrics.k8s.io
```

Expected output:
```
NAME                     SERVICE                      AVAILABLE   AGE
v1beta1.metrics.k8s.io   kube-system/metrics-server   True        2m
```

### Step 1.3 — Test Metrics Collection

```bash
# Wait 60 seconds for initial metrics collection
sleep 60

# Check node resource usage
kubectl top nodes

# Check pod resource usage across all namespaces
kubectl top pods --all-namespaces

# Check pods in kube-system sorted by CPU
kubectl top pods -n kube-system --sort-by=cpu
```

---

## Phase 2: Deploy Prometheus Stack

### Step 2.1 — Apply Prometheus Manifests

```bash
# Deploy all Prometheus components
kubectl apply -f prometheus-config-Day72.yaml
kubectl apply -f prometheus-deployment-Day72.yaml
kubectl apply -f alerting-rules-Day72.yaml
```

### Step 2.2 — Verify Prometheus Components

```bash
# Check all monitoring pods
kubectl get pods -n monitoring

# Wait for Prometheus to be ready
kubectl rollout status deployment/prometheus -n monitoring
kubectl rollout status deployment/alertmanager -n monitoring
```

### Step 2.3 — Access Prometheus UI

```bash
# Port-forward Prometheus to localhost
kubectl port-forward svc/prometheus -n monitoring 9090:9090

# In browser, open: http://localhost:9090
```

**Queries to run in Prometheus UI:**
```promql
# Check all running pods
kube_pod_status_phase{phase="Running"}

# CPU usage by pod
sum(rate(container_cpu_usage_seconds_total[5m])) by (pod)

# Memory usage by namespace
sum(container_memory_working_set_bytes) by (namespace)

# Node disk usage
node_filesystem_avail_bytes / node_filesystem_size_bytes * 100
```

### Step 2.4 — Check Alert Rules

```bash
# Navigate to: http://localhost:9090/alerts
# You should see alert rules from alerting-rules-Day72.yaml

# Also check via kubectl
kubectl get configmap prometheus-alerts -n monitoring -o yaml
```

---

## Phase 3: Deploy Grafana

### Step 3.1 — Apply Grafana Manifest

```bash
kubectl apply -f grafana-deployment-Day72.yaml
```

### Step 3.2 — Access Grafana

```bash
# Port-forward Grafana
kubectl port-forward svc/grafana -n monitoring 3000:3000

# Open: http://localhost:3000
# Default credentials: admin / admin123
```

### Step 3.3 — Import Kubernetes Dashboard

1. Click **+** → **Import**
2. Enter Dashboard ID: **15760** → Load
3. Select **Prometheus** as the datasource
4. Click **Import**

### Step 3.4 — Verify Data

Check that the following panels have data:
- Cluster CPU Usage
- Cluster Memory Usage
- Node Filesystem Usage
- Pod Status Overview

---

## Phase 4: Deploy Loki + Promtail (Log Aggregation)

### Step 4.1 — Apply Loki Stack

```bash
kubectl apply -f loki-stack-Day72.yaml
```

### Step 4.2 — Verify Loki and Promtail

```bash
kubectl get pods -n monitoring -l app=loki
kubectl get pods -n monitoring -l app=promtail

# Check Promtail DaemonSet — should have 1 pod per node
kubectl get daemonset promtail -n monitoring
```

### Step 4.3 — Verify Log Collection

```bash
# Check Promtail logs — should show successful log shipping
kubectl logs -n monitoring -l app=promtail --tail=20
```

### Step 4.4 — Query Logs in Grafana

1. Go to Grafana → **Explore**
2. Select **Loki** datasource
3. Run these LogQL queries:

```logql
# View all logs from monitoring namespace
{namespace="monitoring"}

# View kube-system logs
{namespace="kube-system"}

# Filter error logs from any namespace
{namespace=~".+"} |= "error"

# Count error rate
rate({namespace="monitoring"} |= "error" [5m])
```

---

## Phase 5: Deploy Sample Application

### Step 5.1 — Deploy Demo App

```bash
kubectl apply -f sample-app-Day72.yaml
```

### Step 5.2 — Verify Application

```bash
kubectl get pods -n demo
kubectl get svc -n demo

# Check app logs
kubectl logs -n demo -l app=sample-app --tail=20

# Check resource usage
kubectl top pods -n demo
```

### Step 5.3 — Observe in Grafana

1. Open Grafana → Dashboards
2. Observe `demo` namespace appearing in namespace dropdown
3. Check Loki Explore for `{namespace="demo"}` logs

---

## Phase 6: Alerting Walkthrough

### Step 6.1 — Trigger a Test Alert

```bash
# Create a pod that requests excessive resources to trigger alert
kubectl run stress-test \
  --image=polinux/stress \
  --requests=cpu=800m \
  --limits=cpu=1000m \
  -n demo \
  -- stress --cpu 1 --timeout 120s

# Watch pod
kubectl get pod stress-test -n demo -w
```

### Step 6.2 — Check Alertmanager

```bash
kubectl port-forward svc/alertmanager -n monitoring 9093:9093
# Open: http://localhost:9093
```

### Step 6.3 — Cleanup

```bash
kubectl delete pod stress-test -n demo
```

---

## Phase 7: Debugging Exercises

### Exercise 7.1 — OOMKilled Investigation

```bash
# Create an OOMKilled scenario
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: oom-test
  namespace: demo
spec:
  containers:
  - name: memory-hog
    image: polinux/stress
    resources:
      limits:
        memory: 50Mi
    command: ["stress"]
    args: ["--vm", "1", "--vm-bytes", "100M"]
EOF

# Watch pod status
kubectl get pod oom-test -n demo -w

# After OOMKill, inspect
kubectl describe pod oom-test -n demo | grep -A5 "Last State"
kubectl get events -n demo --sort-by=.lastTimestamp

# Clean up
kubectl delete pod oom-test -n demo
```

### Exercise 7.2 — Log Analysis

```bash
# Check all events in chronological order
kubectl get events --all-namespaces --sort-by=.lastTimestamp | tail -20

# Get logs from a crashed pod (previous run)
kubectl logs <pod-name> -n demo --previous

# Follow live logs from multiple pods using label selector
kubectl logs -n monitoring -l app=prometheus -f
```

### Exercise 7.3 — Resource Audit

```bash
# Find top CPU consumers
kubectl top pods --all-namespaces --sort-by=cpu | head -10

# Find top memory consumers
kubectl top pods --all-namespaces --sort-by=memory | head -10

# Check node resource allocation vs actual usage
kubectl describe nodes | grep -A4 "Allocated resources"
```

---

## Cleanup

```bash
# Remove demo namespace
kubectl delete namespace demo

# Remove monitoring stack (keep if you want to continue exploring)
kubectl delete namespace monitoring

# Remove metrics server
kubectl delete -f metrics-server-Day72.yaml
```

---

## Summary Checklist

- [ ] Metrics Server deployed and `kubectl top` working
- [ ] Prometheus scraping cluster metrics
- [ ] Alert rules configured and visible in Prometheus UI
- [ ] Grafana running with Kubernetes dashboards
- [ ] Loki collecting logs from all namespaces
- [ ] Promtail DaemonSet running on all nodes
- [ ] Sample app observable via both metrics and logs
- [ ] Completed OOMKill debugging exercise
- [ ] Able to query LogQL in Grafana Explore
