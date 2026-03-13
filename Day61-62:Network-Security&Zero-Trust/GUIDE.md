# 📖 GUIDEME: Network Security & Zero-Trust - Complete Walkthrough

## 🎯 16-Hour Learning Path

**Day 1:** Network Policies, mTLS concepts (8 hours)
**Day 2:** Service mesh deployment, zero-trust implementation (8 hours)

---

## Phase 1: Advanced Network Policies (3 hours)

### Step 1: Create Zero-Trust Namespace
```bash
kubectl create namespace zero-trust

# Deploy test application
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: zero-trust
spec:
  replicas: 2
  selector:
    matchLabels:
      app: frontend
      tier: frontend
  template:
    metadata:
      labels:
        app: frontend
        tier: frontend
    spec:
      containers:
      - name: nginx
        image: nginx
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: zero-trust
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backend
      tier: backend
  template:
    metadata:
      labels:
        app: backend
        tier: backend
    spec:
      containers:
      - name: nginx
        image: nginx
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: database
  namespace: zero-trust
spec:
  replicas: 1
  selector:
    matchLabels:
      app: database
      tier: database
  template:
    metadata:
      labels:
        app: database
        tier: database
    spec:
      containers:
      - name: postgres
        image: postgres:15-alpine
        env:
        - name: POSTGRES_PASSWORD
          value: password
---
apiVersion: v1
kind: Service
metadata:
  name: backend
  namespace: zero-trust
spec:
  selector:
    app: backend
  ports:
  - port: 80
---
apiVersion: v1
kind: Service
metadata:
  name: database
  namespace: zero-trust
spec:
  selector:
    app: database
  ports:
  - port: 5432
EOF

# Verify all pods running
kubectl get pods -n zero-trust
```

### Step 2: Test Default Behavior (Everything Allowed)
```bash
# Get pod names
FRONTEND=$(kubectl get pod -n zero-trust -l tier=frontend -o jsonpath='{.items[0].metadata.name}')
BACKEND=$(kubectl get pod -n zero-trust -l tier=backend -o jsonpath='{.items[0].metadata.name}')

# Frontend can reach backend
kubectl exec -n zero-trust $FRONTEND -- curl -s http://backend
# Works! ✅

# Frontend can reach database (BAD!)
kubectl exec -n zero-trust $FRONTEND -- nc -zv database 5432
# Works! ❌ (shouldn't be allowed)
```

**✅ Checkpoint:** Default behavior is insecure (everything allowed).

---

### Step 3: Implement Zero-Trust Network Policies
```bash
# 1. Deny all traffic
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: zero-trust
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
EOF

# Test - everything should fail now
kubectl exec -n zero-trust $FRONTEND -- timeout 5 curl http://backend
# Timeout ✅

# 2. Allow DNS
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
  namespace: zero-trust
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

# 3. Allow Frontend → Backend
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: frontend-to-backend
  namespace: zero-trust
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

# 4. Allow Backend → Database
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-to-database
  namespace: zero-trust
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
EOF

# Test
kubectl exec -n zero-trust $FRONTEND -- curl -s http://backend
# Works ✅

kubectl exec -n zero-trust $FRONTEND -- timeout 3 nc -zv database 5432
# Timeout ✅ (blocked as expected)

kubectl exec -n zero-trust $BACKEND -- nc -zv database 5432
# Works ✅
```

**✅ Checkpoint:** Zero-trust network policies implemented.

---

## Phase 2: Install Istio Service Mesh (2 hours)

### Step 1: Install Istio
```bash
# Download Istio
curl -L https://istio.io/downloadIstio | sh -
cd istio-*
export PATH=$PWD/bin:$PATH

# Install with demo profile (for learning)
istioctl install --set profile=demo -y

# Verify installation
kubectl get pods -n istio-system

# Wait for all pods to be ready
kubectl wait --for=condition=ready pod --all -n istio-system --timeout=300s
```

