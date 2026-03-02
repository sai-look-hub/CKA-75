# 📖 GUIDEME: Network Policies - Complete Walkthrough

## 🎯 16-Hour Learning Path

**Day 1:** Basics, deny-all, simple allows (8 hours)
**Day 2:** Zero-trust, namespace isolation, advanced patterns (8 hours)

---

## Phase 1: The Dangerous Default (2 hours)

### Step 1: Understand Default Behavior

```bash
# Create test namespace
kubectl create namespace test-network

# Deploy 3 pods
kubectl run frontend -n test-network --image=nginx --labels=tier=frontend
kubectl run backend -n test-network --image=nginx --labels=tier=backend
kubectl run database -n test-network --image=nginx --labels=tier=database

# Get IPs
kubectl get pods -n test-network -o wide
```

### Step 2: Test Default Allow-All

```bash
# Get backend IP
BACKEND_IP=$(kubectl get pod backend -n test-network -o jsonpath='{.status.podIP}')
DB_IP=$(kubectl get pod database -n test-network -o jsonpath='{.status.podIP}')

# Frontend can access backend (expected)
kubectl exec frontend -n test-network -- curl -s $BACKEND_IP

# Frontend can access database (SECURITY RISK!)
kubectl exec frontend -n test-network -- curl -s $DB_IP

echo "❌ Any pod can access any pod = INSECURE"
```

**✅ Checkpoint:** Understood default allow-all behavior.

---

## Phase 2: Deny-All Policies (2 hours)

### Step 1: Apply Deny-All Ingress

```bash
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-ingress
  namespace: test-network
spec:
  podSelector: {}
  policyTypes:
  - Ingress
EOF

# Test: Nothing can reach backend now
kubectl exec frontend -n test-network -- timeout 5 curl $BACKEND_IP
# Should timeout!

echo "✅ Deny-all ingress working!"
```

### Step 2: Apply Deny-All Egress

```bash
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-egress
  namespace: test-network
spec:
  podSelector: {}
  policyTypes:
  - Egress
EOF

# Test: Frontend can't reach anything
kubectl exec frontend -n test-network -- timeout 5 curl $BACKEND_IP
# Should fail!

echo "✅ Deny-all egress working!"
```

**✅ Checkpoint:** Complete network isolation achieved.

---

## Phase 3: Selective Allow Rules (3 hours)

### Step 1: Allow DNS (Critical!)

```bash
# Label kube-system namespace
kubectl label namespace kube-system name=kube-system

# Allow DNS
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
  namespace: test-network
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
EOF

# Test DNS
kubectl exec frontend -n test-network -- nslookup kubernetes.default
# Should work!
```

### Step 2: Allow Frontend → Backend

```bash
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-allow-frontend
  namespace: test-network
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
      port: 80
EOF

# Allow frontend egress to backend
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: frontend-egress
  namespace: test-network
spec:
  podSelector:
    matchLabels:
      tier: frontend
  policyTypes:
  - Egress
  egress:
  - to:
    - podSelector:
        matchLabels:
          tier: backend
    ports:
    - protocol: TCP
      port: 80
  - to:
    - namespaceSelector:
        matchLabels:
          name: kube-system
    ports:
    - protocol: UDP
      port: 53
EOF

# Test: Frontend → Backend should work
kubectl exec frontend -n test-network -- curl -s $BACKEND_IP
# Works! ✅

# Test: Frontend → Database should fail
kubectl exec frontend -n test-network -- timeout 5 curl $DB_IP
# Timeout! ✅
```

**✅ Checkpoint:** Selective communication working.

---

## Phase 4: Three-Tier Architecture (2 hours)

### Complete Zero-Trust Setup

```bash
# 1. Frontend receives from ingress, sends to backend
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: frontend-policy
  namespace: test-network
spec:
  podSelector:
    matchLabels:
      tier: frontend
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
  egress:
  - to:
    - podSelector:
        matchLabels:
          tier: backend
    ports:
    - protocol: TCP
      port: 80
  - to:
    - namespaceSelector:
        matchLabels:
          name: kube-system
    ports:
    - protocol: UDP
      port: 53
EOF

# 2. Backend receives from frontend, sends to database
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-policy
  namespace: test-network
spec:
  podSelector:
    matchLabels:
      tier: backend
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          tier: frontend
    ports:
    - protocol: TCP
      port: 80
  egress:
  - to:
    - podSelector:
        matchLabels:
          tier: database
    ports:
    - protocol: TCP
      port: 5432
  - to:
    - namespaceSelector:
        matchLabels:
          name: kube-system
    ports:
    - protocol: UDP
      port: 53
EOF

# 3. Database receives only from backend
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: database-policy
  namespace: test-network
spec:
  podSelector:
    matchLabels:
      tier: database
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          tier: backend
    ports:
    - protocol: TCP
      port: 5432
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: kube-system
    ports:
    - protocol: UDP
      port: 53
EOF
```

