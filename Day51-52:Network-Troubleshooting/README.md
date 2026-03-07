# Day 51-52: Network Troubleshooting

## 📋 Overview

Welcome to Day 51-52! Today we master the art of network troubleshooting in Kubernetes. You'll learn systematic approaches to debug connectivity issues, resolve DNS problems, and become a network debugging expert.

### What You'll Learn

- Systematic troubleshooting methodology
- Common network issues and patterns
- DNS troubleshooting techniques
- Service connectivity debugging
- Network policy issues
- CNI plugin problems
- Advanced debugging tools
- Building troubleshooting runbooks

---

## 🎯 Learning Objectives

By the end of this module, you will be able to:

1. Use systematic troubleshooting methodology
2. Debug pod-to-pod connectivity
3. Resolve DNS issues quickly
4. Troubleshoot service problems
5. Debug network policies
6. Use advanced debugging tools
7. Build troubleshooting runbooks
8. Prevent common network issues

---

## 🔍 Troubleshooting Methodology: The LADDER Approach

### L - List the Symptoms

**What to collect:**
- Error messages
- Affected pods/services
- Timeline (when did it start?)
- Scope (all pods or specific ones?)

**Example:**
```
Symptom: Pod A cannot connect to Pod B
Error: Connection timeout
Started: 30 minutes ago
Scope: Only Pod A affected
```

---

### A - Ask Questions

**Key questions:**
- What changed recently?
- Does it affect all pods or specific ones?
- Does DNS work?
- Can pods reach external services?
- Are network policies involved?

---

### D - Diagnose Layer by Layer

**OSI Model Approach:**

```
Layer 7 - Application   → Check app logs
Layer 4 - Transport     → Test TCP/UDP connectivity
Layer 3 - Network       → Test IP connectivity
Layer 2 - Data Link     → Check CNI/node network
Layer 1 - Physical      → Check node/network status
```

---

### D - Document Findings

**What to document:**
- Commands run
- Output received
- Hypotheses tested
- Solutions attempted

---

### E - Execute Fix

**Apply solution and verify:**
- Implement fix
- Test connectivity
- Monitor for recurrence

---

### R - Review and Prevent

**Post-incident:**
- Document solution
- Add to runbook
- Implement monitoring
- Prevent recurrence

---

## 🚨 Common Network Issues

### Issue 1: Pod Cannot Connect to Another Pod

**Symptoms:**
```bash
kubectl exec pod-a -- curl http://pod-b-ip
# Connection timeout or refused
```

**Diagnosis Flow:**
```
1. Check both pods are Running
   kubectl get pods

2. Get pod IPs
   kubectl get pods -o wide

3. Test basic connectivity
   kubectl exec pod-a -- ping <pod-b-ip>

4. Check network policies
   kubectl get networkpolicy

5. Check CNI
   kubectl get pods -n kube-system | grep cni
```

**Common Causes:**
- Network policy blocking traffic
- CNI plugin issue
- Pod not actually running
- Firewall on node

---

### Issue 2: DNS Resolution Failing

**Symptoms:**
```bash
kubectl exec pod-a -- nslookup service-b
# Server can't find service-b
```

**Diagnosis Flow:**
```
1. Check CoreDNS is running
   kubectl get pods -n kube-system -l k8s-app=kube-dns

2. Test DNS directly
   kubectl exec pod-a -- nslookup kubernetes.default

3. Check /etc/resolv.conf
   kubectl exec pod-a -- cat /etc/resolv.conf

4. Check CoreDNS logs
   kubectl logs -n kube-system -l k8s-app=kube-dns

5. Verify service exists
   kubectl get svc service-b
```

**Common Causes:**
- CoreDNS pods not running
- Service doesn't exist
- Wrong namespace
- Network policy blocking port 53
- DNS cache issues

---

### Issue 3: Service Not Accessible

**Symptoms:**
```bash
kubectl exec pod-a -- curl http://service-b
# Connection refused
```

