# 🔧 TROUBLESHOOTING: Security Capstone - Day 68-69

## 🚨 ISSUE 1: Pod Won't Start (PSS Violation)

**Error:**
```
Error: pods "backend-xxx" is forbidden: violates PodSecurity "restricted:latest"
```

**Fix:** Add all required security context fields:
```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  seccompProfile:
    type: RuntimeDefault
containers:
- securityContext:
    allowPrivilegeEscalation: false
    capabilities:
      drop: [ALL]
```

---

## 🚨 ISSUE 2: Network Policy Blocking Traffic

**Symptoms:** Pods can't communicate

**Diagnosis:**
```bash
# Check policies
kubectl get networkpolicies -n secureshop

# Test connectivity
kubectl exec -n secureshop <pod> -- curl http://backend:8080
```

**Fix:** Ensure DNS egress allowed and correct labels match.

---

## 🚨 ISSUE 3: Permission Denied on Secrets

**Error:** Backend can't read secrets

**Fix:**
```bash
# Verify RBAC
kubectl describe role backend-role -n secureshop
kubectl describe rolebinding backend-binding -n secureshop
```

---

## 📋 Debug Checklist
1. ☑️ Namespace has PSS labels
2. ☑️ All pods use ServiceAccounts
3. ☑️ Network policies allow DNS
4. ☑️ Pods run as non-root
5. ☑️ Secrets exist and RBAC configured
