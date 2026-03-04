# Day 49-50: CoreDNS

## 📋 Overview

Welcome to Day 49-50! Today we master CoreDNS - the DNS server that powers service discovery in Kubernetes. You'll learn how DNS resolution works, configure custom DNS entries, and become an expert at troubleshooting DNS issues.

### What You'll Learn

- Understanding Kubernetes DNS architecture
- How CoreDNS works
- Service discovery mechanisms
- DNS naming conventions
- Custom DNS configuration
- DNS troubleshooting techniques
- Performance optimization
- Common DNS issues and fixes

---

## 🎯 Learning Objectives

By the end of this module, you will be able to:

1. Explain Kubernetes DNS architecture
2. Understand CoreDNS configuration
3. Configure custom DNS entries
4. Debug DNS resolution issues
5. Optimize DNS performance
6. Implement custom DNS policies
7. Monitor DNS health
8. Resolve common DNS problems

---

## 🌐 Kubernetes DNS Architecture

### The Complete Picture

```
┌─────────────────────────────────────────────┐
│              Pod                             │
│                                              │
│  Application makes request:                 │
│  curl http://backend-service                │
│         ↓                                    │
│  /etc/resolv.conf                           │
│  nameserver 10.96.0.10                      │
│         ↓                                    │
└─────────┼───────────────────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────┐
│         CoreDNS Service                      │
│         ClusterIP: 10.96.0.10               │
│         Port: 53 (UDP/TCP)                  │
└─────────┼───────────────────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────┐
│         CoreDNS Pods                         │
│         (Deployment in kube-system)         │
│                                              │
│  Plugins:                                    │
│  - kubernetes (service discovery)           │
│  - cache (performance)                      │
│  - forward (upstream DNS)                   │
│  - errors (logging)                         │
└─────────┼───────────────────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────┐
│         DNS Resolution                       │
│                                              │
│  1. Check kubernetes plugin                 │
│     - service.namespace.svc.cluster.local   │
│  2. Check cache                             │
│  3. Forward to upstream (8.8.8.8)          │
└─────────────────────────────────────────────┘
```

---

## 🔧 How CoreDNS Works

### DNS Resolution Flow

```
1. Pod needs to resolve "backend-service"
   ↓
2. Checks /etc/resolv.conf
   nameserver: 10.96.0.10 (CoreDNS)
   search: default.svc.cluster.local svc.cluster.local cluster.local
   ↓
3. Query sent to CoreDNS (10.96.0.10:53)
   ↓
4. CoreDNS Kubernetes plugin:
   - Checks if "backend-service" is a service
   - Finds service in "default" namespace
   - Returns ClusterIP: 10.96.0.100
   ↓
5. Pod connects to 10.96.0.100
```

---

### CoreDNS ConfigMap

**Location:** `kube-system/coredns`

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns
  namespace: kube-system
data:
  Corefile: |
    .:53 {
        errors
        health {
            lameduck 5s
        }
        ready
        kubernetes cluster.local in-addr.arpa ip6.arpa {
            pods insecure
            fallthrough in-addr.arpa ip6.arpa
        }
        prometheus :9153
        forward . /etc/resolv.conf {
            max_concurrent 1000
        }
        cache 30
        loop
        reload
        loadbalance
    }
```

---

## 📖 DNS Naming Conventions

### Service DNS Names

**Format:** `<service>.<namespace>.svc.<cluster-domain>`

**Default cluster domain:** `cluster.local`

**Examples:**

```bash
# Short name (same namespace)
backend

# Namespace-qualified
backend.default

# Service-qualified
backend.default.svc

# Fully qualified (FQDN)
backend.default.svc.cluster.local
```

---

### Pod DNS Names

**Format:** `<pod-ip-dashes>.<namespace>.pod.<cluster-domain>`

**Example:**
```bash
# Pod IP: 10.244.1.5
# DNS: 10-244-1-5.default.pod.cluster.local
```

**Note:** Pods must have subdomain and hostname set.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-pod
spec:
  subdomain: my-service
  hostname: my-pod
  # DNS: my-pod.my-service.default.svc.cluster.local
```

