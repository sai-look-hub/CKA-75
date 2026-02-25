# 📖 GUIDEME: CNI & Network Plugins - Complete Walkthrough

## 🎯 Learning Path Overview

16-hour hands-on experience with CNI plugins across 2 days.

---

## ⏱️ Time Allocation

**Day 1 (8 hours):**
- Hours 1-2: CNI fundamentals and architecture
- Hours 3-4: Installing Flannel (simplest)
- Hours 5-6: Installing Calico
- Hours 7-8: Network policy testing

**Day 2 (8 hours):**
- Hours 1-2: Installing Cilium
- Hours 3-4: Comparing CNI plugins
- Hours 5-6: Advanced network policies
- Hours 7-8: Troubleshooting and best practices

---

## 📚 Phase 1: Understanding CNI (2 hours)

### Step 1: Explore Existing Network (30 minutes)

```bash
# Check if CNI is configured
kubectl get nodes -o wide

# Check CNI plugin in use
ls /etc/cni/net.d/
cat /etc/cni/net.d/*.conf | head -20

# Check CNI binaries
ls /opt/cni/bin/

# See pod IPs
kubectl get pods -A -o wide

# Check pod networking
kubectl run test-pod --image=nginx
kubectl get pod test-pod -o wide
POD_IP=$(kubectl get pod test-pod -o jsonpath='{.status.podIP}')
echo "Pod IP: $POD_IP"
```

**✅ Checkpoint:** Understanding current CNI setup.

---

### Step 2: CNI Configuration Examination (60 minutes)

```bash
# Examine CNI config (varies by plugin)
cat /etc/cni/net.d/*.conflist

# Check kubelet CNI configuration
ps aux | grep kubelet | grep cni

# For detailed CNI config
kubectl get nodes <node-name> -o yaml | grep -A 10 PodCIDR

# Check kube-proxy configuration
kubectl get configmap -n kube-system kube-proxy -o yaml | grep clusterCIDR
```

**Key concepts to understand:**
- **CIDR ranges**: Which IP ranges are used for pods
- **Bridge vs routing**: How pods connect
- **IPAM**: How IPs are allocated

**✅ Checkpoint:** Understanding CNI configuration structure.

---

### Step 3: Test Current Networking (30 minutes)

```bash
# Create two test pods
kubectl run test-1 --image=nginx
kubectl run test-2 --image=nginx

# Get their IPs
kubectl get pods -o wide

# Test connectivity
kubectl exec test-1 -- ping -c 3 <test-2-ip>

# Test DNS
kubectl exec test-1 -- nslookup kubernetes.default

# Check from node
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}')
ping -c 3 $POD_IP

# Cleanup
kubectl delete pod test-1 test-2
```

**✅ Checkpoint:** Verified basic networking works.

---

## 🔧 Phase 2: Installing Flannel (2 hours)

**Note:** If your cluster already has a CNI, you'll need a fresh cluster or remove existing CNI carefully.

### Step 1: Prepare for Flannel (30 minutes)

```bash
# For a NEW cluster, init without CNI
# (If starting fresh with kubeadm)
kubeadm init --pod-network-cidr=10.244.0.0/16

# Check nodes are NotReady (no CNI yet)
kubectl get nodes
# STATUS: NotReady

# Check CoreDNS pending
kubectl get pods -n kube-system
# CoreDNS pods: Pending
```

**✅ Checkpoint:** Cluster ready for CNI installation.

---

### Step 2: Install Flannel (45 minutes)

```bash
# Download Flannel manifest
curl -O https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

# Review the manifest
less kube-flannel.yml

# Key things to note:
# - DaemonSet (runs on every node)
# - Namespace: kube-flannel
# - ConfigMap with network config
# - ServiceAccount and RBAC

# Apply Flannel
kubectl apply -f kube-flannel.yml

# Watch installation
kubectl get pods -n kube-flannel -w

# Should see:
# kube-flannel-ds-xxx   Running
```

**✅ Checkpoint:** Flannel installed.

---

### Step 3: Verify Flannel (45 minutes)

```bash
# Check nodes now Ready
kubectl get nodes
# STATUS: Ready

# Check CoreDNS now Running
kubectl get pods -n kube-system
# CoreDNS: Running

# Examine Flannel config
kubectl get configmap -n kube-flannel kube-flannel-cfg -o yaml

# Check Flannel on each node
kubectl get pods -n kube-flannel -o wide

# Check CNI config created
ls /etc/cni/net.d/
cat /etc/cni/net.d/10-flannel.conflist

# Test pod-to-pod networking
kubectl run test-1 --image=busybox --command -- sleep 3600
kubectl run test-2 --image=busybox --command -- sleep 3600

kubectl get pods -o wide

POD1_IP=$(kubectl get pod test-1 -o jsonpath='{.status.podIP}')
POD2_IP=$(kubectl get pod test-2 -o jsonpath='{.status.podIP}')

# Test connectivity
kubectl exec test-1 -- ping -c 3 $POD2_IP
kubectl exec test-2 -- ping -c 3 $POD1_IP

# Test DNS
kubectl exec test-1 -- nslookup kubernetes.default

echo "✅ Flannel networking verified!"
```

