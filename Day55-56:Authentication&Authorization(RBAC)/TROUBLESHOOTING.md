# 🔧 TROUBLESHOOTING: RBAC Issues

## 🚨 ISSUE 1: Permission Denied

**Symptoms:**
```bash
kubectl create pod test
# Error: forbidden: User "jane" cannot create pods
```

**Diagnosis:**
```bash
# Check if you can perform action
kubectl auth can-i create pods

# Check as specific user
kubectl auth can-i create pods --as=jane

# List all permissions
kubectl auth can-i --list --as=jane
```

**Solutions:**
- Create appropriate Role
- Create RoleBinding
- Verify roleRef and subjects correct

---

## 🚨 ISSUE 2: ServiceAccount Can't Access API

**Symptoms:**
```bash
# From inside pod
curl https://kubernetes.default.svc/api/v1/pods
# Forbidden
```

**Diagnosis:**
```bash
# Check ServiceAccount exists
kubectl get sa <sa-name>

# Check RoleBinding exists
kubectl get rolebindings | grep <sa-name>

# Test permissions
kubectl auth can-i list pods \
  --as=system:serviceaccount:<namespace>:<sa-name>
```

**Solutions:**
- Create Role with required permissions
- Create RoleBinding linking SA to Role
- Ensure pod uses correct ServiceAccount

---

## 🚨 ISSUE 3: ClusterRole Not Working

**Diagnosis:**
```bash
# Check ClusterRole exists
kubectl get clusterrole <role-name>

# Check ClusterRoleBinding
kubectl get clusterrolebinding | grep <role-name>

# Describe binding
kubectl describe clusterrolebinding <binding-name>
```

**Common Mistakes:**
- Used RoleBinding instead of ClusterRoleBinding
- Wrong apiGroup in roleRef
- Subject kind incorrect

---

## 🚨 ISSUE 4: Can't Access Across Namespaces

**Problem:** RoleBinding only grants access in one namespace

**Solution:**
```bash
# Option 1: Create RoleBinding in each namespace
kubectl create rolebinding <name> -n ns1 --role=<role> --user=<user>
kubectl create rolebinding <name> -n ns2 --role=<role> --user=<user>

# Option 2: Use ClusterRole + ClusterRoleBinding
```

---

## 📋 Debug Checklist

1. ☑️ Does ServiceAccount exist?
2. ☑️ Does Role/ClusterRole exist?
3. ☑️ Does RoleBinding/ClusterRoleBinding exist?
4. ☑️ Does subjects match (kind, name, namespace)?
5. ☑️ Does roleRef match (kind, name, apiGroup)?
6. ☑️ Are verbs sufficient?
7. ☑️ Are resources correct?
8. ☑️ Test with `kubectl auth can-i`
