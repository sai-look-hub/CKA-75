# Day 59-60: Pod Security Standards (PSS)

## 📋 Overview

Welcome to Day 59-60! Today we master Pod Security Standards (PSS) and Pod Security Admission - Kubernetes' built-in mechanism for enforcing security policies across your cluster. You'll learn the three security profiles and how to implement cluster-wide security controls.

### What You'll Learn

- Pod Security Standards (PSS) fundamentals
- Three security profiles (Privileged, Baseline, Restricted)
- Pod Security Admission controller
- Namespace-level policy enforcement
- Migration from PodSecurityPolicy
- Exemptions and exceptions
- Best practices for production

---

## 🎯 Learning Objectives

By the end of this module, you will be able to:

1. Understand the three Pod Security Standards
2. Configure Pod Security Admission
3. Enforce policies at namespace level
4. Implement gradual policy rollout
5. Use warn and audit modes
6. Handle policy violations
7. Migrate from legacy PodSecurityPolicy
8. Build secure cluster configurations

---

## 🔐 What are Pod Security Standards?

### Definition

**Pod Security Standards (PSS):** Kubernetes-native way to enforce security policies across your cluster using three predefined security profiles.

**Replaced:** PodSecurityPolicy (deprecated in 1.21, removed in 1.25)

**Enforced by:** Pod Security Admission controller (built-in, enabled by default in 1.23+)

---

### Why Pod Security Standards?

**Before PSS:**
```
No standard security policies
Each cluster different
Hard to enforce security
PodSecurityPolicy complex
```

**With PSS:**
```
Standard security profiles ✅
Consistent across clusters ✅
Easy to implement ✅
Built-in admission controller ✅
```

---

## 🎭 The Three Security Profiles

### Overview

```
┌─────────────────────────────────────────┐
│     Pod Security Standard Profiles      │
├─────────────────────────────────────────┤
│                                          │
│  Privileged (Most Permissive)           │
│  ↓ No restrictions                      │
│  ↓ Unrestricted policy                  │
│  ↓ For system components                │
│                                          │
│  Baseline (Minimal Restrictions)        │
│  ↓ Prevent known privilege escalations  │
│  ↓ Minimal restrictive policy           │
│  ↓ Good default for most workloads      │
│                                          │
│  Restricted (Most Restrictive)          │
│  ↓ Hardened security                    │
│  ↓ Current best practices               │
│  ↓ Defense in depth                     │
│                                          │
└─────────────────────────────────────────┘
```

---

### 1. Privileged Profile

**Purpose:** Unrestricted policy for trusted workloads.

**Restrictions:** None

**Use cases:**
- System components (CNI, CSI drivers)
- Monitoring agents (node-level access)
- Logging daemons
- Infrastructure pods

**⚠️ Warning:** Use only when absolutely necessary!

**Example workloads:**
- Calico/Cilium network plugins
- Prometheus node exporter
- Fluent Bit log collector

---

### 2. Baseline Profile

**Purpose:** Prevent known privilege escalations while minimizing restrictions.

**Key restrictions:**
- ❌ Privileged containers
- ❌ Host namespaces (hostNetwork, hostPID, hostIPC)
- ❌ Host ports
- ❌ Dangerous capabilities (ALL, SYS_ADMIN, NET_ADMIN)
- ❌ HostPath volumes (with exceptions)
- ❌ Privilege escalation
- ❌ Non-default proc mount
- ❌ SELinux custom options

**Allowed:**
- ✅ Running as root (UID 0)
- ✅ Some capabilities
- ✅ Writable root filesystem
- ✅ Volume types (except hostPath)

**Use cases:**
- Most applications
- Default policy for namespaces
- Development environments
- Non-critical workloads

---

### 3. Restricted Profile

**Purpose:** Heavily restricted policy following current pod hardening best practices.

**Includes all Baseline restrictions, plus:**
- ❌ Running as root (must be non-root)
- ❌ Running as UID 0
- ❌ All capabilities (must drop ALL)
- ❌ Privilege escalation (must be false)
- ❌ seccomp unconfined
- ❌ Writable root filesystem (recommended read-only)

**Required:**
- ✅ Must run as non-root (`runAsNonRoot: true`)
- ✅ Must drop ALL capabilities
- ✅ No privilege escalation (`allowPrivilegeEscalation: false`)
- ✅ Seccomp profile (RuntimeDefault or Localhost)

