# 📖 GUIDEME: Secrets Management - Complete Walkthrough

## 🎯 16-Hour Learning Path

**Day 1:** K8s Secrets, Sealed Secrets (8 hours)
**Day 2:** External Secrets, production setup (8 hours)

---

## Phase 1: Understanding K8s Secrets (1 hour)

### Create and Examine Secrets
```bash
# Create secret from literal
kubectl create secret generic db-credentials \
  --from-literal=username=admin \
  --from-literal=password=password123

# View secret (base64 encoded)
kubectl get secret db-credentials -o yaml

# Decode password
kubectl get secret db-credentials -o jsonpath='{.data.password}' | base64 -d
# Output: password123 (NOT SECURE!)

# Use in pod
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: secret-test
spec:
  containers:
  - name: app
    image: busybox
    command: ['sh', '-c', 'echo "Password: \$DB_PASSWORD" && sleep 3600']
    env:
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: db-credentials
          key: password
EOF

# Check logs
kubectl logs secret-test
# See password in logs (BAD PRACTICE!)

kubectl delete pod secret-test
kubectl delete secret db-credentials
```

**✅ Checkpoint:** Understand K8s Secrets limitations.

---

## Phase 2: Sealed Secrets (3 hours)

### Step 1: Install Sealed Secrets Controller
```bash
# Install controller
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml

# Verify installation
kubectl get pods -n kube-system -l name=sealed-secrets-controller

# Install kubeseal CLI
wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/kubeseal-0.24.0-linux-amd64.tar.gz
tar -xvzf kubeseal-0.24.0-linux-amd64.tar.gz
sudo install -m 755 kubeseal /usr/local/bin/kubeseal
```

### Step 2: Create and Seal Secret
```bash
# Create regular secret (DON'T commit this!)
cat > secret.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: sealed-db-creds
  namespace: default
stringData:
  username: admin
  password: supersecret123
EOF

# Seal it
kubeseal -f secret.yaml -w sealed-secret.yaml

# View sealed secret
cat sealed-secret.yaml
# Encrypted! Safe for Git

# Apply sealed secret
kubectl apply -f sealed-secret.yaml

# Controller creates actual secret
kubectl get secret sealed-db-creds

# Verify it works
kubectl get secret sealed-db-creds -o jsonpath='{.data.password}' | base64 -d
# Output: supersecret123

# Clean up
rm secret.yaml  # Delete plaintext!
```

### Step 3: Test GitOps Workflow
```bash
# Sealed secret can be committed to Git
git init test-gitops
cd test-gitops
cp ../sealed-secret.yaml .
git add sealed-secret.yaml
git commit -m "Add database credentials (sealed)"
# Safe! ✅

# To update:
# 1. Create new secret
# 2. Seal it
# 3. Commit sealed version
# 4. Apply to cluster
```

**✅ Checkpoint:** Sealed Secrets working, safe for Git.

---

## Phase 3: External Secrets Operator (4 hours)

### Step 1: Install External Secrets Operator
```bash
# Add Helm repo
helm repo add external-secrets https://charts.external-secrets.io
helm repo update

# Install operator
helm install external-secrets \
  external-secrets/external-secrets \
  -n external-secrets-system \
  --create-namespace

# Verify
kubectl get pods -n external-secrets-system
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=external-secrets \
  -n external-secrets-system --timeout=300s
```

### Step 2: Set Up Fake Secret Store (for testing)
```bash
# Create namespace
kubectl create namespace external-secrets-demo

# For demo, use K8s Secret as "external" store
kubectl create secret generic external-store \
  -n external-secrets-demo \
  --from-literal=db-username=admin \
  --from-literal=db-password=external-password123

# Create SecretStore
kubectl apply -f - <<EOF
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: demo-secretstore
  namespace: external-secrets-demo
spec:
  provider:
    kubernetes:
      remoteNamespace: external-secrets-demo
      server:
        caProvider:
          type: ConfigMap
          name: kube-root-ca.crt
          key: ca.crt
      auth:
        serviceAccount:
          name: default
EOF

# Verify SecretStore
kubectl get secretstore -n external-secrets-demo
```

### Step 3: Create ExternalSecret
```bash
kubectl apply -f - <<EOF
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: demo-external-secret
  namespace: external-secrets-demo
spec:
  refreshInterval: 1m
  secretStoreRef:
    name: demo-secretstore
    kind: SecretStore
  target:
    name: synced-secret
    creationPolicy: Owner
  data:
  - secretKey: username
    remoteRef:
      key: external-store
      property: db-username
  - secretKey: password
    remoteRef:
      key: external-store
      property: db-password
EOF

# Verify ExternalSecret
kubectl get externalsecret -n external-secrets-demo

# Check created secret
kubectl get secret synced-secret -n external-secrets-demo

# Verify data
kubectl get secret synced-secret -n external-secrets-demo \
  -o jsonpath='{.data.password}' | base64 -d
# Output: external-password123
```

