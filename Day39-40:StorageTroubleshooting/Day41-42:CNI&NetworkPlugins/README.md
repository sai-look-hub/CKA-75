# Day 41-42: CNI & Network Plugins

## 📋 Overview

Welcome to Day 41-42! Today we dive deep into Container Network Interface (CNI) and network plugins - the foundation of Kubernetes networking. You'll learn how CNI works, compare popular plugins, and get hands-on experience installing and configuring different networking solutions.

### What You'll Learn

- Understanding CNI specification and architecture
- How Kubernetes networking works
- Popular CNI plugins (Calico, Flannel, Weave, Cilium)
- Installing and configuring CNI plugins
- Network policy implementation
- Troubleshooting network issues
- Choosing the right CNI for your needs

---

## 🎯 Learning Objectives

By the end of this module, you will be able to:

1. Explain CNI specification and architecture
2. Understand Kubernetes networking requirements
3. Compare popular CNI plugins
4. Install and configure CNI plugins
5. Implement network policies
6. Troubleshoot CNI-related issues
7. Choose appropriate CNI for your use case
8. Optimize network performance

---

## 🌐 Kubernetes Networking Fundamentals

### The Kubernetes Networking Model

**Three fundamental requirements:**

1. **Pod-to-Pod Communication**
   - All pods can communicate with all other pods
   - Without NAT (Network Address Translation)
   - Across all nodes

2. **Node-to-Pod Communication**
   - Nodes can communicate with all pods
   - Pods can communicate with all nodes
   - Without NAT

3. **Pod's View of Its IP**
   - The IP a pod sees for itself
   - Is the same IP others see when communicating with it
   - No IP masquerading

**Visual:**
```
┌─────────────────────────────────────────────┐
│              Kubernetes Cluster              │
│                                              │
│  ┌────────────────┐      ┌────────────────┐│
│  │    Node 1      │      │    Node 2      ││
│  │                │      │                ││
│  │  ┌──────────┐  │      │  ┌──────────┐  ││
│  │  │ Pod A    │  │      │  │ Pod C    │  ││
│  │  │ 10.1.1.2 │◄─┼──────┼─►│ 10.1.2.3 │  ││
│  │  └──────────┘  │      │  └──────────┘  ││
│  │                │      │                ││
│  │  ┌──────────┐  │      │  ┌──────────┐  ││
│  │  │ Pod B    │  │      │  │ Pod D    │  ││
│  │  │ 10.1.1.3 │◄─┼──────┼─►│ 10.1.2.4 │  ││
│  │  └──────────┘  │      │  └──────────┘  ││
│  └────────────────┘      └────────────────┘│
│                                              │
│  All pods can reach each other without NAT  │
└─────────────────────────────────────────────┘
```

---

## 🔌 What is CNI?

### Container Network Interface (CNI)

**Definition:** A specification and set of libraries for configuring network interfaces in Linux containers.

**Purpose:**
- Standardize container networking
- Decouple networking from container runtime
- Enable pluggable networking solutions

**CNI Plugin Responsibilities:**
1. Allocate IP address to container
2. Configure network interface in container
3. Setup routing for container
4. Configure iptables/firewall rules
5. Setup network policies (if supported)

---

### CNI Specification Basics

**Plugin Types:**

1. **Main Plugins** (create network interface)
   - bridge
   - ipvlan
   - macvlan
   - ptp (point-to-point)

2. **IPAM Plugins** (IP Address Management)
   - host-local
   - dhcp
   - static

3. **Meta Plugins** (modify other plugins)
   - flannel
   - tuning
   - portmap
   - bandwidth

---

### How CNI Works

**Workflow:**
```
1. Container Runtime (kubelet) calls CNI plugin
   ↓
2. CNI plugin creates network interface
   ↓
3. IPAM plugin allocates IP address
   ↓
4. CNI plugin configures interface with IP
   ↓
5. CNI plugin sets up routes
   ↓
6. Container has network connectivity
```

**Example CNI Configuration:**
```json
{
  "cniVersion": "0.4.0",
  "name": "k8s-network",
  "type": "bridge",
  "bridge": "cni0",
  "isGateway": true,
  "ipMasq": true,
  "ipam": {
    "type": "host-local",
    "subnet": "10.244.0.0/16",
    "routes": [
      { "dst": "0.0.0.0/0" }
    ]
  }
}
```

