# Day 45-46: Ingress Controllers

## 📋 Overview

Welcome to Day 45-46! Today we master Kubernetes Ingress - the smart way to expose HTTP/HTTPS applications. You'll learn how Ingress works, deploy NGINX Ingress Controller, implement path-based routing, and secure applications with TLS.

### What You'll Learn

- Understanding Ingress resources
- How Ingress Controllers work
- Installing NGINX Ingress Controller
- Path-based and host-based routing
- TLS/SSL termination
- Advanced Ingress patterns
- Ingress vs LoadBalancer
- Troubleshooting Ingress issues

---

## 🎯 Learning Objectives

By the end of this module, you will be able to:

1. Explain Ingress architecture
2. Install and configure NGINX Ingress Controller
3. Implement path-based routing
4. Configure host-based routing
5. Enable TLS/HTTPS with certificates
6. Use annotations for advanced features
7. Debug Ingress issues
8. Choose between Ingress and LoadBalancer

---

## 🌐 What is Ingress?

### The Problem

**Without Ingress:**
```
app1 → LoadBalancer (external IP 1)
app2 → LoadBalancer (external IP 2)
app3 → LoadBalancer (external IP 3)

Cost: 3 × LoadBalancer = $$$ per month
IPs: Need 3 external IPs
Complexity: Manage 3 LBs
```

**With Ingress:**
```
                Ingress Controller
                (1 LoadBalancer)
                       ↓
         ┌─────────────┼─────────────┐
         ↓             ↓             ↓
    /app1 → svc1   /app2 → svc2   /app3 → svc3

Cost: 1 × LoadBalancer
IPs: 1 external IP
Complexity: One entry point
```

---

### Definition

**Ingress:** API object that manages external access to services, typically HTTP/HTTPS.

**Ingress Controller:** Implementation that fulfills the Ingress rules.

**Key Features:**
- HTTP/HTTPS routing
- Path-based routing
- Host-based routing
- TLS termination
- Name-based virtual hosting
- Load balancing

---

## 🏗️ Ingress Architecture

### Complete Picture

```
┌─────────────────────────────────────────────────┐
│              Internet                            │
└────────────────┬────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────┐
│        LoadBalancer / NodePort                   │
│        (External IP: 203.0.113.10)              │
└────────────────┬────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────┐
│         Ingress Controller                       │
│         (NGINX, Traefik, HAProxy)               │
│                                                  │
│  Watches: Ingress resources                     │
│  Configures: Routing rules                      │
│  Handles: TLS termination                       │
└──────┬──────────────┬──────────────┬────────────┘
       │              │              │
       ▼              ▼              ▼
   Service A      Service B      Service C
   (ClusterIP)    (ClusterIP)    (ClusterIP)
       ↓              ↓              ↓
   Pod(s)         Pod(s)         Pod(s)
```

### Traffic Flow

```
1. User: https://example.com/api
   ↓
2. DNS: example.com → 203.0.113.10
   ↓
3. LoadBalancer receives request
   ↓
4. Forwards to Ingress Controller pod
   ↓
5. Ingress Controller:
   - Checks Host header: example.com
   - Checks Path: /api
   - Finds matching Ingress rule
   - Terminates TLS
   ↓
6. Routes to Service: api-service:80
   ↓
7. Service forwards to backend Pod
   ↓
8. Response returns through same path
```

---

## 🎮 Popular Ingress Controllers

### 1. NGINX Ingress Controller

**Most Popular:** Used by 60%+ of Kubernetes clusters.

**Pros:**
- ✅ Mature and stable
- ✅ Rich feature set
- ✅ Great documentation
- ✅ Wide community support
- ✅ High performance

**Cons:**
- ❌ Reload on config changes
- ❌ More resource-intensive

**Use When:**
- Production deployments
- Need reliability
- Want wide support

---

### 2. Traefik

**Modern:** Cloud-native edge router.

**Pros:**
- ✅ Dynamic configuration (no reload)
- ✅ Automatic service discovery
- ✅ Beautiful UI dashboard
- ✅ Let's Encrypt integration