### Step 2: Enable Sidecar Injection
```bash
# Label namespace for automatic sidecar injection
kubectl label namespace zero-trust istio-injection=enabled

# Verify label
kubectl get namespace zero-trust --show-labels

# Restart pods to inject sidecars
kubectl rollout restart deployment -n zero-trust frontend
kubectl rollout restart deployment -n zero-trust backend
kubectl rollout restart deployment -n zero-trust database

# Wait for pods
kubectl wait --for=condition=ready pod --all -n zero-trust --timeout=300s

# Verify sidecars
kubectl get pods -n zero-trust
# Should show 2/2 (app + envoy sidecar)
```

**✅ Checkpoint:** Istio installed, sidecars injected.

---

## Phase 3: Configure mTLS (2 hours)

### Step 1: Check Current mTLS Status
```bash
# Install kiali for visualization (optional)
kubectl apply -f samples/addons/kiali.yaml -n istio-system

# Check mTLS status
istioctl authn tls-check -n zero-trust

# Test current communication
kubectl exec -n zero-trust $FRONTEND -c nginx -- curl -s http://backend
# Works (proxied through Envoy)
```

### Step 2: Enable Strict mTLS
```bash
kubectl apply -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: zero-trust
spec:
  mtls:
    mode: STRICT
EOF

# Verify
istioctl authn tls-check -n zero-trust
# Should show mTLS: STRICT

# Test - still works (Envoy handles mTLS)
kubectl exec -n zero-trust $FRONTEND -c nginx -- curl -s http://backend
# Works ✅ (encrypted with mTLS now!)
```

### Step 3: Verify mTLS Encryption
```bash
# Check Envoy stats
kubectl exec -n zero-trust $FRONTEND -c istio-proxy -- \
  curl -s localhost:15000/stats | grep ssl

# Look for:
# ssl.handshake (successful TLS handshakes)
# ssl.connection_error (failed connections)
```

**✅ Checkpoint:** mTLS enabled and working.

---

## Phase 4: Authorization Policies (3 hours)

### Step 1: Deny All by Default
```bash
kubectl apply -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: deny-all
  namespace: zero-trust
spec:
  {}  # Empty spec = deny all
EOF

# Test - should fail
kubectl exec -n zero-trust $FRONTEND -c nginx -- curl -s http://backend
# RBAC: access denied
```

### Step 2: Create ServiceAccounts
```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: frontend-sa
  namespace: zero-trust
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: backend-sa
  namespace: zero-trust
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: database-sa
  namespace: zero-trust
EOF

# Update deployments to use SAs
kubectl patch deployment frontend -n zero-trust -p '{"spec":{"template":{"spec":{"serviceAccountName":"frontend-sa"}}}}'
kubectl patch deployment backend -n zero-trust -p '{"spec":{"template":{"spec":{"serviceAccountName":"backend-sa"}}}}'
kubectl patch deployment database -n zero-trust -p '{"spec":{"template":{"spec":{"serviceAccountName":"database-sa"}}}}'

# Wait for rollout
kubectl rollout status deployment -n zero-trust frontend
kubectl rollout status deployment -n zero-trust backend
kubectl rollout status deployment -n zero-trust database
```

### Step 3: Allow Frontend → Backend
```bash
kubectl apply -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: frontend-to-backend
  namespace: zero-trust
spec:
  selector:
    matchLabels:
      app: backend
  action: ALLOW
  rules:
  - from:
    - source:
        principals:
        - "cluster.local/ns/zero-trust/sa/frontend-sa"
    to:
    - operation:
        methods: ["GET", "POST"]
EOF

# Test
FRONTEND=$(kubectl get pod -n zero-trust -l tier=frontend -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n zero-trust $FRONTEND -c nginx -- curl -s http://backend
# Works ✅
```