---

### Headless Service DNS

**Headless Service:** `clusterIP: None`

**DNS Returns:** Individual pod IPs (not ClusterIP)

```yaml
apiVersion: v1
kind: Service
metadata:
  name: database
spec:
  clusterIP: None  # Headless
  selector:
    app: database
```

**Resolution:**
```bash
nslookup database.default.svc.cluster.local
# Returns:
# 10.244.1.5  (pod 1)
# 10.244.2.8  (pod 2)
# 10.244.3.2  (pod 3)
```

**Use case:** StatefulSets, direct pod access

---

## 🎨 CoreDNS Plugins

### Essential Plugins

**1. kubernetes**
- Service discovery
- Pod DNS
- Endpoint resolution

```
kubernetes cluster.local in-addr.arpa ip6.arpa {
    pods insecure
    fallthrough in-addr.arpa ip6.arpa
}
```

---

**2. cache**
- Caches DNS responses
- Reduces upstream queries
- Improves performance

```
cache 30  # Cache for 30 seconds
```

---

**3. forward**
- Forwards non-cluster queries
- Upstream DNS servers
- External domain resolution

```
forward . /etc/resolv.conf  # Use node's DNS
forward . 8.8.8.8 8.8.4.4   # Use Google DNS
```

---

**4. errors**
- Logs DNS errors
- Debugging aid

```
errors
```

---

**5. health**
- Health check endpoint
- Used by kubelet

```
health {
    lameduck 5s
}
```

---

**6. ready**
- Readiness endpoint
- Used by Kubernetes

```
ready
```

---

**7. prometheus**
- Metrics endpoint
- Monitoring

```
prometheus :9153
```

---

## 🔧 Custom DNS Configuration

### Adding Custom DNS Entries

**Method 1: ConfigMap with hosts plugin**

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns-custom
  namespace: kube-system
data:
  custom.override: |
    hosts {
        10.0.0.100 custom.example.com
        10.0.0.101 api.example.com
        fallthrough
    }
```

Then add to Corefile:
```
import custom.override
```

---

**Method 2: ExternalName Service**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: external-db
spec:
  type: ExternalName
  externalName: database.example.com
```

**Result:** `external-db` resolves to `database.example.com`

---

### Custom Upstream DNS

**Configure in Corefile:**

```yaml
data:
  Corefile: |
    .:53 {
        errors
        kubernetes cluster.local {
            pods insecure
        }
        forward . 1.1.1.1 1.0.0.1  # Cloudflare DNS
        cache 30
    }
```

---

### Per-Pod DNS Configuration

**Override per pod:**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: custom-dns-pod
spec:
  dnsPolicy: None  # Don't use cluster DNS
  dnsConfig:
    nameservers:
    - 1.1.1.1
    - 8.8.8.8
    searches:
    - my-company.com
    options:
    - name: ndots
      value: "2"
  containers:
  - name: app
    image: nginx
```

---

## 🎯 DNS Policies

### dnsPolicy Options

**1. ClusterFirst (Default)**
- Use CoreDNS for cluster domains
- Forward external queries upstream

```yaml
dnsPolicy: ClusterFirst
```

---

**2. Default**
- Use node's DNS configuration
- Bypass CoreDNS

```yaml
dnsPolicy: Default
```

---

**3. ClusterFirstWithHostNet**
- For pods with `hostNetwork: true`
- Still use CoreDNS

```yaml
hostNetwork: true
dnsPolicy: ClusterFirstWithHostNet
```

---

**4. None**
- No DNS configuration
- Must specify dnsConfig

```yaml
dnsPolicy: None
dnsConfig:
  nameservers:
  - 8.8.8.8
```

---

## 📊 DNS Resolution Examples

### Service Discovery

```bash
# In a pod
nslookup backend
# Returns:
# Name:   backend.default.svc.cluster.local
# Address: 10.96.0.100

