# INTERVIEW Q&A — Day 72: Kubernetes Monitoring & Logging

> 30 questions covering Metrics Server, Prometheus, logging architecture, Grafana, Loki, and debugging. Organized from foundational to advanced.

---

## Section 1: Metrics Server & Resource Monitoring

**Q1. What is the Kubernetes Metrics Server and what does it enable?**

The Metrics Server is a scalable, efficient source of container resource metrics. It collects CPU and memory usage from kubelets via the Summary API, and exposes them through the Kubernetes Metrics API (`metrics.k8s.io`). It enables `kubectl top nodes`, `kubectl top pods`, and is required for the Horizontal Pod Autoscaler (HPA) and Vertical Pod Autoscaler (VPA) to function. It is **not** a full monitoring solution — it holds only the last few minutes of metrics in memory, with no historical storage.

---

**Q2. How does the Metrics Server differ from Prometheus?**

| Aspect | Metrics Server | Prometheus |
|---|---|---|
| Purpose | Live resource usage for HPA/VPA/kubectl | Full metrics collection, alerting, history |
| Storage | In-memory, no persistence | Time-series database (TSDB) |
| Retention | ~1-2 minutes | Configurable (days/weeks) |
| Scrape targets | Only kubelets (CPU/memory) | Any HTTP `/metrics` endpoint |
| Query language | None | PromQL |
| Alerting | No | Yes (with Alertmanager) |
| Resource cost | Very low | Moderate-high |

Use Metrics Server for autoscaling. Use Prometheus for observability.

---

**Q3. What happens to HPA if the Metrics Server is down?**

HPA cannot scale. It will log events like `unable to get metrics for resource cpu` and stop making scaling decisions. Existing pods continue running, but neither scale-up nor scale-down occurs until the Metrics Server is restored. This is why high availability of the Metrics Server is important in production.

---

**Q4. What is the difference between `kubectl top` and resource limits/requests?**

- **Requests** = minimum guaranteed resources (used for scheduling decisions)
- **Limits** = maximum allowed resources (enforced by cgroups)
- **`kubectl top`** = actual current resource consumption

A pod may have `requests: 100m cpu` but currently use `350m cpu`. The `kubectl top` command shows the live `350m`. HPA uses actual usage to decide scaling, not requests or limits.

---

## Section 2: Prometheus Architecture

**Q5. Explain the Prometheus pull model and why it's preferred in Kubernetes.**

Prometheus actively scrapes (pulls) metrics from targets at configurable intervals, rather than targets pushing to Prometheus. This is preferred in Kubernetes because:
1. Prometheus controls scrape rate — prevents metric storms during incidents
2. Service discovery handles dynamic pod IPs automatically
3. Targets don't need to know where Prometheus is
4. Easy to detect when a target goes down (scrape fails)
5. No firewall rules needed from pods to a central collector

---

**Q6. What is kube-state-metrics and why is it important?**

kube-state-metrics is a separate service that listens to the Kubernetes API and generates metrics about the state of Kubernetes objects — deployments, pods, nodes, jobs, etc. While the Metrics Server gives you `how much CPU is pod X using`, kube-state-metrics tells you `how many replicas does deployment Y have` or `is pod Z in a crash loop`. These state metrics are essential for meaningful Kubernetes dashboards and alerting on deployment health.

---

**Q7. How does Prometheus service discovery work in Kubernetes?**

Prometheus uses `kubernetes_sd_configs` with different roles:
- `node` — discovers all cluster nodes
- `pod` — discovers all pods
- `service` — discovers all services
- `endpoints` — discovers service endpoints
- `ingress` — discovers ingress resources

It connects to the Kubernetes API, watches for changes, and dynamically updates scrape targets. Relabeling (`relabel_configs`) then filters and transforms discovered targets — for example, only scraping pods with the `prometheus.io/scrape: "true"` annotation.

---

**Q8. What is a PromQL recording rule and when would you use one?**

