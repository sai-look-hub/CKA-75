# 📋 Command Cheatsheet: Network Security & Zero-Trust

## 🛡️ Network Policy Commands

```bash
# List network policies
kubectl get networkpolicies -n <namespace>
kubectl get netpol -n <namespace>

# Describe network policy
kubectl describe networkpolicy <policy> -n <namespace>

# Test connectivity
kubectl exec <pod> -n <namespace> -- curl http://<service>
kubectl exec <pod> -n <namespace> -- nc -zv <host> <port>

# Delete network policy
kubectl delete networkpolicy <policy> -n <namespace>
```

## 🔒 Istio mTLS Commands

```bash
# Check mTLS status
istioctl authn tls-check -n <namespace>

# Verify peer authentication
kubectl get peerauthentication -n <namespace>

# Check certificate
kubectl exec <pod> -c istio-proxy -- \
  openssl s_client -showcerts -connect <service>:80

# View Envoy config
istioctl proxy-config all <pod> -n <namespace>
```

## 🎯 Authorization Policy Commands

```bash
# List authorization policies
kubectl get authorizationpolicies -n <namespace>

# Describe policy
kubectl describe authorizationpolicy <policy> -n <namespace>

# Test with specific SA
kubectl exec <pod> --as=system:serviceaccount:<ns>:<sa> -- \
  curl http://<service>
```

## 📊 Istio Observability

```bash
# Dashboard commands
istioctl dashboard kiali
istioctl dashboard grafana
istioctl dashboard jaeger
istioctl dashboard prometheus

# Check proxy status
istioctl proxy-status

# Get logs
kubectl logs <pod> -c istio-proxy -n <namespace>
```

## 🔍 Debugging

```bash
# Check sidecar injection
kubectl get pods -n <namespace> -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].name}{"\n"}{end}'

# Verify namespace labeling
kubectl get namespace <namespace> --show-labels

# Test mTLS with verbose
kubectl exec <pod> -c istio-proxy -- \
  curl -v https://<service>:80

# Check Envoy stats
kubectl exec <pod> -c istio-proxy -- \
  curl -s localhost:15000/stats | grep ssl
```

## 💡 Useful One-Liners

```bash
# Enable sidecar injection for namespace
kubectl label namespace <namespace> istio-injection=enabled

# Restart pods to inject sidecars
kubectl rollout restart deployment -n <namespace>

# Check all mTLS connections
for ns in $(kubectl get ns -o name | cut -d/ -f2); do
  echo "=== $ns ==="
  istioctl authn tls-check -n $ns 2>/dev/null
done

# Find pods without sidecars
kubectl get pods -A -o json | \
  jq -r '.items[] | select(.spec.containers | length == 1) | "\(.metadata.namespace)/\(.metadata.name)"'
```
