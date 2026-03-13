# 🎤 Interview Q&A: Pod Security Standards

## Q1: What are Pod Security Standards and why were they introduced?

**Answer:**

**Pod Security Standards (PSS):** Kubernetes-native way to enforce security policies using three predefined profiles.

**Why introduced:**
- Replace deprecated PodSecurityPolicy
- Provide standard security profiles
- Easier to understand and implement
- Built-in admission controller
- Consistent across clusters

**Three profiles:**
1. **Privileged:** No restrictions (system components)
2. **Baseline:** Prevent known escalations (default)
3. **Restricted:** Hardened best practices (production)

**Enforced by:** Pod Security Admission controller via namespace labels.

**Example:**
```yaml
metadata:
  labels:
    pod-security.kubernetes.io/enforce: restricted
```

**Benefits:**
- No complex policies to write
- Standard profiles
- Easy migration
- Built into Kubernetes

---

## Q2: Explain the three security profiles.

**Answer:**

**1. Privileged:**
- No restrictions
- Allows everything
- Use for: System components (CNI, CSI, monitoring)
- Example: kube-system namespace

**2. Baseline:**
- Prevents known privilege escalations
- Minimal restrictions
- Blocks: privileged containers, host namespaces, dangerous capabilities
- Allows: Running as root, some capabilities
- Use for: Most applications, development

**3. Restricted:**
- Current pod hardening best practices
- Maximum security
- Requires:
  - runAsNonRoot: true
  - allowPrivilegeEscalation: false
  - Drop ALL capabilities
  - Seccomp profile
- Use for: Production workloads

**Comparison:**
```
Privileged: Everything allowed
Baseline:   Major violations blocked
Restricted: Hardened security required
```

---

## Q3: How do you enforce Pod Security Standards?

**Answer:**

**Via namespace labels** using Pod Security Admission controller.

**Three modes:**

**1. enforce:**
- Blocks non-compliant pods
- Pod creation fails
```yaml
pod-security.kubernetes.io/enforce: restricted
```

**2. audit:**
- Logs violations to audit log
- Doesn't block pods
```yaml
pod-security.kubernetes.io/audit: restricted
```

**3. warn:**
- Shows warnings to user
- Doesn't block pods
```yaml
pod-security.kubernetes.io/warn: restricted
```

**Use all three together:**
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    pod-security.kubernetes.io/enforce: baseline
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

This:
- Enforces baseline now
- Audits against restricted (monitoring)
- Warns users about restricted violations
- Allows gradual migration

---

## Q4: What are the requirements for restricted profile?

**Answer:**

**Pod-level requirements:**
```yaml
spec:
  securityContext:
    runAsNonRoot: true          # Must not run as root
    seccompProfile:
      type: RuntimeDefault      # Seccomp required
```

**Container-level requirements:**
```yaml
securityContext:
  allowPrivilegeEscalation: false  # No escalation
  capabilities:
    drop:
    - ALL                          # Drop all capabilities
```

**Complete example:**
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
    image: nginx
    securityContext:
      allowPrivilegeEscalation: false
      runAsNonRoot: true
      capabilities:
        drop: [ALL]
```

**All fields required!** Missing any = rejected.

---

## Q5: How do you migrate from PodSecurityPolicy to PSS?

**Answer:**

**PodSecurityPolicy (PSP):**
- Deprecated: Kubernetes 1.21
- Removed: Kubernetes 1.25
- Complex, hard to use

**Migration steps:**

**1. Audit current PSP:**
```bash
kubectl get podsecuritypolicies
# List all PSPs in use
```

**2. Map PSP to PSS profile:**
- Permissive PSP → Baseline or Privileged
- Restrictive PSP → Restricted

**3. Test with warn/audit mode:**
```yaml
pod-security.kubernetes.io/audit: restricted
pod-security.kubernetes.io/warn: restricted
# Don't enforce yet!
```

**4. Fix violations:**
- Update pod specs
- Add security contexts
- Test deployments

**5. Enable enforcement:**
```yaml
pod-security.kubernetes.io/enforce: restricted
```

**6. Remove PSP:**
```bash
kubectl delete psp <psp-name>
kubectl delete clusterrole <psp-role>
kubectl delete clusterrolebinding <psp-binding>
```

**Best practice:**
- Start with audit/warn
- Gradually enforce
- Test thoroughly
