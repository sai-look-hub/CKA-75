# 🎤 Interview Q&A: Network Policies

## Q1: What are Network Policies and why are they important?

**Answer:**

Network Policies control pod-to-pod communication in Kubernetes.

**Default Behavior:**
- ANY pod can talk to ANY pod
- No network segmentation
- Security risk!

**With Network Policies:**
- Explicit allow rules
- Default deny
- Zero-trust networking
- Limit blast radius

**Importance:**
1. **Security:** Prevent lateral movement
2. **Compliance:** Meet regulatory requirements
3. **Isolation:** Separate environments
4. **Defense in Depth:** Multiple security layers

---

## Q2: Explain ingress vs egress rules.

**Answer:**

**Ingress:**
- Controls incoming traffic
- Who can connect TO this pod
- Use: Protect backend from unauthorized access

**Egress:**
- Controls outgoing traffic
- What this pod can connect TO
- Use: Prevent data exfiltration

**Example:**
```yaml
ingress:
- from:
  - podSelector:
      matchLabels:
        app: frontend
  # Frontend can connect to me

egress:
- to:
  - podSelector:
      matchLabels:
        app: database
  # I can connect to database
```

---

## Q3: How do you implement zero-trust networking?

**Answer:**

**Steps:**

1. **Default Deny:**
```yaml
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

2. **Allow DNS:**
```yaml
egress:
- to:
  - namespaceSelector:
      matchLabels:
        name: kube-system
  ports:
  - protocol: UDP
    port: 53
```

3. **Explicit Allows:**
```yaml
# Only allow specific traffic
ingress:
- from:
  - podSelector:
      matchLabels:
        app: frontend
```

4. **Test & Verify**
5. **Monitor & Audit**

---

## Q4: What CNI plugins support Network Policies?

**Answer:**

**Supported:**
- ✅ Calico
- ✅ Cilium
- ✅ Weave Net
- ❌ Flannel (without Calico addon)

**Check:**
```bash
kubectl get pods -n kube-system
# Look for calico/cilium/weave pods
```

Without CNI support, policies are ignored!

---

## Q5: How are multiple policies combined?

**Answer:**

Policies are **additive (OR logic)**.

**Example:**
```yaml
# Policy 1: Allow frontend
ingress:
- from:
  - podSelector:
      matchLabels:
        app: frontend

# Policy 2: Allow monitoring
ingress:
- from:
  - podSelector:
      matchLabels:
        app: monitoring
```

**Result:** Pod accepts from BOTH frontend AND monitoring.

**Not:** Only one or the other.
