# 🎤 Interview Q&A: Ingress Controllers

---

## Q1: What is Kubernetes Ingress and how does it differ from Services?

**Answer:**

**Ingress:**
- API object managing external HTTP/HTTPS access
- Layer 7 (application layer) routing
- Path-based and host-based routing
- TLS termination
- One external IP for multiple services

**Service (LoadBalancer):**
- Layer 4 (transport layer) load balancing
- One external IP per service
- No path/host routing
- Basic port forwarding

**Key Difference:**

```
Without Ingress (LoadBalancer):
app1 → LoadBalancer 1 (IP 1) → Service 1
app2 → LoadBalancer 2 (IP 2) → Service 2
app3 → LoadBalancer 3 (IP 3) → Service 3
Cost: 3 × LoadBalancer

With Ingress:
              Ingress (1 LoadBalancer)
                      ↓
         /app1 → Service 1
         /app2 → Service 2
         /app3 → Service 3
Cost: 1 × LoadBalancer
```

**When to use:**
- **Ingress**: HTTP/HTTPS apps, need routing, cost savings
- **LoadBalancer**: Non-HTTP protocols, simple exposure

---

## Q2: Explain the Ingress architecture and traffic flow.

**Answer:**

**Components:**

1. **Ingress Resource** - Configuration object
2. **Ingress Controller** - Implementation (NGINX, Traefik)
3. **Backend Services** - ClusterIP services
4. **Pods** - Application containers

**Traffic Flow:**

```
1. Client: https://example.com/api
   ↓
2. DNS resolves to Ingress IP
   ↓
3. LoadBalancer → Ingress Controller pod
   ↓
4. Ingress Controller:
   - Checks Host header: example.com
   - Checks Path: /api
   - Finds matching Ingress rule
   - Terminates TLS (if configured)
   ↓
5. Routes to backend Service: api-svc:80
   ↓
6. Service → Pod (kube-proxy)
   ↓
7. Response returns
```

**How Controller Works:**

1. Watches Ingress resources via API
2. Reads routing rules
3. Configures load balancer (NGINX/HAProxy/etc.)
4. Proxies traffic to backends
5. Updates config when Ingress changes

**Example:**
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
spec:
  rules:
  - host: example.com
    http:
      paths:
      - path: /api
        backend:
          service:
            name: api-svc
```

Controller sees this and configures:
- Host: example.com
- Path: /api → api-svc:80

---

## Q3: How do you implement TLS/HTTPS with Ingress?

**Answer:**

**Two Methods:**

**Method 1: Manual Certificates**

Step 1: Create certificate
```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt \
  -subj "/CN=example.com"
```

Step 2: Create secret
```bash
kubectl create secret tls example-tls \
  --cert=tls.crt --key=tls.key
```

Step 3: Configure Ingress
```yaml
spec:
  tls:
  - hosts:
    - example.com
    secretName: example-tls
```

**Method 2: Automatic with cert-manager**

Step 1: Install cert-manager
```bash
kubectl apply -f cert-manager.yaml
```

Step 2: Create Issuer
```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@example.com
    privateKeySecretRef:
      name: letsencrypt-key
    solvers:
    - http01:
        ingress:
          class: nginx
```

Step 3: Annotate Ingress
```yaml
metadata:
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  tls:
  - hosts:
    - example.com
    secretName: example-tls  # Auto-created!
```

**Result:**
- cert-manager gets certificate from Let's Encrypt
- Stores in secret
- Automatically renews before expiry
- Free, trusted certificates!

**HTTP → HTTPS Redirect:**
Automatic with most controllers when TLS configured.

---

## Q4: What are path types in Ingress and when to use each?

**Answer:**

**Three Path Types:**

**1. Exact**
```yaml
pathType: Exact
path: /api/users
```
- Matches exactly `/api/users`
- NOT `/api/users/`
- NOT `/api/users/123`

**Use when:** Need exact path match

**2. Prefix**
```yaml
pathType: Prefix
path: /api
```
- Matches `/api`
- Matches `/api/`
- Matches `/api/users`
- Matches `/api/users/123`

**Use when:** Route all sub-paths (most common)

**3. ImplementationSpecific**
```yaml
pathType: ImplementationSpecific
path: /api(/|$)(.*)
```
- Controller-specific behavior
- Often used with regex
- Different per controller

**Use when:** Need controller-specific features (rewriting)

**Recommendation:**
Use `Prefix` for 90% of cases.

---

## Q5: Explain Ingress annotations and give examples.

**Answer:**

Annotations add controller-specific features beyond standard Ingress spec.

**Common NGINX Annotations:**

**1. URL Rewriting**
```yaml
annotations:
  nginx.ingress.kubernetes.io/rewrite-target: /$2
# With path: /api(/|$)(.*)
# Request: /api/users → Backend gets: /users
```

**2. Rate Limiting**
```yaml
annotations:
  nginx.ingress.kubernetes.io/limit-rps: "10"
  nginx.ingress.kubernetes.io/limit-connections: "5"
# Max 10 requests/second, 5 concurrent connections
```

**3. CORS**
```yaml
annotations:
  nginx.ingress.kubernetes.io/enable-cors: "true"
  nginx.ingress.kubernetes.io/cors-allow-origin: "https://example.com"
```

**4. Custom Headers**
```yaml
annotations:
  nginx.ingress.kubernetes.io/configuration-snippet: |
    more_set_headers "X-Frame-Options: DENY";
```

**5. Basic Auth**
```yaml
annotations:
  nginx.ingress.kubernetes.io/auth-type: basic
  nginx.ingress.kubernetes.io/auth-secret: basic-auth
```

**6. SSL Redirect**
```yaml
annotations:
  nginx.ingress.kubernetes.io/ssl-redirect: "true"
# Force HTTPS
```

**Note:** Annotations are controller-specific!
- NGINX: `nginx.ingress.kubernetes.io/*`
- Traefik: `traefik.ingress.kubernetes.io/*`

**Best Practice:** Use standard Ingress spec when possible, annotations for advanced features.
