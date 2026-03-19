# 📋 Command Cheatsheet: Security Capstone - Day 69-70

## 🚀 Quick Deploy
```bash
# Deploy complete application
kubectl apply -f secureshop-complete-Day69-70.yaml

# Check status
kubectl get all -n secureshop
```

## 🔐 RBAC Commands
```bash
# Test ServiceAccount permissions
kubectl auth can-i get secrets \
  --as=system:serviceaccount:secureshop:backend-sa \
  -n secureshop

# List all RBAC
kubectl get sa,roles,rolebindings -n secureshop
```

## 🛡️ Network Policy Commands
```bash
# List policies
kubectl get networkpolicies -n secureshop

# Test connectivity
kubectl exec -n secureshop <frontend-pod> -- \
  curl http://backend:8080

# Should timeout (blocked)
kubectl exec -n secureshop <frontend-pod> -- \
  timeout 3 nc -zv database 5432
```

## 🔍 Security Validation
```bash
# Check all pods non-root
kubectl get pods -n secureshop -o json | \
  jq -r '.items[] | "\(.metadata.name): UID=\(.spec.securityContext.runAsUser)"'

# Verify Pod Security Standards
kubectl get namespace secureshop -o yaml | grep pod-security

# Check capabilities
kubectl get pods -n secureshop -o json | \
  jq -r '.items[].spec.containers[].securityContext.capabilities'
```

## 📊 Monitoring
```bash
# Get pod status
kubectl get pods -n secureshop -o wide

# View logs
kubectl logs -n secureshop -l tier=backend --tail=50

# Describe pod
kubectl describe pod -n secureshop <pod-name>
```
