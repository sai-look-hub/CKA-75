# Day 47-48: Network Policies

## 📋 Overview

Welcome to Day 47-48! Today we master Kubernetes Network Policies - the key to implementing zero-trust networking. You'll learn how to control pod-to-pod communication, isolate namespaces, and build secure, segmented networks.

### What You'll Learn

- Understanding Network Policies
- Default allow vs deny-all patterns
- Pod-to-pod communication control
- Namespace isolation
- Ingress and egress rules
- Label-based selection
- Zero-trust networking principles
- Troubleshooting policy issues

---

## 🎯 Learning Objectives

By the end of this module, you will be able to:

1. Explain Network Policy concepts
2. Implement deny-all default policies
3. Create selective allow rules
4. Isolate namespaces
5. Control egress traffic
6. Debug policy enforcement
7. Implement zero-trust networking
8. Design secure network architectures

---

## 🌐 Network Policies Fundamentals

### The Problem: Default Allow-All

**Kubernetes Default Behavior:**
```
┌─────────────────────────────────────┐
│         Cluster Network              │
│                                      │
│  ANY pod can talk to ANY pod         │
│                                      │
│  ┌────────┐    ┌────────┐          │
│  │Frontend│───→│Backend │          │
│  └────────┘    └────────┘          │
│      │              │               │
│      └──────────────┴──────┐       │
│                             ↓       │
│                        ┌─────────┐  │
│                        │Database │  │
│                        └─────────┘  │
│                             ↑       │
│  ┌────────┐                │       │
│  │ Test   │────────────────┘       │
│  │ Pod    │ (Should NOT access!)   │
│  └────────┘                         │
└─────────────────────────────────────┘
```

**Security Risk:**
- Compromised pod can access everything
- No network segmentation
- Lateral movement easy
- Not zero-trust!

---

### The Solution: Network Policies

**With Network Policies:**
```
┌─────────────────────────────────────┐
│      Segmented Network               │
│                                      │
│  ┌────────┐    ┌────────┐          │
│  │Frontend│───→│Backend │ ✅       │
│  └────────┘    └────────┘          │
│      ↓              ↓               │
│      ✗         ┌─────────┐         │
│                │Database │         │
│                └─────────┘         │
│                     ↑               │
│  ┌────────┐        │               │
│  │ Test   │────────┘ ✗             │
│  │ Pod    │ (BLOCKED!)             │
│  └────────┘                         │
└─────────────────────────────────────┘
```

**Benefits:**
- Explicit allow rules
- Defense in depth
- Limit blast radius
- Zero-trust architecture

---

## 🔧 Network Policy Components

### Basic Structure

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: example-policy
  namespace: production
spec:
  podSelector:           # Which pods this applies to
    matchLabels:
      app: backend
  policyTypes:           # Ingress, Egress, or both
  - Ingress
  - Egress
  ingress:               # Incoming traffic rules
  - from:
    - podSelector:
        matchLabels:
          app: frontend
    ports:
    - protocol: TCP
      port: 8080
  egress:                # Outgoing traffic rules
  - to:
    - podSelector:
        matchLabels:
          app: database
    ports:
    - protocol: TCP
      port: 5432
```

---

### Key Concepts

**1. podSelector**
- Selects which pods the policy applies to
- Uses label matching
- Empty `{}` = all pods in namespace

**2. policyTypes**
- `Ingress`: Controls incoming traffic
- `Egress`: Controls outgoing traffic
- Can specify one or both

**3. Ingress Rules**
- Define allowed incoming connections
- Specify source pods/namespaces/IPs
- Define allowed ports/protocols

**4. Egress Rules**
- Define allowed outgoing connections
- Specify destination pods/namespaces/IPs
- Define allowed ports/protocols

---

## 🎯 Common Patterns

### Pattern 1: Deny-All Ingress

**Use Case:** Start with zero-trust.

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-ingress
spec:
  podSelector: {}  # All pods
  policyTypes:
  - Ingress
```

**Effect:**
- No ingress rules = deny all incoming
- Pods can't receive traffic
- Still can send traffic (egress not specified)

---

### Pattern 2: Deny-All Egress

**Use Case:** Prevent data exfiltration.

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-egress
spec:
  podSelector: {}
  policyTypes:
  - Egress
```

**Effect:**
- No egress rules = deny all outgoing
- Pods can't send traffic
- Can still receive (ingress not specified)

---

### Pattern 3: Deny-All (Complete Isolation)

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

**Effect:**
- Complete network isolation
- No traffic in or out
- Start of zero-trust implementation

---

### Pattern 4: Allow from Same Namespace

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-same-namespace
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector: {}  # Any pod in this namespace
```

---

### Pattern 5: Allow from Specific Namespace

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-prod
spec:
  podSelector:
    matchLabels:
      app: database
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          environment: production
    ports:
    - protocol: TCP
      port: 5432
```

---

## 🏗️ Building Zero-Trust Networks

### Step 1: Default Deny

**Apply to all namespaces:**
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

**Result:** Everything blocked!

---

### Step 2: Allow DNS

**Critical:** DNS must work for service discovery.

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: kube-system
    ports:
    - protocol: UDP
      port: 53
```

---

### Step 3: Allow Specific Traffic

**Example: 3-Tier App**

```yaml
# Frontend can access Backend
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-allow-frontend
spec:
  podSelector:
    matchLabels:
      tier: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          tier: frontend
    ports:
    - protocol: TCP
      port: 8080
---
# Backend can access Database
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: database-allow-backend
spec:
  podSelector:
    matchLabels:
      tier: database
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          tier: backend
    ports:
    - protocol: TCP
      port: 5432
```

