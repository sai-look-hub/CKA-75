# 📋 Command Cheatsheet: Network Troubleshooting

## 🔍 Basic Connectivity Tests

```bash
# Create debug pod
kubectl run netshoot --rm -it --image=nicolaka/netshoot -- bash

# Ping test
kubectl exec <pod> -- ping -c 3 <ip>

# HTTP test
kubectl exec <pod> -- curl http://<service>

# TCP port test
kubectl exec <pod> -- nc -zv <host> <port>

# DNS lookup
kubectl exec <pod> -- nslookup <service>
```

## 🔬 Service Debugging

```bash
# Check service
kubectl get svc <service>
kubectl describe svc <service>

# Check endpoints
kubectl get endpoints <service>
kubectl get ep <service> -o yaml

# Find pods for service
kubectl get pods -l <selector>

# Test pod directly (bypass service)
POD_IP=$(kubectl get pod <pod> -o jsonpath='{.status.podIP}')
kubectl exec <test-pod> -- curl http://$POD_IP
```

## 🌐 DNS Troubleshooting

```bash
# Check CoreDNS
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl logs -n kube-system -l k8s-app=kube-dns

# Test DNS
kubectl exec <pod> -- nslookup <service>
kubectl exec <pod> -- nslookup <service>.<namespace>.svc.cluster.local

# Check resolv.conf
kubectl exec <pod> -- cat /etc/resolv.conf

# Test external DNS
kubectl exec <pod> -- nslookup google.com
```

## 🔒 Network Policy Debugging

```bash
# List policies
kubectl get networkpolicy -A

# Describe policy
kubectl describe networkpolicy <policy>

# Check which policies affect pod
kubectl get networkpolicy -o json | \
  jq -r '.items[] | select(.spec.podSelector.matchLabels.app=="<app>") | .metadata.name'

# Temporarily delete for testing
kubectl delete networkpolicy <policy>
```

## 📊 Advanced Debugging

```bash
# Packet capture
kubectl exec <pod> -- tcpdump -i any -w /tmp/capture.pcap

# Network interfaces
kubectl exec <pod> -- ip addr
kubectl exec <pod> -- ip route

# Check iptables (if privileged)
kubectl exec <pod> -- iptables -L -n

# Trace route
kubectl exec <pod> -- traceroute <host>
```

## 💡 One-Liners

```bash
# Test all services
for svc in $(kubectl get svc -o name); do
  echo "Testing $svc"
  kubectl run test --rm -it --image=busybox -- wget -qO- http://${svc#service/} || echo "Failed"
done

# Check all CoreDNS pods
kubectl get pods -n kube-system -l k8s-app=kube-dns -o wide

# Get all pod IPs
kubectl get pods -o custom-columns=NAME:.metadata.name,IP:.status.podIP
```