---

## 🚀 Popular CNI Plugins

### 1. Calico

**Overview:**
- Layer 3 networking and security
- BGP-based routing
- Network policy support
- No overlay network (by default)
- Highly scalable

**Architecture:**
```
┌─────────────────────────────────────┐
│          Calico Architecture        │
├─────────────────────────────────────┤
│                                     │
│  Felix (Agent)                      │
│  ├─ Programs routes                │
│  ├─ Configures iptables             │
│  └─ Reports status                  │
│                                     │
│  BIRD (BGP Client)                  │
│  ├─ Distributes routes              │
│  └─ Peers with other nodes          │
│                                     │
│  confd                              │
│  └─ Monitors etcd for config        │
│                                     │
│  CNI Plugin                         │
│  └─ Creates veth pairs              │
└─────────────────────────────────────┘
```

**Key Features:**
- ✅ Network policies (very mature)
- ✅ No overlay network (better performance)
- ✅ BGP peering
- ✅ IP-in-IP or VXLAN (optional)
- ✅ eBPF dataplane support
- ✅ Encryption with WireGuard

**Best For:**
- Large-scale deployments (1000+ nodes)
- On-premises data centers
- Advanced network policies
- High performance requirements

**Pros:**
- Excellent performance (no overlay)
- Mature network policies
- Scalable to very large clusters
- Active development

**Cons:**
- More complex to understand
- Requires BGP knowledge for advanced setups
- Not ideal for cloud environments without BGP support

---

### 2. Flannel

**Overview:**
- Simple overlay network
- VXLAN encapsulation
- Easy to setup
- Limited network policy support

**Architecture:**
```
┌─────────────────────────────────────┐
│         Flannel Architecture        │
├─────────────────────────────────────┤
│                                     │
│  flanneld (Daemon)                  │
│  ├─ Watches etcd/K8s API            │
│  ├─ Allocates subnet per node       │
│  ├─ Creates VXLAN tunnel            │
│  └─ Configures routing              │
│                                     │
│  CNI Plugin                         │
│  ├─ Reads flannel config            │
│  └─ Delegates to bridge plugin      │
│                                     │
│  Backend: VXLAN/host-gw/UDP         │
└─────────────────────────────────────┘
```

**Key Features:**
- ✅ Very simple to install
- ✅ Multiple backends (VXLAN, host-gw, UDP)
- ✅ Works everywhere
- ❌ Limited network policy support
- ❌ No encryption

**Backend Options:**

**VXLAN** (default):
- Overlay network
- Works across any network
- Moderate performance overhead

**host-gw** (host gateway):
- Layer 3 routing (like Calico)
- Requires nodes on same L2 network
- Better performance than VXLAN

**UDP** (deprecated):
- Slowest option
- Compatibility fallback

**Best For:**
- Simple deployments
- Getting started with Kubernetes
- Development/testing
- Small to medium clusters

**Pros:**
- Dead simple to install
- Works everywhere
- Low operational overhead

**Cons:**
- Limited network policies (requires Calico integration)
- VXLAN overhead (unless using host-gw)
- Less feature-rich than alternatives

---

### 3. Weave Net

**Overview:**
- Mesh network between nodes
- Automatic route discovery
- Encryption support
- Network policy support

**Architecture:**
```
┌─────────────────────────────────────┐
│          Weave Architecture         │
├─────────────────────────────────────┤
│                                     │
│  Weave Net (Router)                 │
│  ├─ Mesh network topology           │
│  ├─ Gossip protocol                 │
│  ├─ Encrypts traffic (optional)     │
│  └─ Load balances across paths      │
│                                     │
│  CNI Plugin                         │
│  ├─ Creates bridge                  │
│  ├─ Allocates IPs                   │
│  └─ Configures routes               │
│                                     │
│  Network Policy Controller          │
│  └─ Implements NetworkPolicy        │
└─────────────────────────────────────┘
```

**Key Features:**
- ✅ Easy to install
- ✅ Automatic route discovery
- ✅ Encryption (NaCl crypto)
- ✅ Network policies
- ✅ Multicast support
- ✅ Works across any network