**Result:**
- Frontend → Backend ✅
- Backend → Database ✅
- Frontend → Database ❌ (blocked)
- External → Database ❌ (blocked)

---

## 🔒 Advanced Patterns

### Namespace Isolation

**Problem:** Dev shouldn't access Prod.

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: namespace-isolation
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector: {}  # Only same namespace
```

---

### Allow Ingress Controller

**Allow traffic from Ingress:**

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-ingress-controller
spec:
  podSelector:
    matchLabels:
      app: web
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
    ports:
    - protocol: TCP
      port: 80
```

---

### Allow Monitoring

**Prometheus scraping:**

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-monitoring
spec:
  podSelector:
    matchLabels:
      monitored: "true"
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: monitoring
    ports:
    - protocol: TCP
      port: 9090
```

---

### Allow External Traffic

**Allow specific external IPs:**

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-external
spec:
  podSelector:
    matchLabels:
      app: api
  policyTypes:
  - Ingress
  ingress:
  - from:
    - ipBlock:
        cidr: 203.0.113.0/24  # Allowed IP range
        except:
        - 203.0.113.10/32     # Except this IP
    ports:
    - protocol: TCP
      port: 443
```

---

### Egress to External Services

**Allow external API calls:**

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-external-api
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Egress
  egress:
  - to:
    - ipBlock:
        cidr: 0.0.0.0/0  # Internet
    ports:
    - protocol: TCP
      port: 443
  - to:  # DNS (always needed!)
    - namespaceSelector:
        matchLabels:
          name: kube-system
    ports:
    - protocol: UDP
      port: 53
```

---

## 🎨 Selection Methods

### 1. podSelector

**Select by pod labels:**
```yaml
podSelector:
  matchLabels:
    app: backend
    version: v2
```

**Match expressions:**
```yaml
podSelector:
  matchExpressions:
  - key: environment
    operator: In
    values:
    - production
    - staging
```

---

### 2. namespaceSelector

**Select entire namespace:**
```yaml
namespaceSelector:
  matchLabels:
    environment: production
```

**Note:** Namespace must have label!
```bash
kubectl label namespace production environment=production
```

---

### 3. Combined Selectors

**AND operation:**
```yaml
ingress:
- from:
  - namespaceSelector:
      matchLabels:
        environment: production
    podSelector:
      matchLabels:
        app: frontend
```

**Means:** Pods with `app=frontend` in namespaces with `environment=production`

---

### 4. ipBlock

**CIDR ranges:**
```yaml
ingress:
- from:
  - ipBlock:
      cidr: 10.0.0.0/8
      except:
      - 10.0.1.0/24
```

---

## ⚠️ Important Considerations

### CNI Support Required

**Not all CNI plugins support Network Policies!**

**Supported:**
- ✅ Calico
- ✅ Cilium
- ✅ Weave Net
- ❌ Flannel (without Calico)

**Check support:**
```bash
# Create test policy
kubectl apply -f test-policy.yaml

# If no error = likely supported
# But verify with CNI documentation
```

---

### Policy Ordering

**Important:** Policies are additive (OR logic)!

```yaml
# Policy 1: Allow from frontend
ingress:
- from:
  - podSelector:
      matchLabels:
        app: frontend

---
# Policy 2: Allow from monitoring
ingress:
- from:
  - podSelector:
      matchLabels:
        app: monitoring
```

**Result:** Backend accepts from BOTH frontend AND monitoring.

---

### DNS Always Needed

**Don't forget DNS egress:**
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

Without DNS:
- Service names don't resolve
- Everything breaks!

---

## 🎯 Best Practices

### 1. Start with Deny-All

```yaml
# Apply first
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

Then add specific allows.

---

### 2. Use Descriptive Names

```yaml
# Good
name: frontend-to-backend-http
name: database-allow-from-api
name: deny-all-ingress

# Bad
name: policy-1
name: np-001
```

---

### 3. Document Policies

```yaml
metadata:
  name: backend-policy
  annotations:
    description: "Allows traffic from frontend to backend API"
    owner: "platform-team"
    last-updated: "2025-03-01"
```

---

### 4. Test Before Production

```bash
# Test in dev namespace first
kubectl apply -f policy.yaml -n dev

# Verify
kubectl exec test-pod -n dev -- curl backend

# Then apply to prod
kubectl apply -f policy.yaml -n production
```

---

### 5. Monitor and Alert

```bash
# Check policy existence
kubectl get networkpolicy -A

# Watch for pods without policies
kubectl get pods -A -l '!networkpolicy'
```

---

## 📖 Key Takeaways

✅ Default Kubernetes = allow-all (insecure)
✅ Network Policies enable zero-trust
✅ Start with deny-all, add specific allows
✅ Always allow DNS egress
✅ Requires CNI support (Calico, Cilium, Weave)
✅ Policies are additive (OR logic)
✅ Test before production
✅ Document and monitor

---

## 🔗 Additional Resources

- [Kubernetes Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [Network Policy Editor](https://editor.cilium.io/)
- [Calico Network Policy](https://docs.tigera.io/calico/latest/network-policy/)

---

## 🚀 Next Steps

1. Complete hands-on exercises in GUIDEME.md
2. Implement deny-all policies
3. Create selective allow rules
4. Test policy enforcement
5. Build zero-trust architecture
6. Move to next topic: Advanced Kubernetes

**Happy Securing! 🔒**
