# 🎤 Interview Q&A: Security Capstone - Day 68-69

## Q1: How do you implement zero-trust networking in Kubernetes?

**Answer:**

**Zero-trust** = "Never trust, always verify"

**Implementation:**

**1. Default Deny All**
```yaml
spec:
  podSelector: {}
  policyTypes: [Ingress, Egress]
# No rules = deny everything
```

**2. Explicit Allows Only**
```yaml
# Frontend → Backend only
spec:
  podSelector:
    matchLabels:
      tier: backend
  ingress:
  - from:
    - podSelector:
        matchLabels:
          tier: frontend
```

**3. DNS Egress**
Always allow DNS to kube-system

**4. No Direct External Access**
All external through controlled egress

**Result:** Every connection explicitly allowed.

---

## Q2: What's the complete RBAC strategy for a multi-tier app?

**Answer:**

**Strategy: Least Privilege**

**ServiceAccounts:**
- One per tier (frontend-sa, backend-sa)
- Never use default SA

**Roles:**
- Namespace-scoped
- Specific resources only
- Minimal verbs

**Example:**
```yaml
# Backend needs secrets
rules:
- resources: ["secrets"]
  resourceNames: ["db-credentials"]  # Specific!
  verbs: ["get"]  # Not "list", "*"
```

**Best Practices:**
- Review quarterly
- Test with can-i
- Document decisions

---

## Q3: How do you validate Pod Security Standards compliance?

**Answer:**

**Validation Steps:**

**1. Check PSS Labels**
```bash
kubectl get ns secureshop -o yaml | grep pod-security
```

**2. Verify All Pods Non-Root**
```bash
kubectl get pods -n secureshop -o json | \
  jq '.items[].spec.securityContext.runAsUser'
# All should be 1000+
```

**3. Check Capabilities**
```bash
kubectl get pods -n secureshop -o json | \
  jq '.items[].spec.containers[].securityContext.capabilities'
# Should show drop: [ALL]
```

**4. Test Enforcement**
```bash
# Try to deploy non-compliant pod
kubectl run bad --image=nginx -n secureshop
# Should be rejected
```

---

## Q4: What's a complete secrets management strategy?

**Answer:**

**Never:**
- Commit to Git
- Hardcode in images
- Pass as env variables (use secretRef)

**Use:**
1. External Secrets Operator
2. Sealed Secrets for GitOps
3. Encryption at rest (KMS)

**RBAC:**
```yaml
# Only specific SAs read specific secrets
rules:
- resources: ["secrets"]
  resourceNames: ["db-credentials"]
  verbs: ["get"]
```

**Rotation:**
- Automated via External Secrets
- Regular schedule (30-90 days)

---

## Q5: How do you audit security posture?

**Answer:**

**Audit Commands:**

**RBAC:**
```bash
kubectl get sa,roles,rolebindings -n secureshop
```

**Network Policies:**
```bash
kubectl get networkpolicies -n secureshop
```

**Pod Security:**
```bash
# All non-root?
kubectl get pods -n secureshop -o json | \
  jq '.items[].spec.securityContext.runAsUser'
```

**Secrets:**
```bash
# None in Git?
git log --all -- '*.yaml' | grep -i password
# Should be empty
```

**Images:**
```bash
# All scanned?
kubectl get pods -n secureshop -o json | \
  jq -r '.items[].spec.containers[].image' | \
  xargs trivy image
```

**Regular Schedule:**
- Weekly: Automated scans
- Monthly: Manual review
- Quarterly: Full audit
