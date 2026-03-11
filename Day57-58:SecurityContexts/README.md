# Day 57-58: Security Contexts

## 📋 Overview

Welcome to Day 57-58! Today we master Pod and Container Security Contexts - the key to running secure workloads in Kubernetes. You'll learn about user/group IDs, filesystem permissions, Linux capabilities, and how to lock down containers in production.

### What You'll Learn

- Security Context fundamentals
- runAsUser and runAsGroup
- fsGroup for volume permissions
- Linux capabilities (add/drop)
- Privileged vs unprivileged containers
- readOnlyRootFilesystem
- allowPrivilegeEscalation
- seccompProfile and AppArmor
- Best practices for secure deployments

---

## 🎯 Learning Objectives

By the end of this module, you will be able to:

1. Configure pod and container security contexts
2. Manage user and group IDs
3. Control filesystem permissions with fsGroup
4. Add and drop Linux capabilities
5. Prevent privilege escalation
6. Use read-only root filesystems
7. Implement seccomp and AppArmor profiles
8. Build secure pod deployments

---

## 🔒 What are Security Contexts?

### Definition

**Security Context:** Configuration that defines privilege and access control settings for Pods and Containers.

**Two Levels:**
1. **PodSecurityContext:** Applies to all containers in the pod
2. **SecurityContext:** Applies to individual containers (overrides pod-level)

### Why Security Contexts Matter

**Without Security Contexts:**
```
Container runs as root (UID 0)
Full filesystem access
All Linux capabilities
Can escalate privileges
Security risk! 😱
```

**With Security Contexts:**
```
Container runs as non-root user
Limited filesystem access
Minimal capabilities
No privilege escalation
Secure! ✅
```

---

## 👤 User and Group IDs

### runAsUser

**Purpose:** Specifies user ID to run container processes.

**Pod-level:**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: security-context-demo
spec:
  securityContext:
    runAsUser: 1000  # All containers run as UID 1000
  containers:
  - name: app
    image: nginx
```

**Container-level (overrides pod-level):**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: security-context-demo
spec:
  securityContext:
    runAsUser: 1000  # Default for all
  containers:
  - name: app
    image: nginx
    securityContext:
      runAsUser: 2000  # This container runs as UID 2000
```

**Testing:**
```bash
kubectl exec <pod> -- id
# uid=1000 gid=0(root)
```

---

### runAsGroup

**Purpose:** Specifies primary group ID.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: security-context-demo
spec:
  securityContext:
    runAsUser: 1000
    runAsGroup: 3000
  containers:
  - name: app
    image: nginx
```

**Result:**
```bash
kubectl exec <pod> -- id
# uid=1000 gid=3000
```

---

### runAsNonRoot

**Purpose:** Prevents container from running as root (UID 0).

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: non-root-demo
spec:
  securityContext:
    runAsNonRoot: true  # Enforces non-root
    runAsUser: 1000
  containers:
  - name: app
    image: nginx
```

**If image defaults to root:**
```
Error: container has runAsNonRoot and image will run as root
```

**Best Practice:** Always set `runAsNonRoot: true` in production.

---

## 📁 Filesystem Permissions

### fsGroup

**Purpose:** Sets group ID for volume ownership and permissions.

**Problem without fsGroup:**
```yaml
# Volume owned by root:root
# Container runs as UID 1000
# Result: Permission denied!
```

**Solution with fsGroup:**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: security-context-demo
spec:
  securityContext:
    fsGroup: 2000  # Volume group ownership
    runAsUser: 1000
  containers:
  - name: app
    image: nginx
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    emptyDir: {}
```

**Result:**
```bash
kubectl exec <pod> -- ls -ld /data
# drwxrwsrwx 2 root 2000 4096 /data
# Group: 2000 (matches fsGroup)
```

**How it works:**
1. Volume mounted with group ID = fsGroup
2. All files created in volume inherit group ID
3. Container process (UID 1000) can access if in group 2000

---

### readOnlyRootFilesystem

**Purpose:** Makes container's root filesystem read-only.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: readonly-demo
spec:
  containers:
  - name: app
    image: nginx
    securityContext:
      readOnlyRootFilesystem: true
    volumeMounts:
    - name: cache
      mountPath: /var/cache/nginx  # Writable tmpfs
    - name: run
      mountPath: /var/run
  volumes:
  - name: cache
    emptyDir: {}
  - name: run
    emptyDir: {}
```

