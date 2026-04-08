# COMMAND CHEATSHEET — Day 72: Kubernetes Monitoring & Logging

---

## Metrics Server & kubectl top

```bash
# Node resource usage
kubectl top nodes
kubectl top nodes --sort-by=cpu
kubectl top nodes --sort-by=memory

# Pod resource usage
kubectl top pods
kubectl top pods -n <namespace>
kubectl top pods --all-namespaces
kubectl top pods -n <namespace> --sort-by=cpu
kubectl top pods -n <namespace> --sort-by=memory
kubectl top pods -n <namespace> --containers          # show individual containers

# Check Metrics Server health
kubectl get pods -n kube-system -l app=metrics-server
kubectl get apiservice v1beta1.metrics.k8s.io
kubectl api-resources | grep metrics
```

---

## Logs

```bash
# Basic log retrieval
kubectl logs <pod>
kubectl logs <pod> -n <namespace>
kubectl logs <pod> -c <container>                     # specific container
kubectl logs <pod> --previous                         # previous crashed container
kubectl logs <pod> -f                                 # follow/tail live
kubectl logs <pod> --tail=100                         # last 100 lines
kubectl logs <pod> --since=1h                         # last 1 hour
kubectl logs <pod> --since-time="2024-01-15T10:00:00Z"

# Multi-pod logs (by label selector)
kubectl logs -l app=my-app -n <namespace>
kubectl logs -l app=my-app -n <namespace> --all-containers
kubectl logs -l app=my-app -n <namespace> -f          # follow all pods

# Logs with grep
kubectl logs <pod> | grep ERROR
kubectl logs <pod> | grep -E "ERROR|WARN" | tail -50

# Logs from deployment
kubectl logs deployment/<deployment-name> -n <namespace>
kubectl logs deployment/<deployment-name> -n <namespace> -f

# Check init container logs
kubectl logs <pod> -c <init-container-name>
```

---

## Events & Describe

```bash
# Get events (sorted by time)
kubectl get events -n <namespace> --sort-by=.lastTimestamp
kubectl get events --all-namespaces --sort-by=.lastTimestamp
kubectl get events -n <namespace> --field-selector type=Warning

# Describe resources (includes events)
kubectl describe pod <pod> -n <namespace>
kubectl describe node <node-name>
kubectl describe deployment <deployment> -n <namespace>

# Watch events live
kubectl get events -n <namespace> -w
```

---

## Prometheus CLI

```bash
# Port-forward Prometheus
kubectl port-forward svc/prometheus -n monitoring 9090:9090

# Port-forward Alertmanager
kubectl port-forward svc/alertmanager -n monitoring 9093:9093

# Validate Prometheus config
kubectl exec -n monitoring deployment/prometheus -- \
  promtool check config /etc/prometheus/prometheus.yml

# Validate alert rules
kubectl exec -n monitoring deployment/prometheus -- \
  promtool check rules /etc/prometheus/rules/kubernetes-alerts.yml

# Reload Prometheus config (no restart needed)
kubectl exec -n monitoring deployment/prometheus -- \
  wget -qO- --post-data='' http://localhost:9090/-/reload

# Query Prometheus API
kubectl exec -n monitoring deployment/prometheus -- \
  wget -qO- 'http://localhost:9090/api/v1/query?query=up'

# Check Prometheus targets
kubectl exec -n monitoring deployment/prometheus -- \
  wget -qO- 'http://localhost:9090/api/v1/targets' | python3 -m json.tool
```

---

## Useful PromQL Queries

```promql
# ── Cluster Overview ──────────────────────────────────

# All targets health
up

# Count running pods by namespace
count(kube_pod_status_phase{phase="Running"}) by (namespace)

# Pod restarts in last 15 minutes
increase(kube_pod_container_status_restarts_total[15m]) > 0

# OOMKilled containers
kube_pod_container_status_last_terminated_reason{reason="OOMKilled"} == 1


# ── CPU ───────────────────────────────────────────────

# CPU usage by pod (cores)
sum(rate(container_cpu_usage_seconds_total{container!=""}[5m])) by (pod, namespace)

# CPU usage % of limit
sum(rate(container_cpu_usage_seconds_total[5m])) by (pod) /
sum(kube_pod_container_resource_limits{resource="cpu"}) by (pod) * 100

# Node CPU usage %
(1 - avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) by (instance)) * 100


# ── Memory ────────────────────────────────────────────

# Memory usage by pod (bytes)
sum(container_memory_working_set_bytes{container!=""}) by (pod, namespace)

# Memory usage % of limit
sum(container_memory_working_set_bytes) by (pod) /
sum(kube_pod_container_resource_limits{resource="memory"}) by (pod) * 100

# Node memory usage %
(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100


# ── Networking ────────────────────────────────────────

# Network receive rate by pod
sum(rate(container_network_receive_bytes_total[5m])) by (pod)

# Network transmit rate by pod
sum(rate(container_network_transmit_bytes_total[5m])) by (pod)


# ── API Server ────────────────────────────────────────

# API server request rate by verb
sum(rate(apiserver_request_total[5m])) by (verb)

# API server error rate
sum(rate(apiserver_request_total{code=~"5.."}[5m])) /
sum(rate(apiserver_request_total[5m])) * 100

# API server p99 latency
histogram_quantile(0.99,
  sum(rate(apiserver_request_duration_seconds_bucket[5m])) by (verb, le)
)


# ── Cardinality ───────────────────────────────────────

# Total number of time series
count({__name__=~".+"})

# Top 10 metrics by cardinality
topk(10, count by (__name__)({__name__=~".+"}))
```