**Best For:**
- Medium-sized clusters
- Need for encryption
- Multi-cloud deployments
- Quick setup with security

**Pros:**
- Simple installation
- Built-in encryption
- No external dependencies
- Good documentation

**Cons:**
- Higher CPU overhead
- Slower than Calico/Cilium
- Not as scalable (< 500 nodes recommended)
- Project less active recently

---

### 4. Cilium

**Overview:**
- eBPF-based networking and security
- API-aware network policies
- Modern, high-performance
- Observability built-in

**Architecture:**
```
┌─────────────────────────────────────┐
│         Cilium Architecture         │
├─────────────────────────────────────┤
│                                     │
│  Cilium Agent                       │
│  ├─ eBPF programs in kernel         │
│  ├─ API-aware policies              │
│  ├─ Load balancing                  │
│  └─ Observability                   │
│                                     │
│  CNI Plugin                         │
│  └─ Configures network              │
│                                     │
│  Hubble (Observability)             │
│  ├─ Network flow visibility         │
│  ├─ Service map                     │
│  └─ Metrics and logs                │
└─────────────────────────────────────┘
```

**Key Features:**
- ✅ eBPF dataplane (kernel-level)
- ✅ API-aware policies (L7)
- ✅ Built-in load balancing
- ✅ Service mesh integration
- ✅ Encryption (WireGuard/IPSec)
- ✅ Hubble for observability

**Best For:**
- Modern cloud-native applications
- Need for API-level policies
- High-performance requirements
- Observability needs
- Service mesh capabilities

**Pros:**
- Cutting-edge technology (eBPF)
- Excellent performance
- Layer 7 policies
- Great observability
- Active development

**Cons:**
- Requires newer kernels (4.19+)
- Steeper learning curve
- More complex to troubleshoot
- Overkill for simple use cases

---

## 📊 CNI Plugin Comparison

### Feature Matrix

| Feature | Calico | Flannel | Weave Net | Cilium |
|---------|--------|---------|-----------|--------|
| **Network Model** | L3 (BGP) | Overlay (VXLAN) | Mesh | eBPF |
| **Network Policies** | ✅ Advanced | ❌ (needs Calico) | ✅ Basic | ✅ L7 |
| **Encryption** | ✅ WireGuard | ❌ | ✅ NaCl | ✅ WireGuard/IPSec |
| **Performance** | Excellent | Good | Moderate | Excellent |
| **Scalability** | 5000+ nodes | 100-500 nodes | 100-500 nodes | 1000+ nodes |
| **Complexity** | Medium | Low | Low | High |
| **L7 Policies** | ❌ | ❌ | ❌ | ✅ |
| **Observability** | Basic | Basic | Basic | ✅ Hubble |
| **Service Mesh** | ❌ | ❌ | ❌ | ✅ |
| **IPv6 Support** | ✅ | ✅ | ✅ | ✅ |
| **Windows Support** | ✅ | ✅ | ❌ | ❌ |

---

### Performance Comparison

**Throughput (single stream TCP):**
- Cilium: ~9.5 Gbps (eBPF, no overlay)
- Calico: ~9.4 Gbps (no overlay)
- Flannel (host-gw): ~9.2 Gbps (no overlay)
- Flannel (VXLAN): ~7.5 Gbps (overlay)
- Weave: ~6.8 Gbps (mesh overhead)

**Latency (pod-to-pod):**
- Cilium: ~0.05ms
- Calico: ~0.06ms
- Flannel (host-gw): ~0.07ms
- Flannel (VXLAN): ~0.15ms
- Weave: ~0.20ms

**CPU Overhead:**
- Flannel: Lowest (~1-2%)
- Calico: Low (~2-3%)
- Cilium: Low (~2-4%)
- Weave: Higher (~5-8%)

---

## 🔧 CNI Installation

### Generic Installation Pattern

**1. Prerequisites:**
```bash
# Ensure kubelet configured with CNI
cat /etc/kubernetes/kubelet.conf | grep network-plugin
# Should show: --network-plugin=cni

# Check CNI directories
ls /etc/cni/net.d/      # CNI config
ls /opt/cni/bin/        # CNI binaries
```

