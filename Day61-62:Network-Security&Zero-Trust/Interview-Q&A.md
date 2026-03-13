# 🎤 Interview Q&A: Network Security & Zero-Trust

## Q1: What is zero-trust network architecture?

**Answer:**

**Zero-Trust:** Security model that assumes breach and verifies every request.

**Principle:** "Never trust, always verify"

**Key components:**

**1. Identity-based authentication**
- Every service has unique identity
- mTLS certificates
- Not IP-based

**2. Least privilege access**
- Deny all by default
- Explicit allow rules
- Minimal permissions

**3. Encrypt everything**
- All traffic encrypted (mTLS)
- No plaintext communication
- TLS 1.2+ minimum

**4. Continuous verification**
- Every request authenticated
- Every request authorized
- Continuous monitoring

**Contrast with traditional:**
```
Traditional: Castle & moat
- Perimeter security
- Inside = trusted
- Once in, free access

Zero-Trust: Verify everything
- No trust by default
- Every connection verified
- Defense in depth
```

---

## Q2: How does mTLS work and why is it important?

**Answer:**

**mTLS (Mutual TLS):** Both client and server verify each other.

**Traditional TLS (HTTPS):**
- Client verifies server
- One-way authentication
- Server identity confirmed

**Mutual TLS:**
- Client verifies server
- Server verifies client
- Two-way authentication
- Both identities confirmed

**How it works:**
```
1. Handshake:
   Service A → Certificate (signed by CA)
   Service B → Certificate (signed by CA)

2. Verification:
   A verifies B's cert against CA
   B verifies A's cert against CA

3. Encrypted connection:
   All traffic encrypted with TLS 1.2+
```

**Why important:**

**Without mTLS:**
- No encryption between services
- No identity verification
- Easy to intercept
- Easy to impersonate

**With mTLS:**
✅ Traffic encrypted
✅ Identity verified
✅ Cannot intercept without cert
✅ Cannot impersonate without private key

**In Kubernetes:**
- Service mesh handles mTLS automatically
- Transparent to application
- Automatic certificate rotation

---

## Q3: What's the difference between Network Policies and Service Mesh authorization?

**Answer:**

**Network Policies (L3-4):**
- IP and port-based
- Layer 3-4 (Network/Transport)
- No encryption
- Kubernetes-native
- Simple to implement

**Example:**
```yaml
# Allow from pod with label X to port 80
ingress:
- from:
  - podSelector:
      matchLabels:
        app: frontend
  ports:
  - port: 80
```

**Service Mesh Authorization (L7):**
- Identity and HTTP-based
- Layer 7 (Application)
- Includes mTLS
- Requires service mesh
- More complex

**Example:**
```yaml
# Allow from specific ServiceAccount to GET /api
rules:
- from:
  - source:
      principals:
      - "cluster.local/ns/prod/sa/frontend"
  to:
  - operation:
      methods: ["GET"]
      paths: ["/api/*"]
```

**Comparison:**

| Feature | Network Policy | Service Mesh |
|---------|---------------|--------------|
| Layer | L3-4 | L7 |
| Based on | IP/Port | Identity/HTTP |
| Encryption | ❌ | ✅ mTLS |
| HTTP rules | ❌ | ✅ Methods/paths |
| Complexity | Simple | Complex |

**Best practice: Use BOTH**
- Network Policies: Foundation
- Service Mesh: Advanced features

---

## Q4: How do you implement zero-trust in Kubernetes?

**Answer:**

**Four-layer approach:**

**Layer 1: Network Policies**
```yaml
# Deny all by default
spec:
  podSelector: {}
  policyTypes: [Ingress, Egress]

# Explicit allows only
# DNS egress
# Tier-to-tier communication
```

**Layer 2: Service Mesh (mTLS)**
```yaml
# Install Istio/Linkerd
# Enable sidecar injection
# Configure strict mTLS
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
spec:
  mtls:
    mode: STRICT
```

**Layer 3: Authorization Policies**
```yaml
# Deny all
spec: {}

# Identity-based allows
rules:
- from:
  - source:
      principals: ["cluster.local/ns/prod/sa/app"]
```

**Layer 4: Monitoring**
```
- Prometheus metrics
- Jaeger tracing
- Kiali visualization
- Audit logging
```

**Implementation steps:**

1. Deploy Network Policies first
2. Install service mesh
3. Enable sidecar injection gradually
4. Configure mTLS (permissive → strict)
5. Add authorization policies
6. Enable monitoring
7. Continuous validation

**Result:** Defense in depth with multiple security layers.

---

## Q5: What are the challenges of implementing service mesh?

**Answer:**

**Challenges:**

**1. Complexity**
- Many new concepts
- Steep learning curve
- More moving parts

**2. Performance overhead**
- Sidecar proxy latency (2-5ms typical)
- Memory per pod (~50MB for Envoy)
- CPU usage

**3. Debugging**
- Multiple layers (app + proxy)
- Complex traffic routing
- Certificate issues

**4. Operational burden**
- Monitoring required
- Upgrade complexity
- Configuration management

**5. Resource usage**
- Sidecar per pod
- Control plane components
- Increased cluster size

**Mitigation strategies:**

**Start small:**
- One namespace first
- Non-critical services
- Gradual rollout

**Use permissive mode:**
- Allow both mTLS and plaintext
- Migrate gradually
- Test thoroughly

**Invest in monitoring:**
- Understand traffic patterns
- Detect issues early
- Performance baselines

**Training:**
- Team education
- Documentation
- Runbooks

**When to use service mesh:**

✅ Microservices architecture
✅ Need mTLS encryption
✅ Complex traffic routing
✅ Advanced observability
✅ Large scale (50+ services)

❌ Simple deployments
❌ Monolithic apps
❌ Limited resources
❌ Small teams

**Alternative:** Start with Network Policies, add service mesh when needed.