### Step 4: Allow Backend → Database
```bash
kubectl apply -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: backend-to-database
  namespace: zero-trust
spec:
  selector:
    matchLabels:
      app: database
  action: ALLOW
  rules:
  - from:
    - source:
        principals:
        - "cluster.local/ns/zero-trust/sa/backend-sa"
EOF

# Verify identity
kubectl exec -n zero-trust $FRONTEND -c istio-proxy -- \
  openssl s_client -showcerts -connect backend:80 </dev/null 2>/dev/null | \
  openssl x509 -noout -text | grep "Subject Alternative Name" -A1
```

**✅ Checkpoint:** Identity-based authorization working.

---

## Phase 5: Monitoring & Observability (2 hours)

### Deploy Monitoring Stack
```bash
# Deploy Prometheus, Grafana, Jaeger, Kiali
kubectl apply -f samples/addons/prometheus.yaml -n istio-system
kubectl apply -f samples/addons/grafana.yaml -n istio-system
kubectl apply -f samples/addons/jaeger.yaml -n istio-system
kubectl apply -f samples/addons/kiali.yaml -n istio-system

# Wait for ready
kubectl wait --for=condition=ready pod --all -n istio-system --timeout=300s
```

### Access Dashboards
```bash
# Kiali (Service mesh visualization)
istioctl dashboard kiali &

# Grafana (Metrics)
istioctl dashboard grafana &

# Jaeger (Distributed tracing)
istioctl dashboard jaeger &

# Browse to http://localhost:20001 (Kiali)
# See service graph with mTLS locks
```

### Generate Traffic
```bash
# Generate traffic for visualization
for i in {1..100}; do
  kubectl exec -n zero-trust $FRONTEND -c nginx -- curl -s http://backend
  sleep 1
done
```

**✅ Checkpoint:** Observability stack deployed.

---

## Phase 6: Testing & Validation (2 hours)

### Test Security Boundaries
```bash
# 1. Frontend CAN access Backend
kubectl exec -n zero-trust $FRONTEND -c nginx -- curl -s http://backend
# Works ✅

# 2. Frontend CANNOT access Database
kubectl exec -n zero-trust $FRONTEND -c nginx -- timeout 3 nc -zv database 5432
# Timeout ✅

# 3. Backend CAN access Database
BACKEND=$(kubectl get pod -n zero-trust -l tier=backend -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n zero-trust $BACKEND -c nginx -- nc -zv database 5432
# Works ✅

# 4. Verify mTLS
istioctl authn tls-check -n zero-trust
# All connections: STRICT
```

### Security Audit
```bash
cat > audit-zero-trust.sh <<'SCRIPT'
#!/bin/bash
echo "=== Zero-Trust Security Audit ==="

echo -e "\n1. Network Policies:"
kubectl get networkpolicies -n zero-trust

echo -e "\n2. mTLS Status:"
istioctl authn tls-check -n zero-trust 2>/dev/null || echo "Istio not available"

echo -e "\n3. Authorization Policies:"
kubectl get authorizationpolicies -n zero-trust

echo -e "\n4. Sidecars Injected:"
kubectl get pods -n zero-trust -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].name}{"\n"}{end}'

echo -e "\n=== Audit Complete ==="
SCRIPT

chmod +x audit-zero-trust.sh
./audit-zero-trust.sh
```

**✅ Checkpoint:** Zero-trust architecture validated.

---

## ✅ Final Validation

### Checklist
- [ ] Network Policies deny-all implemented
- [ ] Explicit tier-to-tier allows configured
- [ ] Istio installed and running
- [ ] Sidecars injected in all pods
- [ ] Strict mTLS enabled
- [ ] Authorization policies deny-all
- [ ] Identity-based allows configured
- [ ] Frontend → Backend works
- [ ] Frontend ✗ Database blocked
- [ ] Backend → Database works
- [ ] Monitoring stack deployed
- [ ] mTLS verified in dashboards

---

**Congratulations! You've built a production-grade zero-trust network! 🔒🚀**
