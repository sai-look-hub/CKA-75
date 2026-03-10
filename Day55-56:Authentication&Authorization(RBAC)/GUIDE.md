# 📖 GUIDEME: RBAC - Complete Walkthrough

## 🎯 16-Hour Learning Path

**Day 1:** Service accounts, basic RBAC (8 hours)
**Day 2:** Advanced patterns, testing, audit (8 hours)

---

## Phase 1: Service Accounts (2 hours)

### Step 1: Explore Default ServiceAccount
```bash
# Check default SA
kubectl get serviceaccount default -o yaml

# See token secret
kubectl get secrets

# Create test pod
kubectl run test-default --image=nginx

# Check SA in pod
kubectl get pod test-default -o jsonpath='{.spec.serviceAccountName}'

# See mounted token
kubectl exec test-default -- ls /var/run/secrets/kubernetes.io/serviceaccount/
```

### Step 2: Create Custom ServiceAccount
```bash
kubectl create serviceaccount my-app-sa

# View it
kubectl describe serviceaccount my-app-sa

# Use in pod
kubectl run test-custom --image=nginx --serviceaccount=my-app-sa

# Verify
kubectl get pod test-custom -o jsonpath='{.spec.serviceAccountName}'
```

**✅ Checkpoint:** ServiceAccounts created and used.

---

## Phase 2: Basic RBAC (3 hours)

### Step 1: Create Read-Only Role
```bash
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: default
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]
EOF

kubectl describe role pod-reader
```

### Step 2: Create RoleBinding
```bash
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-pods
  namespace: default
subjects:
- kind: ServiceAccount
  name: my-app-sa
  namespace: default
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
EOF

kubectl describe rolebinding read-pods
```

### Step 3: Test Permissions
```bash
# Test as ServiceAccount
kubectl auth can-i list pods \
  --as=system:serviceaccount:default:my-app-sa
# Should return: yes

kubectl auth can-i create pods \
  --as=system:serviceaccount:default:my-app-sa
# Should return: no

kubectl auth can-i delete pods \
  --as=system:serviceaccount:default:my-app-sa
# Should return: no
```

**✅ Checkpoint:** Basic RBAC working.

---

## Phase 3: Namespace-Scoped Permissions (2 hours)

### Create Test Environments
```bash
kubectl create namespace dev
kubectl create namespace prod

# Create SA in each
kubectl create serviceaccount app-sa -n dev
kubectl create serviceaccount app-sa -n prod
```

### Dev: Full Access
```bash
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: dev-full-access
  namespace: dev
rules:
- apiGroups: ["", "apps"]
  resources: ["*"]
  verbs: ["*"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: dev-access
  namespace: dev
subjects:
- kind: ServiceAccount
  name: app-sa
  namespace: dev
roleRef:
  kind: Role
  name: dev-full-access
  apiGroup: rbac.authorization.k8s.io
EOF
```

### Prod: Read-Only
```bash
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: prod-readonly
  namespace: prod
rules:
- apiGroups: ["", "apps"]
  resources: ["*"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: prod-access
  namespace: prod
subjects:
- kind: ServiceAccount
  name: app-sa
  namespace: prod
roleRef:
  kind: Role
  name: prod-readonly
  apiGroup: rbac.authorization.k8s.io
EOF
```

### Test Isolation
```bash
# Dev SA can create in dev
kubectl auth can-i create deployments -n dev \
  --as=system:serviceaccount:dev:app-sa
# yes

# Dev SA cannot create in prod
kubectl auth can-i create deployments -n prod \
  --as=system:serviceaccount:dev:app-sa
# no

# Prod SA can read in prod
kubectl auth can-i list deployments -n prod \
  --as=system:serviceaccount:prod:app-sa
# yes

# Prod SA cannot delete in prod
kubectl auth can-i delete deployments -n prod \
  --as=system:serviceaccount:prod:app-sa
# no
```

**✅ Checkpoint:** Namespace isolation working.

---

## Phase 4: ClusterRoles (2 hours)

### Create Node Reader ClusterRole
```bash
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: node-reader
rules:
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["get", "list", "watch"]
EOF
```

### Bind to ServiceAccount
```bash
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: node-reader-binding
subjects:
- kind: ServiceAccount
  name: app-sa
  namespace: dev
roleRef:
  kind: ClusterRole
  name: node-reader
  apiGroup: rbac.authorization.k8s.io
EOF
```

### Test
```bash
# Can read nodes
kubectl auth can-i list nodes \
  --as=system:serviceaccount:dev:app-sa
# yes

# Cannot delete nodes
kubectl auth can-i delete nodes \
  --as=system:serviceaccount:dev:app-sa
# no
```

**✅ Checkpoint:** ClusterRole permissions working.

---

## Phase 5: Real-World Scenarios (3 hours)

