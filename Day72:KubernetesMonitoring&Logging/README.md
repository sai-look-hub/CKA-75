# Day 72: Kubernetes Monitoring & Logging

## Overview

Observability is the backbone of production Kubernetes operations. This module covers the three pillars of observability — **Metrics**, **Logs**, and **Traces** — implemented through a complete monitoring stack using Prometheus, Grafana, and a centralized logging solution with the EFK/PLG stack.

---

## Learning Objectives

By the end of Day 72, you will be able to:

- Deploy and configure the Kubernetes Metrics Server
- Understand the full logging architecture in Kubernetes
- Set up Prometheus for metrics collection and alerting
- Configure Grafana dashboards for cluster visualization
- Implement centralized logging with Loki + Promtail
- Debug application and cluster-level issues using observability tools
- Use `kubectl top`, `kubectl logs`, and event analysis for troubleshooting

---

## Topics Covered

### 1. Metrics Server

The Metrics Server is a cluster-wide aggregator of resource usage data. It collects CPU and memory metrics from kubelets and exposes them through the Kubernetes Metrics API.

**Key Concepts:**
- Metrics Server vs. Full Prometheus — when to use each
- `kubectl top nodes` and `kubectl top pods` commands
- Horizontal Pod Autoscaler (HPA) dependency on Metrics Server
- Resource request vs. actual usage analysis

**Architecture:**
```
Kubelet (cAdvisor) → Metrics Server → Metrics API → HPA / kubectl top
```

### 2. Logging Architecture

Kubernetes supports three logging patterns:

| Pattern | Description | Use Case |
|---|---|---|
| Node-level logging | Logs written to stdout/stderr, rotated by kubelet | Default for all containers |
| Sidecar logging | Dedicated logging container per pod | Legacy apps writing to files |
| Cluster-level logging | Centralized log aggregation | Production environments |

**Log Pipeline:**
```
Application → stdout/stderr → Container Runtime → /var/log/containers/
                                                          ↓
                                               Promtail / Fluentd (DaemonSet)
                                                          ↓
                                               Loki / Elasticsearch
                                                          ↓
                                               Grafana / Kibana
```

### 3. Prometheus Stack

Prometheus is the de-facto standard for Kubernetes metrics. It uses a pull-based model with service discovery.

**Components:**
- **Prometheus Server** — scrapes, stores, and queries metrics
- **Alertmanager** — handles alert routing and deduplication
- **Node Exporter** — exposes hardware/OS metrics
- **kube-state-metrics** — exposes Kubernetes object state metrics
- **Grafana** — visualization and dashboarding

**Prometheus Data Model:**
```
metric_name{label1="value1", label2="value2"} value timestamp
```

**Key Metrics to Monitor:**
- `container_cpu_usage_seconds_total` — CPU consumption per container
- `container_memory_working_set_bytes` — Active memory per container
- `kube_pod_status_phase` — Pod phase distribution
- `kube_node_status_condition` — Node health conditions
- `apiserver_request_duration_seconds` — API server latency

### 4. Grafana Dashboards

Pre-built dashboards for Kubernetes:
- **15760** — Kubernetes / Views / Global
- **6417** — Kubernetes Cluster (Prometheus)
- **13770** — 1 Kubernetes All-in-one Cluster Monitoring KR

### 5. Loki + Promtail (Logging Stack)

Loki is Prometheus-inspired log aggregation — it indexes only labels, not log content, making it extremely cost-efficient.

**Promtail** is the log shipper deployed as a DaemonSet that tails container logs and sends them to Loki.

**LogQL Query Examples:**
```logql
# All logs from namespace
{namespace="production"}

# Error logs from specific app
{app="api-service"} |= "ERROR"

# Rate of errors over time
rate({app="api-service"} |= "ERROR" [5m])
```

### 6. Debugging with Observability

**Systematic Debugging Approach:**
1. Check pod status: `kubectl get pods -n <namespace>`
2. Describe resource: `kubectl describe pod <pod>`
3. Check logs: `kubectl logs <pod> --previous`
4. Check events: `kubectl get events --sort-by=.lastTimestamp`
5. Check resource usage: `kubectl top pod <pod>`
6. Query metrics in Prometheus/Grafana
7. Correlate logs in Loki

---

## Project: Complete Observability Stack

The project deploys a full monitoring and logging stack on a Kubernetes cluster:

**Components Deployed:**
- Metrics Server (kube-system namespace)
- Prometheus + Alertmanager (monitoring namespace)
- Grafana with pre-configured datasources (monitoring namespace)
- Loki + Promtail for log aggregation (monitoring namespace)
- Sample application with custom metrics (demo namespace)
- AlertingRules for pod failures, high CPU/memory, and node conditions

**Namespace Structure:**
```
kube-system/     → metrics-server
monitoring/      → prometheus, alertmanager, grafana, loki, promtail
demo/            → sample-app (instrumented with custom metrics)
```

---

## Key Takeaways

- Metrics Server is lightweight; use it for HPA and basic `kubectl top`. Prometheus is for full observability.
- Always log to stdout/stderr — Kubernetes handles rotation. Never write to files inside containers.
- Loki is cheaper than Elasticsearch for pure log aggregation; pair with Grafana for unified dashboards.
- Alerts should be actionable — avoid alert fatigue by setting meaningful thresholds.
- The four golden signals (Latency, Traffic, Errors, Saturation) are the foundation of SRE monitoring.

---

## References

- [Kubernetes Metrics Server GitHub](https://github.com/kubernetes-sigs/metrics-server)
- [Prometheus Operator Documentation](https://prometheus-operator.dev/)
- [Grafana Loki Documentation](https://grafana.com/docs/loki/latest/)
- [Kubernetes Logging Architecture](https://kubernetes.io/docs/concepts/cluster-administration/logging/)
