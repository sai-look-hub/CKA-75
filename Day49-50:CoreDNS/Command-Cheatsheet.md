# 📋 Command Cheatsheet: CoreDNS

## 🔍 CoreDNS Status

```bash
# Check CoreDNS pods
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Check CoreDNS service
kubectl get svc -n kube-system kube-dns

# Describe CoreDNS deployment
kubectl describe deployment coredns -n kube-system

# Get CoreDNS logs
kubectl logs -n kube-system -l k8s-app=kube-dns

# Follow logs
kubectl logs -n kube-system -l k8s-app=kube-dns -f
```

## 📝 Configuration

```bash
# Get CoreDNS config
kubectl get cm coredns -n kube-system -o yaml

# Edit config
kubectl edit cm coredns -n kube-system

# Backup config
kubectl get cm coredns -n kube-system -o yaml > coredns-backup.yaml

# Restart CoreDNS
kubectl rollout restart deployment coredns -n kube-system
```

## 🧪 Testing DNS

```bash
# Create test pod
kubectl run test --image=busybox --command -- sleep 3600

# Test service resolution
kubectl exec test -- nslookup <service-name>

# Test FQDN
kubectl exec test -- nslookup <service>.<namespace>.svc.cluster.local

# Test external DNS
kubectl exec test -- nslookup google.com

# Check resolv.conf
kubectl exec test -- cat /etc/resolv.conf

# Test with dig (if available)
kubectl exec test -- dig <service-name>
```

## 📊 Monitoring

```bash
# Check CoreDNS metrics
kubectl port-forward -n kube-system svc/kube-dns 9153:9153
curl http://localhost:9153/metrics

# Check resource usage
kubectl top pod -n kube-system -l k8s-app=kube-dns

# Scale CoreDNS
kubectl scale deployment coredns -n kube-system --replicas=3
```

## 💡 One-Liners

```bash
# Find all CoreDNS pods
kubectl get pods -A -l k8s-app=kube-dns

# Check CoreDNS service IP
kubectl get svc -n kube-system kube-dns -o jsonpath='{.spec.clusterIP}'

# Count DNS queries (from metrics)
kubectl exec -n kube-system <coredns-pod> -- wget -qO- localhost:9153/metrics | grep coredns_dns_requests_total
```
