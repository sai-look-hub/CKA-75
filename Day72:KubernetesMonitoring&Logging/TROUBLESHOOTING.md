# TROUBLESHOOTING — Day 72: Monitoring & Logging

> Systematic issue resolution for Kubernetes observability stack problems.

---

## Issue 1: `kubectl top nodes` Returns "Error from server (ServiceUnavailable)"

**Symptom:**
```
Error from server (ServiceUnavailable): the server is currently unable to handle the request (get nodes.metrics.k8s.io)
```

**Causes & Fixes:**

### Cause A: Metrics Server Not Deployed
```bash
kubectl get deployment metrics-server -n kube-system
# If NotFound, deploy it:
kubectl apply -f metrics-server-Day72.yaml
```

### Cause B: Metrics Server Pod Crashing
```bash
kubectl get pods -n kube-system -l app=metrics-server
kubectl logs -n kube-system -l app=metrics-server --tail=30

# Common fix: TLS issue on kubeadm clusters
# Add --kubelet-insecure-tls to args (dev only)
kubectl edit deployment metrics-server -n kube-system
```

### Cause C: APIService Not Available
```bash
kubectl get apiservice v1beta1.metrics.k8s.io
# If AVAILABLE=False:
kubectl describe apiservice v1beta1.metrics.k8s.io

# Fix: Ensure metrics-server service is reachable
kubectl get svc metrics-server -n kube-system
kubectl get endpoints metrics-server -n kube-system
```

### Cause D: Metrics Not Yet Collected
```bash
# Metrics Server needs ~60 seconds to start collecting
kubectl rollout status deployment/metrics-server -n kube-system
sleep 60
kubectl top nodes
```

---

## Issue 2: Prometheus Targets Showing "Down"

**Symptom:** In Prometheus UI → Status → Targets, targets show as DOWN.

**Diagnosis:**
```bash
# Check Prometheus pod logs
kubectl logs -n monitoring -l app=prometheus --tail=50

# Check if Prometheus config is valid
kubectl exec -n monitoring deployment/prometheus -- \
  promtool check config /etc/prometheus/prometheus.yml
```

### Cause A: RBAC Permissions Missing
```bash
# Prometheus needs ClusterRole to list pods/nodes/services
kubectl get clusterrolebinding prometheus
kubectl auth can-i list pods --as=system:serviceaccount:monitoring:prometheus
# If no: reapply prometheus-config-Day72.yaml
```

### Cause B: Service Discovery Not Finding Pods
```bash
# Check if annotation is present on target pods
kubectl get pods -n demo -o yaml | grep -A3 "prometheus.io"

# Fix: Add annotation to pod spec
# annotations:
#   prometheus.io/scrape: "true"
#   prometheus.io/port: "8080"
```

### Cause C: Network Policy Blocking Scrape
```bash
# Check for network policies
kubectl get networkpolicy --all-namespaces

# If policies exist, allow ingress from monitoring namespace
# Add appropriate NetworkPolicy allow rules
```

---

## Issue 3: Prometheus Shows No Data / Empty Graphs

**Symptom:** Queries return no results or "no data" in Grafana.

**Diagnosis:**
```bash
# Check scrape health
# In Prometheus UI: Status → Targets → check Last Scrape column

# Verify data exists
kubectl exec -n monitoring deployment/prometheus -- \
  wget -qO- 'http://localhost:9090/api/v1/query?query=up' | python3 -m json.tool
```

### Cause A: Wrong Time Range
- In Prometheus/Grafana, ensure time range covers when cluster was running
- Default range might be "Last 1 hour" — expand to "Last 6 hours"

### Cause B: Storage Full
```bash
kubectl exec -n monitoring deployment/prometheus -- \
  df -h /prometheus
# If full, reduce retention or increase storage
```

---

## Issue 4: Loki Showing No Logs in Grafana

**Symptom:** Grafana Explore → Loki shows empty results.

### Step 1: Verify Loki is Running
```bash
kubectl get pods -n monitoring -l app=loki
kubectl logs -n monitoring -l app=loki --tail=20

# Check Loki ready endpoint
kubectl exec -n monitoring deployment/loki -- \
  wget -qO- http://localhost:3100/ready
# Should return: ready
```

### Step 2: Verify Promtail is Running
```bash
kubectl get daemonset promtail -n monitoring
kubectl get pods -n monitoring -l app=promtail

# Check Promtail logs for shipping success
kubectl logs -n monitoring -l app=promtail --tail=30

# Look for lines like:
# level=info ts=... msg="Flushing stream" stream=...
```

### Step 3: Check Promtail Targets
```bash
# Port-forward Promtail for debug
kubectl port-forward -n monitoring daemonset/promtail 9080:9080
# Open: http://localhost:9080/targets
# Verify log paths are being tailed
```