### Scenario 1: Deployment Manager
```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: deployment-manager
  namespace: prod
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: manage-deployments
  namespace: prod
rules:
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: [""]
  resources: ["pods", "pods/log"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: deployment-manager-binding
  namespace: prod
subjects:
- kind: ServiceAccount
  name: deployment-manager
  namespace: prod
roleRef:
  kind: Role
  name: manage-deployments
  apiGroup: rbac.authorization.k8s.io
EOF
```

### Test Deployment Manager
```bash
# Can manage deployments
kubectl auth can-i create deployments -n prod \
  --as=system:serviceaccount:prod:deployment-manager
# yes

# Can view pods
kubectl auth can-i list pods -n prod \
  --as=system:serviceaccount:prod:deployment-manager
# yes

# Cannot manage services
kubectl auth can-i create services -n prod \
  --as=system:serviceaccount:prod:deployment-manager
# no
```

### Scenario 2: Secret Reader
```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: secret-reader
  namespace: prod
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: read-secrets
  namespace: prod
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: secret-reader-binding
  namespace: prod
subjects:
- kind: ServiceAccount
  name: secret-reader
  namespace: prod
roleRef:
  kind: Role
  name: read-secrets
  apiGroup: rbac.authorization.k8s.io
EOF
```

**✅ Checkpoint:** Real scenarios implemented.

---

## Phase 6: Testing & Validation (2 hours)

### Create Test Pod with SA
```bash
# Create deployment with custom SA
kubectl create deployment test-app -n prod --image=nginx
kubectl set serviceaccount deployment test-app deployment-manager -n prod

# Get pod
POD=$(kubectl get pod -n prod -l app=test-app -o jsonpath='{.items[0].metadata.name}')

# Test from inside pod
kubectl exec -n prod $POD -- sh -c "
  TOKEN=\$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
  curl -s https://kubernetes.default.svc/api/v1/namespaces/prod/deployments \
    --cacert /var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
    --header \"Authorization: Bearer \$TOKEN\" | grep -o '\"name\"'
"
```

### Comprehensive Test Script
```bash
cat > test-rbac.sh << 'SCRIPT'
#!/bin/bash
echo "=== RBAC Testing ==="

echo "1. Testing pod-reader..."
kubectl auth can-i list pods --as=system:serviceaccount:default:my-app-sa && echo "✅ Can list pods" || echo "❌ Cannot list pods"
kubectl auth can-i create pods --as=system:serviceaccount:default:my-app-sa && echo "❌ SHOULD NOT create pods" || echo "✅ Correctly denied create"

echo "2. Testing deployment-manager..."
kubectl auth can-i create deployments -n prod --as=system:serviceaccount:prod:deployment-manager && echo "✅ Can create deployments" || echo "❌ Cannot create deployments"
kubectl auth can-i delete services -n prod --as=system:serviceaccount:prod:deployment-manager && echo "❌ SHOULD NOT delete services" || echo "✅ Correctly denied"

echo "3. Testing node-reader..."
kubectl auth can-i list nodes --as=system:serviceaccount:dev:app-sa && echo "✅ Can list nodes" || echo "❌ Cannot list nodes"

echo "=== All Tests Complete ==="
SCRIPT

chmod +x test-rbac.sh
./test-rbac.sh
```

**✅ Checkpoint:** All permissions tested.

---

## Phase 7: Audit & Security (2 hours)

### Audit Existing RBAC
```bash
# List all ServiceAccounts
kubectl get serviceaccounts -A

# List all Roles
kubectl get roles -A

# List all RoleBindings
kubectl get rolebindings -A

# List all ClusterRoles
kubectl get clusterroles

# List all ClusterRoleBindings
kubectl get clusterrolebindings

# Find cluster-admin users
kubectl get clusterrolebindings -o json | \
  jq -r '.items[] | select(.roleRef.name=="cluster-admin") | 
    "ClusterRoleBinding: \(.metadata.name), Subject: \(.subjects[].name)"'
```

### Check Permissions for All SAs
```bash
for sa in $(kubectl get sa -o name); do
  echo "=== $sa ==="
  kubectl auth can-i --list --as=system:serviceaccount:default:${sa#serviceaccount/}
done
```

**✅ Checkpoint:** Security audit complete.

---

## ✅ Final Validation

### Checklist
- [ ] Created custom ServiceAccounts
- [ ] Created Roles with specific permissions
- [ ] Created RoleBindings
- [ ] Tested with `can-i` command
- [ ] Created ClusterRole
- [ ] Created ClusterRoleBinding
- [ ] Tested namespace isolation
- [ ] Implemented real-world scenarios
- [ ] Tested from pod with ServiceAccount
- [ ] Audited existing RBAC

### Clean Up (Optional)
```bash
kubectl delete namespace dev prod
kubectl delete serviceaccount my-app-sa
kubectl delete role pod-reader
kubectl delete rolebinding read-pods
kubectl delete clusterrole node-reader
kubectl delete clusterrolebinding node-reader-binding
```

---

**Congratulations! You've mastered Kubernetes RBAC! 🔒🚀**