# Different namespace
nslookup backend.production
# Returns:
# Name:   backend.production.svc.cluster.local
# Address: 10.96.0.200

# External domain
nslookup google.com
# Forwarded to upstream DNS
# Returns: Google's IP addresses
```

---

### Search Domains

**/etc/resolv.conf in pods:**

```
nameserver 10.96.0.10
search default.svc.cluster.local svc.cluster.local cluster.local
options ndots:5
```

**How search works:**

Query: `backend`
1. Try: `backend.default.svc.cluster.local` ✅ (found)
2. Skip remaining searches

Query: `backend.production`
1. Try: `backend.production.default.svc.cluster.local` ❌
2. Try: `backend.production.svc.cluster.local` ✅ (found)

Query: `google.com`
1. Try all searches (none match)
2. Try as-is: `google.com` ✅

---

## 🔍 Troubleshooting DNS

### Common Issues

**Issue 1: Service Not Resolving**

```bash
# Symptoms
nslookup backend
# Server can't find backend

# Diagnosis
kubectl get svc backend
kubectl get endpoints backend
kubectl get pods -l app=backend

# Common causes
- Service doesn't exist
- Wrong namespace
- No endpoints (no pods)
- Typo in name
```

---

**Issue 2: External DNS Not Working**

```bash
# Symptoms
nslookup google.com
# Connection timeout

# Diagnosis
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl logs -n kube-system -l k8s-app=kube-dns

# Common causes
- CoreDNS pods not running
- Network policy blocking port 53
- Upstream DNS unreachable
- Firewall blocking
```

---

**Issue 3: Slow DNS Resolution**

```bash
# Symptoms
Long delays on first request

# Diagnosis
kubectl top pod -n kube-system -l k8s-app=kube-dns
kubectl logs -n kube-system -l k8s-app=kube-dns | grep -i timeout

# Common causes
- Cache disabled/too small
- Upstream DNS slow
- Too few CoreDNS pods
- Network latency
```

---

**Issue 4: DNS Loops**

```bash
# Symptoms
nslookup hangs or fails

# Diagnosis
kubectl logs -n kube-system -l k8s-app=kube-dns | grep loop

# Solution
- Fix forward configuration
- Check upstream DNS
- Enable loop detection plugin
```

---

## 🎯 Best Practices

### 1. Resource Limits

```yaml
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 256Mi
```

---

### 2. High Availability

```yaml
# Multiple replicas
replicas: 2

# Pod anti-affinity
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 100
      podAffinityTerm:
        labelSelector:
          matchLabels:
            k8s-app: kube-dns
        topologyKey: kubernetes.io/hostname
```

---

### 3. Monitoring

```yaml
# Prometheus metrics
prometheus :9153

# Health checks
livenessProbe:
  httpGet:
    path: /health
    port: 8080
readinessProbe:
  httpGet:
    path: /ready
    port: 8181
```

---

### 4. Cache Configuration

```yaml
# Increase cache size for busy clusters
cache 300  # 5 minutes

# Separate cache per record type
cache {
    success 9984
    denial 9984
    prefetch 10
}
```

---

## 📖 Key Takeaways

✅ CoreDNS handles DNS in Kubernetes
✅ Service discovery via DNS names
✅ Format: service.namespace.svc.cluster.local
✅ Multiple DNS policies available
✅ Custom DNS configuration possible
✅ Monitor and optimize for performance
✅ Common issues: service not found, slow resolution
✅ Always check CoreDNS pods first

---

## 🔗 Additional Resources

- [CoreDNS Documentation](https://coredns.io/manual/toc/)
- [Kubernetes DNS](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/)
- [CoreDNS Plugins](https://coredns.io/plugins/)

---

## 🚀 Next Steps

1. Complete hands-on exercises in GUIDEME.md
2. Configure CoreDNS
3. Test service discovery
4. Add custom DNS entries
5. Troubleshoot DNS issues
6. Optimize performance
7. Move to next advanced topic

**Happy DNS Resolving! 🌐**