**Use cases:**
- Production workloads
- Security-critical applications
- Compliance requirements
- Public-facing services

---

## 📊 Profile Comparison Matrix

| Feature | Privileged | Baseline | Restricted |
|---------|-----------|----------|------------|
| Privileged containers | ✅ | ❌ | ❌ |
| Host namespaces | ✅ | ❌ | ❌ |
| Host ports | ✅ | ❌ | ❌ |
| HostPath volumes | ✅ | Limited | ❌ |
| Running as root | ✅ | ✅ | ❌ |
| Capabilities | ✅ All | Some | None (must drop ALL) |
| Privilege escalation | ✅ | ❌ | ❌ (must be false) |
| Seccomp | ✅ Any | Any | RuntimeDefault/Localhost |
| Read-only root | ❌ | ❌ | ✅ Recommended |

---

## 🎯 Pod Security Admission

### How it Works

**Pod Security Admission:** Built-in admission controller that enforces Pod Security Standards at namespace level.

**Architecture:**
```
Pod Creation Request
    ↓
API Server
    ↓
Pod Security Admission
    ↓
Check namespace labels
    ↓
Apply profile (enforce/audit/warn)
    ↓
Decision: Allow or Deny
```

---

### Three Modes

**1. enforce**
- Rejects pods that violate the policy
- Pods cannot be created
- Production security

```yaml
pod-security.kubernetes.io/enforce: restricted
```

**2. audit**
- Allows pods but logs violations to audit log
- Monitoring and compliance
- No impact on pod creation

```yaml
pod-security.kubernetes.io/audit: restricted
```

**3. warn**
- Allows pods but returns warning to user
- User feedback
- No impact on pod creation

```yaml
pod-security.kubernetes.io/warn: restricted
```

**Use together:**
```yaml
pod-security.kubernetes.io/enforce: baseline
pod-security.kubernetes.io/audit: restricted
pod-security.kubernetes.io/warn: restricted
```

This configuration:
- Enforces baseline (blocks violations)
- Audits against restricted (logs violations)
- Warns against restricted (shows warnings)

---

### Namespace Labels

**Apply PSS via namespace labels:**

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

**Version pinning (optional):**
```yaml
pod-security.kubernetes.io/enforce-version: v1.28
```

Without version, uses latest.

---

## 🚀 Implementation Patterns

### Pattern 1: Development Namespace (Baseline)

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: development
  labels:
    pod-security.kubernetes.io/enforce: baseline
    pod-security.kubernetes.io/audit: baseline
    pod-security.kubernetes.io/warn: baseline
```

**Characteristics:**
- Prevents dangerous practices
- Allows most workloads
- Good for testing

---

### Pattern 2: Production Namespace (Restricted)

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

**Characteristics:**
- Maximum security
- Requires compliant pods
- Best practice for production

---

### Pattern 3: System Namespace (Privileged)

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: kube-system
  labels:
    pod-security.kubernetes.io/enforce: privileged
    pod-security.kubernetes.io/audit: privileged
    pod-security.kubernetes.io/warn: privileged
```

**Characteristics:**
- No restrictions
- For system components
- Use sparingly!

---

### Pattern 4: Gradual Rollout

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: migration-namespace
  labels:
    pod-security.kubernetes.io/enforce: baseline  # Current enforcement
    pod-security.kubernetes.io/audit: restricted  # Future target
    pod-security.kubernetes.io/warn: restricted   # User warnings
```

**Strategy:**
1. Start with enforce=baseline
2. Audit against restricted (see violations)
3. Fix violations
4. Change enforce to restricted

---

## 🔧 Cluster-Wide Configuration

### AdmissionConfiguration

**Enable at cluster level:**

```yaml
apiVersion: apiserver.config.k8s.io/v1
kind: AdmissionConfiguration
plugins:
- name: PodSecurity
  configuration:
    apiVersion: pod-security.admission.config.k8s.io/v1
    kind: PodSecurityConfiguration
    defaults:
      enforce: baseline
      enforce-version: latest
      audit: restricted
      audit-version: latest
      warn: restricted
      warn-version: latest
    exemptions:
      usernames: []
      runtimeClasses: []
      namespaces:
      - kube-system
      - kube-public
      - kube-node-lease
