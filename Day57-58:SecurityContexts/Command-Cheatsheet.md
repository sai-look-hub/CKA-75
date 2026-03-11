# 📋 Command Cheatsheet: Security Contexts

## 🔍 Viewing Security Contexts

```bash
# View pod security context
kubectl get pod <pod> -o jsonpath='{.spec.securityContext}' | jq

# View container security context
kubectl get pod <pod> -o jsonpath='{.spec.containers[0].securityContext}' | jq

# Check user/group
kubectl exec <pod> -- id

# Check capabilities
kubectl exec <pod> -- capsh --print

# Check filesystem permissions
kubectl exec <pod> -- ls -ld /path
```

## 👤 Testing User/Group

```bash
# Run as specific user
kubectl run test --image=nginx --dry-run=client -o yaml | \
  sed '/spec:/a\  securityContext:\n    runAsUser: 1000' | \
  kubectl apply -f -

# Check user
kubectl exec test -- id

# Cleanup
kubectl delete pod test
```

## 📁 Testing Filesystem

```bash
# Test read-only filesystem
kubectl run readonly --image=nginx --dry-run=client -o yaml | \
  sed '/image: nginx/a\    securityContext:\n      readOnlyRootFilesystem: true' | \
  kubectl apply -f -

# Try to write
kubectl exec readonly -- touch /test
# Should fail

kubectl delete pod readonly
```

## 🎩 Testing Capabilities

```bash
# Drop all capabilities
kubectl run no-caps --image=nginx --overrides='
{
  "spec": {
    "containers": [{
      "name": "nginx",
      "image": "nginx",
      "securityContext": {
        "capabilities": {
          "drop": ["ALL"]
        }
      }
    }]
  }
}'

# Check capabilities
kubectl exec no-caps -- capsh --print

kubectl delete pod no-caps
```

## 🔐 Auditing Security

```bash
# Find pods running as root
kubectl get pods -A -o json | \
  jq -r '.items[] | select(.spec.securityContext.runAsUser == 0 or .spec.securityContext.runAsUser == null) | "\(.metadata.namespace)/\(.metadata.name)"'

# Find pods without security contexts
kubectl get pods -A -o json | \
  jq -r '.items[] | select(.spec.securityContext == null) | "\(.metadata.namespace)/\(.metadata.name)"'

# Find privileged containers
kubectl get pods -A -o json | \
  jq -r '.items[] | select(.spec.containers[].securityContext.privileged == true) | "\(.metadata.namespace)/\(.metadata.name)"'

# Check specific security settings
kubectl get pods -A -o json | \
  jq -r '.items[] | {name: .metadata.name, user: .spec.securityContext.runAsUser, nonRoot: .spec.securityContext.runAsNonRoot}'
```

## 💡 Quick One-Liners

```bash
# Create pod with all security features
kubectl run secure --image=nginx --dry-run=client -o yaml > secure.yaml
# Edit to add security contexts
kubectl apply -f secure.yaml

# Check if running as root
kubectl exec <pod> -- whoami

# Test privilege escalation
kubectl exec <pod> -- grep NoNewPrivs /proc/1/status
```