---

## Grafana

```bash
# Port-forward Grafana
kubectl port-forward svc/grafana -n monitoring 3000:3000
# Open: http://localhost:3000  (admin/admin123)

# Reload datasource provisioning
curl -X POST http://admin:admin123@localhost:3000/api/admin/provisioning/datasources/reload

# Import dashboard via API
curl -X POST -H "Content-Type: application/json" \
  -d '{"dashboard": {...}, "overwrite": true}' \
  http://admin:admin123@localhost:3000/api/dashboards/import

# Useful Dashboard IDs to import
# 15760 — Kubernetes / Views / Global
# 6417  — Kubernetes Cluster (Prometheus)
# 13770 — Kubernetes All-in-one
# 12611 — Loki Kubernetes Logs
```

---

## Loki & Promtail

```bash
# Port-forward Loki
kubectl port-forward svc/loki -n monitoring 3100:3100

# Check Loki health
curl http://localhost:3100/ready
curl http://localhost:3100/metrics | grep loki_ingester

# View Promtail targets
kubectl port-forward daemonset/promtail -n monitoring 9080:9080
# Open: http://localhost:9080/targets

# Check Promtail logs
kubectl logs -n monitoring -l app=promtail --tail=30

# Query Loki via API
curl -G 'http://localhost:3100/loki/api/v1/query' \
  --data-urlencode 'query={namespace="monitoring"}'

# Query Loki with time range
curl -G 'http://localhost:3100/loki/api/v1/query_range' \
  --data-urlencode 'query={app="nginx-demo"}' \
  --data-urlencode 'start=2024-01-15T10:00:00Z' \
  --data-urlencode 'end=2024-01-15T11:00:00Z'
```

---

## LogQL Quick Reference

```logql
# All logs from namespace
{namespace="monitoring"}

# Filter by app label
{app="nginx-demo", namespace="demo"}

# Contains string
{namespace="demo"} |= "error"

# Does not contain string
{namespace="demo"} != "healthz"

# Regex match
{namespace="demo"} |~ "error|timeout|5[0-9][0-9]"

# JSON parsing
{app="my-app"} | json | level="error"

# Rate of log lines
rate({namespace="demo"} |= "error" [5m])

# Count by label
sum by (pod) (count_over_time({namespace="demo"}[5m]))

# Top 5 error-producing pods
topk(5, sum by (pod) (count_over_time({namespace="demo"} |= "error" [5m])))
```

---

## Debugging Quick Commands

```bash
# Full pod diagnosis
POD=<pod-name> NS=<namespace>
kubectl get pod $POD -n $NS
kubectl describe pod $POD -n $NS
kubectl logs $POD -n $NS --previous 2>/dev/null || kubectl logs $POD -n $NS
kubectl top pod $POD -n $NS
kubectl get events -n $NS --field-selector involvedObject.name=$POD

# Find OOMKilled pods cluster-wide
kubectl get pods --all-namespaces -o json | \
  jq -r '.items[] | 
    select(
      .status.containerStatuses[]? | 
      .lastState.terminated.reason == "OOMKilled"
    ) | 
    "\(.metadata.namespace)/\(.metadata.name)"'

# Find pods not running
kubectl get pods --all-namespaces | grep -v Running | grep -v Completed

# Check node capacity vs requests
kubectl describe nodes | grep -A10 "Allocated resources"

# HPA status
kubectl get hpa --all-namespaces
kubectl describe hpa <hpa-name> -n <namespace>

# Check configmap is valid YAML
kubectl get configmap prometheus-config -n monitoring -o jsonpath='{.data.prometheus\.yml}' | python3 -c "import sys,yaml; yaml.safe_load(sys.stdin.read()); print('Valid YAML')"
```

---

## Resource Quotas & Limits

```bash
# Check resource quotas
kubectl get resourcequota -n <namespace>
kubectl describe resourcequota -n <namespace>

# Check limit ranges
kubectl get limitrange -n <namespace>
kubectl describe limitrange -n <namespace>

# Check pod resource requests/limits
kubectl get pods -n <namespace> -o json | \
  jq -r '.items[] | .metadata.name + " cpu_req:" + 
    (.spec.containers[0].resources.requests.cpu // "none") + 
    " mem_req:" + 
    (.spec.containers[0].resources.requests.memory // "none")'
```

---

## Monitoring Stack Health Check (One-Liner)

```bash
for comp in metrics-server prometheus alertmanager grafana loki; do
  ns="monitoring"
  [[ "$comp" == "metrics-server" ]] && ns="kube-system"
  status=$(kubectl get pods -n $ns -l app=$comp --no-headers 2>/dev/null | awk '{print $3}' | tr '\n' '/')
  echo "$comp: ${status:-NOT FOUND}"
done
```
