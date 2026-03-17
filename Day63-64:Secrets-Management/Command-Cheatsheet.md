# 📋 Command Cheatsheet: Secrets Management

## 🔐 Basic Secret Commands

```bash
# Create secret from literal
kubectl create secret generic <name> \
  --from-literal=key=value

# Create secret from file
kubectl create secret generic <name> \
  --from-file=ssh-key=~/.ssh/id_rsa

# View secret
kubectl get secret <name> -o yaml

# Decode secret
kubectl get secret <name> -o jsonpath='{.data.password}' | base64 -d

# Delete secret
kubectl delete secret <name>
```

## 🔏 Sealed Secrets

```bash
# Install controller
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml

# Seal a secret
kubeseal -f secret.yaml -w sealed-secret.yaml

# Seal with scope
kubeseal --scope namespace-wide -f secret.yaml
kubeseal --scope cluster-wide -f secret.yaml

# Get public key
kubeseal --fetch-cert > pub-cert.pem

# Apply sealed secret
kubectl apply -f sealed-secret.yaml

# View sealed secret
kubectl get sealedsecrets
```

## 🗝️ External Secrets

```bash
# Install operator (Helm)
helm install external-secrets \
  external-secrets/external-secrets \
  -n external-secrets-system \
  --create-namespace

# Create SecretStore
kubectl apply -f secretstore.yaml

# Create ExternalSecret
kubectl apply -f externalsecret.yaml

# View external secrets
kubectl get externalsecrets -A
kubectl get secretstores -A
kubectl get clustersecretstores

# Check sync status
kubectl describe externalsecret <name>
```

## 🔄 Secret Rotation

```bash
# Update secret
kubectl create secret generic <name> \
  --from-literal=password=newpass \
  --dry-run=client -o yaml | kubectl apply -f -

# Restart deployment (to pick up new secret)
kubectl rollout restart deployment <name>

# Install Reloader (auto-restart)
kubectl apply -f https://raw.githubusercontent.com/stakater/Reloader/master/deployments/kubernetes/reloader.yaml

# Use Reloader annotation
kubectl annotate deployment <name> \
  reloader.stakater.com/auto="true"
```

## 🔍 Auditing

```bash
# List all secrets
kubectl get secrets -A

# Find secrets without labels
kubectl get secrets -A -o json | \
  jq -r '.items[] | select(.metadata.labels == null) | 
    "\(.metadata.namespace)/\(.metadata.name)"'

# Check who can read secrets
kubectl auth can-i get secrets --as=<user>

# View secret access in RBAC
kubectl get rolebindings,clusterrolebindings -A -o json | \
  jq -r '.items[] | select(.roleRef.name | contains("secret"))'
```

## 💡 Useful One-Liners

```bash
# Generate random password
openssl rand -base64 32

# Create secret from env file
kubectl create secret generic app-config --from-env-file=.env

# Copy secret to another namespace
kubectl get secret <name> -n <ns1> -o yaml | \
  sed 's/namespace: .*/namespace: <ns2>/' | \
  kubectl apply -f -

# Backup all secrets
kubectl get secrets -A -o yaml > secrets-backup.yaml

# Find secrets older than 90 days
kubectl get secrets -A -o json | \
  jq -r '.items[] | select((.metadata.creationTimestamp | 
    fromdateiso8601) < (now - 7776000)) | 
    "\(.metadata.namespace)/\(.metadata.name)"'
```
