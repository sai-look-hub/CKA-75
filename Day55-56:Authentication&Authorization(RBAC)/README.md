# Day 55-56: Authentication & Authorization (RBAC)

## 📋 Overview

Welcome to Day 55-56! Today we master Kubernetes security through Authentication and Authorization. You'll learn RBAC (Role-Based Access Control), service accounts, users and groups, and build production-ready access control policies.

### What You'll Learn

- Authentication vs Authorization
- Service Accounts
- RBAC fundamentals (Roles, RoleBindings, ClusterRoles)
- Users and Groups
- Best practices for access control
- Troubleshooting RBAC issues
- Audit and compliance

---

## 🎯 Learning Objectives

By the end of this module, you will be able to:

1. Understand authentication and authorization flow
2. Create and manage service accounts
3. Implement RBAC policies (Roles, RoleBindings)
4. Configure ClusterRoles and ClusterRoleBindings
5. Manage user and group access
6. Debug permission issues
7. Implement least privilege principle
8. Audit access controls

---

## 🔐 Authentication vs Authorization

### The Security Flow

```
┌─────────────────────────────────────────┐
│     1. Authentication (AuthN)            │
│     "Who are you?"                       │
│                                          │
│  Methods:                                │
│  - X.509 Certificates                   │
│  - Bearer Tokens (ServiceAccount)       │
│  - OpenID Connect (OIDC)                │
│  - Webhook                              │
│                                          │
│  Result: Identity (User/ServiceAccount) │
└──────────────┬──────────────────────────┘
               ↓
┌─────────────────────────────────────────┐
│     2. Authorization (AuthZ)             │
│     "What can you do?"                   │
│                                          │
│  Methods:                                │
│  - RBAC (Role-Based Access Control)     │
│  - ABAC (Attribute-Based)               │
│  - Webhook                              │
│                                          │
│  Result: Allowed/Denied                 │
└──────────────┬──────────────────────────┘
               ↓
┌─────────────────────────────────────────┐
│     3. Admission Control                 │
│     "Is this request valid?"            │
│                                          │
│  Mutating/Validating webhooks           │
└─────────────────────────────────────────┘
```

---

## 👤 Service Accounts

### What are Service Accounts?

**Definition:** Kubernetes identities for pods/processes running in the cluster.

**Key Points:**
- Namespace-scoped
- Automatically created for each namespace (`default` ServiceAccount)
- Used by pods to authenticate with API server
- Token mounted in pod at `/var/run/secrets/kubernetes.io/serviceaccount/token`

### Default Service Account

Every namespace has a `default` ServiceAccount:

```bash
kubectl get serviceaccount -n default
# NAME      SECRETS   AGE
# default   1         30d
```

### Creating Service Accounts

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-app-sa
  namespace: production
```

### Using Service Accounts in Pods

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-app
spec:
  serviceAccountName: my-app-sa  # Use custom SA
  containers:
  - name: app
    image: nginx
```

**Inside the pod:**
```bash
# Token location
cat /var/run/secrets/kubernetes.io/serviceaccount/token

# CA certificate
cat /var/run/secrets/kubernetes.io/serviceaccount/ca.crt

# Namespace
cat /var/run/secrets/kubernetes.io/serviceaccount/namespace
```

---

## 🎭 RBAC (Role-Based Access Control)

### RBAC Components

```
┌─────────────────────────────────────────┐
│         RBAC Architecture                │
│                                          │
│  ┌──────────┐      ┌────────────────┐  │
│  │  Role    │      │  RoleBinding   │  │
│  │          │      │                │  │
│  │ - get    │◄─────│ Subject:       │  │
│  │ - list   │      │ - User         │  │
│  │ - watch  │      │ - Group        │  │
│  │          │      │ - ServiceAcct  │  │
│  └──────────┘      └────────────────┘  │
│  (Namespace)             ↓              │
│                      Binds              │
│                                          │
│  ┌──────────┐      ┌────────────────┐  │
│  │ClusterRole      │ClusterRole     │  │
│  │          │      │Binding         │  │
│  │ - get    │◄─────│                │  │
│  │ - list   │      │ Subject:       │  │
│  │ - delete │      │ - User         │  │
│  │          │      │                │  │
│  └──────────┘      └────────────────┘  │
│  (Cluster-wide)          ↓              │
│                      Binds              │
└─────────────────────────────────────────┘
```