Recording rules pre-compute expensive PromQL expressions and store the result as a new metric. Use them when:
1. A complex query is used frequently in dashboards and is slow
2. You need a derived metric available for alerting over time
3. Reducing query load on Prometheus (federation scenarios)

Example:
```yaml
- record: job:http_requests:rate5m
  expr: sum(rate(http_requests_total[5m])) by (job)
```
This pre-computes per-job request rates and stores as `job:http_requests:rate5m`.

---

**Q9. What is the difference between `rate()` and `irate()` in PromQL?**

- `rate()` — calculates the per-second average rate over the entire time range. Smoothed, good for dashboards and slow-moving counters.
- `irate()` — calculates the per-second rate using only the **last two data points**. More responsive to sudden spikes, but noisier. Better for alerting on instantaneous issues.

Rule of thumb: use `rate()` for dashboards, `irate()` for alerting on fast-changing metrics.

---

**Q10. How do you handle Prometheus high cardinality issues?**

High cardinality (millions of unique label combinations) causes Prometheus memory explosion. Solutions:
1. Drop high-cardinality labels using `metric_relabel_configs` (e.g., remove `pod_template_hash`, request IDs, user IDs from labels)
2. Use `recording rules` to aggregate before storing
3. Avoid using unbounded values (user IDs, request paths) as labels
4. Monitor cardinality: `count({__name__=~".+"})` — alert if above 1-2 million series
5. Use `--storage.tsdb.max-block-duration` tuning for large clusters

---

## Section 3: Logging Architecture

**Q11. What are the three logging patterns in Kubernetes?**

1. **Node-level (default)** — Containers write to stdout/stderr. The container runtime (containerd/Docker) captures and rotates logs. Accessible via `kubectl logs`. Simple but ephemeral — logs disappear when pod is deleted.

2. **Sidecar logging** — A log-shipper container (e.g., Fluentd) runs alongside the app container, reads from a shared volume, and ships logs centrally. Used when apps write to files instead of stdout.

3. **Cluster-level (recommended for production)** — A DaemonSet (Promtail/Fluentd/Filebeat) runs on every node, tails `/var/log/pods/`, and ships to a central store (Loki/Elasticsearch). Logs survive pod deletion.

---

**Q12. Why should containers always log to stdout/stderr?**

1. Kubernetes and container runtimes automatically handle log rotation for stdout/stderr
2. `kubectl logs` command works out of the box
3. DaemonSet log shippers (Promtail, Fluentd) are pre-configured to tail these paths
4. No volume mounts or file permission management needed
5. Logs are accessible immediately without container filesystem access
6. Follows the Twelve-Factor App methodology

Writing to files inside containers requires sidecar log shippers, shared volumes, and custom configuration — significantly more operational complexity.

---

**Q13. What is the difference between Loki and Elasticsearch for log aggregation?**

| Aspect | Loki | Elasticsearch |
|---|---|---|
| Indexing | Labels only (not log content) | Full-text index on all content |
| Query language | LogQL | Lucene / EQL |
| Resource usage | Low (no full-text index) | High (index ~30% of raw data size) |
| Search capability | Label + grep/regex | Full-text search, fuzzy, aggregations |
| Cost | Lower | Higher |
| Best for | Cloud-native microservices with good labels | Complex search, security, compliance |

Loki is "Prometheus for logs" — index labels, not content. If you need `grep`, Loki is sufficient and cheap. If you need full-text search or complex analytics, use Elasticsearch.

---

**Q14. What is structured logging and why does it matter for Kubernetes observability?**

Structured logging outputs JSON instead of plain text:
```json
{"level":"error","ts":"2024-01-15T10:30:00Z","msg":"DB timeout","latency_ms":5000,"user_id":"u123"}
```

Benefits:
- Log shippers can extract fields as Loki/Prometheus labels
- Grafana can filter by level, latency, user without regex
- Enables log-based metrics (count errors by service)
- Easier to correlate with distributed tracing

---

## Section 4: Alerting