**2. Install CNI Plugin:**
```bash
# Apply CNI manifest
kubectl apply -f <cni-plugin>.yaml

# Verify installation
kubectl get pods -n kube-system | grep <cni-name>

# Check node status
kubectl get nodes
# STATUS should be Ready
```

**3. Verify Networking:**
```bash
# Deploy test pods
kubectl run test-1 --image=nginx
kubectl run test-2 --image=nginx

# Check IPs assigned
kubectl get pods -o wide

# Test connectivity
kubectl exec test-1 -- ping -c 3 <test-2-ip>
```

---

### Calico Installation

**Quick Install:**
```bash
# Install Calico operator
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/tigera-operator.yaml

# Install Calico custom resources
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/custom-resources.yaml

# Watch for installation
watch kubectl get pods -n calico-system
```

**Verify:**
```bash
# Check Calico status
kubectl get installation -o yaml

# Check Calico nodes
kubectl get nodes -o wide
```

---

### Flannel Installation

**Quick Install:**
```bash
# Install Flannel
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

# Verify
kubectl get pods -n kube-flannel
kubectl get daemonset -n kube-flannel
```

---

### Weave Installation

**Quick Install:**
```bash
# Install Weave Net
kubectl apply -f https://github.com/weaveworks/weave/releases/download/v2.8.1/weave-daemonset-k8s.yaml

# Verify
kubectl get pods -n kube-system -l name=weave-net
```

---

### Cilium Installation

**Using Cilium CLI:**
```bash
# Install Cilium CLI
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
curl -L --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-amd64.tar.gz{,.sha256sum}
tar xzvfC cilium-linux-amd64.tar.gz /usr/local/bin
rm cilium-linux-amd64.tar.gz{,.sha256sum}

# Install Cilium
cilium install --version 1.15.0

# Check status
cilium status
```

---

## 🛡️ Network Policies

### Basic Network Policy (Works with Calico, Cilium, Weave)

**Deny all ingress:**
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-ingress
spec:
  podSelector: {}
  policyTypes:
  - Ingress
```

**Allow specific traffic:**
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-frontend
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
    ports:
    - protocol: TCP
      port: 8080
```

---

## 🎯 Choosing the Right CNI

### Decision Matrix

**Use Calico if:**
- ✅ Large-scale deployment (1000+ nodes)
- ✅ On-premises with BGP support
- ✅ Need advanced network policies
- ✅ Performance is critical
- ✅ Have networking expertise

**Use Flannel if:**
- ✅ Simple requirements
- ✅ Getting started
- ✅ Small to medium clusters
- ✅ Don't need advanced policies
- ✅ Want minimal complexity

**Use Weave Net if:**
- ✅ Need built-in encryption
- ✅ Multi-cloud deployment
- ✅ Want easy setup
- ✅ Medium-sized clusters
- ✅ Basic network policies sufficient

**Use Cilium if:**
- ✅ Modern cloud-native apps
- ✅ Need L7/API-level policies
- ✅ Want observability (Hubble)
- ✅ High performance required
- ✅ Service mesh capabilities
- ✅ Can run newer kernels

---

## 📖 Key Takeaways

✅ CNI is the standard for container networking
✅ Multiple CNI plugins available for different needs
✅ Calico: Best for large-scale, high-performance
✅ Flannel: Simplest option, good for getting started
✅ Weave: Easy setup with encryption
✅ Cilium: Most advanced, eBPF-based
✅ Choose based on scale, complexity, and requirements

---

## 🔗 Additional Resources

- [CNI Specification](https://github.com/containernetworking/cni)
- [Calico Documentation](https://docs.tigera.io/calico/latest/about/)
- [Flannel Documentation](https://github.com/flannel-io/flannel)
- [Weave Documentation](https://www.weave.works/docs/net/latest/overview/)
- [Cilium Documentation](https://docs.cilium.io/)

---

## 🚀 Next Steps

1. Complete hands-on exercises in GUIDEME.md
2. Install and test different CNI plugins
3. Implement network policies
4. Review troubleshooting guide
5. Move to Day 43-44: Service Mesh

**Happy Networking! 🌐**
