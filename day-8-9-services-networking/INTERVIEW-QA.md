# Kubernetes Services & Networking - Interview Questions & Answers

> **50+ Interview Questions covering Basic, Intermediate, and Advanced levels**

---

## Table of Contents

- [Basic Level (1-15)](#basic-level)
- [Intermediate Level (16-35)](#intermediate-level)
- [Advanced Level (36-50)](#advanced-level)
- [Scenario-Based Questions (51-60)](#scenario-based-questions)
- [Troubleshooting Questions (61-70)](#troubleshooting-questions)

---

## Basic Level

### Q1: What is a Kubernetes Service?

**Answer:**
A Service is an abstraction that defines a logical set of Pods and a policy to access them. It provides:
- Stable IP address and DNS name
- Load balancing across pod replicas
- Service discovery mechanism
- Decoupling between frontend and backend pods

Services solve the problem of dynamic pod IPs by providing a stable endpoint that doesn't change even when pods are recreated.

---

### Q2: What are the different types of Services in Kubernetes?

**Answer:**
There are four main service types:

1. **ClusterIP** (Default)
   - Internal cluster access only
   - Virtual IP within cluster
   - Use case: Backend APIs, databases

2. **NodePort**
   - Exposes service on each node's IP at a static port (30000-32767)
   - Use case: Development, testing

3. **LoadBalancer**
   - Provisions external load balancer (cloud provider)
   - Use case: Production external access

4. **ExternalName**
   - Maps service to external DNS name
   - Use case: External databases, third-party APIs

---

### Q3: What is the default Service type in Kubernetes?

**Answer:**
ClusterIP is the default service type. If you don't specify a type in the Service manifest, Kubernetes automatically creates a ClusterIP service. This provides internal cluster-only access with a virtual IP address.

---

### Q4: What port range does NodePort use by default?

**Answer:**
NodePort uses the range **30000-32767** by default. This range can be configured in the API server using the `--service-node-port-range` flag.

Example:
```bash
kube-apiserver --service-node-port-range=30000-32767
```

---

### Q5: How does service discovery work in Kubernetes?

**Answer:**
Kubernetes provides two service discovery mechanisms:

1. **DNS (Primary Method)**
   - CoreDNS automatically creates DNS records
   - Format: `<service-name>.<namespace>.svc.cluster.local`
   - Pods can access services by name

2. **Environment Variables (Legacy)**
   - Kubernetes injects service environment variables into pods
   - Format: `<SERVICE_NAME>_SERVICE_HOST` and `<SERVICE_NAME>_SERVICE_PORT`
   - Only for services that exist when pod is created

DNS is the recommended approach as it's more dynamic and doesn't require pod restarts.

---

### Q6: What is an Endpoint in Kubernetes?

**Answer:**
An Endpoint is a Kubernetes object that tracks the IP addresses and ports of pods that match a Service's selector. 

Key points:
- Automatically created and managed by Kubernetes
- Updated when pods are added/removed
- One Endpoint object per Service
- Contains list of pod IPs and ports

Example:
```bash
kubectl get endpoints myservice
# Shows: 10.244.1.5:8080,10.244.1.6:8080,10.244.1.7:8080
```

---

### Q7: What is the difference between `port`, `targetPort`, and `nodePort`?

**Answer:**

- **port**: The port the service listens on (what clients connect to)
- **targetPort**: The port on the container/pod where the application is listening
- **nodePort**: The port exposed on each node (only for NodePort/LoadBalancer types)

Example:
```yaml
ports:
  - port: 80          # Service port
    targetPort: 8080  # Container port
    nodePort: 30080   # Node port (optional)
```

Traffic flow: `Client → Service:80 → Pod:8080`

---

### Q8: Can you access a ClusterIP service from outside the cluster?

**Answer:**
No, ClusterIP services are only accessible from within the cluster. They have a virtual IP that's only routable within the cluster network.

To access from outside, you can:
1. Use `kubectl port-forward`
2. Change to NodePort or LoadBalancer type
3. Use an Ingress controller
4. Use `kubectl proxy`

---

### Q9: What is a headless service?

**Answer:**
A headless service is a service with `clusterIP: None`. It doesn't allocate a virtual IP address and doesn't provide load balancing.

Characteristics:
- DNS returns all pod IPs directly
- No kube-proxy load balancing
- Used with StatefulSets
- Enables direct pod-to-pod communication

Use cases:
- Databases requiring direct pod access
- StatefulSet applications
- Peer-to-peer applications

---

### Q10: How do you create a Service imperatively?

**Answer:**
```bash
# Create ClusterIP service
kubectl create service clusterip myservice --tcp=80:8080

# Create NodePort service
kubectl create service nodeport myservice --tcp=80:8080 --node-port=30080

# Create LoadBalancer service
kubectl create service loadbalancer myservice --tcp=80:8080

# Expose a deployment
kubectl expose deployment myapp --port=80 --target-port=8080 --type=ClusterIP

# Expose a pod
kubectl expose pod mypod --port=80 --type=NodePort
```

---

### Q11: What is the DNS format for Kubernetes services?

**Answer:**
The DNS format follows this pattern:
```
<service-name>.<namespace>.svc.<cluster-domain>
```

Default cluster domain is `cluster.local`, so:
```
<service-name>.<namespace>.svc.cluster.local
```

Examples:
- `backend.production.svc.cluster.local`
- `mysql.database.svc.cluster.local`
- `api.default.svc.cluster.local`

Within the same namespace, you can use just the service name:
```bash
curl http://backend:8080
```

---

### Q12: What happens when you delete a Service?

**Answer:**
When you delete a Service:
1. The Service object is removed from the API server
2. The associated Endpoints object is deleted
3. DNS records are removed
4. kube-proxy removes iptables/ipvs rules
5. The virtual IP is released back to the pool
6. **Pods are NOT deleted** (they're independent resources)

The pods continue running but lose their stable network endpoint.

---

### Q13: Can a Service select Pods from different namespaces?

**Answer:**
No, Services can only select Pods within the same namespace. The selector only works within the Service's namespace.

For cross-namespace communication:
- Use FQDN: `service-name.namespace.svc.cluster.local`
- Or use ExternalName service pointing to another namespace's service

---

### Q14: What is sessionAffinity in Services?

**Answer:**
Session affinity (sticky sessions) ensures that requests from the same client always go to the same pod.

Configuration:
```yaml
spec:
  sessionAffinity: ClientIP  # Options: None, ClientIP
  sessionAffinityConfig:
    clientIP:
      timeoutSeconds: 10800  # 3 hours
```

Use cases:
- Shopping carts
- User sessions
- WebSocket connections
- Stateful applications

---

### Q15: How do you view the endpoints of a Service?

**Answer:**
```bash
# List all endpoints
kubectl get endpoints

# Get endpoints for specific service
kubectl get endpoints myservice

# Describe endpoints (detailed view)
kubectl describe endpoints myservice

# Get endpoints in YAML format
kubectl get endpoints myservice -o yaml

# Watch endpoints in real-time
kubectl get endpoints myservice -w
```

---

## Intermediate Level

### Q16: Explain how kube-proxy works.

**Answer:**
kube-proxy is a network proxy that runs on each node and implements Kubernetes Services.

**Responsibilities:**
1. Watches API server for Service and Endpoint changes
2. Maintains network rules on each node
3. Performs connection forwarding

**Operating Modes:**

1. **iptables mode** (default):
   - Creates iptables NAT rules
   - Randomly selects backend pod
   - No userspace proxying (better performance)

2. **IPVS mode**:
   - Uses Linux IPVS for load balancing
   - Better performance at scale
   - More load balancing algorithms (rr, lc, dh, sh, sed, nq)

3. **userspace mode** (legacy):
   - Proxies connections in userspace
   - Slower, rarely used

**Packet Flow (iptables mode):**
```
Client → Service VIP → iptables rules → NAT to Pod IP → Pod
```

---

### Q17: What is the difference between ClusterIP and Headless Service?

**Answer:**

| Aspect | ClusterIP | Headless Service |
|--------|-----------|------------------|
| Virtual IP | Yes (allocated) | No (`clusterIP: None`) |
| Load Balancing | Yes (kube-proxy) | No (client-side) |
| DNS Response | Single VIP | All pod IPs |
| Use Case | Standard services | StatefulSets, direct pod access |
| Endpoint | Service VIP | Individual pod IPs |

**ClusterIP Example:**
```bash
nslookup backend
# Returns: 10.96.0.50 (service VIP)
```

**Headless Example:**
```bash
nslookup mysql
# Returns: 
# 10.244.1.5 (mysql-0)
# 10.244.1.6 (mysql-1)
# 10.244.1.7 (mysql-2)
```

---

### Q18: How does LoadBalancer service work in cloud environments?

**Answer:**
LoadBalancer service creates a multi-layer architecture:

**Layers Created:**
1. **ClusterIP Service** - Internal virtual IP
2. **NodePort** - Port opened on all nodes
3. **External Load Balancer** - Provisioned by cloud provider

**Traffic Flow:**
```
Internet → Cloud LB (External IP) → NodePort → ClusterIP → Pods
```

**Cloud Provider Integration:**
- **AWS**: Creates ELB/NLB/ALB
- **GCP**: Creates Cloud Load Balancer
- **Azure**: Creates Azure Load Balancer

**Process:**
1. Service created with `type: LoadBalancer`
2. Cloud controller manager detects new service
3. Calls cloud provider API to create load balancer
4. External IP assigned to service
5. Load balancer configured to forward to NodePorts

**Example:**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: web
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
spec:
  type: LoadBalancer
  selector:
    app: web
  ports:
    - port: 80
      targetPort: 8080
```

---

### Q19: What is externalTrafficPolicy and what are its options?

**Answer:**
`externalTrafficPolicy` controls how external traffic is routed to pods.

**Options:**

1. **Cluster** (default):
   ```yaml
   externalTrafficPolicy: Cluster
   ```
   - Traffic can go to pods on any node
   - Even load distribution
   - Source IP is SNATed (lost)
   - Additional network hop possible
   - Better for general use

2. **Local**:
   ```yaml
   externalTrafficPolicy: Local
   ```
   - Traffic only to pods on receiving node
   - Preserves source IP address
   - No extra network hops
   - Potential uneven load distribution
   - Health checks per node

**Use Cases for Local:**
- Need to preserve client IP
- Applications requiring IP-based access control
- Reducing latency (fewer hops)
- Applications logging client IPs

**Trade-offs:**
```
Cluster:
✅ Even load distribution
✅ High availability
❌ Lost source IP
❌ Extra hop

Local:
✅ Preserve source IP
✅ Lower latency
❌ Uneven distribution
❌ Potential packet drops if no local pods
```

---

### Q20: How do you troubleshoot a Service that's not working?

**Answer:**
Systematic troubleshooting approach:

**Step 1: Verify Service exists**
```bash
kubectl get svc myservice
kubectl describe svc myservice
```

**Step 2: Check Endpoints**
```bash
kubectl get endpoints myservice
# Should show pod IPs. If empty, selector is wrong
```

**Step 3: Verify Pod Labels**
```bash
kubectl get pods --show-labels
kubectl describe svc myservice | grep Selector
```

**Step 4: Check Pod Status**
```bash
kubectl get pods -l app=myapp
# Ensure pods are Running and Ready
```

**Step 5: Test Pod Directly**
```bash
POD_IP=$(kubectl get pod <pod-name> -o jsonpath='{.status.podIP}')
kubectl run test --image=curlimages/curl -it --rm -- curl $POD_IP:8080
```

**Step 6: Test Service from Pod**
```bash
kubectl run test --image=curlimages/curl -it --rm -- curl http://myservice:80
```

**Step 7: Check DNS Resolution**
```bash
kubectl run -it --rm debug --image=busybox -- nslookup myservice
```

**Step 8: Check kube-proxy**
```bash
kubectl get pods -n kube-system -l k8s-app=kube-proxy
kubectl logs -n kube-system -l k8s-app=kube-proxy
```

**Step 9: Check Events**
```bash
kubectl get events --sort-by='.lastTimestamp'
```

---

### Q21: What is the difference between Service and Ingress?

**Answer:**

| Feature | Service | Ingress |
|---------|---------|---------|
| Layer | Layer 4 (TCP/UDP) | Layer 7 (HTTP/HTTPS) |
| Load Balancing | Yes | Yes |
| Path-based Routing | No | Yes |
| Host-based Routing | No | Yes |
| SSL Termination | Cloud-dependent | Yes |
| External IPs | One per service | One for multiple services |
| Protocol | Any TCP/UDP | HTTP/HTTPS |

**When to Use:**

**Service (LoadBalancer):**
- Non-HTTP protocols
- Simple TCP/UDP load balancing
- Each app needs separate external IP
- Direct pod access needed

**Ingress:**
- HTTP/HTTPS applications
- Multiple services behind single IP
- Path-based routing (`/api`, `/web`)
- Host-based routing (`api.example.com`, `web.example.com`)
- SSL termination
- Cost optimization (one LB for many services)

**Example:**
```yaml
# Service: One external IP
apiVersion: v1
kind: Service
metadata:
  name: web
spec:
  type: LoadBalancer  # Gets external IP
  ports:
    - port: 80

---
# Ingress: One IP for multiple services
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: main-ingress
spec:
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
              number: 8080
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

---

### Q22: Can you have a Service without a selector? If yes, when would you use it?

**Answer:**
Yes, you can create Services without selectors by manually managing Endpoints.

**Use Cases:**
1. External database connections
2. Services in different clusters
3. During migration (pointing to external services)
4. Third-party services with static IPs

**Example:**
```yaml
---
# Service without selector
apiVersion: v1
kind: Service
metadata:
  name: external-database
spec:
  ports:
    - protocol: TCP
      port: 3306
      targetPort: 3306

---
# Manually created Endpoints
apiVersion: v1
kind: Endpoints
metadata:
  name: external-database  # Must match service name
subsets:
  - addresses:
      - ip: 192.168.1.100
      - ip: 192.168.1.101
    ports:
      - port: 3306
```

**Key Points:**
- Service name and Endpoints name must match
- You're responsible for updating Endpoints
- No automatic endpoint management
- Useful for gradual migration to Kubernetes

---

### Q23: What happens when a LoadBalancer Service is in "Pending" state?

**Answer:**
LoadBalancer stuck in `<pending>` indicates the external load balancer hasn't been provisioned.

**Common Causes:**

1. **No Cloud Provider Configured**
   - Cluster not running on supported cloud platform
   - Cloud controller manager not installed

2. **Cloud Provider Quota Exceeded**
   - Reached maximum load balancers
   - Insufficient permissions

3. **Incorrect Annotations**
   - Wrong cloud-specific annotations
   - Invalid configuration

4. **On-Premises Cluster**
   - No cloud provider available
   - Need MetalLB or similar

**Solutions:**

```bash
# Check events
kubectl describe svc myservice

# Verify cloud provider
kubectl get nodes -o jsonpath='{.items[*].spec.providerID}'

# For testing, convert to NodePort
kubectl patch svc myservice -p '{"spec":{"type":"NodePort"}}'

# For on-prem, install MetalLB
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.0/config/manifests/metallb-native.yaml

# Configure MetalLB IP pool
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: first-pool
  namespace: metallb-system
spec:
  addresses:
  - 192.168.1.240-192.168.1.250
```

---

### Q24: How does DNS work for headless services with StatefulSets?

**Answer:**
Headless services with StatefulSets provide stable, predictable DNS names for each pod.

**DNS Pattern:**
```
<pod-name>.<service-name>.<namespace>.svc.<cluster-domain>
```

**Example Setup:**
```yaml
---
apiVersion: v1
kind: Service
metadata:
  name: mysql
spec:
  clusterIP: None  # Headless
  selector:
    app: mysql
  ports:
    - port: 3306

---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mysql
spec:
  serviceName: mysql
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
```

**DNS Records Created:**
```
# Service DNS (returns all pod IPs)
mysql.default.svc.cluster.local

# Individual pod DNS (stable, persistent)
mysql-0.mysql.default.svc.cluster.local → 10.244.1.5
mysql-1.mysql.default.svc.cluster.local → 10.244.1.6
mysql-2.mysql.default.svc.cluster.local → 10.244.1.7
```

**Key Benefits:**
- Stable DNS even if pod restarts
- Direct pod-to-pod communication
- Predictable naming (mysql-0, mysql-1, etc.)
- Supports master-slave configurations

**Testing:**
```bash
# Query service (returns all pods)
kubectl run -it --rm debug --image=busybox -- nslookup mysql.default.svc.cluster.local

# Query specific pod
kubectl run -it --rm debug --image=busybox -- nslookup mysql-0.mysql.default.svc.cluster.local
```

---

### Q25: Explain multi-port services with an example.

**Answer:**
Multi-port services expose multiple ports on the same service, useful when an application listens on multiple ports.

**Example: Web Application with HTTP, HTTPS, and Metrics**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web-app
spec:
  selector:
    app: web
  ports:
    - name: http        # Must name ports in multi-port services
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
  type: LoadBalancer
```

**Important Rules:**
1. **Must name all ports** in multi-port services
2. Names must be unique within the service
3. Names must be DNS-compatible (lowercase alphanumeric + hyphens)

**Accessing Ports:**
```bash
# HTTP
curl http://web-app:80

# HTTPS
curl https://web-app:443

# Metrics
curl http://web-app:9090/metrics
```

**Common Use Cases:**
- Web server: HTTP (80) + HTTPS (443)
- Application: API (8080) + Admin (8081) + Metrics (9090)
- Database: Primary (3306) + Replication (3307)
- gRPC: Service (50051) + Health (50052)

---

### Q26: How do you implement blue-green deployment using Services?

**Answer:**
Blue-green deployment uses service selectors to switch traffic between versions instantly.

**Implementation:**

**Step 1: Deploy Blue (Current)**
```bash
kubectl create deployment app-blue --image=myapp:v1.0 --replicas=3
kubectl label deployment app-blue version=blue
```

**Step 2: Create Service (pointing to blue)**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: app
spec:
  selector:
    version: blue  # Points to blue deployment
  ports:
    - port: 80
      targetPort: 8080
```

**Step 3: Deploy Green (New Version)**
```bash
kubectl create deployment app-green --image=myapp:v2.0 --replicas=3
kubectl label deployment app-green version=green
```

**Step 4: Test Green Internally**
```bash
# Create test service for green
kubectl expose deployment app-green --name=app-green-test --port=80 --target-port=8080

# Test
kubectl run test --image=curlimages/curl -it --rm -- curl http://app-green-test
```

**Step 5: Switch Traffic to Green**
```bash
kubectl patch svc app -p '{"spec":{"selector":{"version":"green"}}}'
# All traffic now goes to green instantly
```

**Step 6: Rollback if Needed**
```bash
kubectl patch svc app -p '{"spec":{"selector":{"version":"blue"}}}'
# Instant rollback to blue
```

**Step 7: Cleanup Old Version**
```bash
# After confirming green is stable
kubectl delete deployment app-blue
```

**Advantages:**
- Instant traffic switching
- Easy rollback
- Zero downtime
- Full testing before switching

**Disadvantages:**
- Double resource usage during transition
- Database migrations can be complex
- Need monitoring of both versions

---

### Q27: What is the service-cluster-ip-range and why is it important?

**Answer:**
`service-cluster-ip-range` is a CIDR range from which cluster IPs for services are allocated.

**Configuration:**
```bash
# Set in kube-apiserver
kube-apiserver --service-cluster-ip-range=10.96.0.0/12
```

**Characteristics:**
- Virtual IP range (not routable outside cluster)
- Default: `10.96.0.0/12` (gives ~1 million IPs)
- Must not overlap with pod network
- Must not overlap with node network

**Example Ranges:**
```
Service Range:  10.96.0.0/12  (10.96.0.0 - 10.111.255.255)
Pod Range:      10.244.0.0/16 (10.244.0.0 - 10.244.255.255)
Node Range:     192.168.0.0/16
```

**Why Important:**
1. **Capacity Planning**: Determines max number of services
2. **Network Design**: Must not conflict with other networks
3. **Routing**: Services only accessible within cluster
4. **Troubleshooting**: Understanding IP allocation helps debug

**Check Current Range:**
```bash
# View kube-apiserver configuration
kubectl cluster-info dump | grep service-cluster-ip-range

# Or check a service IP
kubectl get svc kubernetes -o yaml | grep clusterIP
```

---

### Q28: How do you expose a Deployment as a Service?

**Answer:**
Multiple methods to expose a Deployment:

**Method 1: Using kubectl expose**
```bash
# ClusterIP (default)
kubectl expose deployment myapp --port=80 --target-port=8080

# NodePort
kubectl expose deployment myapp --type=NodePort --port=80 --target-port=8080

# LoadBalancer
kubectl expose deployment myapp --type=LoadBalancer --port=80 --target-port=8080

# With specific name
kubectl expose deployment myapp --name=myservice --port=80
```

**Method 2: Using YAML**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: myservice
spec:
  selector:
    app: myapp  # Must match deployment labels
  ports:
    - port: 80
      targetPort: 8080
  type: ClusterIP
```

**Method 3: Using kubectl create service**
```bash
kubectl create service clusterip myservice --tcp=80:8080
# Then patch to add correct selector
kubectl patch svc myservice -p '{"spec":{"selector":{"app":"myapp"}}}'
```

**Verification:**
```bash
# Check service
kubectl get svc myservice

# Check endpoints match deployment pods
kubectl get endpoints myservice
kubectl get pods -l app=myapp -o wide

# Test connectivity
kubectl run test --image=curlimages/curl -it --rm -- curl http://myservice
```

---

### Q29: What are the pros and cons of NodePort services?

**Answer:**

**Pros:**
✅ Simple external access without cloud provider
✅ Works in any environment (cloud, on-prem, local)
✅ No additional infrastructure needed
✅ Good for development and testing
✅ Can access via any node's IP
✅ Automatic high availability (any node works)
✅ Easy to set up and understand

**Cons:**
❌ Exposes service on all nodes (security concern)
❌ Uses non-standard ports (30000-32767)
❌ Limited port range (only ~2700 ports available)
❌ Need to manage node IPs
❌ If node goes down, need to update DNS/clients
❌ Not ideal for production
❌ No built-in SSL termination
❌ Manual load balancer needed for HA

**When to Use:**
- Development environments
- Testing and demos
- On-premises without load balancers
- Quick prototypes
- CI/CD pipelines
- Lab environments

**When NOT to Use:**
- Production applications
- Security-sensitive workloads
- When you need standard ports (80, 443)
- When you have cloud load balancer available

**Better Alternatives for Production:**
- LoadBalancer service (cloud environments)
- Ingress controller (HTTP/HTTPS)
- Service mesh (advanced traffic management)

---

### Q30: How does service discovery work across namespaces?

**Answer:**
Services can be accessed across namespaces using fully qualified domain names (FQDN).

**DNS Format:**
```
<service-name>.<namespace>.svc.<cluster-domain>
```

**Example Setup:**
```yaml
# Namespace: production
apiVersion: v1
kind: Service
metadata:
  name: backend
  namespace: production
spec:
  selector:
    app: backend
  ports:
    - port: 8080

---
# Namespace: staging
apiVersion: v1
kind: Pod
metadata:
  name: frontend
  namespace: staging
spec:
  containers:
  - name: app
    image: myapp
```

**Accessing Across Namespaces:**

```bash
# From pod in staging namespace

# Short form (same namespace only)
curl http://backend:8080  # ❌ Won't work

# With namespace
curl http://backend.production:8080  # ✅ Works

# Fully qualified
curl http://backend.production.svc.cluster.local:8080  # ✅ Works
```

**Environment Variable Method:**
```yaml
# Pod in staging namespace
spec:
  containers:
  - name: app
    env:
    - name: BACKEND_URL
      value: "http://backend.production.svc.cluster.local:8080"
```

**Key Points:**
- Services can't select pods from other namespaces
- DNS allows cross-namespace communication
- Network policies can restrict cross-namespace traffic
- Use FQDN for clarity and avoiding confusion

---

## Advanced Level

### Q31: Explain the complete packet flow for a ClusterIP service request.

**Answer:**
Detailed packet flow from client pod to backend pod through ClusterIP service.

**Architecture:**
```
Client Pod (10.244.1.5)
    ↓
Service VIP (10.96.0.50:8080)
    ↓
iptables/IPVS rules (on node)
    ↓
Backend Pod (10.244.2.10:8080)
```

**Step-by-Step Flow:**

**1. Client Pod Makes Request**
```
Source: 10.244.1.5:random-port
Destination: 10.96.0.50:8080 (Service VIP)
```

**2. Packet Hits Node's Network Stack**
- Packet enters node's network namespace
- Linux kernel processes the packet

**3. iptables/IPVS Intercepts (kube-proxy rules)**
```bash
# iptables rule example
-A KUBE-SERVICES -d 10.96.0.50/32 -p tcp -m tcp --dport 8080 \
   -j KUBE-SVC-BACKEND
```

**4. DNAT (Destination NAT) Applied**
- Service VIP replaced with pod IP
- Random pod selected (load balancing)
```
Before DNAT:
  Dst: 10.96.0.50:8080

After DNAT:
  Dst: 10.244.2.10:8080 (randomly selected pod)
```

**5. Packet Routed via CNI**
- CNI plugin (Calico/Flannel/Weave) routes packet
- Packet forwarded to destination node if needed
- Delivered to backend pod

**6. Backend Pod Processes Request**
- Application receives packet
- Sees source IP: 10.244.1.5
- Processes and generates response

**7. Response Packet**
```
Source: 10.244.2.10:8080
Destination: 10.244.1.5:random-port
```

**8. Connection Tracking (conntrack)**
- Linux conntrack remembers DNAT mapping
- Automatically applies reverse SNAT on response

**9. SNAT Applied to Response**
```
Before SNAT:
  Src: 10.244.2.10:8080

After SNAT:
  Src: 10.96.0.50:8080 (Service VIP)
```

**10. Response Delivered to Client**
- Client pod receives response
- Sees source as Service VIP (not backend pod)
- Application doesn't know which pod serviced request

**iptables Rules (Simplified):**
```bash
# Main service chain
-A KUBE-SERVICES -d 10.96.0.50/32 -p tcp --dport 8080 -j KUBE-SVC-XXX

# Load balancing (random selection)
-A KUBE-SVC-XXX -m statistic --mode random --probability 0.33 -j KUBE-SEP-POD1
-A KUBE-SVC-XXX -m statistic --mode random --probability 0.50 -j KUBE-SEP-POD2
-A KUBE-SVC-XXX -j KUBE-SEP-POD3

# DNAT to specific pods
-A KUBE-SEP-POD1 -p tcp -j DNAT --to-destination 10.244.2.10:8080
-A KUBE-SEP-POD2 -p tcp -j DNAT --to-destination 10.244.2.11:8080
-A KUBE-SEP-POD3 -p tcp -j DNAT --to-destination 10.244.2.12:8080
```

**Key Takeaways:**
- Service VIP is virtual (not assigned to any interface)
- kube-proxy creates iptables/IPVS rules
- DNAT changes destination to actual pod IP
- conntrack maintains connection state
- SNAT makes response appear from service VIP
- Client never knows actual backend pod IP

---

### Q32: How would you implement canary deployments using services?

**Answer:**
Canary deployment gradually shifts traffic from stable to new version.

**Strategy: Weight-Based Using Replicas**

**Step 1: Deploy Stable Version (90% traffic)**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-stable
spec:
  replicas: 9  # 90% of traffic
  selector:
    matchLabels:
      app: myapp
      track: stable
  template:
    metadata:
      labels:
        app: myapp
        track: stable
    spec:
      containers:
      - name: app
        image: myapp:v1.0
```

**Step 2: Deploy Canary Version (10% traffic)**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-canary
spec:
  replicas: 1  # 10% of traffic
  selector:
    matchLabels:
      app: myapp
      track: canary
  template:
    metadata:
      labels:
        app: myapp
        track: canary
    spec:
      containers:
      - name: app
        image: myapp:v2.0
```

**Step 3: Service Selects Both**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: app
spec:
  selector:
    app: myapp  # Selects both stable and canary
  ports:
    - port: 80
      targetPort: 8080
```

**Step 4: Monitor Canary**
```bash
# Watch logs
kubectl logs -f -l track=canary

# Check metrics
kubectl top pods -l track=canary

# Monitor errors
kubectl get events --field-selector involvedObject.name=app-canary
```

**Step 5: Gradually Increase Canary Traffic**
```bash
# 20% canary
kubectl scale deployment app-canary --replicas=2
kubectl scale deployment app-stable --replicas=8

# 50% canary
kubectl scale deployment app-canary --replicas=5
kubectl scale deployment app-stable --replicas=5

# 100% canary (complete rollout)
kubectl scale deployment app-canary --replicas=10
kubectl scale deployment app-stable --replicas=0
```

**Step 6: Rollback if Issues Detected**
```bash
# Quick rollback: scale canary to 0
kubectl scale deployment app-canary --replicas=0
kubectl scale deployment app-stable --replicas=10
```

**Step 7: Cleanup After Success**
```bash
# Delete stable deployment
kubectl delete deployment app-stable

# Rename canary to stable (optional)
kubectl label deployment app-canary track=stable --overwrite
```

**Advanced: Using Service Mesh (Istio)**
```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: app
spec:
  hosts:
  - app
  http:
  - match:
    - headers:
        user-type:
          exact: beta-tester
    route:
    - destination:
        host: app
        subset: canary
  - route:
    - destination:
        host: app
        subset: stable
      weight: 90
    - destination:
        host: app
        subset: canary
      weight: 10
```

**Benefits:**
- Gradual rollout reduces risk
- Easy to rollback
- Monitor canary in production
- A/B testing capability

**Limitations:**
- Rough traffic distribution (not exact percentages)
- Need service mesh for precise control
- Requires monitoring and automation

---

### Q33: What are the implications and use cases of topology-aware routing?

**Answer:**
Topology-aware routing routes traffic based on topology (zone, region, node).

**Configuration:**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: regional-service
spec:
  selector:
    app: myapp
  topologyKeys:
    - "kubernetes.io/hostname"           # Same node
    - "topology.kubernetes.io/zone"      # Same zone
    - "topology.kubernetes.io/region"    # Same region
    - "*"                                # Any endpoint
  ports:
    - port: 80
```

**How It Works:**
1. Client makes request to service
2. kube-proxy checks topology constraints in order
3. Routes to pod matching first constraint
4. Falls back to next constraint if no match

**Example Scenario:**
```
Client Pod on node-1 in us-east-1a requests service

Topology Key Check:
1. kubernetes.io/hostname = node-1
   → Found pod on node-1 ✓ Use this pod
   
If no pod on node-1:
2. topology.kubernetes.io/zone = us-east-1a
   → Found pod in us-east-1a ✓ Use this pod
   
If no pod in us-east-1a:
3. topology.kubernetes.io/region = us-east
   → Found pod in us-east ✓ Use this pod
   
If no pod in us-east:
4. "*" (any)
   → Use any available pod
```

**Use Cases:**

1. **Reduce Latency**
   - Keep traffic in same zone
   - Avoid cross-zone network hops
   
2. **Reduce Costs**
   - Avoid inter-zone data transfer charges
   - Cloud providers charge for cross-AZ traffic
   
3. **Data Locality**
   - Keep data processing close to storage
   - Regulatory compliance (data residency)
   
4. **High Availability**
   - Prefer local, fallback to remote
   - Gradual degradation

**Cost Example (AWS):**
```
Same AZ:       $0 (free)
Cross-AZ:      $0.01/GB
Cross-Region:  $0.02/GB

With topology routing:
✅ Traffic stays in AZ → Save money
```

**Node Labels Required:**
```bash
# Check node labels
kubectl get nodes --show-labels

# Should have:
kubernetes.io/hostname=node-1
topology.kubernetes.io/zone=us-east-1a
topology.kubernetes.io/region=us-east
```

**Limitations:**
- Potential uneven load distribution
- Requires proper node labeling
- May not route optimally if pod distribution is uneven
- Deprecated in favor of Topology Aware Hints (K8s 1.21+)

**New: Topology Aware Hints (Replacement)**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: myservice
  annotations:
    service.kubernetes.io/topology-aware-hints: auto
spec:
  selector:
    app: myapp
  ports:
    - port: 80
```

---

### Q34: Explain how session affinity works at a low level.

**Answer:**
Session affinity ensures requests from the same client go to the same pod.

**Configuration:**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: app
spec:
  selector:
    app: myapp
  sessionAffinity: ClientIP
  sessionAffinityConfig:
    clientIP:
      timeoutSeconds: 10800  # 3 hours
  ports:
    - port: 80
```

**How It Works (iptables mode):**

**1. First Request:**
```
Client IP: 192.168.1.100
Service VIP: 10.96.0.50

iptables creates entry in connection tracking (conntrack):
  Source: 192.168.1.100
  Destination: 10.96.0.50
  Selected Pod: 10.244.2.10 (randomly chosen)
  Timeout: 10800 seconds
```

**2. Subsequent Requests:**
```
Same client (192.168.1.100) makes another request
↓
iptables checks conntrack table
↓
Finds existing entry for 192.168.1.100 → 10.96.0.50
↓
Routes to same pod: 10.244.2.10 (not random)
```

**3. After Timeout:**
```
10800 seconds (3 hours) pass
↓
conntrack entry expires
↓
Next request treated as new (random pod selection)
```

**iptables Rules:**
```bash
# Without session affinity (random each time)
-A KUBE-SVC-XXX -m statistic --mode random --probability 0.33 -j KUBE-SEP-POD1
-A KUBE-SVC-XXX -m statistic --mode random --probability 0.50 -j KUBE-SEP-POD2
-A KUBE-SVC-XXX -j KUBE-SEP-POD3

# With session affinity (recent module)
-A KUBE-SVC-XXX -m recent --name KUBE-SEP-POD1 --rcheck --seconds 10800 --reap -j KUBE-SEP-POD1
-A KUBE-SVC-XXX -m recent --name KUBE-SEP-POD2 --rcheck --seconds 10800 --reap -j KUBE-SEP-POD2
-A KUBE-SVC-XXX -m recent --name KUBE-SEP-POD3 --rcheck --seconds 10800 --reap -j KUBE-SEP-POD3
-A KUBE-SVC-XXX -m statistic --mode random --probability 0.33 -j KUBE-SEP-POD1
```

**View conntrack entries:**
```bash
# Install conntrack
sudo apt-get install conntrack

# View entries
sudo conntrack -L | grep 10.96.0.50

# Output
tcp 6 431978 ESTABLISHED src=192.168.1.100 dst=10.96.0.50 sport=52341 dport=80 \
    src=10.244.2.10 dst=192.168.1.100 sport=8080 dport=52341
```

**Affinity Based On:**
- **ClientIP only** - Source IP address
- Not based on:
  - HTTP cookies
  - HTTP headers
  - Username
  - Session IDs

**Limitations:**
1. **NAT Issues:**
   - Clients behind NAT appear as same IP
   - All users from same corporate network → same pod

2. **Uneven Distribution:**
   - Some clients more active → pod overload
   - Can't rebalance without breaking sessions

3. **Pod Failure:**
   - If pod dies, sessions lost
   - Clients redistributed on next request

4. **No HTTP-level Affinity:**
   - Can't use cookies
   - Need Ingress/Service Mesh for advanced affinity

**When to Use:**
- WebSocket connections
- Shopping carts (if no shared storage)
- Stateful applications without shared backend
- Applications with in-memory sessions

**Better Alternatives:**
- External session storage (Redis, Memcached)
- Sticky sessions in Ingress controller
- Service mesh (Istio) with header-based routing
- Shared session backend (database)

---

### Q35: How do services work with Network Policies?

**Answer:**
Services and Network Policies work together to control traffic flow in Kubernetes.

**Key Concept:**
- **Services**: Provide stable endpoints and load balancing
- **Network Policies**: Control allowed traffic between pods

**Example: Restricting Backend Access**

**Setup: 3-Tier App**
```
Frontend Pods → Backend Service → Backend Pods → Database Service → Database Pods
```

**1. Backend Service (ClusterIP)**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: backend
  namespace: production
spec:
  selector:
    app: backend
    tier: api
  ports:
    - port: 8080
```

**2. Network Policy (Restrict Access to Backend)**
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-policy
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: backend
      tier: api
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend  # Only frontend can access
    ports:
    - protocol: TCP
      port: 8080
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: database  # Backend can only reach database
    ports:
    - protocol: TCP
      port: 3306
  - to:  # DNS
    - namespaceSelector:
        matchLabels:
          name: kube-system
    ports:
    - protocol: UDP
      port: 53
```

**How They Work Together:**

**Scenario 1: Frontend → Backend (Allowed)**
```
1. Frontend pod calls: http://backend:8080
2. Service resolves to backend pod IPs
3. Network Policy checks:
   - Source: frontend pod ✓
   - Destination: backend pod ✓
   - Port: 8080 ✓
4. Traffic allowed ✓
```

**Scenario 2: Random Pod → Backend (Blocked)**
```
1. Random pod calls: http://backend:8080
2. Service resolves to backend pod IPs
3. Network Policy checks:
   - Source: random pod (not frontend) ✗
4. Traffic blocked ✗
```

**Important Points:**

1. **Network Policies Apply to Pods, Not Services**
   ```yaml
   # Policy selector matches POD labels
   podSelector:
     matchLabels:
       app: backend  # Actual pods
   ```

2. **Service DNS Still Works**
   - Network Policy doesn't block DNS resolution
   - Only blocks actual traffic to pods

3. **Default Behavior:**
   - No Network Policy = All traffic allowed
   - With Network Policy = Default deny (must explicitly allow)

4. **Service Traffic Flow:**
   ```
   Source Pod
       ↓
   Service (DNS/VIP) - No policy enforcement
       ↓
   Backend Pod - Network Policy enforced here
   ```

**Advanced Example: Cross-Namespace with Service**

```yaml
# Allow frontend in namespace A to reach backend service in namespace B
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-policy
  namespace: namespace-b
spec:
  podSelector:
    matchLabels:
      app: backend
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: namespace-a
      podSelector:
        matchLabels:
          app: frontend
    ports:
    - protocol: TCP
      port: 8080
```

**Testing Network Policies:**
```bash
# From frontend pod (should work)
kubectl exec -it frontend-pod -- curl http://backend:8080
# Expected: 200 OK

# From random pod (should fail)
kubectl run test --image=curlimages/curl -it --rm -- curl http://backend:8080
# Expected: Timeout or connection refused

# Check policy
kubectl describe networkpolicy backend-policy
```

**Best Practices:**
1. Always allow DNS (port 53 UDP)
2. Start with broad policies, narrow down
3. Test policies before applying to production
4. Document allowed traffic flows
5. Use namespace selectors for multi-tier apps

---

## Scenario-Based Questions

### Q36: Design a service architecture for a multi-tenant application.

**Answer:**

**Requirements:**
- Isolate tenants
- Shared infrastructure
- Cost-effective
- Scalable

**Architecture:**

**Option 1: Namespace-per-Tenant**
```yaml
# Tenant A - Namespace
apiVersion: v1
kind: Namespace
metadata:
  name: tenant-a
  labels:
    tenant: a

---
# Backend Service (Tenant A)
apiVersion: v1
kind: Service
metadata:
  name: backend
  namespace: tenant-a
spec:
  selector:
    app: backend
    tenant: a
  ports:
    - port: 8080

---
# Tenant B - Namespace
apiVersion: v1
kind: Namespace
metadata:
  name: tenant-b
  labels:
    tenant: b

---
# Backend Service (Tenant B)
apiVersion: v1
kind: Service
metadata:
  name: backend
  namespace: tenant-b
spec:
  selector:
    app: backend
    tenant: b
  ports:
    - port: 8080
```

**Option 2: Shared Services with Headers**
```yaml
# Single multi-tenant service
apiVersion: v1
kind: Service
metadata:
  name: api-gateway
spec:
  selector:
    app: api-gateway
  ports:
    - port: 80

---
# Ingress routes by tenant
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: multi-tenant
spec:
  rules:
  - host: tenant-a.example.com
    http:
      paths:
      - path: /
        backend:
          service:
            name: api-gateway
            port:
              number: 80
  - host: tenant-b.example.com
    http:
      paths:
      - path: /
        backend:
          service:
            name: api-gateway
            port:
              number: 80
```

**Network Isolation:**
```yaml
# Prevent cross-tenant communication
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-cross-tenant
  namespace: tenant-a
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          tenant: a  # Only same tenant
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          tenant: a
```

**Benefits:**
- ✅ Strong isolation
- ✅ Independent scaling
- ✅ Separate resource quotas
- ✅ Clear tenant boundaries

**Challenges:**
- Resource overhead per tenant
- Management complexity
- Shared services configuration

---

### Q37: You have a service that sometimes returns 503 errors. How do you troubleshoot?

**Answer:**

**Systematic Troubleshooting:**

**Step 1: Check Service and Endpoints**
```bash
# Verify service exists
kubectl get svc myservice

# Check endpoints - are there any?
kubectl get endpoints myservice

# Expected: Should show pod IPs
# If empty: selector mismatch
```

**Step 2: Check Pod Health**
```bash
# Pod status
kubectl get pods -l app=myapp

# Are pods ready?
kubectl get pods -l app=myapp -o wide

# Check readiness probes
kubectl describe pods -l app=myapp | grep -A 5 Readiness

# Pod logs
kubectl logs -l app=myapp --tail=100
```

**Step 3: Test Pods Directly**
```bash
# Get pod IP
POD_IP=$(kubectl get pod <pod-name> -o jsonpath='{.status.podIP}')

# Test directly (bypass service)
kubectl run test --image=curlimages/curl -it --rm -- curl http://$POD_IP:8080

# If this works but service doesn't: service/endpoint issue
# If this fails: application issue
```

**Step 4: Check Resource Limits**
```bash
# Check if pods are being OOMKilled or CPU throttled
kubectl describe pod <pod-name> | grep -i -A 5 "last state"

# Check current resource usage
kubectl top pods -l app=myapp

# Check limits
kubectl describe pod <pod-name> | grep -A 5 Limits
```

**Step 5: Check kube-proxy**
```bash
# kube-proxy pods healthy?
kubectl get pods -n kube-system -l k8s-app=kube-proxy

# Check logs
kubectl logs -n kube-system -l k8s-app=kube-proxy | grep -i error

# Check iptables rules (on node)
sudo iptables-save | grep myservice
```

**Step 6: Check for Connection Limits**
```bash
# Too many connections?
kubectl exec <pod-name> -- netstat -an | grep ESTABLISHED | wc -l

# Check application max connections
kubectl logs <pod-name> | grep -i "connection"
```

**Step 7: Monitor in Real-Time**
```bash
# Watch endpoints
kubectl get endpoints myservice -w

# Watch pods
kubectl get pods -l app=myapp -w

# Stream logs from all pods
kubectl logs -f -l app=myapp --all-containers=true
```

**Common Causes of 503:**

1. **No Healthy Endpoints**
   - All pods failing readiness probes
   - Pods not ready yet (rolling update)
   
2. **Resource Exhaustion**
   - CPU throttling
   - Memory limits reached
   - Too many connections

3. **Application Issues**
   - Slow database queries
   - External dependency timeout
   - Application crashes/restarts

4. **Network Issues**
   - kube-proxy problems
   - CNI issues
   - iptables rules missing

**Quick Fixes:**

```bash
# Scale up if resource constrained
kubectl scale deployment myapp --replicas=10

# Restart pods if they're in bad state
kubectl rollout restart deployment myapp

# Update readiness probe if too strict
kubectl patch deployment myapp -p '{"spec":{"template":{"spec":{"containers":[{"name":"myapp","readinessProbe":{"initialDelaySeconds":30}}]}}}}'
```

---

### Q38: Design service architecture for a microservices application with 10+ services.

**Answer:**

**Architecture Design:**

**Layer 1: Frontend (External Access)**
```yaml
# LoadBalancer for web traffic
apiVersion: v1
kind: Service
metadata:
  name: frontend
  namespace: production
spec:
  type: LoadBalancer
  selector:
    app: frontend
  ports:
    - port: 80
      targetPort: 3000
```

**Layer 2: API Gateway (Entry Point)**
```yaml
# ClusterIP - internal traffic orchestration
apiVersion: v1
kind: Service
metadata:
  name: api-gateway
  namespace: production
spec:
  type: ClusterIP
  selector:
    app: api-gateway
  ports:
    - port: 8080
      targetPort: 8080
```

**Layer 3: Business Services (ClusterIP)**
```yaml
# User Service
---
apiVersion: v1
kind: Service
metadata:
  name: user-service
  namespace: production
  labels:
    tier: business
spec:
  type: ClusterIP
  selector:
    app: user-service
  ports:
    - name: http
      port: 8080
    - name: grpc
      port: 9090

# Order Service
---
apiVersion: v1
kind: Service
metadata:
  name: order-service
  namespace: production
  labels:
    tier: business
spec:
  type: ClusterIP
  selector:
    app: order-service
  ports:
    - name: http
      port: 8080

# Payment Service
---
apiVersion: v1
kind: Service
metadata:
  name: payment-service
  namespace: production
  labels:
    tier: business
spec:
  type: ClusterIP
  selector:
    app: payment-service
  ports:
    - name: http
      port: 8080

# ... 7 more services
```

**Layer 4: Data Layer (Headless for StatefulSets)**
```yaml
# PostgreSQL
---
apiVersion: v1
kind: Service
metadata:
  name: postgres
  namespace: production
spec:
  clusterIP: None  # Headless
  selector:
    app: postgres
  ports:
    - port: 5432

# Redis Cluster
---
apiVersion: v1
kind: Service
metadata:
  name: redis
  namespace: production
spec:
  clusterIP: None
  selector:
    app: redis
  ports:
    - port: 6379

# Kafka
---
apiVersion: v1
kind: Service
metadata:
  name: kafka
  namespace: production
spec:
  clusterIP: None
  selector:
    app: kafka
  ports:
    - port: 9092
```

**Layer 5: External Services**
```yaml
# External payment gateway
---
apiVersion: v1
kind: Service
metadata:
  name: stripe-api
  namespace: production
spec:
  type: ExternalName
  externalName: api.stripe.com

# External email service
---
apiVersion: v1
kind: Service
metadata:
  name: sendgrid-api
  namespace: production
spec:
  type: ExternalName
  externalName: api.sendgrid.com
```

**Network Policies:**
```yaml
# API Gateway can call all business services
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: api-gateway-policy
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: api-gateway
  policyTypes:
  - Egress
  egress:
  - to:
    - podSelector:
        matchLabels:
          tier: business
    ports:
    - protocol: TCP
      port: 8080

# Business services can only call data layer
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: business-services-policy
  namespace: production
spec:
  podSelector:
    matchLabels:
      tier: business
  policyTypes:
  - Egress
  egress:
  - to:
    - podSelector:
        matchLabels:
          tier: data
```

**Service Mesh (Optional - Istio)**
```yaml
# Better observability, traffic management
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: user-service
spec:
  hosts:
  - user-service
  http:
  - timeout: 10s
    retries:
      attempts: 3
      perTryTimeout: 2s
    route:
    - destination:
        host: user-service
```

**Benefits:**
- Clear separation of concerns
- Easy to scale individual services
- Network policies for security
- Service mesh for observability
- ExternalName for external dependencies

---

## Troubleshooting Questions

### Q39: Service endpoints are empty. What could be wrong?

**Answer:**

**Causes and Solutions:**

**1. Label Selector Mismatch**
```bash
# Check service selector
kubectl describe svc myservice | grep Selector
# Shows: app=backend,tier=api

# Check pod labels
kubectl get pods --show-labels
# If labels don't match exactly: no endpoints

# Fix: Update pod labels
kubectl label pods mypod app=backend tier=api
```

**2. Pods Not Ready**
```bash
# Check pod status
kubectl get pods -l app=backend

# If STATUS is not "Running" or READY is "0/1"
kubectl describe pod <pod-name>

# Check readiness probe
kubectl describe pod <pod-name> | grep -A 5 Readiness

# Fix: Fix readiness probe or application
```

**3. Wrong Namespace**
```bash
# Service in namespace A, pods in namespace B
kubectl get svc myservice -n namespace-a
kubectl get pods -l app=backend -n namespace-b

# Fix: Deploy service in correct namespace
```

**4. Selector Typo**
```yaml
# Service has typo
selector:
  app: backnd  # Missing 'e'

# Pods have
labels:
  app: backend

# Fix: Correct the selector
kubectl patch svc myservice -p '{"spec":{"selector":{"app":"backend"}}}'
```

**5. Pods Haven't Started Yet**
```bash
# During deployment, pods may not be ready
kubectl get pods -l app=backend -w

# Wait for pods to be ready
kubectl wait --for=condition=ready pod -l app=backend --timeout=180s
```

**Verification Steps:**
```bash
# 1. Get service details
kubectl get svc myservice -o yaml

# 2. Extract selector
SELECTOR=$(kubectl get svc myservice -o jsonpath='{.spec.selector}')

# 3. Find matching pods
kubectl get pods -l app=backend --show-labels

# 4. Check if any match
kubectl get pods -l app=backend -o name

# 5. Manually create endpoint if needed (temporary fix)
kubectl patch svc myservice --type='json' -p='[{"op": "replace", "path": "/spec/selector", "value": {"app":"backend"}}]'
```

---

### Q40: LoadBalancer external IP stuck in `<pending>`. How to fix?

**Answer:**

**Diagnosis:**

**1. Check Service Events**
```bash
kubectl describe svc myservice

# Look for errors like:
# - "cloud provider not configured"
# - "quota exceeded"
# - "invalid annotations"
```

**2. Verify Cloud Provider**
```bash
# Check if cluster has cloud provider
kubectl get nodes -o jsonpath='{.items[*].spec.providerID}'

# Should show: aws://us-east-1a/i-xxxxx
# Empty = no cloud provider
```

**Solutions:**

**Option 1: Wait (Cloud Provisioning)**
```bash
# Can take 1-5 minutes
kubectl get svc myservice -w

# Check cloud provider console for LB creation
```

**Option 2: Check Cloud Provider Quota**
```bash
# AWS
aws elbv2 describe-load-balancers --region us-east-1

# GCP
gcloud compute addresses list

# Azure
az network lb list
```

**Option 3: Convert to NodePort (Workaround)**
```bash
kubectl patch svc myservice -p '{"spec":{"type":"NodePort"}}'

# Get NodePort
kubectl get svc myservice
# Access via: http://<node-ip>:<node-port>
```

**Option 4: Install MetalLB (On-Premises)**
```bash
# Install MetalLB
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.0/config/manifests/metallb-native.yaml

# Configure IP pool
cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: first-pool
  namespace: metallb-system
spec:
  addresses:
  - 192.168.1.240-192.168.1.250
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: empty
  namespace: metallb-system
EOF

# Service should get IP from pool
kubectl get svc myservice
```

**Option 5: Check Annotations (Cloud-Specific)**
```yaml
# AWS - may need specific annotations
annotations:
  service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
  service.beta.kubernetes.io/aws-load-balancer-nlb-target-type