**Q15. What is the difference between `for` duration and scrape interval in alert rules?**

- **Scrape interval** — how often Prometheus collects metrics (e.g., `15s`)
- **`for` duration in alert rules** — how long the condition must be **continuously true** before the alert fires

Example:
```yaml
- alert: HighCPU
  expr: cpu_usage > 90
  for: 10m
```
This means: CPU must be above 90% for **10 consecutive minutes** before alerting. This prevents false alerts from momentary spikes. Setting `for: 0m` fires immediately on first occurrence.

---

**Q16. Explain Alertmanager's routing, grouping, and inhibition.**

- **Routing** — routes alerts to different receivers (Slack/PagerDuty/email) based on label matchers. Allows critical alerts to go to on-call engineers while warning alerts go to Slack.
- **Grouping** — bundles related alerts into a single notification. `group_by: [alertname, namespace]` prevents 50 separate Slack messages for 50 pod failures — sends 1 grouped message.
- **Inhibition** — suppresses lower-severity alerts when a higher-severity alert exists. If `NodeDown` is firing, suppress all pod/service alerts on that node — they're all downstream of the same root cause.

---

## Section 5: Grafana & Dashboards

**Q17. What are Grafana datasource provisioning and dashboard provisioning?**

**Datasource provisioning** — configures datasources (Prometheus, Loki) via YAML files at startup. No manual UI clicks needed. Stored in `/etc/grafana/provisioning/datasources/`. Changes require restart or `POST /api/admin/provisioning/datasources/reload`.

**Dashboard provisioning** — loads dashboards from JSON files at startup via a provider config. Dashboards in `/var/lib/grafana/dashboards/`. Grafana checks for file changes on a configurable interval. Essential for GitOps-style Grafana management — dashboards in Git, deployed via ConfigMaps.

---

**Q18. What are the four golden signals of monitoring?**

Coined by Google SRE:
1. **Latency** — time to service a request (separate successful vs. error latency)
2. **Traffic** — how much demand is on the system (requests/second, transactions/second)
3. **Errors** — rate of failed requests (HTTP 5xx, exceptions, timeouts)
4. **Saturation** — how "full" the service is (CPU%, memory%, queue depth)

These four signals apply to almost every service and are the foundation of meaningful SRE alerting. If all four look healthy, users are probably happy.

---

## Section 6: Debugging

**Q19. Walk through your process for debugging a pod that's been restarting frequently.**

1. `kubectl get pod <pod> -n <ns>` — check restart count and current status
2. `kubectl describe pod <pod> -n <ns>` — look at Events section for OOMKilled, liveness probe failures, image pull errors
3. `kubectl logs <pod> -n <ns> --previous` — get logs from the **previous** (crashed) container run
4. Check `lastState.terminated.reason` in pod status — OOMKilled means memory limit too low; Error means application crash
5. `kubectl top pod <pod> -n <ns>` — check if memory is near limits
6. If OOMKilled: increase memory limits or optimize application
7. If liveness probe: check probe path/port is correct and app starts in time (`initialDelaySeconds`)
8. Query Prometheus for historical patterns
9. Query Loki for error messages around restart timestamps

---

**Q20. How do you find which pod is consuming the most resources in a namespace?**

```bash
# CPU top consumers
kubectl top pods -n <namespace> --sort-by=cpu

# Memory top consumers
kubectl top pods -n <namespace> --sort-by=memory

# PromQL for sustained high CPU
topk(5, sum(rate(container_cpu_usage_seconds_total[5m])) by (pod, namespace))

# PromQL for memory approaching limits
sum(container_memory_working_set_bytes) by (pod) /
sum(kube_pod_container_resource_limits{resource="memory"}) by (pod) * 100
```

---

**Q21. What is the difference between `kubectl logs` and querying Loki?**

