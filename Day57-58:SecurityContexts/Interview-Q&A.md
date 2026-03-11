# 🎤 Interview Q&A: Security Contexts

## Q1: What are Security Contexts and why are they important?

**Answer:**

**Security Context:** Configuration defining privilege and access control for Pods/Containers.

**Two levels:**
- **PodSecurityContext:** Applies to all containers
- **SecurityContext:** Per-container (overrides pod-level)

**Why important:**

**Without security contexts:**
- Container runs as root (UID 0)
- Has many Linux capabilities
- Full filesystem access
- Can escalate privileges
- Security risk!

**With security contexts:**
- Run as non-root user
- Minimal capabilities
- Limited filesystem access
- No privilege escalation
- Secure!

**Example:**
```yaml
securityContext:
  runAsUser: 1000        # Non-root
  runAsNonRoot: true     # Enforce
  allowPrivilegeEscalation: false
  capabilities:
    drop: [ALL]
```

---

## Q2: Explain runAsUser, runAsGroup, and fsGroup.

**Answer:**

**runAsUser:**
- Sets user ID (UID) for container processes
- Default: 0 (root) - insecure!
- Best practice: 1000+ (non-root)

```yaml
securityContext:
  runAsUser: 1000
# Process runs as UID 1000
```

**runAsGroup:**
- Sets primary group ID (GID)
- Controls process group ownership

```yaml
securityContext:
  runAsUser: 1000
  runAsGroup: 3000
# Process: uid=1000 gid=3000
```

**fsGroup:**
- Sets group ownership for VOLUMES
- All files in volume inherit this group
- Allows non-root users to access volumes

```yaml
securityContext:
  fsGroup: 2000
# Volume: drwxrwsr-x root 2000
# Files created: -rw-r--r-- 1000 2000
```

**Use together:**
```yaml
securityContext:
  runAsUser: 1000   # Process user
  runAsGroup: 3000  # Process group
  fsGroup: 2000     # Volume group
```

---

## Q3: What are Linux capabilities and how do you manage them?

**Answer:**

**Linux Capabilities:** Fine-grained permissions splitting root's powers.

**Traditional:**
- Root (UID 0): All permissions
- Non-root: Limited

**With capabilities:**
- Root powers split into ~40 capabilities
- Can add/drop specific ones

**Common capabilities:**
- `NET_BIND_SERVICE`: Bind ports < 1024
- `NET_ADMIN`: Network configuration
- `SYS_ADMIN`: Many admin operations
- `CHOWN`: Change file ownership

**Best practice: Drop ALL, add only needed**

```yaml
securityContext:
  capabilities:
    drop:
    - ALL           # Drop everything
    add:
    - NET_BIND_SERVICE  # Only add required
```

**Why:**
- Reduces attack surface
- Principle of least privilege
- Even if compromised, limited damage

**Default containers have many capabilities!**
Always explicitly drop ALL.

---

## Q4: What is allowPrivilegeEscalation and why set it to false?

**Answer:**

**allowPrivilegeEscalation:** Controls if process can gain more privileges.

**Default:** `true` (allows escalation)

**What it prevents when `false`:**
- No setuid binaries
- Can't gain capabilities
- Can't become root
- No_new_privs flag set

**Example:**
```yaml
securityContext:
  allowPrivilegeEscalation: false
```

**Why set to false:**

1. **Prevents escalation attacks:**
   - Even if vulnerability exists
   - Can't escalate to root
   - Limits damage

2. **Defense in depth:**
   - Extra security layer
   - Complements other settings

3. **Compliance:**
   - Required by many standards
   - Pod Security Standards

**Best practice:** Always set to `false` unless specific need.

**Check if enabled:**
```bash
kubectl exec <pod> -- grep NoNewPrivs /proc/1/status
# NoNewPrivs: 1 (escalation prevented)
```

---

## Q5: How do you create a production-ready secure pod?

**Answer:**

**Complete security checklist:**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secure-pod
spec:
  # Pod-level security
  securityContext:
    runAsUser: 1000          # 1. Non-root user
    runAsGroup: 3000         # 2. Non-root group
    runAsNonRoot: true       # 3. Enforce non-root
    fsGroup: 2000            # 4. Volume permissions
    seccompProfile:
      type: RuntimeDefault   # 5. Seccomp profile
  
  containers:
  - name: app
    image: nginx:1.21
    
    # Container-level security
    securityContext:
      allowPrivilegeEscalation: false  # 6. No escalation
      readOnlyRootFilesystem: true     # 7. Immutable
      capabilities:
        drop:
        - ALL                          # 8. No capabilities
        add:
        - NET_BIND_SERVICE             # 9. Only needed
    
    # Writable volumes
    volumeMounts:
    - name: cache
      mountPath: /var/cache/nginx
    - name: run
      mountPath: /var/run
  
  volumes:
  - name: cache
    emptyDir: {}
  - name: run
    emptyDir: {}
```

**Security features:**
1. ✅ Runs as non-root (UID 1000)
2. ✅ Non-root group (GID 3000)
3. ✅ Enforces non-root
4. ✅ Volume permissions (fsGroup 2000)
5. ✅ Seccomp profile
6. ✅ No privilege escalation
7. ✅ Read-only root filesystem
8. ✅ All capabilities dropped
9. ✅ Only required capability added

**Result:** Production-grade security!
