# Week 3-4 Review - Command Cheatsheet

## Multi-Environment Management Commands

### Environment Setup

```bash
# Create all namespaces
kubectl apply -f examples/01-infrastructure/namespaces.yaml

# Apply resource policies
kubectl apply -f examples/01-infrastructure/resource-quotas.yaml

# Label nodes for production
kubectl label nodes node-1 environment=production tier=high-performance

# Label nodes for staging
kubectl label nodes node-2 environment=staging tier=medium-performance

# Label nodes for development
kubectl label nodes node-3 environment=development tier=standard

# View all node labels
kubectl get nodes --show-labels
kubectl get nodes -L environment,tier,zone
```

### Namespace Operations

```bash
# List all namespaces
kubectl get namespaces

# Get resources in specific namespace
kubectl get all -n development
kubectl get all -n staging
kubectl get all -n production

# Switch default namespace
kubectl config set-context --current --namespace=production

# View current namespace
kubectl config view --minify | grep namespace:
```

### Resource Quota Management

```bash
# View all quotas
kubectl get resourcequota -A

# Describe quota for environment
kubectl describe resourcequota dev-quota -n development
kubectl describe resourcequota staging-quota -n staging
kubectl describe resourcequota prod-quota -n production

# Check quota usage
kubectl get resourcequota -A -o custom-columns=\
NAMESPACE:.metadata.namespace,\
NAME:.metadata.name,\
CPU_USED:.status.used.requests\\.cpu,\
CPU_HARD:.status.hard.requests\\.cpu,\
MEM_USED:.status.used.requests\\.memory,\
MEM_HARD:.status.hard.requests\\.memory

# Monitor quota usage
watch kubectl describe resourcequota -A
```

### Deployment Commands

```bash
# Deploy to development
kubectl apply -f examples/02-development/ -n development

# Deploy to staging
kubectl apply -f examples/03-staging/ -n staging

# Deploy to production
kubectl apply -f examples/04-production/ -n production

# Deploy specific service
kubectl apply -f examples/04-production/backend-prod.yaml

# Update image
kubectl set image deployment/backend backend=backend:v1.1.0 -n production

# Scale deployment
kubectl scale deployment backend --replicas=10 -n production

# Rollout status
kubectl rollout status deployment/backend -n production

# Rollback
kubectl rollout undo deployment/backend -n production
```

### Pod Distribution & Scheduling

```bash
# Check pod distribution across nodes
kubectl get pods -A -o wide | awk '{print $8}' | sort | uniq -c

# View pod placement by environment
kubectl get pods -n production -o custom-columns=\
NAME:.metadata.name,\
NODE:.spec.nodeName,\
QOS:.status.qosClass

# Check anti-affinity working
kubectl get pods -n production -l app=backend -o wide

# Verify zone distribution
kubectl get pods -n production -o custom-columns=\
NAME:.metadata.name,\
NODE:.spec.nodeName,\
ZONE:.spec.nodeSelector.zone
```

### Resource Monitoring

```bash
# Node resource usage
kubectl top nodes

# Pod resource usage (all namespaces)
kubectl top pods -A

# Pod resource usage (specific namespace)
kubectl top pods -n production

# Sort by CPU
kubectl top pods -A --sort-by=cpu | head -20

# Sort by memory
kubectl top pods -A --sort-by=memory | head -20

# Watch resource usage
watch kubectl top pods -n production
```

### QoS Class Verification

```bash
# Check QoS classes
kubectl get pods -A -o custom-columns=\
NAMESPACE:.metadata.namespace,\
NAME:.metadata.name,\
QOS:.status.qosClass

# Filter by QoS class
kubectl get pods -A -o json | \
  jq -r '.items[] | select(.status.qosClass=="Guaranteed") | .metadata.name'

# Count pods by QoS
kubectl get pods -A -o jsonpath='{range .items[*]}{.status.qosClass}{"\n"}{end}' | \
  sort | uniq -c
```

### HPA Management

```bash
# List all HPAs
kubectl get hpa -A

# Describe HPA
kubectl describe hpa backend-hpa -n production

# Watch HPA scaling
watch kubectl get hpa -n production

# Manually scale
kubectl scale deployment backend --replicas=15 -n production

# Check HPA events
kubectl get events -n production | grep HorizontalPodAutoscaler
```

### StatefulSet Operations

```bash
# Get StatefulSets
kubectl get statefulset -A

# Watch StatefulSet
kubectl get statefulset database -n production -w

# Scale StatefulSet
kubectl scale statefulset database --replicas=5 -n production

# Delete StatefulSet (keep PVCs)
kubectl delete statefulset database -n production --cascade=orphan

# Check PVCs
kubectl get pvc -n production

# Check pod order
kubectl get pods -n production -l app=database
```