| Aspect | `kubectl logs` | Loki (Grafana Explore) |
|---|---|---|
| Data source | Live from kubelet | Indexed from DaemonSet shipper |
| Historical | Only current/previous run | Retention period (days/weeks) |
| Multi-pod | `-l selector` for multiple | `{app="foo"}` across all instances |
| Filtering | `grep` pipe | LogQL native `|=`, `|~`, `!=` |
| Metrics | No | `rate()` log-based metrics |
| After pod deletion | Gone | Still available in Loki |

For real-time debugging of a running pod: `kubectl logs`. For historical analysis, post-incident review, multi-pod correlation: Loki.

---

## Section 7: Advanced

**Q22. What is Prometheus federation and when is it used?**

Federation allows one Prometheus server to scrape metrics from other Prometheus servers. Use cases:
1. **Multi-cluster aggregation** — a global Prometheus aggregates high-level metrics from per-cluster Prometheus instances
2. **Hierarchical scraping** — reduce load on remote Prometheus by having a central one scrape only aggregated recording rules
3. **Cross-datacenter visibility** — single dashboard across multiple sites

The federated Prometheus scrapes `/federate?match[]=<metric>` endpoint with specific metric selectors.

---

**Q23. What are Prometheus remote write and remote read?**

- **Remote write** — Prometheus streams all scraped metrics to an external storage backend (Thanos, Cortex, VictoriaMetrics, Mimir) in real-time. Enables long-term storage beyond local TSDB capacity and multi-cluster query.
- **Remote read** — Prometheus queries an external backend for historical data when local TSDB doesn't have it. Transparent to PromQL queries.

In large production environments, Prometheus stores ~2 weeks locally and uses remote write to Thanos for 1-2 years of history.

---

**Q24. Explain Thanos and why it's used with Prometheus.**

Thanos extends Prometheus with:
1. **Unlimited retention** — object storage (S3/GCS) instead of local disk
2. **Global query view** — query metrics from multiple Prometheus instances as one
3. **Deduplication** — removes duplicate metrics from HA Prometheus pairs
4. **Downsampling** — reduces old data to 5m/1h resolution to save storage

Thanos is the standard solution for large-scale, multi-cluster Kubernetes monitoring. Components: Sidecar (runs alongside Prometheus), Store Gateway, Querier, Compactor.

---

**Q25. What is OpenTelemetry and how does it relate to Kubernetes monitoring?**

OpenTelemetry (OTel) is a CNCF project providing a unified observability framework for collecting metrics, logs, and traces. It standardizes instrumentation across languages with a single SDK and collector.

In Kubernetes:
- Applications are instrumented with OTel SDK
- OTel Collector runs as a DaemonSet or sidecar
- Collector exports to Prometheus (metrics), Loki/Elasticsearch (logs), Jaeger/Tempo (traces)
- Enables correlation between all three observability pillars — a single trace ID can link metrics, logs, and traces for a request

---

## Rapid Fire

**Q26. What annotation enables Prometheus auto-discovery for a pod?**
`prometheus.io/scrape: "true"` (with optional `prometheus.io/port` and `prometheus.io/path`)

**Q27. What is the `up` metric in Prometheus?**
`up{job="...", instance="..."}` equals `1` if Prometheus successfully scraped the target, `0` if the scrape failed. Fundamental health check for all monitored targets.

**Q28. How do you reload Prometheus configuration without restarting it?**
Send a POST to the lifecycle endpoint: `curl -X POST http://localhost:9090/-/reload` (requires `--web.enable-lifecycle` flag)

**Q29. What causes "ALERTS" to appear in the Prometheus Alerts page but not in Alertmanager?**
The alert is in `pending` state — the `for` duration hasn't elapsed yet. Alerts only transition to `firing` and reach Alertmanager after the condition holds for the full `for` duration.

**Q30. What is the difference between a Prometheus `gauge` and `counter`?**
- **Counter** — monotonically increasing value (total requests, total errors). Never decreases except on restart. Always use `rate()` or `increase()` with counters.
- **Gauge** — value that can go up or down (current memory, active connections, temperature). Use directly in queries without `rate()`.
