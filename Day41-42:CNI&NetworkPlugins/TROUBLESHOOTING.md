# 🔧 TROUBLESHOOTING: CNI & Network Plugins

---

## 🚨 ISSUE 1: Nodes Stuck in NotReady

**Symptoms:**
```bash
kubectl get nodes
# NAME     STATUS     AGE
# node-1   NotReady   5m
```

**Common Causes:**

**Cause 1: No CNI installed**
```bash
# Check CNI config
ls /etc/cni/net.d/
# Empty or no files

# Solution: Install a CNI plugin
kubectl apply -f <cni-manifest.yaml>
```

**Cause 2: CNI pods not running**
```bash
kubectl get pods -A | grep -i 'flannel\|calico\|weave\|cilium'
# Pods CrashLooping or Pending

# Check logs
kubectl logs -n <cni-namespace> <cni-pod>

# Common fix: Restart DaemonSet
kubectl rollout restart daemonset -n <namespace> <cni-ds>
```

**Cause 3: Incorrect pod CIDR**
```bash
# Check configured CIDR
kubectl cluster-info dump | grep -m 1 cluster-cidr

# Check CNI config
cat /etc/cni/net.d/*.conf | grep subnet

# Solution: Match pod-network-cidr in kubeadm init
```

---

## 🚨 ISSUE 2: Pods Cannot Communicate

**Symptoms:**
```bash
kubectl exec pod-1 -- ping <pod-2-ip>
# Destination Host Unreachable
```

**Diagnosis:**
```bash
# Check both pods have IPs
kubectl get pods -o wide

# Check CNI pods running
kubectl get pods -n <cni-namespace>

# Check routes on node
ip route

# Check iptables
sudo iptables -L -n -v | grep <pod-ip>
```

**Solutions:**

**Solution 1: Restart CNI**
```bash
kubectl rollout restart daemonset -n <cni-namespace>
```

**Solution 2: Network policies blocking**
```bash
kubectl get networkpolicy -A
# Check if policies deny traffic

# Temporarily delete to test
kubectl delete networkpolicy <policy>
```

**Solution 3: Firewall rules**
```bash
# Check node firewall
sudo iptables -L
sudo firewalld --list-all

# Allow pod CIDR
sudo iptables -A INPUT -s 10.244.0.0/16 -j ACCEPT
```

---

## 🚨 ISSUE 3: DNS Not Working

**Symptoms:**
```bash
kubectl exec pod -- nslookup kubernetes.default
# Connection timed out
```

**Diagnosis:**
```bash
# Check CoreDNS pods
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Check CoreDNS logs
kubectl logs -n kube-system <coredns-pod>

# Check service
kubectl get svc -n kube-system kube-dns
```

**Solutions:**

**Solution 1: CoreDNS pending (no CNI)**
```bash
# Install CNI first
# CoreDNS will start automatically
```

**Solution 2: Network policy blocking DNS**
```bash
# Allow egress to kube-system DNS
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
spec:
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: kube-system
    ports:
    - protocol: UDP
      port: 53
```

---

## 🚨 ISSUE 4: Network Policies Not Working

**Symptoms:**
- Created NetworkPolicy but traffic still flows
- Or policy blocks more than expected

**Diagnosis:**
```bash
# Check CNI supports NetworkPolicy
# Flannel: NO (needs Calico)
# Calico: YES
# Weave: YES
# Cilium: YES

# Verify policy applied
kubectl describe networkpolicy <policy>

# Check pod labels match
kubectl get pods --show-labels
```

**Solutions:**

**Solution 1: CNI doesn't support policies**
```bash
# Use Calico, Weave, or Cilium
# Or add Calico to Flannel
kubectl apply -f canal.yaml  # Flannel + Calico
```

**Solution 2: Policy not selecting pods**
```bash
# Check label selectors
kubectl get pods -l app=backend

# Fix labels or policy selector
```

---

## 🔍 Debugging Commands

```bash
# Check CNI config
cat /etc/cni/net.d/*.conf

# Check CNI logs
kubectl logs -n <cni-namespace> <cni-pod>

# Test pod connectivity
kubectl exec pod-1 -- ping <pod-2-ip>

# Check routes
ip route

# Check if pod has network namespace
kubectl exec <pod> -- ip addr

# Check DNS
kubectl exec <pod> -- nslookup kubernetes.default

# Packet capture
kubectl exec <pod> -- tcpdump -i any -n
```

---

## 📊 Common Error Messages

| Error | Cause | Solution |
|-------|-------|----------|
| `No route to host` | CNI not configured | Install CNI |
| `Connection refused` | Network policy | Check policies |
| `Name resolution failed` | DNS issue | Check CoreDNS |
| `CNI failed to initialize` | Config error | Check CNI config |
| `Failed to create pod network` | CNI crash | Restart CNI pods |

---

**Pro Tip:** Always check CNI pod logs first!