### DaemonSet Operations

```bash
# Get DaemonSets
kubectl get daemonset -A

# Check DaemonSet coverage
kubectl get daemonset fluentd -n kube-system

# Verify pod on each node
kubectl get pods -l app=fluentd -o wide

# Update DaemonSet image
kubectl set image daemonset/fluentd fluentd=fluentd:v2 -n kube-system

# Check rollout
kubectl rollout status daemonset/fluentd -n kube-system
```

### Service & Networking

```bash
# List services per environment
kubectl get svc -n development
kubectl get svc -n staging
kubectl get svc -n production

# Get service endpoints
kubectl get endpoints -n production

# Test service connectivity
kubectl run test --rm -it --image=busybox -n production -- \
  wget -qO- http://backend:8080/health

# Port forward
kubectl port-forward svc/backend 8080:8080 -n production
```

### Troubleshooting

```bash
# Check pending pods
kubectl get pods -A --field-selector=status.phase=Pending

# Describe pending pod
kubectl describe pod <pod-name> -n <namespace>

# Check events
kubectl get events -n production --sort-by='.lastTimestamp'

# Check why pod failed
kubectl describe pod <pod-name> -n <namespace> | grep -A 10 Events

# View logs
kubectl logs <pod-name> -n <namespace>

# Follow logs
kubectl logs -f <pod-name> -n <namespace>

# Previous container logs (if crashed)
kubectl logs <pod-name> -n <namespace> --previous

# Execute into pod
kubectl exec -it <pod-name> -n <namespace> -- /bin/bash
```

### Comparison Commands

```bash
# Compare resource usage across environments
for ns in development staging production; do
  echo "=== $ns ==="
  kubectl top pods -n $ns
done

# Compare deployments
kubectl get deployments -A -o custom-columns=\
NAMESPACE:.metadata.namespace,\
NAME:.metadata.name,\
REPLICAS:.spec.replicas

# Compare services
kubectl get svc -A -o custom-columns=\
NAMESPACE:.metadata.namespace,\
NAME:.metadata.name,\
TYPE:.spec.type
```

### Validation Commands

```bash
# Validate environment isolation
kubectl auth can-i get pods -n production --as=system:serviceaccount:development:default

# Check resource allocation
kubectl describe nodes | grep -A 10 "Allocated resources"

# Verify quotas not exceeded
kubectl describe resourcequota -A | grep -B 2 "exceeded"

# Check pod health
kubectl get pods -A -o custom-columns=\
NAMESPACE:.metadata.namespace,\
NAME:.metadata.name,\
READY:.status.conditions[?(@.type==\"Ready\")].status
```

### Cleanup Commands

```bash
# Delete specific environment
kubectl delete namespace development

# Delete all test namespaces
kubectl delete namespace development staging production

# Force delete stuck namespace
kubectl delete namespace <namespace> --grace-period=0 --force

# Remove labels from nodes
kubectl label nodes --all environment- tier- zone-

# Delete all in namespace
kubectl delete all --all -n development
```

### Useful One-Liners

```bash
# Total pods per environment
kubectl get pods -A --no-headers | awk '{print $1}' | sort | uniq -c

# Total CPU requests per environment
for ns in development staging production; do
  echo "$ns: $(kubectl get pods -n $ns -o json | \
    jq -r '.items[].spec.containers[].resources.requests.cpu' | \
    grep -v null | sed 's/m//' | awk '{s+=$1} END {print s}')m"
done

# Find pods without resource limits
kubectl get pods -A -o json | \
  jq -r '.items[] | select(.spec.containers[].resources.limits == null) | .metadata.name'

# Check HPA targets
kubectl get hpa -A -o custom-columns=\
NAMESPACE:.metadata.namespace,\
NAME:.metadata.name,\
MIN:.spec.minReplicas,\
MAX:.spec.maxReplicas,\
CURRENT:.status.currentReplicas
```

---

## Quick Reference Table

| Task | Command |
|------|---------|
| Deploy to dev | `kubectl apply -f file.yaml -n development` |
| Deploy to prod | `kubectl apply -f file.yaml -n production` |
| Check quota | `kubectl describe resourcequota -n <ns>` |
| View QoS | `kubectl get pod <pod> -o jsonpath='{.status.qosClass}'` |
| Scale | `kubectl scale deployment <n> --replicas=5 -n <ns>` |
| Top pods | `kubectl top pods -n <ns>` |
| Check HPA | `kubectl get hpa -n <ns>` |
| Pod logs | `kubectl logs <pod> -n <ns>` |

---

This cheatsheet covers all essential multi-environment management commands!