---

### Role (Namespace-scoped)

**Definition:** Set of permissions within a namespace.

**Example:**
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: production
rules:
- apiGroups: [""]  # "" = core API group
  resources: ["pods"]
  verbs: ["get", "list", "watch"]
```

**Verbs (Permissions):**
- `get` - Read single resource
- `list` - List resources
- `watch` - Watch for changes
- `create` - Create resources
- `update` - Update resources
- `patch` - Patch resources
- `delete` - Delete resources
- `deletecollection` - Delete multiple resources

---

### RoleBinding (Namespace-scoped)

**Definition:** Grants permissions defined in a Role to subjects.

**Example:**
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-pods
  namespace: production
subjects:
- kind: User
  name: jane
  apiGroup: rbac.authorization.k8s.io
- kind: ServiceAccount
  name: my-app-sa
  namespace: production
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```

**Subjects (Who):**
- `User` - Human user
- `Group` - Group of users
- `ServiceAccount` - Pod identity

---

### ClusterRole (Cluster-wide)

**Definition:** Set of permissions across all namespaces or for cluster-scoped resources.

**Use Cases:**
- Access to cluster-scoped resources (nodes, namespaces)
- Access to non-resource endpoints (`/healthz`, `/metrics`)
- Access to resources across all namespaces

**Example:**
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: node-reader
rules:
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["get", "list", "watch"]
```

---

### ClusterRoleBinding (Cluster-wide)

**Definition:** Grants ClusterRole permissions cluster-wide.

**Example:**
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: read-nodes-global
subjects:
- kind: User
  name: ops-team
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: node-reader
  apiGroup: rbac.authorization.k8s.io
```

---

## 🎯 Common RBAC Patterns

### Pattern 1: Read-Only Access to Namespace

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: namespace-reader
  namespace: production
