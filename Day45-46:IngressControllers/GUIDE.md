# 📖 GUIDEME: Ingress Controllers - Complete Walkthrough

## 🎯 Learning Path (16 hours)

**Day 1:** Ingress basics, NGINX installation, path-based routing
**Day 2:** TLS configuration, advanced patterns, production deployment

---

## Phase 1: Understanding Ingress (2 hours)

### Step 1: The Problem Without Ingress
```bash
# Create 3 services with LoadBalancer
kubectl create deployment app1 --image=nginx
kubectl create deployment app2 --image=nginx
kubectl create deployment app3 --image=nginx

kubectl expose deployment app1 --type=LoadBalancer --port=80
kubectl expose deployment app2 --type=LoadBalancer --port=80
kubectl expose deployment app3 --type=LoadBalancer --port=80

# Watch external IPs (takes time on cloud)
kubectl get svc -w

# Problem: 3 LoadBalancers = 3x cost!
```

**✅ Checkpoint:** Understand cost and complexity of multiple LoadBalancers.

---

### Step 2: Ingress Architecture
```bash
# Clean up LoadBalancers
kubectl delete svc app1 app2 app3

# Change to ClusterIP
kubectl expose deployment app1 --port=80
kubectl expose deployment app2 --port=80
kubectl expose deployment app3 --port=80

# Now we'll route via Ingress
```

**✅ Checkpoint:** Ready for Ingress.

---

## Phase 2: Install NGINX Ingress (2 hours)

### Step 1: Install Using Helm
```bash
# Add repo
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Install
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.replicaCount=2

# Watch installation
kubectl get pods -n ingress-nginx -w
```

**✅ Checkpoint:** Ingress controller running.

---

### Step 2: Verify Installation
```bash
# Check pods
kubectl get pods -n ingress-nginx

# Check service
kubectl get svc -n ingress-nginx

# Get external IP
INGRESS_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Ingress IP: $INGRESS_IP"

# Test controller
curl http://$INGRESS_IP
# Should return 404 (no backend configured yet)
```

**✅ Checkpoint:** Ingress controller accessible.

---

## Phase 3: Path-Based Routing (3 hours)

### Step 1: Deploy Test Applications
```bash
# Create deployments
kubectl create deployment web --image=gcr.io/google-samples/hello-app:1.0
kubectl create deployment api --image=gcr.io/google-samples/hello-app:2.0

# Expose as ClusterIP
kubectl expose deployment web --port=8080
kubectl expose deployment api --port=8080

# Verify
kubectl get svc
```

---

### Step 2: Create Simple Ingress
```bash
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: simple-ingress
spec:
  ingressClassName: nginx
  rules:
  - http:
      paths:
      - path: /web
        pathType: Prefix
        backend:
          service:
            name: web
            port:
              number: 8080
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: api
            port:
              number: 8080
EOF

# Wait for ingress
kubectl get ingress -w
```

---

### Step 3: Test Path-Based Routing
```bash
# Get ingress IP
INGRESS_IP=$(kubectl get ingress simple-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Test /web
curl http://$INGRESS_IP/web
# Should show: Hello, world! Version: 1.0.0

# Test /api
curl http://$INGRESS_IP/api
# Should show: Hello, world! Version: 2.0.0

echo "✅ Path-based routing working!"
```

**✅ Checkpoint:** Path-based routing successful.

---

## Phase 4: Host-Based Routing (2 hours)

### Step 1: Create Host-Based Ingress
```bash
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: host-based-ingress
spec:
  ingressClassName: nginx
  rules:
  - host: web.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web
            port:
              number: 8080
  - host: api.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: api
            port:
              number: 8080
EOF
```

---

### Step 2: Test with Host Headers
```bash
# Test web.example.com
curl -H "Host: web.example.com" http://$INGRESS_IP/
# Version: 1.0.0

# Test api.example.com
curl -H "Host: api.example.com" http://$INGRESS_IP/
# Version: 2.0.0

echo "✅ Host-based routing working!"
```

**✅ Checkpoint:** Virtual hosting working.

---

## Phase 5: TLS/HTTPS Configuration (3 hours)

### Step 1: Create Self-Signed Certificate
```bash
# Generate certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt \
  -subj "/CN=example.com/O=example.com"

# Create secret
kubectl create secret tls example-tls \
  --cert=tls.crt \
  --key=tls.key

# Verify secret
kubectl get secret example-tls
```