**Benefits:**
- ✅ Prevents malware from writing to filesystem
- ✅ Prevents container modification
- ✅ Immutable infrastructure

**Note:** Applications that need to write require volume mounts.

---

## 🎩 Linux Capabilities

### What are Capabilities?

**Traditional Unix:**
- Root (UID 0): All permissions
- Non-root: Limited permissions

**Linux Capabilities:**
- Fine-grained permissions
- Root's powers split into ~40 capabilities
- Can add/drop specific capabilities

### Common Capabilities

**Networking:**
- `NET_BIND_SERVICE` - Bind to ports < 1024
- `NET_ADMIN` - Network configuration
- `NET_RAW` - Use RAW/PACKET sockets

**Filesystem:**
- `CHOWN` - Change file ownership
- `DAC_OVERRIDE` - Bypass file permissions
- `FOWNER` - Bypass permission checks for UID

**System:**
- `SYS_ADMIN` - Mount filesystems, many admin operations
- `SYS_TIME` - Set system clock
- `SYS_CHROOT` - Use chroot()

---

### Dropping Capabilities

**Default:** Containers run with several capabilities.

**Drop all, add specific:**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: caps-demo
spec:
  containers:
  - name: app
    image: nginx
    securityContext:
      capabilities:
        drop:
        - ALL  # Drop everything
        add:
        - NET_BIND_SERVICE  # Only add what's needed
```

**Best Practice:** Drop ALL, add only required capabilities.

---

### Adding Capabilities

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: caps-demo
spec:
  containers:
  - name: app
    image: nginx
    securityContext:
      capabilities:
        add:
        - NET_ADMIN  # Add network admin capability
```

**⚠️ Warning:** Only add capabilities when absolutely necessary.

---

## 🔓 Privilege Escalation

### allowPrivilegeEscalation

**Purpose:** Controls if process can gain more privileges.

**Default:** `true` (allows escalation)

**Secure setting:**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: no-escalation
spec:
  containers:
  - name: app
    image: nginx
    securityContext:
      allowPrivilegeEscalation: false
```

**What it prevents:**
- No setuid binaries
- No gaining capabilities
- No becoming root

**Best Practice:** Always set to `false` unless specific need.

---

## 👑 Privileged Containers

### What is Privileged?

**Privileged container:**
- Runs as root
- Has ALL capabilities
- Can access host devices
- Essentially same as host root

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: privileged-pod
spec:
  containers:
  - name: app
    image: nginx
    securityContext:
      privileged: true  # ⚠️ DANGEROUS!
```

**When privileged is needed:**
- Container needs to manipulate kernel
- System-level operations
- Device access

**Examples:**
- CNI plugins (network setup)
- Storage drivers
- Monitoring agents

**⚠️ DO NOT use privileged containers unless absolutely necessary!**

---

## 🛡️ Complete Security Context Example

### Production-Ready Pod

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secure-app
spec:
  securityContext:
    runAsUser: 1000          # Non-root user
    runAsGroup: 3000         # Non-root group
    runAsNonRoot: true       # Enforce non-root
    fsGroup: 2000            # Volume group ownership
    seccompProfile:
      type: RuntimeDefault   # Seccomp profile
  containers:
  - name: app
    image: nginx:1.21
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop:
        - ALL
        add:
        - NET_BIND_SERVICE
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

**Security Features:**
- ✅ Runs as non-root (UID 1000)
- ✅ Non-root group (GID 3000)
- ✅ Enforces non-root
- ✅ Volume permissions (fsGroup 2000)
- ✅ No privilege escalation
- ✅ Read-only root filesystem
- ✅ Minimal capabilities
- ✅ Seccomp profile

---

## 🔐 Advanced Security Features

### SELinux

