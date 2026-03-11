# 🔧 TROUBLESHOOTING: Security Contexts

## 🚨 ISSUE 1: Pod Fails to Start

**Error:**
```
Error: container has runAsNonRoot and image will run as root
```

**Cause:** Image defaults to root, but `runAsNonRoot: true` set.

**Solution:**
```yaml
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000  # Explicitly set non-root user
```

---

## 🚨 ISSUE 2: Permission Denied on Volume

**Error:**
```
touch: /data/test: Permission denied
```

**Cause:** Volume owned by different user/group.

**Solution:**
```yaml
spec:
  securityContext:
    fsGroup: 2000  # Set volume group ownership
```

---

## 🚨 ISSUE 3: Application Can't Write

**Cause:** `readOnlyRootFilesystem: true` but app needs to write.

**Solution:** Mount writable volumes
```yaml
containers:
- securityContext:
    readOnlyRootFilesystem: true
  volumeMounts:
  - name: tmp
    mountPath: /tmp
  - name: cache
    mountPath: /var/cache
volumes:
- name: tmp
  emptyDir: {}
- name: cache
  emptyDir: {}
```

---

## 🚨 ISSUE 4: Can't Bind to Port

**Error:**
```
Permission denied binding to port 80
```

**Cause:** Dropped `NET_BIND_SERVICE` capability.

**Solution:**
```yaml
securityContext:
  capabilities:
    drop:
    - ALL
    add:
    - NET_BIND_SERVICE
```

Or use port > 1024.

---

## 📋 Debug Checklist

1. ☑️ Check user: `kubectl exec <pod> -- id`
2. ☑️ Check capabilities: `kubectl exec <pod> -- capsh --print`
3. ☑️ Check filesystem: `kubectl exec <pod> -- mount | grep ro`
4. ☑️ View security context: `kubectl get pod <pod> -o yaml | grep -A20 securityContext`
5. ☑️ Check volume permissions: `kubectl exec <pod> -- ls -ld /path`
