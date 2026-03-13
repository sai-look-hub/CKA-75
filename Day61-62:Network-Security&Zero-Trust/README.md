# Day 61-62: Network Security & Zero-Trust

## 📋 Overview

Welcome to Day 61-62! Today we master Network Security in Kubernetes - implementing zero-trust networking, mTLS encryption, and service mesh security. You'll build a production-grade secure network architecture that assumes breach and verifies everything.

### What You'll Learn

- Zero-trust network architecture
- Advanced Network Policies
- mTLS (mutual TLS) encryption
- Service mesh security (Istio/Linkerd)
- Identity-based authentication
- Traffic encryption end-to-end
- Authorization policies
- Building secure microservices

---

## 🎯 Learning Objectives

By the end of this module, you will be able to:

1. Implement zero-trust network architecture
2. Configure advanced Network Policies
3. Deploy mTLS for service-to-service encryption
4. Set up service mesh security
5. Implement identity-based authentication
6. Create authorization policies
7. Monitor encrypted traffic
8. Build production-ready secure networks

---

## 🔐 Zero-Trust Network Architecture

### Traditional Network Security

```
┌─────────────────────────────────────┐
│     Traditional "Castle & Moat"     │
├─────────────────────────────────────┤
│                                      │
│  Perimeter Security                 │
│  ↓                                   │
│  ┌─────────────────────┐            │
│  │   Firewall          │            │
│  └──────────┬──────────┘            │
│             ↓                        │
│  Inside = Trusted ✅                │
│  Outside = Untrusted ❌             │
│                                      │
│  Problem:                           │
│  - Once inside, full access         │
│  - Lateral movement easy            │
│  - Assumes internal = safe          │
└─────────────────────────────────────┘
```

---

### Zero-Trust Architecture

```
┌─────────────────────────────────────┐
│        Zero-Trust Network            │
├─────────────────────────────────────┤
│                                      │
│  "Never Trust, Always Verify"       │
│                                      │
│  Every connection:                  │
│  1. Authenticated (mTLS)            │
│  2. Authorized (Policies)           │
│  3. Encrypted (TLS 1.2+)           │
│  4. Monitored (Logs/Metrics)        │
│                                      │
│  Principles:                        │
│  ✅ Verify identity                │
│  ✅ Least privilege access          │
│  ✅ Assume breach                   │
│  ✅ Encrypt everything              │
│  ✅ Inspect and log all traffic     │
└─────────────────────────────────────┘
```

---

### Zero-Trust Components

**1. Identity**
- Every service has unique identity
- Certificate-based (mTLS)
- Short-lived credentials

**2. Authentication**
- mTLS for service-to-service
- Verify both sides of connection
- Cryptographic proof of identity

**3. Authorization**
- Policy-based access control
- Deny by default
- Explicit allow rules

**4. Encryption**
- All traffic encrypted in transit
- TLS 1.2+ minimum
- No plaintext communication

**5. Monitoring**
- Log all connections
- Detect anomalies
- Audit compliance

---

## 🛡️ Network Policies (Advanced)

### Beyond Basic Policies

**Review: Basic deny-all + allow specific**

**Advanced patterns:**
- Multi-tier applications
- Namespace isolation with exceptions
- External traffic control
- DNS egress management
- IP-based rules
- Port-specific policies

---

### Pattern 1: Complete Three-Tier Isolation

```yaml
# Deny all by default
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress

---
# Allow DNS
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
  namespace: production
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

---
# Frontend → Backend only
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: frontend-to-backend
  namespace: production
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
# Backend → Database only
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-to-database
  namespace: production
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
```
Frontend ✅ Backend ✅ Database
Frontend ❌ Database
External ❌ All (except via Ingress)
```

---

### Pattern 2: Namespace Isolation with Cross-Namespace Access

```yaml
# Prod namespace can access shared services
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-shared-services
  namespace: shared-services
spec:
  podSelector:
    matchLabels:
      shared: "true"
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          environment: production
    ports:
    - protocol: TCP
      port: 6379  # Redis
```

---

### Pattern 3: External API Access Control

```yaml
# Allow egress to specific external IPs
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-external-api
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: payment-service
  policyTypes:
  - Egress
  egress:
  - to:
    - ipBlock:
        cidr: 52.1.2.3/32  # Stripe API
    ports:
    - protocol: TCP
      port: 443
  - to:
    - ipBlock:
        cidr: 34.5.6.7/32  # PayPal API
    ports:
    - protocol: TCP
      port: 443