**Purpose:** Mandatory Access Control (MAC) system.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: selinux-demo
spec:
  securityContext:
    seLinuxOptions:
      level: "s0:c123,c456"
      role: "sysadm_r"
      type: "sysadm_t"
      user: "sysadm_u"
  containers:
  - name: app
    image: nginx
```

**Note:** Requires SELinux-enabled nodes.

---

### Seccomp Profiles

**Purpose:** Restrict system calls available to container.

**Types:**
1. `Unconfined` - No restrictions (default, insecure)
2. `RuntimeDefault` - Container runtime's default profile
3. `Localhost` - Custom profile from node

**Recommended:**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: seccomp-demo
spec:
  securityContext:
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: nginx
```

**Custom profile:**
```yaml
securityContext:
  seccompProfile:
    type: Localhost
    localhostProfile: profiles/audit.json
```

---

### AppArmor

**Purpose:** Another MAC system (alternative to SELinux).

**Annotation-based:**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: apparmor-demo
  annotations:
    container.apparmor.security.beta.kubernetes.io/app: localhost/k8s-apparmor-example
spec:
  containers:
  - name: app
    image: nginx
```

**Note:** Requires AppArmor-enabled nodes and loaded profiles.

---

## 🎯 Best Practices

### 1. Always Run as Non-Root

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
```

---

### 2. Drop All Capabilities

```yaml
securityContext:
  capabilities:
    drop:
    - ALL
```

---

### 3. Read-Only Root Filesystem

```yaml
securityContext:
  readOnlyRootFilesystem: true
```

---

### 4. Prevent Privilege Escalation

```yaml
securityContext:
  allowPrivilegeEscalation: false
```

---

### 5. Use Seccomp Profile

```yaml
securityContext:
  seccompProfile:
    type: RuntimeDefault
```

---

### 6. Set fsGroup for Volumes

```yaml
securityContext:
  fsGroup: 2000
```

---

### 7. Never Use Privileged

```yaml
# ❌ DON'T DO THIS (unless absolutely necessary)
securityContext:
  privileged: true
```

---

## 📖 Security Context Decision Tree

```
Need to run as root? ───YES──→ ⚠️ Reconsider architecture
    │                         
    NO
    ↓
Set runAsNonRoot: true
Set runAsUser: 1000+
    ↓
Need write access? ───NO──→ Set readOnlyRootFilesystem: true
    │                        Mount tmpfs for writable dirs
    YES
    ↓
Set fsGroup for volumes
    ↓
Need special capabilities? ───NO──→ Drop ALL capabilities
    │
    YES
    ↓
Drop ALL, add ONLY required
    ↓
Always set:
- allowPrivilegeEscalation: false
- seccompProfile: RuntimeDefault
```

---

## 📊 Security Context Levels

### Level 1: Baseline (Minimum)

```yaml
securityContext:
  runAsNonRoot: true
```

---

### Level 2: Restricted (Recommended)

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  allowPrivilegeEscalation: false
  capabilities:
    drop:
    - ALL
```

---

### Level 3: Hardened (Maximum Security)

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  runAsGroup: 3000
  fsGroup: 2000
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  seccompProfile:
    type: RuntimeDefault
  capabilities:
    drop:
    - ALL
```

---

## 📖 Key Takeaways

✅ Security contexts control privilege and access
✅ runAsUser sets user ID (always non-root!)
✅ fsGroup controls volume permissions
✅ Capabilities provide fine-grained permissions
✅ Drop ALL capabilities, add only needed
✅ readOnlyRootFilesystem prevents tampering
✅ allowPrivilegeEscalation: false prevents escalation
✅ Privileged containers = dangerous (avoid!)
✅ Seccomp adds syscall filtering
✅ Apply security contexts to ALL pods

---

## 🔗 Additional Resources

- [Security Contexts](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/)
- [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
- [Linux Capabilities](https://man7.org/linux/man-pages/man7/capabilities.7.html)

---

## 🚀 Next Steps

1. Complete hands-on exercises in GUIDEME.md
2. Configure security contexts for all pods
3. Test with different user IDs
4. Experiment with capabilities
5. Implement read-only filesystems
6. Build secure deployment templates
7. Move to Pod Security Policies/Admission

**Happy Securing! 🔒**
