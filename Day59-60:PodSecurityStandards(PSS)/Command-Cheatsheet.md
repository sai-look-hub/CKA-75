# 📋 Command Cheatsheet: Pod Security Standards

## 🏷️ Namespace Label Management

```bash
# Label namespace with enforce
kubectl label namespace <ns> \
  pod-security.kubernetes.io/enforce=<profile>

# Label with all three modes
kubectl label namespace <ns> \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/audit=restricted \
  pod-security.kubernetes.io/warn=restricted

# Remove label
kubectl label namespace <ns> \
  pod-security.kubernetes.io/enforce-

# Update label
kubectl label namespace <ns> \
  pod-security.kubernetes.io/enforce=baseline --overwrite
```

## 🔍 Viewing PSS Configuration

```bash
# View namespace labels
kubectl get namespace <ns> --show-labels

# Get PSS labels only
kubectl get namespace <ns> -o json | \
  jq '.metadata.labels | with_entries(select(.key | contains("pod-security")))'

# List all namespaces with PSS
kubectl get namespaces -o json | \
  jq -r '.items[] | "\(.metadata.name): \(.metadata.labels["pod-security.kubernetes.io/enforce"] // "none")"'
```

## 🧪 Testing Compliance

```bash
# Dry run to test pod compliance
kubectl run test --image=nginx --dry-run=server -n <ns>

# Check if pod would be admitted
kubectl apply --dry-run=server -f pod.yaml -n <ns>

# View warnings
kubectl run test --image=nginx -n <ns>
# Check output for warnings
```

## 📊 Auditing

```bash
# Find namespaces without PSS
kubectl get namespaces -o json | \
  jq -r '.items[] | select(.metadata.labels["pod-security.kubernetes.io/enforce"] == null) | .metadata.name'

# Find all privileged namespaces
kubectl get namespaces -l pod-security.kubernetes.io/enforce=privileged

# Find all restricted namespaces
kubectl get namespaces -l pod-security.kubernetes.io/enforce=restricted

# Find all baseline namespaces
kubectl get namespaces -l pod-security.kubernetes.io/enforce=baseline
```

## 🔧 Creating Compliant Resources

```bash
# Create restricted-compliant deployment
kubectl create deployment secure-app --image=nginx:1.21 -n <ns> \
  --dry-run=client -o yaml > deployment.yaml

# Then edit to add security contexts
# Apply:
kubectl apply -f deployment.yaml
```

## 💡 Useful One-Liners

```bash
# Set all modes at once
for mode in enforce audit warn; do
  kubectl label namespace <ns> \
    pod-security.kubernetes.io/$mode=restricted --overwrite
done

# Audit all namespaces
kubectl get ns -o json | \
  jq -r '.items[] | {
    name: .metadata.name,
    enforce: .metadata.labels["pod-security.kubernetes.io/enforce"],
    audit: .metadata.labels["pod-security.kubernetes.io/audit"],
    warn: .metadata.labels["pod-security.kubernetes.io/warn"]
  }'

# Check pod compliance
kubectl get pods -n <ns> -o json | \
  jq -r '.items[] | "\(.metadata.name): 
    runAsNonRoot=\(.spec.securityContext.runAsNonRoot // false)"'
```