### Cause A: Promtail Cannot Read Log Files
```bash
# Check if /var/log/pods is accessible
kubectl exec -n monitoring -it $(kubectl get pod -n monitoring -l app=promtail -o name | head -1) \
  -- ls /var/log/pods/

# If empty — log path may differ on your distro (e.g. /var/log/containers)
# Edit promtail-config ConfigMap to adjust __path__
```

### Cause B: Grafana Loki Datasource Misconfigured
```bash
# Verify datasource URL
# Grafana → Configuration → Data Sources → Loki
# URL should be: http://loki:3100
# Click "Test" button

# Also check from Grafana pod
kubectl exec -n monitoring deployment/grafana -- \
  wget -qO- http://loki:3100/ready
```

---

## Issue 5: Grafana Shows "No Data" on Dashboards

**Symptom:** Imported Kubernetes dashboard shows "No data" panels.

### Cause A: Wrong Prometheus Datasource UID
```bash
# In Grafana: Configuration → Data Sources → Prometheus
# Note the UID value
# In dashboard, ensure all panels reference this exact UID
```

### Cause B: Missing kube-state-metrics
Many Kubernetes dashboards require kube-state-metrics. Deploy it:
```bash
# Quick deploy
kubectl apply -f https://github.com/kubernetes/kube-state-metrics/releases/download/v2.10.1/standard/
```

### Cause C: Dashboard Variables Not Resolving
- In dashboard, check top dropdowns (cluster, namespace, pod)
- If all show "No options", Prometheus isn't returning label data
- Verify Prometheus has data: run `kube_pod_info` in Prometheus UI

---

## Issue 6: Alertmanager Not Receiving Alerts

**Symptom:** Alerts fire in Prometheus but not visible in Alertmanager.

```bash
# Check Prometheus → Alertmanager connectivity
kubectl exec -n monitoring deployment/prometheus -- \
  wget -qO- http://alertmanager:9093/-/healthy
# Should return: OK

# Check alert rule evaluation
kubectl exec -n monitoring deployment/prometheus -- \
  promtool check rules /etc/prometheus/rules/kubernetes-alerts.yml

# Check Prometheus logs for alert routing errors
kubectl logs -n monitoring -l app=prometheus | grep -i alert
```

---

## Issue 7: High Memory Usage on Prometheus

**Symptom:** Prometheus pod OOMKilled or consuming excessive memory.

```bash
# Check cardinality (number of unique time series)
# In Prometheus UI run:
# count({__name__=~".+"})

# Top 10 metrics by cardinality:
# topk(10, count by (__name__) ({__name__=~".+"}))
```

**Fixes:**
- Reduce scrape interval (15s → 30s) for non-critical targets
- Add `metric_relabel_configs` to drop high-cardinality labels
- Reduce `--storage.tsdb.retention.time`
- Increase memory limits if the data volume is justified

```yaml
# Example: Drop high-cardinality pod hash label
metric_relabel_configs:
  - source_labels: [pod_template_hash]
    action: labeldrop
    regex: pod_template_hash
```

---

## Issue 8: Container Logs Not Appearing with `kubectl logs`

**Symptom:** `kubectl logs <pod>` returns empty output.

```bash
# Check if container is running
kubectl get pod <pod> -o jsonpath='{.status.containerStatuses[*].ready}'

# Check log location on node
kubectl describe pod <pod> | grep "Node:"
# SSH to node and check:
# ls /var/log/pods/<namespace>_<pod>_<uid>/

# Check if app is writing to stdout/stderr (not files)
kubectl exec <pod> -- cat /proc/1/fd/1  # stdout
kubectl exec <pod> -- cat /proc/1/fd/2  # stderr

# For crashed/completed pod
kubectl logs <pod> --previous
```

---

## Quick Diagnostic Commands

```bash
# Full cluster observability health check
echo "=== Metrics Server ===" && kubectl get pods -n kube-system -l app=metrics-server
echo "=== Prometheus ===" && kubectl get pods -n monitoring -l app=prometheus
echo "=== Alertmanager ===" && kubectl get pods -n monitoring -l app=alertmanager
echo "=== Grafana ===" && kubectl get pods -n monitoring -l app=grafana
echo "=== Loki ===" && kubectl get pods -n monitoring -l app=loki
echo "=== Promtail ===" && kubectl get daemonset promtail -n monitoring
echo "=== Cluster Metrics ===" && kubectl top nodes 2>/dev/null || echo "Metrics Server not ready"

# Check all monitoring pod events
kubectl get events -n monitoring --sort-by=.lastTimestamp | tail -20

# Check for OOMKilled pods across cluster
kubectl get pods --all-namespaces -o json | \
  jq -r '.items[] | select(.status.containerStatuses[]?.lastState.terminated.reason == "OOMKilled") | .metadata.namespace + "/" + .metadata.name'
```