**Diagnosis Flow:**
```
1. Check service exists
   kubectl get svc service-b

2. Check endpoints
   kubectl get endpoints service-b

3. Check pods are running
   kubectl get pods -l <service-selector>

4. Test pod directly (bypass service)
   kubectl exec pod-a -- curl http://<pod-ip>

5. Check kube-proxy
   kubectl get pods -n kube-system -l k8s-app=kube-proxy
```

**Common Causes:**
- No backend pods
- Wrong service selector
- Pods not ready
- kube-proxy issue
- Wrong port

---

### Issue 4: Cannot Connect to External Services

**Symptoms:**
```bash
kubectl exec pod-a -- curl https://google.com
# Connection timeout
```

**Diagnosis Flow:**
```
1. Test DNS first
   kubectl exec pod-a -- nslookup google.com

2. Test with IP (bypass DNS)
   kubectl exec pod-a -- curl http://8.8.8.8

3. Check egress network policies
   kubectl get networkpolicy

4. Check node internet access
   ssh node
   curl https://google.com

5. Check CNI configuration
   kubectl logs -n kube-system <cni-pod>
```

**Common Causes:**
- Egress network policy blocking
- No route to internet from nodes
- DNS not resolving external domains
- Firewall blocking outbound

---

## 🛠️ Essential Debugging Tools

### 1. kubectl exec with Network Tools

**Create debug pod:**
```bash
kubectl run netshoot --rm -it --image=nicolaka/netshoot -- bash
```

**Inside netshoot:**
```bash
# Ping
ping <ip>

# DNS lookup
nslookup <hostname>
dig <hostname>

# HTTP test
curl http://<service>

# TCP connectivity
nc -zv <host> <port>

# Trace route
traceroute <ip>

# Network interfaces
ip addr
ip route

# DNS config
cat /etc/resolv.conf

# Port scan
nmap <ip>
```

---

### 2. tcpdump for Packet Capture

**Capture traffic:**
```bash
# On specific interface
kubectl exec <pod> -- tcpdump -i eth0 -w /tmp/capture.pcap

# Filter by port
kubectl exec <pod> -- tcpdump -i eth0 port 80

# Filter by host
kubectl exec <pod> -- tcpdump -i eth0 host 10.244.1.5

# Save and download
kubectl cp <pod>:/tmp/capture.pcap ./capture.pcap
```

---

### 3. Service Endpoints Debug

**Check service routing:**
```bash
# Get service info
kubectl describe svc <service-name>

# Check endpoints
kubectl get endpoints <service-name>

# Check endpoint details
kubectl get endpoints <service-name> -o yaml

# Find pods matching selector
kubectl get pods -l <selector>
```

---

### 4. DNS Debugging

**Test DNS resolution:**
```bash
# Quick test
kubectl run dnstest --rm -it --image=busybox -- nslookup <service>

# Detailed DNS query
kubectl exec <pod> -- dig <service> +short

# Test different formats
kubectl exec <pod> -- nslookup <service>
kubectl exec <pod> -- nslookup <service>.<namespace>
kubectl exec <pod> -- nslookup <service>.<namespace>.svc.cluster.local

# Check DNS config
kubectl exec <pod> -- cat /etc/resolv.conf
```

---

### 5. Network Policy Debugging

**Check policies:**
```bash
# List all policies
kubectl get networkpolicy -A

# Describe policy
kubectl describe networkpolicy <policy>

# Check which policies affect a pod
kubectl get networkpolicy -o json | \
  jq -r '.items[] | select(.spec.podSelector.matchLabels | 
    .app=="<app-label>") | .metadata.name'

# Temporarily disable policy (for testing)
kubectl delete networkpolicy <policy>
# Test connectivity
# Recreate policy
kubectl apply -f <policy.yaml>
```

---

## 🔬 Advanced Troubleshooting Scenarios

### Scenario 1: Intermittent Connection Failures

**Symptoms:**
- Sometimes works, sometimes fails
- No clear pattern

**Investigation:**
```bash
# 1. Check for pod restarts
kubectl get pods -w

# 2. Check endpoints stability
watch kubectl get endpoints <service>

# 3. Test repeatedly
for i in {1..100}; do
  kubectl exec <pod> -- curl -s http://<service> || echo "Failed: $i"
done

# 4. Check load balancing
kubectl get endpoints <service> -o yaml

# 5. Check node network
kubectl get nodes -o wide
```