**✅ Checkpoint:** Flannel working correctly.

---

## 🛡️ Phase 3: Installing Calico (2 hours)

**Note:** This requires removing Flannel first or using a new cluster.

### Step 1: Remove Flannel (if needed) (15 minutes)

```bash
# Delete Flannel
kubectl delete -f kube-flannel.yml

# Remove CNI config
sudo rm -f /etc/cni/net.d/*flannel*

# Restart kubelet
sudo systemctl restart kubelet

# Nodes will be NotReady
kubectl get nodes
```

---

### Step 2: Install Calico (60 minutes)

```bash
# Install Calico operator
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/tigera-operator.yaml

# Verify operator
kubectl get pods -n tigera-operator

# Download custom resources
curl -O https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/custom-resources.yaml

# Edit if needed (check CIDR matches your cluster)
# Default: 192.168.0.0/16
vi custom-resources.yaml

# Apply custom resources
kubectl create -f custom-resources.yaml

# Watch Calico installation
watch kubectl get pods -n calico-system

# Should see:
# calico-kube-controllers
# calico-node (DaemonSet)
# calico-typha
```

**✅ Checkpoint:** Calico installed.

---

### Step 3: Verify Calico (45 minutes)

```bash
# Check installation status
kubectl get tigerastatus

# Verify calico-node on each node
kubectl get pods -n calico-system -o wide

# Check Calico configuration
kubectl get installation default -o yaml

# Install calicoctl (for advanced operations)
curl -L https://github.com/projectcalico/calico/releases/download/v3.27.0/calicoctl-linux-amd64 -o calicoctl
chmod +x calicoctl
sudo mv calicoctl /usr/local/bin/

# Check Calico node status
sudo calicoctl node status

# View IP pools
calicoctl get ippool -o wide

# Test networking
kubectl run test-1 --image=nginx
kubectl run test-2 --image=nginx

kubectl get pods -o wide

# Verify connectivity
kubectl exec test-1 -- ping -c 3 <test-2-ip>

echo "✅ Calico networking verified!"
```

**✅ Checkpoint:** Calico working correctly.

---

## 🔐 Phase 4: Network Policies (2 hours)

### Step 1: Test Without Policies (30 minutes)

```bash
# Create namespace
kubectl create namespace policy-test

# Deploy backend
kubectl run backend -n policy-test --image=nginx --labels=app=backend --port=80

# Deploy frontend
kubectl run frontend -n policy-test --image=busybox --command -- sleep 3600

# Deploy unrelated pod
kubectl run other -n policy-test --image=busybox --command -- sleep 3600

# Get backend IP
BACKEND_IP=$(kubectl get pod backend -n policy-test -o jsonpath='{.status.podIP}')

# Test: Frontend can reach backend (should work)
kubectl exec frontend -n policy-test -- wget -qO- $BACKEND_IP

# Test: Other can reach backend (should work)
kubectl exec other -n policy-test -- wget -qO- $BACKEND_IP

echo "✅ All pods can communicate (no policies)"
```

**✅ Checkpoint:** Baseline connectivity established.

---

### Step 2: Apply Deny-All Policy (45 minutes)

```bash
# Create deny-all ingress policy
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-ingress
  namespace: policy-test
spec:
  podSelector: {}
  policyTypes:
  - Ingress
EOF

# Verify policy created
kubectl get networkpolicy -n policy-test

# Test: Frontend CANNOT reach backend now
kubectl exec frontend -n policy-test -- timeout 5 wget -qO- $BACKEND_IP
# Should timeout!

# Test: Other CANNOT reach backend
kubectl exec other -n policy-test -- timeout 5 wget -qO- $BACKEND_IP
# Should timeout!

echo "✅ Deny-all policy working!"
```

**✅ Checkpoint:** Network policies enforced.

---

### Step 3: Allow Specific Traffic (45 minutes)

```bash
# Allow frontend to backend
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend
  namespace: policy-test
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
      port: 80
EOF

# Wait a moment for policy to apply
sleep 5

# Label frontend pod
kubectl label pod frontend -n policy-test app=frontend

# Test: Frontend CAN reach backend now
kubectl exec frontend -n policy-test -- wget -qO- $BACKEND_IP
# Should work!

# Test: Other still CANNOT reach backend
kubectl exec other -n policy-test -- timeout 5 wget -qO- $BACKEND_IP
# Should timeout!

echo "✅ Selective policy working!"
```

**✅ Checkpoint:** Advanced policies working.

---

## 🚀 Phase 5: Installing Cilium (2 hours)

### Step 1: Install Cilium CLI (30 minutes)

```bash
# Download Cilium CLI
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
CLI_ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH=arm64; fi
curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum
sudo tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin
rm cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}

# Verify
cilium version --client
```