**Test the setup:**
```bash
# Frontend → Backend: ✅
kubectl exec frontend -n test-network -- curl -s $BACKEND_IP

# Frontend → Database: ❌ (blocked)
kubectl exec frontend -n test-network -- timeout 5 curl $DB_IP

# Backend → Database: ✅
kubectl exec backend -n test-network -- curl -s $DB_IP
```

**✅ Checkpoint:** Three-tier zero-trust working!

---

## Phase 5: Namespace Isolation (2 hours)

### Step 1: Create Multiple Namespaces

```bash
kubectl create namespace production
kubectl create namespace development
kubectl create namespace staging

# Label them
kubectl label namespace production environment=production
kubectl label namespace development environment=development
kubectl label namespace staging environment=staging
```

### Step 2: Deploy Apps in Each

```bash
# Production
kubectl run app -n production --image=nginx --labels=app=web

# Development
kubectl run app -n development --image=nginx --labels=app=web

# Staging
kubectl run app -n staging --image=nginx --labels=app=web
```

### Step 3: Isolate Namespaces

```bash
# Production: Only accept from production
kubectl apply -f - <<EOF
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
EOF

# Apply to all namespaces
for ns in development staging; do
  kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: namespace-isolation
  namespace: $ns
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector: {}
EOF
done
```

### Step 4: Test Isolation

```bash
PROD_IP=$(kubectl get pod app -n production -o jsonpath='{.status.podIP}')

# Dev can't reach prod
kubectl exec app -n development -- timeout 5 curl $PROD_IP
# Should timeout! ✅
```

**✅ Checkpoint:** Namespace isolation working.

---

## Phase 6: Advanced Patterns (3 hours)

### Allow Monitoring

```bash
# Create monitoring namespace
kubectl create namespace monitoring
kubectl label namespace monitoring name=monitoring

# Deploy Prometheus
kubectl run prometheus -n monitoring --image=prom/prometheus

# Allow Prometheus scraping
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-monitoring
  namespace: production
spec:
  podSelector:
    matchLabels:
      monitoring: "true"
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
EOF

# Label pods to be monitored
kubectl label pod app -n production monitoring=true
```

### Allow External IPs

```bash
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-external
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: web
  policyTypes:
  - Ingress
  ingress:
  - from:
    - ipBlock:
        cidr: 203.0.113.0/24
    ports:
    - protocol: TCP
      port: 443
EOF
```

**✅ Checkpoint:** Advanced patterns implemented.

---

## Phase 7: Zero-Trust Production (2 hours)

### Complete Production Setup

```bash
# 1. Default deny-all
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
EOF

# 2. Allow DNS
kubectl apply -f - <<EOF
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
EOF

# 3. Allow ingress controller
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-ingress
  namespace: production
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
EOF

# 4. Allow monitoring
# (Already created above)
```

**✅ Checkpoint:** Zero-trust production ready!

---

## ✅ Final Validation

### Checklist

- [ ] Default deny-all applied
- [ ] DNS egress working
- [ ] Frontend → Backend allowed
- [ ] Frontend → Database blocked
- [ ] Backend → Database allowed
- [ ] Namespace isolation working
- [ ] Ingress controller can reach apps
- [ ] Monitoring can scrape metrics

### Test Commands

```bash
# List all policies
kubectl get networkpolicy -A

# Describe policy
kubectl describe networkpolicy <policy> -n <namespace>

# Test connectivity
kubectl exec <pod> -n <namespace> -- curl <target-ip>
```

---

## 🎓 Key Learnings

**Zero-Trust Principles:**
1. Deny all by default
2. Allow only what's necessary
3. Verify and document
4. Monitor continuously

**Policy Order:**
1. Default deny-all
2. Allow DNS
3. Allow specific traffic
4. Test thoroughly

**Best Practices:**
- Start with development
- Test before production
- Document all policies
- Monitor and alert
- Review regularly

---

**Congratulations! You've mastered Network Policies! 🔒🚀**