**Common Causes:**
- Pod restarts
- Inconsistent endpoints
- Network flapping
- kube-proxy sync delays

---

### Scenario 2: Slow Network Performance

**Symptoms:**
- High latency
- Slow responses

**Investigation:**
```bash
# 1. Test latency
kubectl exec <pod> -- time curl http://<service>

# 2. Check network path
kubectl exec <pod> -- traceroute <service-ip>

# 3. Check pod resources
kubectl top pod <pod>

# 4. Check node network
kubectl describe node <node>

# 5. Test bandwidth
kubectl run iperf-server --image=networkstatic/iperf3 -- iperf3 -s
kubectl run iperf-client --image=networkstatic/iperf3 -- \
  iperf3 -c <server-ip>
```

---

### Scenario 3: Cross-Namespace Connectivity Issues

**Symptoms:**
- Pods in namespace A can't reach namespace B

**Investigation:**
```bash
# 1. Check network policies
kubectl get networkpolicy -n <namespace-a>
kubectl get networkpolicy -n <namespace-b>

# 2. Test with FQDN
kubectl exec <pod> -n namespace-a -- \
  nslookup service.namespace-b.svc.cluster.local

# 3. Check DNS search domains
kubectl exec <pod> -- cat /etc/resolv.conf

# 4. Test direct IP
kubectl exec <pod> -n namespace-a -- \
  curl http://<service-ip-in-namespace-b>
```

---

## 📊 Troubleshooting Decision Tree

```
Connection Issue?
    ↓
Can you ping pod IP? ───NO──→ Network/CNI issue
    ↓ YES
Can you resolve DNS? ───NO──→ DNS issue
    ↓ YES
Can you reach service? ───NO──→ Service/Endpoints issue
    ↓ YES
Can you reach external? ───NO──→ Egress/NAT issue
    ↓ YES
Application issue (not network)
```

---

## 🎯 Best Practices

### 1. Build a Debug Toolkit

**Deploy permanent debug pod:**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: network-debug
spec:
  containers:
  - name: netshoot
    image: nicolaka/netshoot
    command: ['sleep', 'infinity']
```

---

### 2. Create Monitoring Dashboards

**Key metrics:**
- CoreDNS query latency
- Service endpoint count
- Network policy violations
- kube-proxy sync duration
- CNI plugin errors

---

### 3. Document Common Issues

**Runbook template:**
```markdown
## Issue: Service Not Accessible

**Symptoms:**
- Connection refused to service

**Diagnosis:**
1. Check service: kubectl get svc
2. Check endpoints: kubectl get ep
3. Check pods: kubectl get pods -l <selector>

**Solution:**
- If no endpoints: Check pod labels
- If pods not ready: Check pod logs
```

---

### 4. Use Labels for Troubleshooting

**Add troubleshooting labels:**
```yaml
metadata:
  labels:
    app: backend
    version: v2
    troubleshoot: enabled  # For easy filtering
```

---

### 5. Implement Health Checks

**Proper health checks help isolation:**
```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 8080
readinessProbe:
  httpGet:
    path: /ready
    port: 8080
```

---

## 📖 Key Takeaways

✅ Use systematic methodology (LADDER)
✅ Test layer by layer (OSI model)
✅ Check DNS first for name resolution
✅ Verify service endpoints exist
✅ Test direct pod-to-pod before service
✅ Network policies are common culprits
✅ Document findings and solutions
✅ Build troubleshooting runbooks

---

## 🔗 Additional Resources

- [Kubernetes Debugging Services](https://kubernetes.io/docs/tasks/debug-application-cluster/debug-service/)
- [Network Troubleshooting](https://kubernetes.io/docs/tasks/administer-cluster/dns-debugging-resolution/)

---

## 🚀 Next Steps

1. Complete hands-on exercises in GUIDEME.md
2. Practice systematic troubleshooting
3. Build your debugging toolkit
4. Create runbooks for common issues
5. Set up monitoring and alerts
6. Continue to advanced Kubernetes topics

**Happy Debugging! 🔍**
