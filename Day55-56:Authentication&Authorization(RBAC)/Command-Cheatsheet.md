# 📋 Command Cheatsheet: RBAC

## 🔑 ServiceAccount Commands

```bash
# Create ServiceAccount
kubectl create serviceaccount <sa-name>
kubectl create serviceaccount <sa-name> -n <namespace>

# Get ServiceAccounts
kubectl get serviceaccounts
kubectl get sa -A

# Describe ServiceAccount
kubectl describe serviceaccount <sa-name>

# Delete ServiceAccount
kubectl delete serviceaccount <sa-name>
```

## 🎭 Role Commands

```bash
# Create Role (imperative)
kubectl create role <role-name> \
  --verb=get,list,watch \
  --resource=pods

# Get Roles
kubectl get roles
kubectl get roles -A

# Describe Role
kubectl describe role <role-name>

# Delete Role
kubectl delete role <role-name>
```

## 🔗 RoleBinding Commands

```bash
# Create RoleBinding
kubectl create rolebinding <binding-name> \
  --role=<role-name> \
  --serviceaccount=<namespace>:<sa-name>

# Bind to user
kubectl create rolebinding <binding-name> \
  --role=<role-name> \
  --user=<username>

# Get RoleBindings
kubectl get rolebindings
kubectl get rolebindings -A

# Describe RoleBinding
kubectl describe rolebinding <binding-name>
```

## 🌐 ClusterRole Commands

```bash
# Create ClusterRole
kubectl create clusterrole <role-name> \
  --verb=get,list \
  --resource=nodes

# Get ClusterRoles
kubectl get clusterroles

# Describe ClusterRole
kubectl describe clusterrole <role-name>

# View built-in roles
kubectl get clusterroles | grep -E 'admin|edit|view'
```

## 🔗 ClusterRoleBinding Commands

```bash
# Create ClusterRoleBinding
kubectl create clusterrolebinding <binding-name> \
  --clusterrole=<role-name> \
  --serviceaccount=<namespace>:<sa-name>

# Get ClusterRoleBindings
kubectl get clusterrolebindings

# Find who has cluster-admin
kubectl get clusterrolebindings -o json | \
  jq -r '.items[] | select(.roleRef.name=="cluster-admin") | .metadata.name'
```

## 🧪 Testing Permissions

```bash
# Check your permissions
kubectl auth can-i create pods
kubectl auth can-i delete deployments -n production

# Check as another user
kubectl auth can-i list pods --as=jane
kubectl auth can-i create deployments --as=john

# Check as ServiceAccount
kubectl auth can-i list secrets \
  --as=system:serviceaccount:default:my-app-sa

# List all permissions
kubectl auth can-i --list

# List permissions for ServiceAccount
kubectl auth can-i --list \
  --as=system:serviceaccount:default:my-app-sa
```

## 🔍 Audit Commands

```bash
# List all ServiceAccounts
kubectl get sa -A

# List all Roles
kubectl get roles -A -o wide

# List all RoleBindings
kubectl get rolebindings -A -o wide

# List all ClusterRoles
kubectl get clusterroles -o wide

# List all ClusterRoleBindings
kubectl get clusterrolebindings -o wide

# Get RBAC for specific resource
kubectl get rolebindings,clusterrolebindings --all-namespaces -o json | \
  jq -r '.items[] | select(.roleRef.name=="<role-name>")'
```

## 💡 Useful One-Liners

```bash
# Get all Roles and their namespaces
kubectl get roles -A -o custom-columns=\
NAMESPACE:.metadata.namespace,\
NAME:.metadata.name,\
RESOURCES:.rules[*].resources

# List all ServiceAccounts with secrets
kubectl get sa -A -o custom-columns=\
NAMESPACE:.metadata.namespace,\
NAME:.metadata.name,\
SECRETS:.secrets[*].name

# Find all RoleBindings for a ServiceAccount
kubectl get rolebindings -A -o json | \
  jq -r '.items[] | select(.subjects[]?.name=="<sa-name>") | 
    "\(.metadata.namespace)/\(.metadata.name)"'

# Check if any SA has cluster-admin
kubectl get clusterrolebindings -o json | \
  jq -r '.items[] | select(.roleRef.name=="cluster-admin") | 
    .subjects[]? | "\(.kind): \(.name)"'
```
