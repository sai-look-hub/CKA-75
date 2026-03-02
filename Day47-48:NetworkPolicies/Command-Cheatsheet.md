# 📋 Command Cheatsheet: Network Policies

## 🔍 Network Policy Operations

```bash
# List all network policies
kubectl get networkpolicy -A
kubectl get netpol -A

# Describe network policy
kubectl describe networkpolicy <policy-name>

# Get policy in YAML
kubectl get netpol <policy-name> -o yaml

# Delete network policy
kubectl delete networkpolicy <policy-name>
```

## 📝 Quick Creation

```bash
# Deny all ingress
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-ingress
spec:
  podSelector: {}
  policyTypes:
  - Ingress
EOF

# Deny all egress
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-egress
spec:
  podSelector: {}
  policyTypes:
  - Egress
EOF
```

## 🧪 Testing Connectivity

```bash
# Get pod IP
POD_IP=$(kubectl get pod <pod> -o jsonpath='{.status.podIP}')

# Test connectivity
kubectl exec <source-pod> -- curl -s $POD_IP
kubectl exec <source-pod> -- nc -zv $POD_IP <port>

# Test with timeout
kubectl exec <source-pod> -- timeout 5 curl $POD_IP

# Test DNS
kubectl exec <pod> -- nslookup kubernetes.default
```

## 💡 Useful One-Liners

```bash
# Count policies per namespace
kubectl get netpol -A --no-headers | awk '{print $1}' | sort | uniq -c

# Find pods without network policies
kubectl get pods -A -o json | jq -r '.items[] | select(.metadata.labels | length > 0) | "\(.metadata.namespace)/\(.metadata.name)"'

# Check if policy affects pod
kubectl describe netpol <policy> | grep -A5 "Pod selector"
```
