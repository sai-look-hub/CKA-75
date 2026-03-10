# 🎤 Interview Q&A: RBAC

## Q1: Explain the difference between authentication and authorization in Kubernetes.

**Answer:**

**Authentication (AuthN):** "Who are you?"
- Verifies identity
- Methods: Certificates, tokens, OIDC
- Results in User or ServiceAccount identity

**Authorization (AuthZ):** "What can you do?"
- Checks permissions
- Method: RBAC (most common)
- Results in Allow/Deny

**Flow:**
```
1. User/SA → Authenticates → Identity established
2. Makes request → Authorization check → RBAC
3. RBAC checks Roles/RoleBindings → Allow/Deny
```

**Example:**
```bash
# Authentication
User: jane (via certificate)

# Authorization
Can jane create pods in production?
→ Check Roles/RoleBindings
→ If match: Allow
→ If no match: Deny
```

---

## Q2: What are the main components of RBAC?

**Answer:**

**Four main components:**

**1. Role (namespace-scoped)**
- Defines permissions
- Resources and verbs
- Example: "get, list, watch pods"

**2. RoleBinding (namespace-scoped)**
- Grants Role to subjects
- Links Who → What permissions
- Subjects: User, Group, ServiceAccount

**3. ClusterRole (cluster-wide)**
- Like Role but cluster-scoped
- For nodes, namespaces, non-resource URLs
- Can be bound namespace or cluster-wide

**4. ClusterRoleBinding (cluster-wide)**
- Grants ClusterRole cluster-wide
- For cluster resources

**Example:**
```yaml
Role: pod-reader (can list pods)
    ↓
RoleBinding: Grants pod-reader to SA
    ↓
ServiceAccount: my-app-sa can now list pods
```

---

## Q3: How do ServiceAccounts work?

**Answer:**

**ServiceAccounts:** Kubernetes identities for pods.

**Key points:**
- Namespace-scoped
- Auto-created: `default` in each namespace
- Token mounted in pod at `/var/run/secrets/kubernetes.io/serviceaccount/`

**How it works:**
```yaml
# 1. Create SA
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-app-sa

# 2. Use in pod
spec:
  serviceAccountName: my-app-sa

# 3. Token automatically mounted
# 4. Pod uses token to authenticate with API
```

**Inside pod:**
```bash
# Token
cat /var/run/secrets/kubernetes.io/serviceaccount/token

# Use in API calls
curl -H "Authorization: Bearer $TOKEN" \
  https://kubernetes.default.svc/api/v1/pods
```

---

## Q4: What's the difference between Role and ClusterRole?

**Answer:**

**Role:**
- Namespace-scoped
- Permissions within one namespace
- Can't access cluster resources (nodes)

```yaml
kind: Role
metadata:
  namespace: production  # Required
rules:
- resources: ["pods"]
  verbs: ["get", "list"]
```

**ClusterRole:**
- Cluster-scoped
- Permissions cluster-wide OR in all namespaces
- Required for cluster resources

```yaml
kind: ClusterRole
# No namespace
rules:
- resources: ["nodes"]  # Cluster resource
  verbs: ["get", "list"]
```

**When to use:**
- Role: Namespace-specific permissions
- ClusterRole: Cluster resources OR reusable across namespaces

**Note:** ClusterRole can be bound with RoleBinding (grants in one namespace) or ClusterRoleBinding (grants cluster-wide)

---

## Q5: How do you implement least privilege with RBAC?

**Answer:**

**Principle:** Grant minimum permissions needed.

**Steps:**

**1. Start with no permissions**
- Don't use default SA
- Create dedicated SA

**2. Grant specific resources**
```yaml
# BAD
resources: ["*"]

# GOOD
resources: ["pods", "configmaps"]
```

**3. Grant specific verbs**
```yaml
# BAD
verbs: ["*"]

# GOOD
verbs: ["get", "list"]  # Only what's needed
```

**4. Use namespace-scoped when possible**
```yaml
# Use Role + RoleBinding
# Not ClusterRole + ClusterRoleBinding
```

**5. Avoid cluster-admin**
```yaml
# Only for actual admins
# Not for applications
```

**6. Regular audits**
```bash
# Check who has what
kubectl get rolebindings -A
kubectl auth can-i --list --as=<user>
```

**Example:**
```yaml
# Application only needs to read ConfigMaps
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
rules:
- apiGroups: [""]
  resources: ["configmaps"]  # Specific
  verbs: ["get", "list"]     # Limited
  # NOT: ["*"] and ["*"]
```
