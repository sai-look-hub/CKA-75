# 🎤 Interview Q&A: CNI & Network Plugins

---

## Q1: What is CNI and why is it important in Kubernetes?

**Answer:**

**CNI = Container Network Interface**

A **specification** and set of libraries for configuring network interfaces in Linux containers.

**Why Important:**

1. **Standardization**
   - Common interface for all networking solutions
   - Container runtime agnostic
   - Kubernetes can work with any CNI-compliant plugin

2. **Pluggability**
   - Easy to switch networking solutions
   - No vendor lock-in
   - Choose based on requirements

3. **Decoupling**
   - Networking separate from container runtime
   - Different teams can manage each
   - Easier to update independently

**How It Works:**

```
1. kubelet creates pod
   ↓
2. kubelet calls CNI plugin
   ↓
3. CNI plugin creates network interface
   ↓
4. IPAM allocates IP address
   ↓
5. CNI configures interface with IP
   ↓
6. CNI sets up routing
   ↓
7. Pod has network connectivity
```

**CNI Plugin Types:**

**Main Plugins:**
- Create network interface
- Examples: bridge, ipvlan, macvlan

**IPAM Plugins:**
- Allocate IP addresses
- Examples: host-local, dhcp

**Meta Plugins:**
- Modify behavior
- Examples: portmap, bandwidth, tuning

**Example CNI Config:**
```json
{
  "cniVersion": "0.4.0",
  "name": "k8s-network",
  "type": "bridge",
  "bridge": "cni0",
  "ipam": {
    "type": "host-local",
    "subnet": "10.244.0.0/16"
  }
}
```

**Without CNI:**
- Every runtime implements networking differently
- Hard to switch solutions
- No standardization

**With CNI:**
- Standard interface
- Easy to switch plugins
- Better ecosystem

---

## Q2: Compare Calico, Flannel, and Cilium. When would you use each?

**Answer:**

### **Calico**

**Architecture:**
- Layer 3 routing (BGP-based)
- No overlay network (by default)
- Felix agent programs routes
- BIRD handles BGP

**Pros:**
- ✅ Excellent performance (no overlay)
- ✅ Advanced network policies
- ✅ Highly scalable (5000+ nodes)
- ✅ BGP peering support

**Cons:**
- ❌ More complex
- ❌ Requires BGP knowledge
- ❌ More moving parts

**Use Calico When:**
- Large-scale deployment (1000+ nodes)
- On-premises with BGP infrastructure
- Need advanced network policies
- Performance critical
- Have networking expertise

**Example:** Enterprise data center with 2000 nodes

---

### **Flannel**

**Architecture:**
- Overlay network (VXLAN default)
- Simple subnet allocation per node
- flanneld daemon manages config

**Pros:**
- ✅ Very simple installation
- ✅ Works everywhere
- ✅ Low operational overhead
- ✅ Good for getting started

**Cons:**
- ❌ Limited network policy support
- ❌ VXLAN overhead (~15%)
- ❌ Less feature-rich

**Use Flannel When:**
- Simple requirements
- Getting started with Kubernetes
- Small to medium clusters (< 500 nodes)
- Don't need complex policies
- Want minimal complexity

**Example:** Development cluster, startup MVP

---

### **Cilium**

**Architecture:**
- eBPF-based (kernel-level)
- API-aware networking
- Hubble for observability

**Pros:**
- ✅ Cutting-edge (eBPF)
- ✅ Excellent performance
- ✅ L7/API-level policies
- ✅ Built-in observability (Hubble)
- ✅ Service mesh capabilities

**Cons:**
- ❌ Requires newer kernels (4.19+)
- ❌ Steeper learning curve
- ❌ More complex troubleshooting

**Use Cilium When:**
- Modern cloud-native applications
- Need API-level security policies
- Want observability out-of-box
- High performance required
- Can run newer kernels
- Service mesh features needed

**Example:** Microservices platform with hundreds of APIs

---

### **Decision Matrix:**

