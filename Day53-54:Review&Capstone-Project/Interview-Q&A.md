# 🎤 Interview Q&A: Week 7-8 Review

## Q1: Explain the architecture of your capstone project.

**Answer:**

**Architecture:** 3-tier e-commerce microservices platform

**Components:**
1. **Frontend** - Web interface (Nginx)
2. **Backend API** - Business logic (REST API)
3. **Admin Panel** - Management interface
4. **Database** - PostgreSQL (internal only)

**Networking:**
- **Ingress:** NGINX with path-based routing
  - `/` → Frontend
  - `/api` → Backend
  - `/admin` → Admin panel
- **TLS:** Automatic HTTPS with cert-manager
- **Network Policies:** Zero-trust (default deny-all)

**Security:**
- Frontend ✅ Backend
- Backend ✅ Database
- Frontend ❌ Database (blocked)
- All ✅ DNS
- External ❌ Except via Ingress

---

## Q2: How did you implement zero-trust networking?

**Answer:**

**Step-by-step approach:**

**1. Default Deny:**
```yaml
spec:
  podSelector: {}  # All pods
  policyTypes:
  - Ingress
  - Egress
# No rules = deny all
```

**2. Allow DNS (critical):**
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

**3. Tier-based policies:**
- Frontend: Accepts from Ingress, sends to Backend
- Backend: Accepts from Frontend, sends to Database
- Database: Accepts only from Backend

**4. Verification:**
```bash
# Tested blocked paths
kubectl exec frontend -- curl database  # Timeout ✅
```

**Result:** Only explicitly allowed traffic flows.

---

## Q3: What would you do if services couldn't communicate?

**Answer:**

**Systematic troubleshooting (LADDER):**

**1. List symptoms:**
- Which services?
- Error message?
- When started?

**2. Ask questions:**
- What changed?
- Does DNS work?
- Network policies involved?

**3. Diagnose layer-by-layer:**

**Layer 1: Pod connectivity**
```bash
kubectl exec pod-a -- ping <pod-b-ip>
```
If fails → CNI issue

**Layer 2: DNS**
```bash
kubectl exec pod-a -- nslookup service-b
```
If fails → DNS/CoreDNS issue

**Layer 3: Service**
```bash
kubectl get endpoints service-b
```
If empty → No backend pods

**Layer 4: Network Policy**
```bash
kubectl get networkpolicy
```
Check if blocking

**4. Document & Execute fix**
**5. Review & prevent**

---

## Q4: How does Ingress routing work in your project?

**Answer:**

**Path-based routing with rewrite:**

```yaml
- path: /()(.*)
  # Frontend: /anything → /anything
  
- path: /api(/|$)(.*)
  # Backend: /api/users → /users
  
- path: /admin(/|$)(.*)
  # Admin: /admin/dashboard → /dashboard
```

**Rewrite annotation:**
```yaml
nginx.ingress.kubernetes.io/rewrite-target: /$2
```

**Flow:**
1. Client: `https://ecommerce.example.com/api/users`
2. Ingress: Terminates TLS
3. Matches path: `/api`
4. Rewrites to: `/users`
5. Routes to: `backend:8080/users`
6. Response returns

**TLS:**
- cert-manager auto-provisions Let's Encrypt
- HTTP → HTTPS redirect automatic

---

## Q5: What did you learn from this project?

**Answer:**

**Technical skills:**
1. **Network architecture design**
   - Zero-trust principles
   - Defense in depth
   - Least privilege access

2. **Ingress configuration**
   - Path-based routing
   - TLS automation
   - Annotation usage

3. **Network policies**
   - Default deny pattern
   - Label-based selection
   - Egress control

4. **Troubleshooting**
   - Systematic methodology
   - Layer-by-layer diagnosis
   - Using debug tools

**Best practices:**
- Test incrementally
- Document everything
- Verify security controls
- Monitor continuously

**Real-world skills:**
- Production-ready deployments
- Security-first design
- Comprehensive testing
- Incident response