**Cons:**
- ❌ Less mature than NGINX
- ❌ Smaller community

**Use When:**
- Want modern features
- Need automatic cert management
- Like dashboards

---

### 3. HAProxy Ingress

**High Performance:** Based on HAProxy.

**Pros:**
- ✅ Excellent performance
- ✅ Low resource usage
- ✅ Advanced load balancing

**Cons:**
- ❌ Smaller community
- ❌ Less documentation

**Use When:**
- Performance critical
- Familiar with HAProxy

---

### 4. Contour

**VMware-backed:** Envoy-based.

**Pros:**
- ✅ Uses Envoy proxy
- ✅ Multi-team support
- ✅ HTTPProxy CRD

**Cons:**
- ❌ Less popular
- ❌ Different API

---

## 📦 Installing NGINX Ingress Controller

### Using Helm (Recommended)

```bash
# Add repo
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Install
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace

# Verify
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx
```

### Using Manifests

```bash
# Apply
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.0/deploy/static/provider/cloud/deploy.yaml

# Verify
kubectl get pods -n ingress-nginx
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s
```

### Get External IP

```bash
kubectl get svc -n ingress-nginx ingress-nginx-controller
# Note the EXTERNAL-IP
```

---

## 🛣️ Ingress Routing Patterns

### 1. Simple Fanout (Path-based)

**Use Case:** Multiple services under one domain.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: simple-fanout
spec:
  ingressClassName: nginx
  rules:
  - host: example.com
    http:
      paths:
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: api-service
            port:
              number: 80
      - path: /web
        pathType: Prefix
        backend:
          service:
            name: web-service
            port:
              number: 80
```

**Result:**
- `example.com/api` → api-service
- `example.com/web` → web-service

---

### 2. Name-based Virtual Hosting

**Use Case:** Multiple domains on one IP.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: name-virtual-host
spec:
  ingressClassName: nginx
  rules:
  - host: api.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: api-service
            port:
              number: 80
  - host: web.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web-service
            port:
              number: 80
```

**Result:**
- `api.example.com` → api-service
- `web.example.com` → web-service

---

### 3. Default Backend

**Use Case:** Catch-all for undefined routes.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: with-default
spec:
  ingressClassName: nginx
  defaultBackend:
    service:
      name: default-service
      port:
        number: 80
  rules:
  - host: example.com
    http:
      paths:
      - path: /app
        pathType: Prefix
        backend:
          service:
            name: app-service
            port:
              number: 80
```

**Result:**
- `example.com/app` → app-service
- `example.com/anything-else` → default-service

---

## 🔒 TLS/HTTPS Configuration

### With Kubernetes Secret

**Step 1: Create TLS Secret**
```bash
# Generate self-signed cert (testing)
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt \
  -subj "/CN=example.com"

# Create secret
kubectl create secret tls example-tls \
  --cert=tls.crt --key=tls.key
```

**Step 2: Configure Ingress**
```yaml
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
            name: web-service
            port:
              number: 80
```

**Result:**
- HTTPS enabled on example.com
- HTTP automatically redirects to HTTPS
- Certificate from secret used

---

### With cert-manager (Let's Encrypt)

**Install cert-manager:**
```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.0/cert-manager.yaml
```

**Create ClusterIssuer:**
```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
```

**Ingress with Auto TLS:**
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: auto-tls
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - example.com
    secretName: example-tls  # Auto-created!
  rules:
  - host: example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web-service
            port:
              number: 80
```

**Result:**
- cert-manager automatically gets Let's Encrypt cert
- Automatically renews before expiry
- Free, trusted SSL certificates!

---

## 🎨 Advanced Ingress Features

### Rewrite Target

**Problem:** Backend expects `/` but traffic comes to `/api`

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: rewrite-example
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /$2
spec:
  ingressClassName: nginx
  rules:
  - host: example.com
    http:
      paths:
      - path: /api(/|$)(.*)
        pathType: ImplementationSpecific
        backend:
          service:
            name: api-service
            port:
              number: 80