```

---

## 🔒 mTLS (Mutual TLS)

### What is mTLS?

**Traditional TLS:**
- Client verifies server (HTTPS)
- One-way authentication
- Server identity verified

**Mutual TLS (mTLS):**
- Both client AND server verify each other
- Two-way authentication
- Cryptographic proof of identity
- Used for service-to-service communication

---

### mTLS Flow

```
Service A ←→ Service B

1. Handshake:
   A: "Here's my certificate (signed by CA)"
   B: "Here's my certificate (signed by CA)"

2. Verification:
   A: Verifies B's certificate against CA
   B: Verifies A's certificate against CA

3. Both verified:
   ✅ Identity confirmed
   ✅ Encrypted connection established

4. Communication:
   All traffic encrypted with TLS 1.2+
```

---

### Why mTLS?

**Without mTLS:**
```
Service A → Service B (HTTP plaintext)
- No encryption 😱
- No identity verification 😱
- Easy to intercept 😱
- Easy to impersonate 😱
```

**With mTLS:**
```
Service A → Service B (mTLS)
✅ Encrypted in transit
✅ Identity verified
✅ Cannot intercept (without cert)
✅ Cannot impersonate (need private key)
```

---

## 🕸️ Service Mesh Security

### What is a Service Mesh?

**Definition:** Infrastructure layer that handles service-to-service communication.

**Common implementations:**
- **Istio** - Full-featured, complex
- **Linkerd** - Lightweight, simpler
- **Consul** - HashiCorp ecosystem

---

### Service Mesh Architecture

```
┌─────────────────────────────────────────┐
│         Service Mesh (Istio)             │
├─────────────────────────────────────────┤
│                                          │
│  Service A Pod                           │
│  ┌──────────────┐                       │
│  │  App         │                       │
│  ├──────────────┤                       │
│  │  Envoy Proxy │←─────┐               │
│  └──────────────┘      │               │
│         ↕ mTLS          │               │
│  Service B Pod          │               │
│  ┌──────────────┐      │               │
│  │  App         │      │               │
│  ├──────────────┤      │               │
│  │  Envoy Proxy │←─────┘               │
│  └──────────────┘                       │
│         ↑                                │
│         │                                │
│  Control Plane (istiod)                 │
│  - Certificate management               │
│  - Configuration distribution           │
│  - Service discovery                    │
└─────────────────────────────────────────┘
```

---

### Istio Security Features

**1. Automatic mTLS**
- Sidecar proxies (Envoy) handle TLS
- Apps communicate over localhost
- Transparent to application code

**2. Identity (SPIFFE)**
- Every service gets unique identity
- Based on ServiceAccount
- Format: `spiffe://cluster.local/ns/namespace/sa/serviceaccount`

**3. Certificate Management**
- Automatic certificate issuance
- Rotation (default: 24 hours)
- No manual cert management

**4. Authorization Policies**
- Fine-grained access control
- Layer 7 (HTTP) rules
- Source identity-based

---

### Istio mTLS Configuration

**Strict mTLS (recommended):**
```yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: production
spec:
  mtls:
    mode: STRICT  # Only mTLS traffic allowed
```

**Permissive mTLS (migration):**
```yaml
spec:
  mtls:
    mode: PERMISSIVE  # Both mTLS and plaintext allowed
```

---

### Istio Authorization Policies

**Deny by default:**
```yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: deny-all
  namespace: production
spec:
  {}  # Empty = deny all
```

**Allow specific access:**
```yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: frontend-to-backend
  namespace: production
spec:
  selector:
    matchLabels:
      app: backend
  action: ALLOW
  rules:
  - from:
    - source:
        principals:
        - "cluster.local/ns/production/sa/frontend-sa"
    to:
    - operation:
        methods: ["GET", "POST"]
        paths: ["/api/*"]
```

**Benefits:**
- Identity-based (not IP-based)
- HTTP-level rules (methods, paths)
- More granular than Network Policies

---

## 🎯 Zero-Trust Implementation

### Complete Zero-Trust Stack

**Layer 1: Network Policies**
- Deny all by default
- Explicit allow rules
- IP/port-based filtering

**Layer 2: mTLS (Service Mesh)**
- Encrypt all service-to-service traffic
- Verify identities cryptographically
- Automatic certificate rotation