**✅ Checkpoint:** Cilium CLI installed.

---

### Step 2: Install Cilium (60 minutes)

```bash
# Remove existing CNI (if needed)
# Similar to removing Flannel earlier

# Install Cilium
cilium install --version 1.15.0

# Wait for installation
cilium status --wait

# Check Cilium pods
kubectl get pods -n kube-system -l k8s-app=cilium

# Verify connectivity
cilium connectivity test

# This runs comprehensive tests!
# Takes several minutes
```

**✅ Checkpoint:** Cilium installed and verified.

---

### Step 3: Explore Cilium Features (30 minutes)

```bash
# Install Hubble (observability)
cilium hubble enable

# Install Hubble CLI
HUBBLE_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/hubble/master/stable.txt)
HUBBLE_ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then HUBBLE_ARCH=arm64; fi
curl -L --fail --remote-name-all https://github.com/cilium/hubble/releases/download/$HUBBLE_VERSION/hubble-linux-${HUBBLE_ARCH}.tar.gz{,.sha256sum}
sha256sum --check hubble-linux-${HUBBLE_ARCH}.tar.gz.sha256sum
sudo tar xzvfC hubble-linux-${HUBBLE_ARCH}.tar.gz /usr/local/bin
rm hubble-linux-${HUBBLE_ARCH}.tar.gz{,.sha256sum}

# Port-forward Hubble relay
cilium hubble port-forward &

# Observe traffic
hubble observe

# Create test traffic
kubectl run test --image=nginx
kubectl exec test -- curl kubernetes.default

# See flows in Hubble
hubble observe --pod test
```

**✅ Checkpoint:** Cilium advanced features explored.

---

## 📊 Phase 6: CNI Comparison (2 hours)

### Performance Testing (60 minutes)

```bash
# Install iperf3 on two pods
kubectl run iperf-server --image=networkstatic/iperf3 -- iperf3 -s
kubectl run iperf-client --image=networkstatic/iperf3 -- sleep 3600

# Get server IP
SERVER_IP=$(kubectl get pod iperf-server -o jsonpath='{.status.podIP}')

# Run bandwidth test
kubectl exec iperf-client -- iperf3 -c $SERVER_IP -t 30

# Record results for each CNI:
# Flannel (VXLAN): ~X Gbps
# Calico (no overlay): ~Y Gbps
# Cilium (eBPF): ~Z Gbps
```

**✅ Checkpoint:** Performance comparison completed.

---

### Feature Comparison (60 minutes)

```bash
# Create comparison table
cat > cni-comparison.md << 'EOF'
# CNI Plugin Comparison

## Tested Features

| Feature | Flannel | Calico | Cilium |
|---------|---------|--------|--------|
| Install Time | 2 min | 5 min | 7 min |
| Network Policies | ❌ | ✅ | ✅ |
| Performance | Good | Excellent | Excellent |
| Complexity | Low | Medium | High |
| Observability | Basic | Basic | ✅ Hubble |

## Recommendations

- **Flannel**: Best for simplicity
- **Calico**: Best for scale and policies
- **Cilium**: Best for modern features
EOF

cat cni-comparison.md
```

**✅ Checkpoint:** Comparison documented.

---

## ✅ Final Validation Checklist

### CNI Understanding
- [ ] Explain CNI specification
- [ ] Understand pod networking model
- [ ] Know CNI plugin types
- [ ] Understand IPAM

### Installation Skills
- [ ] Install Flannel
- [ ] Install Calico
- [ ] Install Cilium
- [ ] Verify networking after install

### Network Policies
- [ ] Create deny-all policy
- [ ] Create allow policy
- [ ] Test policy enforcement
- [ ] Understand policy syntax

### Troubleshooting
- [ ] Check CNI pods
- [ ] Verify pod connectivity
- [ ] Debug network issues
- [ ] Use CNI-specific tools

---

## 🧹 Cleanup

```bash
# Clean up test resources
kubectl delete pod --all
kubectl delete namespace policy-test

# If testing multiple CNIs, clean between installs
# Remove CNI
kubectl delete -f <cni-manifest.yaml>

# Remove CNI configs
sudo rm -f /etc/cni/net.d/*

# Restart kubelet
sudo systemctl restart kubelet
```

---

## 🎓 Key Learnings

**CNI Basics:**
- Standard interface for container networking
- Multiple plugins available
- Each with different tradeoffs

**Popular Plugins:**
- **Flannel**: Simplest, good for getting started
- **Calico**: Best for scale and security
- **Cilium**: Most advanced, eBPF-based

**Network Policies:**
- Default allow-all
- Use policies to restrict traffic
- Label-based selection
- Ingress and egress rules

**Best Practices:**
- Choose CNI based on requirements
- Test network policies
- Monitor network performance
- Keep CNI updated

---

**Congratulations! You've mastered CNI plugins! 🌐🚀**