---

### Step 2: Enable TLS in Ingress
```bash
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: tls-ingress
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - example.com
    secretName: example-tls
  rules:
  - host: example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web
            port:
              number: 8080
EOF
```

---

### Step 3: Test HTTPS
```bash
# Test HTTPS (with self-signed cert)
curl -k -H "Host: example.com" https://$INGRESS_IP/

# Test HTTP redirect
curl -I -H "Host: example.com" http://$INGRESS_IP/
# Should show 308 redirect to HTTPS

echo "✅ TLS termination working!"
```

**✅ Checkpoint:** HTTPS enabled.

---

## Phase 6: Advanced Features (2 hours)

### Step 1: URL Rewriting
```bash
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: rewrite-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /\$2
spec:
  ingressClassName: nginx
  rules:
  - http:
      paths:
      - path: /api(/|$)(.*)
        pathType: ImplementationSpecific
        backend:
          service:
            name: api
            port:
              number: 8080
EOF

# Test
curl http://$INGRESS_IP/api/test
# Backend receives: /test
```

---

### Step 2: Rate Limiting
```bash
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: rate-limit-ingress
  annotations:
    nginx.ingress.kubernetes.io/limit-rps: "5"
spec:
  ingressClassName: nginx
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web
            port:
              number: 8080
EOF

# Test rate limiting
for i in {1..10}; do
  curl -w "%{http_code}\n" -o /dev/null http://$INGRESS_IP/
  sleep 0.1
done
# Should see some 503 errors (rate limited)
```

**✅ Checkpoint:** Advanced features tested.

---

## Phase 7: Production Deployment (2 hours)

### Step 1: Install cert-manager
```bash
# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.0/cert-manager.yaml

# Wait for pods
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/instance=cert-manager \
  -n cert-manager \
  --timeout=120s
```

---

### Step 2: Create Let's Encrypt Issuer (Staging)
```bash
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-staging
    solvers:
    - http01:
        ingress:
          class: nginx
EOF
```

---

### Step 3: Deploy with Auto-TLS
```bash
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: auto-tls-ingress
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-staging"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - your-domain.com  # Replace with real domain!
    secretName: auto-tls-cert
  rules:
  - host: your-domain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web
            port:
              number: 8080
EOF

# Watch certificate creation
kubectl get certificate -w
```

**✅ Checkpoint:** Auto-TLS configured.

---

## ✅ Final Validation Checklist

### Ingress Basics
- [ ] Understand Ingress vs LoadBalancer
- [ ] Install NGINX Ingress Controller
- [ ] Verify controller running
- [ ] Get external IP

### Routing
- [ ] Implement path-based routing
- [ ] Implement host-based routing
- [ ] Test both routing methods
- [ ] Understand pathType options

### TLS/HTTPS
- [ ] Create TLS secret
- [ ] Configure HTTPS
- [ ] Test TLS termination
- [ ] Verify HTTP→HTTPS redirect

### Advanced
- [ ] URL rewriting
- [ ] Rate limiting
- [ ] Custom headers
- [ ] cert-manager integration

---

## 🧹 Cleanup

```bash
# Delete ingresses
kubectl delete ingress --all

# Delete deployments
kubectl delete deployment web api app1 app2 app3

# Delete services
kubectl delete svc web api app1 app2 app3

# Uninstall ingress-nginx
helm uninstall ingress-nginx -n ingress-nginx

# Delete cert-manager (if installed)
kubectl delete -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.0/cert-manager.yaml
```

---

## 🎓 Key Learnings

**Ingress Benefits:**
- One LoadBalancer for all apps
- Layer 7 (HTTP/HTTPS) routing
- Path and host-based routing
- Built-in TLS termination
- Cost-effective

**NGINX Ingress:**
- Most popular controller
- Rich annotations
- Production-ready
- Great documentation

**TLS Management:**
- Manual: Create secrets
- Automatic: Use cert-manager
- Let's Encrypt: Free certificates
- Auto-renewal

**Best Practices:**
- Use ingressClassName
- Enable monitoring
- Set resource limits
- Plan for HA (replicas)
- Test failover

---

**Congratulations! You've mastered Ingress! 🚀**