rules:
- apiGroups: ["", "apps", "batch"]
  resources: ["*"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: developers-read
  namespace: production
subjects:
- kind: Group
  name: developers
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: namespace-reader
  apiGroup: rbac.authorization.k8s.io
```

---

### Pattern 2: Deployment Manager

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: deployment-manager
  namespace: production
rules:
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: [""]
  resources: ["pods", "pods/log"]
  verbs: ["get", "list", "watch"]
```

---

### Pattern 3: Secret Reader (ServiceAccount)

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: secret-reader-sa
  namespace: production
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: secret-reader
  namespace: production
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-secrets
  namespace: production
subjects:
- kind: ServiceAccount
  name: secret-reader-sa
  namespace: production
roleRef:
  kind: Role
  name: secret-reader
  apiGroup: rbac.authorization.k8s.io
```

---

### Pattern 4: Cluster Admin (Use Carefully!)

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
subjects:
- kind: User
  name: admin@example.com
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: cluster-admin  # Built-in role
  apiGroup: rbac.authorization.k8s.io
```

**⚠️ Warning:** `cluster-admin` has full cluster access!

---

## 📦 Built-in ClusterRoles

Kubernetes provides default ClusterRoles:

**1. cluster-admin**
- Full cluster access
- **Use sparingly!**

**2. admin**
- Full access within namespace
- Can create Roles/RoleBindings
- Cannot modify namespace itself

**3. edit**
- Read/write access to most resources
- Cannot view Roles/RoleBindings
- Cannot modify Secrets (by default)

**4. view**
- Read-only access
- Cannot view Secrets
- Good for read-only users

```bash
# List built-in ClusterRoles
kubectl get clusterroles | grep -E '^(cluster-admin|admin|edit|view)\s'
```

---

## 👥 Users and Groups

### Users in Kubernetes

**Important:** Kubernetes does NOT manage users internally!

**User Authentication Methods:**
1. **X.509 Client Certificates**
   - CN (Common Name) = Username
   - O (Organization) = Groups

2. **Static Token File**
   - Not recommended for production

3. **OpenID Connect (OIDC)**
   - Google, Azure AD, Okta
   - Recommended for production

4. **Webhook Token Authentication**
   - Custom authentication server

### Creating User with Certificate

```bash
# 1. Generate private key
openssl genrsa -out jane.key 2048

# 2. Create CSR (Certificate Signing Request)
openssl req -new -key jane.key -out jane.csr -subj "/CN=jane/O=developers"

# 3. Sign with Kubernetes CA (simplified)
# In production, use CertificateSigningRequest API

# 4. Create kubeconfig for user
kubectl config set-credentials jane \
  --client-certificate=jane.crt \
  --client-key=jane.key

kubectl config set-context jane-context \
  --cluster=kubernetes \
  --user=jane
```

---

### Groups

**Groups:** Logical grouping of users.

**System Groups:**
- `system:authenticated` - All authenticated users
- `system:unauthenticated` - Unauthenticated requests
- `system:masters` - Cluster admins

**Custom Groups:**
- Defined in user certificate (O field)
- Used in RoleBinding subjects

```yaml
subjects:
- kind: Group
  name: developers  # All users with O=developers
  apiGroup: rbac.authorization.k8s.io
```

---

## 🔍 Testing RBAC Permissions

### Can-I Command

```bash
# Check if you can perform action
kubectl auth can-i create pods

# Check for specific user
kubectl auth can-i create pods --as=jane

# Check for ServiceAccount
kubectl auth can-i create pods \
  --as=system:serviceaccount:default:my-app-sa

# Check in specific namespace
kubectl auth can-i create pods --namespace=production

# Check all permissions
kubectl auth can-i --list
```

---

### Testing as ServiceAccount

```bash
# Create test pod with ServiceAccount
kubectl run test-pod --image=nginx \
  --serviceaccount=my-app-sa

# Exec into pod
kubectl exec -it test-pod -- sh

# Inside pod, try API calls
curl https://kubernetes.default.svc/api/v1/namespaces/default/pods \
  --cacert /var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
  --header "Authorization: Bearer $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)"
```

---

## 🎯 Best Practices

### 1. Principle of Least Privilege

**Grant minimum permissions needed.**

```yaml
# BAD: Too broad
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["*"]

# GOOD: Specific
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
```

---

### 2. Use Service Accounts for Applications

**Don't use default ServiceAccount:**

```yaml
# Create dedicated ServiceAccount
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-backend-sa
---
# Use in Deployment
spec:
  template:
    spec:
      serviceAccountName: app-backend-sa
```

---

### 3. Separate Roles by Function

```yaml
# Deployment manager
kind: Role
metadata:
  name: deployment-manager

# ConfigMap manager
kind: Role
metadata:
  name: configmap-manager

# Combine via multiple RoleBindings
```

---

### 4. Avoid Cluster-Admin

**Use namespace-scoped permissions when possible.**

```yaml
# Instead of ClusterRoleBinding to cluster-admin
# Use RoleBinding to admin in specific namespace
kind: RoleBinding
metadata:
  name: prod-admin
  namespace: production
roleRef:
  kind: ClusterRole
  name: admin  # Built-in namespace admin role
```

---

### 5. Regular Audits

```bash
# List all ClusterRoleBindings
kubectl get clusterrolebindings -o wide

# Find who has cluster-admin
kubectl get clusterrolebindings -o json | \
  jq -r '.items[] | select(.roleRef.name=="cluster-admin") | .metadata.name'

# List all RoleBindings in namespace
kubectl get rolebindings -n production
```

---

## 📖 Key Takeaways

✅ Authentication = "Who are you?" (Users, ServiceAccounts)
✅ Authorization = "What can you do?" (RBAC)
✅ Role = Permissions in namespace
✅ ClusterRole = Permissions cluster-wide
✅ RoleBinding = Grants Role to subjects
✅ ServiceAccounts = Identities for pods
✅ Least privilege = Best practice
✅ Test with `kubectl auth can-i`

---

## 🔗 Additional Resources

- [RBAC Documentation](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- [Service Accounts](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/)
- [Authentication](https://kubernetes.io/docs/reference/access-authn-authz/authentication/)

---

## 🚀 Next Steps

1. Complete hands-on exercises in GUIDEME.md
2. Create Roles and RoleBindings
3. Test permissions with can-i
4. Implement least privilege
5. Audit existing RBAC
6. Move to advanced security topics

**Happy Securing! 🔒**