### Step 4: Test Automatic Sync
```bash
# Update "external" secret
kubectl patch secret external-store -n external-secrets-demo \
  --type='json' -p='[{"op": "replace", "path": "/data/db-password", "value":"'$(echo -n "newpassword456" | base64)'"}]'

# Wait 1 minute (refreshInterval)
sleep 65

# Check synced secret updated
kubectl get secret synced-secret -n external-secrets-demo \
  -o jsonpath='{.data.password}' | base64 -d
# Output: newpassword456 (updated!)
```

**✅ Checkpoint:** External Secrets Operator working.

---

## Phase 4: Production Patterns (3 hours)

### Pattern 1: Multiple Secrets from One Store
```bash
kubectl apply -f - <<EOF
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: app-secrets
  namespace: external-secrets-demo
spec:
  refreshInterval: 5m
  secretStoreRef:
    name: demo-secretstore
  target:
    name: app-all-secrets
  dataFrom:
  - extract:
      key: external-store
EOF

# All keys from external-store synced
kubectl get secret app-all-secrets -n external-secrets-demo -o yaml
```

### Pattern 2: ClusterSecretStore (for multiple namespaces)
```bash
kubectl apply -f - <<EOF
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: global-secretstore
spec:
  provider:
    kubernetes:
      remoteNamespace: external-secrets-demo
      server:
        caProvider:
          type: ConfigMap
          name: kube-root-ca.crt
          key: ca.crt
          namespace: kube-system
      auth:
        serviceAccount:
          name: default
          namespace: external-secrets-demo
EOF

# Use in any namespace
kubectl create namespace team-a
kubectl apply -f - <<EOF
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: team-secret
  namespace: team-a
spec:
  secretStoreRef:
    name: global-secretstore
    kind: ClusterSecretStore
  target:
    name: team-secret
  data:
  - secretKey: password
    remoteRef:
      key: external-store
      property: db-password
EOF
```

**✅ Checkpoint:** Production patterns implemented.

---

## Phase 5: Secret Rotation (2 hours)

### Automatic Rotation with Reloader
```bash
# Install Reloader
kubectl apply -f https://raw.githubusercontent.com/stakater/Reloader/master/deployments/kubernetes/reloader.yaml

# Create deployment with auto-reload
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-with-reload
  namespace: external-secrets-demo
  annotations:
    reloader.stakater.com/auto: "true"
spec:
  replicas: 2
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: app
        image: nginx
        env:
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: synced-secret
              key: password
EOF

# Watch pods
kubectl get pods -n external-secrets-demo -l app=myapp -w &

# Update secret
kubectl patch secret external-store -n external-secrets-demo \
  --type='json' -p='[{"op": "replace", "path": "/data/db-password", "value":"'$(echo -n "rotated-password" | base64)'"}]'

# Wait for sync (1 min) + Reloader detects change
# Pods automatically restart with new password!
```

**✅ Checkpoint:** Automatic secret rotation working.

---

## Phase 6: Security Audit (3 hours)

### Audit Secret Access
```bash
# Create audit script
cat > audit-secrets.sh <<'SCRIPT'
#!/bin/bash
echo "=== Secrets Management Audit ==="

echo -e "\n1. All Secrets:"
kubectl get secrets -A --no-headers | wc -l

echo -e "\n2. Secrets without encryption at rest:"
echo "Check etcd encryption configuration"

echo -e "\n3. Sealed Secrets:"
kubectl get sealedsecrets -A 2>/dev/null || echo "Sealed Secrets not installed"

echo -e "\n4. External Secrets:"
kubectl get externalsecrets -A 2>/dev/null || echo "External Secrets not installed"

echo -e "\n5. SecretStores:"
kubectl get secretstores -A 2>/dev/null
kubectl get clustersecretstores 2>/dev/null

echo -e "\n6. RBAC - Who can read secrets:"
kubectl get rolebindings,clusterrolebindings -A -o json | \
  jq -r '.items[] | select(.roleRef.name | contains("secret")) | 
    "\(.metadata.namespace)/\(.metadata.name): \(.subjects[].name)"' | head -10

echo -e "\n=== Audit Complete ==="
SCRIPT

chmod +x audit-secrets.sh
./audit-secrets.sh
```

**✅ Checkpoint:** Security audit complete.

---

## ✅ Final Validation

### Checklist
- [ ] Understand K8s Secrets are base64 (not encrypted)
- [ ] Installed Sealed Secrets Controller
- [ ] Created and sealed secrets
- [ ] Sealed secrets safe for Git
- [ ] Installed External Secrets Operator
- [ ] Created SecretStore
- [ ] Created ExternalSecret
- [ ] Secrets auto-sync working
- [ ] Implemented secret rotation
- [ ] Deployed with auto-reload
- [ ] Completed security audit

---

**Congratulations! You've mastered Secrets Management! 🔒🚀**