```
Scale?
├─ < 100 nodes → Flannel or Weave
├─ 100-1000 nodes → Calico or Cilium
└─ > 1000 nodes → Calico

Network Policies?
├─ Basic → Any
├─ Advanced (L3/L4) → Calico
└─ API-aware (L7) → Cilium only

Complexity?
├─ Low → Flannel
├─ Medium → Calico or Weave
└─ High → Cilium

Performance?
├─ Critical → Calico or Cilium
└─ Standard → Flannel or Weave

Observability?
├─ Basic → Any
└─ Advanced → Cilium (Hubble)
```

**My Recommendations (2025):**

**Startups:** Flannel → Simple, works, cheap
**Enterprises:** Calico → Proven, scalable, mature
**Modern Platform:** Cilium → Future-proof, advanced features

---

## Q3: Explain how network policies work and give an example.

**Answer:**

### **Network Policy Basics**

**Default Behavior:**
- All pods can communicate with all pods
- No restrictions by default

**With Network Policy:**
- Explicit allow rules
- Default deny (if policy exists)
- Label-based selection

### **How They Work**

**Implementation:**
1. User creates NetworkPolicy
2. CNI controller watches for policies
3. CNI programs firewall rules (iptables/eBPF)
4. Rules enforced at network layer
5. Traffic allowed/denied based on policy

**Components:**

**podSelector:**
- Which pods the policy applies to
- Label-based matching

**policyTypes:**
- Ingress (incoming traffic)
- Egress (outgoing traffic)

**ingress/egress rules:**
- Source/destination selection
- Protocols and ports

### **Example Scenario**

**Setup:**
```
Frontend pods → Backend pods → Database pods
(web tier)      (API tier)     (data tier)
```

**Requirement:**
- Frontend can only access Backend
- Backend can only access Database
- Database accepts only from Backend

### **Implementation**

**Step 1: Deny All (Defense in Depth)**
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-ingress
  namespace: production
spec:
  podSelector: {}  # All pods
  policyTypes:
  - Ingress
```

Result: No pod can receive traffic

**Step 2: Allow Frontend → Backend**
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend
  namespace: production
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
      port: 8080
```

Result: Backend accepts from Frontend on port 8080

**Step 3: Allow Backend → Database**
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-backend-to-database
  namespace: production
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
```

Result: Database accepts from Backend on port 5432

**Step 4: Allow DNS (Important!)**
```yaml
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
```

Result: All pods can resolve DNS

### **Testing**

```bash
# Deploy pods with labels
kubectl run frontend --labels=tier=frontend --image=busybox -- sleep 3600
kubectl run backend --labels=tier=backend --image=nginx
kubectl run database --labels=tier=database --image=postgres

# Get IPs
BACKEND_IP=$(kubectl get pod backend -o jsonpath='{.status.podIP}')
DATABASE_IP=$(kubectl get pod database -o jsonpath='{.status.podIP}')

# Test (should work)
kubectl exec frontend -- wget -qO- $BACKEND_IP:8080

# Test (should fail - no policy allows this)
kubectl exec frontend -- wget -qO- $DATABASE_IP:5432
# Connection timeout!

# Test backend to database (should work)
kubectl exec backend -- nc -zv $DATABASE_IP 5432
# Connection successful
```

### **Common Patterns**

**1. Deny-All Default:**
```yaml
spec:
  podSelector: {}
  policyTypes: [Ingress, Egress]
```

**2. Namespace Isolation:**
```yaml
ingress:
- from:
  - namespaceSelector:
      matchLabels:
        environment: production
```

**3. Allow External Traffic:**
```yaml
ingress:
- from:
  - ipBlock:
      cidr: 0.0.0.0/0
      except:
      - 10.0.0.0/8
```

### **Best Practices**

1. **Start with deny-all**
2. **Add explicit allows**
3. **Test thoroughly**
4. **Document policies**
5. **Use labels consistently**
6. **Don't forget DNS/monitoring**

---

Continue with more Q&A...
