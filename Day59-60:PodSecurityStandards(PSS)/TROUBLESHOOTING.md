# 🔧 TROUBLESHOOTING: Pod Security Standards

## 🚨 ISSUE 1: Pod Rejected by Restricted Profile

**Error:**
```
Error: pods "test" is forbidden: violates PodSecurity "restricted:latest":
allowPrivilegeEscalation != false
runAsNonRoot != true
seccompProfile
```

**Cause:** Pod doesn't meet restricted profile requirements.

**Solution:** Add all required fields
```yaml
spec:
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

## 🚨 ISSUE 2: Namespace Labels Not Working

**Symptoms:** Pods admitted despite violating policy.

**Diagnosis:**
```bash
# Check labels exist
kubectl get namespace <ns> --show-labels

# Verify label format
kubectl get namespace <ns> -o yaml | grep pod-security
```

**Common mistakes:**
- Typo in label name
- Wrong label prefix
- Missing enforce mode

**Solution:**
```bash
kubectl label namespace <ns> \
  pod-security.kubernetes.io/enforce=restricted --overwrite
```

---

## 🚨 ISSUE 3: Can't Deploy to Restricted Namespace

**Error:** Multiple violations listed.

**Solution:** Create template pod
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: template
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    fsGroup: 2000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: your-image
    securityContext:
      allowPrivilegeEscalation: false
      runAsNonRoot: true
      capabilities:
        drop: [ALL]
```

---

## 🚨 ISSUE 4: System Pods Failing

**Cause:** System namespaces need privileged profile.

**Solution:**
```bash
kubectl label namespace kube-system \
  pod-security.kubernetes.io/enforce=privileged
```

---

## 📋 Debug Checklist

1. ☑️ Check namespace has labels
2. ☑️ Verify label spelling
3. ☑️ Confirm profile level (privileged/baseline/restricted)
4. ☑️ Test with dry-run first
5. ☑️ Check all required fields present
6. ☑️ Review error message details