```

**Result:**
- `example.com/api/users` → backend receives `/users`

---

### Rate Limiting

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: rate-limit
  annotations:
    nginx.ingress.kubernetes.io/limit-rps: "10"
    nginx.ingress.kubernetes.io/limit-connections: "5"
spec:
  ingressClassName: nginx
  rules:
  - host: example.com
    http:
      paths:
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: api-service
            port:
              number: 80
```

---

### Custom Headers

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: custom-headers
  annotations:
    nginx.ingress.kubernetes.io/configuration-snippet: |
      more_set_headers "X-Custom-Header: MyValue";
      more_set_headers "X-Frame-Options: DENY";
spec:
  # ... rest of config
```

---

### Basic Auth

```bash
# Create htpasswd file
htpasswd -c auth myuser

# Create secret
kubectl create secret generic basic-auth --from-file=auth
```

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: basic-auth
  annotations:
    nginx.ingress.kubernetes.io/auth-type: basic
    nginx.ingress.kubernetes.io/auth-secret: basic-auth
    nginx.ingress.kubernetes.io/auth-realm: 'Authentication Required'
spec:
  # ... rest of config
```

---

### CORS Configuration

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: cors-example
  annotations:
    nginx.ingress.kubernetes.io/enable-cors: "true"
    nginx.ingress.kubernetes.io/cors-allow-methods: "GET, POST, PUT, DELETE"
    nginx.ingress.kubernetes.io/cors-allow-origin: "https://example.com"
spec:
  # ... rest of config
```

---

## 🆚 Ingress vs LoadBalancer

### Comparison

| Feature | Ingress | LoadBalancer |
|---------|---------|--------------|
| **Cost** | 1 LB for all apps | 1 LB per service |
| **IP Address** | 1 external IP | Multiple IPs |
| **Layer** | Layer 7 (HTTP/HTTPS) | Layer 4 (TCP/UDP) |
| **Routing** | Path/host-based | Port-based only |
| **TLS** | Built-in termination | Manual setup |
| **Features** | Rich (rewrite, auth, etc.) | Basic |

### When to Use

**Use Ingress:**
- ✅ HTTP/HTTPS applications
- ✅ Multiple services
- ✅ Need path-based routing
- ✅ Want to save costs
- ✅ Need TLS termination

**Use LoadBalancer:**
- ✅ Non-HTTP protocols (TCP/UDP)
- ✅ Single service exposure
- ✅ Need specific port exposure
- ✅ Want simplest setup

---

## 🎯 Best Practices

### 1. Use IngressClassName

```yaml
# Specify controller explicitly
spec:
  ingressClassName: nginx  # Not annotation!
```

**Why:** Clear, standard way to specify controller.

---

### 2. Limit Ingress Access

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-ingress-only
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
```

---

### 3. Monitor Ingress

```bash
# Check controller logs
kubectl logs -n ingress-nginx <controller-pod>

# Check metrics
kubectl top pod -n ingress-nginx

# Prometheus metrics (if enabled)
curl http://ingress-controller:10254/metrics
```

---

### 4. Resource Limits

```yaml
# For controller deployment
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi
```

---

## 📖 Key Takeaways

✅ Ingress provides Layer 7 routing
✅ One LoadBalancer for multiple services
✅ NGINX Ingress Controller most popular
✅ Path-based and host-based routing
✅ TLS termination built-in
✅ Rich annotations for advanced features
✅ cert-manager for automatic Let's Encrypt
✅ Use Ingress for HTTP/HTTPS apps

---

## 🔗 Additional Resources

- [Kubernetes Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/)
- [NGINX Ingress Controller](https://kubernetes.github.io/ingress-nginx/)
- [cert-manager](https://cert-manager.io/)

---

## 🚀 Next Steps

1. Complete hands-on exercises in GUIDEME.md
2. Install NGINX Ingress Controller
3. Deploy app with path-based routing
4. Configure TLS with certificates
5. Explore advanced annotations
6. Move to next topic: Advanced Kubernetes

**Happy Routing! 🌐**