```

**Apply:**
- Pass to kube-apiserver via `--admission-control-config-file`

---

### Exemptions

**Who can bypass PSS:**

```yaml
exemptions:
  # Specific users
  usernames:
  - "system:serviceaccount:kube-system:daemon-set-controller"
  
  # Specific namespaces
  namespaces:
  - kube-system
  - monitoring
  
  # Runtime classes
  runtimeClasses:
  - kata-containers
```

**⚠️ Use exemptions carefully!**

---

## 📝 Restricted Profile Requirements

### Complete Checklist

**Pod must have:**
```yaml
spec:
  securityContext:
    runAsNonRoot: true          # Required
    seccompProfile:
      type: RuntimeDefault      # Required
```

**Each container must have:**
```yaml
securityContext:
  allowPrivilegeEscalation: false  # Required
  capabilities:
    drop:
    - ALL                           # Required
  runAsNonRoot: true                # If not set at pod level
```

**Example compliant pod:**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: restricted-pod
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    fsGroup: 2000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: nginx:1.21
    securityContext:
      allowPrivilegeEscalation: false
      runAsNonRoot: true
      capabilities:
        drop:
        - ALL
```

---

## 🔄 Migration from PodSecurityPolicy

### PodSecurityPolicy (Deprecated)

**Timeline:**
- Deprecated: Kubernetes 1.21
- Removed: Kubernetes 1.25

**Why deprecated:**
- Complex to configure
- Hard to understand
- Inconsistent behavior
- Difficult to troubleshoot

---

### Migration Steps

**1. Audit current PSP usage**
```bash
kubectl get podsecuritypolicies
kubectl get clusterrolebindings -o json | \
  jq -r '.items[] | select(.roleRef.kind=="ClusterRole" and 
    (.roleRef.name | startswith("system:psp:"))) | .metadata.name'
```

**2. Map PSP to PSS profile**
- Permissive PSP → Baseline
- Restrictive PSP → Restricted

**3. Enable Pod Security Admission**
- Add namespace labels
- Test in warn/audit mode

**4. Remove PodSecurityPolicy**
```bash
kubectl delete psp <psp-name>
kubectl delete clusterrole <psp-clusterrole>
kubectl delete clusterrolebinding <psp-binding>
```

---

## 🎯 Best Practices

### 1. Default to Baseline

**New namespaces:**
```yaml
pod-security.kubernetes.io/enforce: baseline
```

Start restrictive, loosen if needed.

---

### 2. Production = Restricted

**Always use restricted for production:**
```yaml
pod-security.kubernetes.io/enforce: restricted
```

---

### 3. Use All Three Modes

**Gradual rollout:**
```yaml
enforce: baseline    # What's enforced now
audit: restricted    # What you're monitoring
warn: restricted     # What users see
```

---

### 4. Exempt System Namespaces

```yaml
exemptions:
  namespaces:
  - kube-system
  - kube-public
  - kube-node-lease
```

---

### 5. Monitor Violations

**Check audit logs:**
```bash
kubectl logs -n kube-system <apiserver-pod> | \
  grep "pod-security"
```

---

### 6. Version Pin for Stability

```yaml
pod-security.kubernetes.io/enforce-version: v1.28
```

Prevents policy changes on upgrade.

---

## 📖 Key Takeaways

✅ PSS provides three standard security profiles
✅ Privileged (no restrictions) for system pods
✅ Baseline (minimal restrictions) for most workloads
✅ Restricted (hardened) for production
✅ Pod Security Admission enforces via namespace labels
✅ Three modes: enforce (block), audit (log), warn (notify)
✅ Use multiple modes for gradual rollout
✅ Replaced deprecated PodSecurityPolicy
✅ Apply via namespace labels
✅ Production should use restricted profile

---

## 🔗 Additional Resources

- [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
- [Pod Security Admission](https://kubernetes.io/docs/concepts/security/pod-security-admission/)
- [PSP Migration](https://kubernetes.io/docs/tasks/configure-pod-container/migrate-from-psp/)

---

## 🚀 Next Steps

1. Complete hands-on exercises in GUIDEME.md
2. Configure PSS for all namespaces
3. Test with different profiles
4. Implement gradual rollout
5. Monitor violations
6. Build compliant pod templates
7. Move to advanced security topics

**Happy Securing! 🔒**