**Layer 3: Authorization**
- Identity-based access control
- HTTP-level policies
- Deny by default

**Layer 4: Monitoring**
- Log all connections
- Metrics on traffic
- Anomaly detection

---

### Implementation Architecture

```
┌─────────────────────────────────────────┐
│     Zero-Trust Implementation            │
├─────────────────────────────────────────┤
│                                          │
│  1. Network Policies                    │
│     └─ Deny all                         │
│     └─ Allow DNS                        │
│     └─ Allow specific tier-to-tier      │
│                                          │
│  2. Service Mesh (Istio)                │
│     └─ Automatic mTLS                   │
│     └─ Certificate rotation             │
│     └─ Identity per service             │
│                                          │
│  3. Authorization Policies              │
│     └─ Deny all by default              │
│     └─ Identity-based allows            │
│     └─ HTTP method/path rules           │
│                                          │
│  4. Monitoring                          │
│     └─ Prometheus metrics               │
│     └─ Jaeger tracing                   │
│     └─ Kiali visualization              │
└─────────────────────────────────────────┘
```

---

## 📊 Comparison: Network Policies vs Service Mesh

| Feature | Network Policy | Service Mesh |
|---------|---------------|--------------|
| OSI Layer | Layer 3-4 (IP/Port) | Layer 7 (HTTP) |
| Encryption | ❌ | ✅ mTLS |
| Identity | IP/Label-based | Certificate-based |
| Traffic control | Port-level | HTTP method/path |
| Complexity | Simple | Complex |
| Performance | Minimal overhead | Proxy overhead |
| HTTP rules | ❌ | ✅ |
| Observability | Limited | Rich metrics |
| When to use | Always (baseline) | Advanced features |

**Best practice:** Use BOTH
- Network Policies: Foundation
- Service Mesh: Advanced features

---

## 🔧 Best Practices

### 1. Defense in Depth

**Multiple layers:**
```
1. Network Policies (L3-4)
2. mTLS (Encryption)
3. Authorization (L7)
4. RBAC (API access)
5. Pod Security (Container security)
```

Don't rely on just one!

---

### 2. Start with Network Policies

**Before service mesh:**
```yaml
# Always start here
- Default deny-all
- Explicit allows
- Test thoroughly
```

Service mesh adds on top.

---

### 3. Gradual Service Mesh Adoption

**Permissive mode first:**
```yaml
mtls:
  mode: PERMISSIVE  # Allow both mTLS and plaintext
```

**Then strict:**
```yaml
mtls:
  mode: STRICT  # Only mTLS
```

Migrate one namespace at a time.

---

### 4. Identity-Based Authorization

**Don't use IPs:**
```yaml
# ❌ BAD: IP-based
- from:
  - ipBlock:
      cidr: 10.1.2.0/24
```

**Use identities:**
```yaml
# ✅ GOOD: Identity-based
- from:
  - source:
      principals:
      - "cluster.local/ns/prod/sa/frontend"
```

---

### 5. Monitor Everything

**Metrics to track:**
- mTLS success rate
- Policy violations
- Connection denials
- Certificate expiration
- Latency (p50, p95, p99)

---

### 6. Automate Certificate Rotation

**Service mesh handles this!**
- Default rotation: 24 hours
- No manual intervention
- Automatic renewal

---

## 📖 Key Takeaways

✅ Zero-trust = "Never trust, always verify"
✅ Network Policies provide L3-4 security
✅ mTLS encrypts and authenticates service-to-service
✅ Service mesh automates security
✅ Use defense in depth (multiple layers)
✅ Identity-based > IP-based
✅ Start with Network Policies, add service mesh
✅ Monitor all traffic
✅ Gradual rollout for service mesh
✅ Production = zero-trust architecture

---

## 🔗 Additional Resources

- [Istio Security](https://istio.io/latest/docs/concepts/security/)
- [Zero Trust Networks (Book)](https://www.oreilly.com/library/view/zero-trust-networks/9781491962183/)
- [NIST Zero Trust Architecture](https://www.nist.gov/publications/zero-trust-architecture)

---

## 🚀 Next Steps

1. Complete hands-on exercises in GUIDEME.md
2. Implement Network Policies
3. Deploy service mesh (Istio)
4. Configure mTLS
5. Create authorization policies
6. Monitor encrypted traffic
7. Build production zero-trust network

**Happy Securing! 🔒**
