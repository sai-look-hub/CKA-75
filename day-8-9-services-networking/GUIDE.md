# Kubernetes Services & Networking - Comprehensive Guide

> **Deep dive into Kubernetes Services, Networking Concepts, and Service Discovery**

---

## Table of Contents

1. [Introduction to Services](#introduction-to-services)
2. [Service Types Deep Dive](#service-types-deep-dive)
3. [Service Discovery](#service-discovery)
4. [Networking Architecture](#networking-architecture)
5. [Advanced Concepts](#advanced-concepts)
6. [Network Troubleshooting](#network-troubleshooting)
7. [Best Practices](#best-practices)
8. [Real-World Scenarios](#real-world-scenarios)

---

## Introduction to Services

### What is a Kubernetes Service?

A **Service** in Kubernetes is an abstract way to expose an application running on a set of Pods as a network service. With Kubernetes, you don't need to modify your application to use an unfamiliar service discovery mechanism. Kubernetes gives Pods their own IP addresses and a single DNS name for a set of Pods, and can load-balance across them.

### Why Do We Need Services?

**The Problem:**
```
Pod lifecycle is ephemeral:
- Pods can be created and destroyed dynamically
- Pod IPs change when pods restart
- Pod IPs are unpredictable
- Direct pod-to-pod communication is fragile

Example:
Frontend Pod → Backend Pod (10.244.1.5) ✅
Backend Pod restarts → New IP (10.244.1.23) ❌
Frontend Pod → Backend Pod (10.244.1.5) ❌ Connection refused
```

**The Solution: Services**
```
Services provide:
✅ Stable IP address (doesn't change)
✅ Stable DNS name
✅ Load balancing across pod replicas
✅ Automatic endpoint management
✅ Service discovery

Example with Service:
Frontend Pod → Backend Service (10.96.0.10) ✅
Backend Pod restarts → Service IP unchanged (10.96.0.10) ✅
Frontend Pod → Backend Service (10.96.0.10) ✅ Still works!
```

### Core Service Concepts

#### 1. **Selectors**
Services use label selectors to determine which Pods to route traffic to.

```yaml
# Service selector
selector:
  app: backend
  tier: api

# Matching Pod labels
labels:
  app: backend
  tier: api
```

#### 2. **Endpoints**
Endpoints are automatically created and updated when Pods matching the selector are created/destroyed.

```bash
# View endpoints
kubectl get endpoints backend

# Output
NAME      ENDPOINTS                           AGE
backend   10.244.1.5:8080,10.244.2.3:8080    5m
```

#### 3. **Service IP (ClusterIP)**
Every service (except headless) gets a virtual IP address from the service IP range.

```bash
# Check service IP range (on API server)
kube-apiserver --service-cluster-ip-range=10.96.0.0/12

# Services get IPs from this range
```

---

## Service Types Deep Dive

### 1. ClusterIP (Default)

**Purpose:** Internal cluster communication only

#### Characteristics
- Virtual IP address within cluster
- Only accessible from within cluster
- Default service type
- Most common for backend services
- Supports TCP and UDP

#### Use Cases
- Backend APIs
- Internal microservices
- Database connections
- Cache servers
- Internal tools

#### How It Works

```
Client Pod Request
      ↓
ClusterIP (Virtual IP: 10.96.0.10)
      ↓
kube-proxy (iptables/ipvs rules)
      ↓
Pod Endpoints (Load balanced)
  - Pod1: 10.244.1.5:8080
  - Pod2: 10.244.1.6:8080
  - Pod3: 10.244.1.7:8080
```

#### Example YAML

```yaml
apiVersion: v1
kind: Service
metadata:
  name: backend-api
  namespace: production
  labels:
    app: backend
    tier: api
spec:
  type: ClusterIP  # Can be omitted (default)
  selector:
    app: backend
    tier: api
  ports:
    - name: http
      protocol: TCP
      port: 8080        # Service port
      targetPort: 8080  # Container port
    - name: metrics
      protocol: TCP
      port: 9090
      targetPort: 9090
  sessionAffinity: None  # Options: None, ClientIP
```

#### Key Points
- ✅ Best for internal communication
- ✅ No external exposure
- ✅ Low latency (internal routing)
- ✅ Automatic load balancing
- ❌ Cannot be accessed from outside cluster

---

### 2. NodePort

**Purpose:** Expose service on each Node's IP at a static port

#### Characteristics
- Builds on top of ClusterIP
- Opens same port on ALL nodes
- Port range: 30000-32767 (configurable)
- Accessible via `<NodeIP>:<NodePort>`
- Traffic: External → NodePort → ClusterIP → Pods

#### Use Cases
- Development environments
- Testing and demos
- On-premises clusters without load balancers
- Direct node access scenarios
- Quick external access

#### How It Works

```
External Client
      ↓
Node1:30080 OR Node2:30080 OR Node3:30080
      ↓
NodePort forwards to ClusterIP
      ↓
ClusterIP (10.96.0.10)
      ↓
kube-proxy routes to Pod
      ↓
Pod Endpoints (any pod in cluster)
```

#### Example YAML

```yaml
apiVersion: v1
kind: Service
metadata:
  name: frontend-dev
  namespace: development
spec:
  type: NodePort
  selector:
    app: frontend
    env: dev
  ports:
    - name: http
      protocol: TCP
      port: 80          # Service port (ClusterIP)
      targetPort: 8080  # Container port
      nodePort: 30080   # Optional: specific port (30000-32767)
```

#### Accessing NodePort Services

```bash
# Get node IPs
kubectl get nodes -o wide

# Access format
curl http://<node-ip>:30080

# Examples
curl http://192.168.1.10:30080
curl http://192.168.1.11:30080  # Any node works

# Get NodePort automatically
NODE_PORT=$(kubectl get svc frontend-dev -o jsonpath='{.spec.ports[0].nodePort}')
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}')
curl http://$NODE_IP:$NODE_PORT
```

#### Key Points
- ✅ Simple external access
- ✅ Works without cloud load balancers
- ✅ Good for development/testing
- ❌ Exposes service on all nodes
- ❌ Uses non-standard ports
- ❌ Not ideal for production
- ⚠️ Need to manage node IPs if nodes change

---

### 3. LoadBalancer

**Purpose:** Expose service via cloud provider's load balancer

#### Characteristics
- Builds on NodePort (creates NodePort + ClusterIP)
- Provisions external load balancer
- Gets external IP from cloud provider
- Production-standard for external access
- Supports health checks and SSL termination (cloud-dependent)

#### Use Cases
- Production web applications
- Public-facing APIs
- Services requiring stable external IP
- SSL termination requirements
- Applications needing cloud load balancer features

#### How It Works

```
Internet
      ↓
Cloud Load Balancer (External IP: 203.0.113.10)
      ↓
NodePort (30080 on all nodes)
      ↓
ClusterIP (10.96.0.10)
      ↓
kube-proxy
      ↓
Pod Endpoints (load balanced)
```

#### Cloud Provider Integration

**AWS:**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: web-app
  annotations:
    # Use Network Load Balancer
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
    
    # Internal load balancer
    service.beta.kubernetes.io/aws-load-balancer-internal: "true"
    
    # Cross-zone load balancing
    service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: "true"
    
    # SSL certificate ARN
    service.beta.kubernetes.io/aws-load-balancer-ssl-cert: "arn:aws:acm:region:account:certificate/123456"
    
    # Backend protocol
    service.beta.kubernetes.io/aws-load-balancer-backend-protocol: "http"
spec:
  type: LoadBalancer
  selector:
    app: web
  ports:
    - port: 443
      targetPort: 8080
```

**GCP:**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: web-app
  annotations:
    # Internal load balancer
    cloud.google.com/load-balancer-type: "Internal"
    
    # Specific IP address
    cloud.google.com/load-balancer-ip: "10.0.0.10"
spec:
  type: LoadBalancer
  loadBalancerIP: "35.186.203.10"  # Request specific IP
  selector:
    app: web
  ports:
    - port: 80
      targetPort: 8080
```

**Azure:**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: web-app
  annotations:
    # Internal load balancer
    service.beta.kubernetes.io/azure-load-balancer-internal: "true"
    
    # Specific subnet
    service.beta.kubernetes.io/azure-load-balancer-internal-subnet: "subnet-name"
spec:
  type: LoadBalancer
  selector:
    app: web
  ports:
    - port: 80
      targetPort: 8080
```

#### Example YAML

```yaml
apiVersion: v1
kind: Service
metadata:
  name: production-web
  namespace: production
  labels:
    app: web
    environment: production
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
spec:
  type: LoadBalancer
  selector:
    app: web
    environment: production
  ports:
    - name: http
      protocol: TCP
      port: 80
      targetPort: 8080
    - name: https
      protocol: TCP
      port: 443
      targetPort: 8443
  loadBalancerIP: ""  # Optional: request specific IP
  loadBalancerSourceRanges:  # Optional: restrict source IPs
    - "203.0.113.0/24"
    - "198.51.100.0/24"
  externalTrafficPolicy: Cluster  # Options: Cluster, Local
```

#### Getting External IP

```bash
# Watch for external IP (can take 1-2 minutes)
kubectl get svc production-web -w

# Output
NAME             TYPE           CLUSTER-IP      EXTERNAL-IP     PORT(S)
production-web   LoadBalancer   10.96.0.50      <pending>       80:30123/TCP
production-web   LoadBalancer   10.96.0.50      203.0.113.10    80:30123/TCP

# Access the service
curl http://203.0.113.10
```

#### External Traffic Policy

**Cluster (Default):**
```yaml
externalTrafficPolicy: Cluster
```
- Traffic can go to any pod in cluster
- Even load distribution
- Source IP is SNATed
- Additional network hop possible

**Local:**
```yaml
externalTrafficPolicy: Local
```
- Traffic only to pods on receiving node
- Preserves source IP
- No extra network hops
- Potential uneven load distribution
- Health checks per node

#### Key Points
- ✅ Production-ready external access
- ✅ Managed by cloud provider
- ✅ Automatic health checks
- ✅ SSL termination support
- ✅ Stable external IP
- ❌ Cloud provider required
- ❌ Costs money (cloud LB charges)
- ⚠️ One external IP per service (can get expensive)

---

### 4. ExternalName

**Purpose:** Map service to external DNS name

#### Characteristics
- Returns CNAME record
- No proxying or load balancing
- No selectors needed
- No IP address assigned
- DNS-level redirection

#### Use Cases
- External databases
- Third-party APIs
- Legacy systems during migration
- Services in other clusters
- External SaaS platforms

#### How It Works

```
Pod makes request to service
      ↓
DNS lookup: external-db.default.svc.cluster.local
      ↓
CoreDNS returns CNAME
      ↓
CNAME: mysql.external-company.com
      ↓
Pod connects directly to external service
```

#### Example YAML

```yaml
apiVersion: v1
kind: Service
metadata:
  name: external-database
  namespace: production
spec:
  type: ExternalName
  externalName: mysql.rds.amazonaws.com  # External DNS name
  ports:
    - port: 3306
      protocol: TCP

---
# Application connects to external-database
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
spec:
  template:
    spec:
      containers:
      - name: app
        env:
        - name: DB_HOST
          value: "external-database.production.svc.cluster.local"
        - name: DB_PORT
          value: "3306"
```

#### Migration Pattern

```yaml
# Stage 1: Point to external service
apiVersion: v1
kind: Service
metadata:
  name: database
spec:
  type: ExternalName
  externalName: legacy-db.company.com

---
# Stage 2: Migrate to Kubernetes, change to ClusterIP
apiVersion: v1
kind: Service
metadata:
  name: database
spec:
  type: ClusterIP  # Changed from ExternalName
  selector:
    app: mysql
  ports:
    - port: 3306
# Application code unchanged - still uses "database" service name!
```

#### Key Points
- ✅ Easy external service integration
- ✅ Transparent to applications
- ✅ Good for migrations
- ✅ No IP address needed
- ❌ No load balancing
- ❌ No health checks
- ❌ DNS resolution depends on external DNS

---

### 5. Headless Service

**Purpose:** Direct pod-to-pod communication without load balancing

#### Characteristics
- `clusterIP: None`
- No virtual IP allocated
- DNS returns all pod IPs
- No load balancing by kube-proxy
- Client chooses which pod to connect to

#### Use Cases
- StatefulSets
- Databases requiring direct pod access
- Distributed systems (Cassandra, Kafka)
- Peer-to-peer applications
- Service discovery without load balancing

#### How It Works

```
DNS Query: mysql.default.svc.cluster.local
      ↓
CoreDNS returns ALL pod IPs
      ↓
Response:
  - mysql-0.mysql.default.svc.cluster.local → 10.244.1.5
  - mysql-1.mysql.default.svc.cluster.local → 10.244.1.6
  - mysql-2.mysql.default.svc.cluster.local → 10.244.1.7
      ↓
Client chooses which pod to connect to
```

#### Example with StatefulSet

```yaml
---
apiVersion: v1
kind: Service
metadata:
  name: mysql
  labels:
    app: mysql
spec:
  clusterIP: None  # Headless service
  selector:
    app: mysql
  ports:
    - port: 3306
      name: mysql

---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mysql
spec:
  serviceName: mysql  # References headless service
  replicas: 3
  selector:
    matchLabels:
      app: mysql
  template:
    metadata:
      labels:
        app: mysql
    spec:
      containers:
      - name: mysql
        image: mysql:8.0
        ports:
        - containerPort: 3306
          name: mysql
```

#### DNS Records for StatefulSet Pods

```bash
# Individual pod DNS names
mysql-0.mysql.default.svc.cluster.local  # First pod
mysql-1.mysql.default.svc.cluster.local  # Second pod
mysql-2.mysql.default.svc.cluster.local  # Third pod

# Service DNS returns all pod IPs
nslookup mysql.default.svc.cluster.local

# Output
Server:    10.96.0.10
Address 1: 10.96.0.10 kube-dns.kube-system.svc.cluster.local

Name:      mysql.default.svc.cluster.local
Address 1: 10.244.1.5 mysql-0.mysql.default.svc.cluster.local
Address 2: 10.244.1.6 mysql-1.mysql.default.svc.cluster.local
Address 3: 10.244.1.7 mysql-2.mysql.default.svc.cluster.local
```

#### Key Points
- ✅ Direct pod access
- ✅ Stable DNS names per pod
- ✅ Required for StatefulSets
- ✅ Client-side load balancing
- ❌ No automatic load balancing
- ❌ Client must handle pod selection

---

## Service Discovery

### 1. DNS-Based Service Discovery (Primary Method)

Kubernetes automatically creates DNS records for services using CoreDNS.

#### DNS Record Format

```bash
# Service DNS format
<service-name>.<namespace>.svc.<cluster-domain>

# Default cluster domain: cluster.local
<service-name>.<namespace>.svc.cluster.local

# Examples
backend.production.svc.cluster.local
mysql.database.svc.cluster.local
redis.cache.svc.cluster.local
```

#### DNS Resolution Examples

```bash
# From pod in same namespace
curl http://backend:8080

# From pod in different namespace
curl http://backend.production:8080

# Fully qualified domain name (FQDN)
curl http://backend.production.svc.cluster.local:8080
```

#### Testing DNS Resolution

```bash
# Using busybox
kubectl run -it --rm debug --image=busybox --restart=Never -- \
  nslookup backend.production.svc.cluster.local

# Using dnsutils
kubectl run -it --rm debug --image=tutum/dnsutils --restart=Never -- \
  dig backend.production.svc.cluster.local

# Check DNS config in pod
kubectl run -it --rm debug --image=busybox --restart=Never -- \
  cat /etc/resolv.conf

# Output
nameserver 10.96.0.10
search production.svc.cluster.local svc.cluster.local cluster.local
options ndots:5
```

### 2. Environment Variable-Based Discovery (Legacy)

Kubernetes injects environment variables for services into pods at creation time.

#### Environment Variable Format

```bash
# For service named "backend"
BACKEND_SERVICE_HOST=10.96.0.50
BACKEND_SERVICE_PORT=8080
BACKEND_PORT=tcp://10.96.0.50:8080
BACKEND_PORT_8080_TCP=tcp://10.96.0.50:8080
BACKEND_PORT_8080_TCP_PROTO=tcp
BACKEND_PORT_8080_TCP_PORT=8080
BACKEND_PORT_8080_TCP_ADDR=10.96.0.50
```

#### Limitations
- Only for services that exist when pod is created
- Services created after pod start won't have env vars
- DNS is preferred method

---

## Networking Architecture

### kube-proxy Modes

kube-proxy is responsible for implementing Services by programming network rules.

#### 1. iptables Mode (Default)

**How it works:**
- kube-proxy watches for Service and Endpoint changes
- Creates iptables NAT rules for each service
- Random load balancing across endpoints
- No userspace proxying (better performance than userspace mode)

**iptables rules example:**
```bash
# View iptables rules for service
sudo iptables-save | grep KUBE-SERVICES
sudo iptables-save | grep backend

# Example rules
-A KUBE-SERVICES -d 10.96.0.50/32 -p tcp -m tcp --dport 8080 \
   -j KUBE-SVC-BACKEND

-A KUBE-SVC-BACKEND -m statistic --mode random --probability 0.33 \
   -j KUBE-SEP-POD1
-A KUBE-SVC-BACKEND -m statistic --mode random --probability 0.50 \
   -j KUBE-SEP-POD2
-A KUBE-SVC-BACKEND -j KUBE-SEP-POD3
```

**Pros:**
- Fast and efficient
- No extra latency
- Default mode

**Cons:**
- Scales linearly with number of services
- No real load balancing (just random selection)
- Hard to troubleshoot

#### 2. IPVS Mode

**How it works:**
- Uses Linux IPVS (IP Virtual Server)
- Better performance for large clusters
- More load balancing algorithms
- Scales better than iptables

**Enable IPVS mode:**
```yaml
# kube-proxy ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: kube-proxy
  namespace: kube-system
data:
  config.conf: |
    mode: "ipvs"
    ipvs:
      scheduler: "rr"  # Options: rr, lc, dh, sh, sed, nq
```

**Load balancing algorithms:**
- `rr` - Round Robin
- `lc` - Least Connection
- `dh` - Destination Hashing
- `sh` - Source Hashing
- `sed` - Shortest Expected Delay
- `nq` - Never Queue

**View IPVS rules:**
```bash
# Install ipvsadm
sudo apt-get install ipvsadm

# View IPVS rules
sudo ipvsadm -L -n

# Example output
IP Virtual Server version 1.2.1 (size=4096)
Prot LocalAddress:Port Scheduler Flags
  -> RemoteAddress:Port           Forward Weight ActiveConn InActConn
TCP  10.96.0.50:8080 rr
  -> 10.244.1.5:8080              Masq    1      0          0
  -> 10.244.1.6:8080              Masq    1      0          0
  -> 10.244.1.7:8080              Masq    1      0          0
```

**Pros:**
- Better performance at scale
- More load balancing options
- Designed for load balancing

**Cons:**
- Requires kernel modules
- More complex setup
- Additional dependencies

---

## Advanced Concepts

### 1. Session Affinity (Sticky Sessions)

Ensures requests from same client go to same pod.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: stateful-app
spec:
  selector:
    app: stateful-app
  sessionAffinity: ClientIP
  sessionAffinityConfig:
    clientIP:
      timeoutSeconds: 10800  # 3 hours
  ports:
    - port: 80
      targetPort: 8080
```

**Use cases:**
- Shopping carts
- User sessions
- WebSocket connections
- Applications with session state

### 2. Multi-Port Services

Single service exposing multiple ports.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: multi-port-app
spec:
  selector:
    app: myapp
  ports:
    - name: http
      protocol: TCP
      port: 80
      targetPort: 8080
    - name: https
      protocol: TCP
      port: 443
      targetPort: 8443
    - name: metrics
      protocol: TCP
      port: 9090
      targetPort: 9090
```

### 3. Service Without Selectors

Manually manage endpoints.

```yaml
---
apiVersion: v1
kind: Service
metadata:
  name: external-service
spec:
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80

---
apiVersion: v1
kind: Endpoints
metadata:
  name: external-service  # Must match service name
subsets:
  - addresses:
      - ip: 203.0.113.10
      - ip: 203.0.113.11
    ports:
      - port: 80
```

### 4. Topology-Aware Routing

Route traffic to pods in same zone/region.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: regional-service
spec:
  selector:
    app: myapp
  topologyKeys:
    - "kubernetes.io/hostname"
    - "topology.kubernetes.io/zone"
    - "topology.kubernetes.io/region"
    - "*"
  ports:
    - port: 80
```

---

## Network Troubleshooting

### Common Issues and Solutions

#### Issue 1: Service Not Accessible

**Symptoms:**
```
curl: (7) Failed to connect to service port 8080: Connection refused
```

**Debugging steps:**
```bash
# 1. Check if service exists
kubectl get svc myservice

# 2. Check service endpoints
kubectl get endpoints myservice

# 3. Verify pod labels match service selector
kubectl describe svc myservice | grep Selector
kubectl get pods --show-labels

# 4. Check if pods are running and ready
kubectl get pods -l app=myapp

# 5. Test pod directly
POD_IP=$(kubectl get pod <pod-name> -o jsonpath='{.status.podIP}')
kubectl run test --image=curlimages/curl -it --rm -- curl $POD_IP:8080

# 6. Check service definition
kubectl get svc myservice -o yaml
```

#### Issue 2: DNS Not Resolving

**Symptoms:**
```
nslookup: can't resolve 'backend'
```

**Debugging steps:**
```bash
# 1. Check CoreDNS pods
kubectl get pods -n kube-system -l k8s-app=kube-dns

# 2. Check CoreDNS logs
kubectl logs -n kube-system -l k8s-app=kube-dns

# 3. Test DNS from pod
kubectl run -it --rm debug --image=busybox --restart=Never -- \
  nslookup kubernetes.default

# 4. Check resolv.conf in pod
kubectl run -it --rm debug --image=busybox --restart=Never -- \
  cat /etc/resolv.conf

# 5. Test service DNS
kubectl run -it --rm debug --image=busybox --restart=Never -- \
  nslookup myservice.default.svc.cluster.local
```

#### Issue 3: LoadBalancer Pending

**Symptoms:**
```
EXTERNAL-IP shows <pending>
```

**Solutions:**
```bash
# 1. Check events
kubectl describe svc myservice

# 2. Verify cloud provider configured
kubectl get nodes -o jsonpath='{.items[*].spec.providerID}'

# 3. For testing, use NodePort instead
kubectl patch svc myservice -p '{"spec":{"type":"NodePort"}}'

# 4. Install MetalLB for on-prem clusters
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.0/config/manifests/metallb-native.yaml
```

---

## Best Practices

### 1. Service Naming

```yaml
# Good naming conventions
backend-api          # Clear and descriptive
user-service        # Service purpose clear
mysql-primary       # Indicates role
redis-cache         # Technology and purpose

# Avoid
svc1, service-1, my-service, app
```

### 2. Port Naming

```yaml
# Always name ports in multi-port services
ports:
  - name: http     # Named
    port: 80
  - name: https    # Named
    port: 443
  - name: metrics  # Named
    port: 9090
```

### 3. Use ClusterIP by Default

```yaml
# Internal services should be ClusterIP
spec:
  type: ClusterIP  # Default, most secure
  selector:
    app: backend
```

### 4. Implement Health Checks

```yaml
spec:
  template:
    spec:
      containers:
      - name: app
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
```

### 5. Use Resource Limits

```yaml
spec:
  template:
    spec:
      containers:
      - name: app
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
```

---

## Real-World Scenarios

### Scenario 1: Blue-Green Deployment

```bash
# Deploy blue version
kubectl create deployment app-blue --image=myapp:v1.0 --replicas=3
kubectl label deployment app-blue version=blue

# Create service pointing to blue
kubectl create svc clusterip app --tcp=80:8080
kubectl patch svc app -p '{"spec":{"selector":{"version":"blue"}}}'

# Deploy green version
kubectl create deployment app-green --image=myapp:v2.0 --replicas=3
kubectl label deployment app-green version=green

# Switch traffic to green
kubectl patch svc app -p '{"spec":{"selector":{"version":"green"}}}'

# Rollback if needed
kubectl patch svc app -p '{"spec":{"selector":{"version":"blue"}}}'
```

### Scenario 2: Canary Deployment

```bash
# Stable version (90% traffic)
kubectl scale deployment app-stable --replicas=9

# Canary version (10% traffic)
kubectl scale deployment app-canary --replicas=1

# Both selected by same service
kubectl patch svc app -p '{"spec":{"selector":{"app":"myapp"}}}'
```

---

**This concludes the comprehensive guide. Refer to README.md for quick start and INTERVIEW-QA.md for exam preparation.**