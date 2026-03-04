# 📖 GUIDEME: CoreDNS - Complete Walkthrough

## 🎯 16-Hour Learning Path

**Day 1:** DNS basics, CoreDNS architecture, service discovery (8 hours)
**Day 2:** Custom DNS, troubleshooting, optimization (8 hours)

---

## Phase 1: Understanding DNS (2 hours)

### Step 1: Check CoreDNS Deployment

```bash
# Check CoreDNS pods
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Check CoreDNS service
kubectl get svc -n kube-system kube-dns

# Get CoreDNS config
kubectl get configmap coredns -n kube-system -o yaml

# Check logs
kubectl logs -n kube-system -l k8s-app=kube-dns
```

**✅ Checkpoint:** CoreDNS is running and accessible.

---

### Step 2: Test Basic Service Discovery

```bash
# Create test service
kubectl create deployment web --image=nginx
kubectl expose deployment web --port=80

# Create test pod
kubectl run test --image=busybox --command -- sleep 3600

# Test DNS resolution
kubectl exec test -- nslookup web
kubectl exec test -- nslookup web.default
kubectl exec test -- nslookup web.default.svc.cluster.local

# Check /etc/resolv.conf
kubectl exec test -- cat /etc/resolv.conf
```

**✅ Checkpoint:** Service discovery working.

---

## Phase 2: DNS Resolution Testing (2 hours)

### Test Different DNS Names

```bash
# Create services in different namespaces
kubectl create namespace test-ns
kubectl create deployment app -n test-ns --image=nginx
kubectl expose deployment app -n test-ns --port=80

# From default namespace
kubectl exec test -- nslookup app.test-ns
kubectl exec test -- nslookup app.test-ns.svc.cluster.local

# Test external DNS
kubectl exec test -- nslookup google.com
kubectl exec test -- nslookup kubernetes.io
```

### Test Headless Service

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: headless
spec:
  clusterIP: None
  selector:
    app: web
  ports:
  - port: 80
EOF

# Check resolution
kubectl exec test -- nslookup headless
# Should return pod IPs, not ClusterIP
```

**✅ Checkpoint:** Understanding DNS name formats.

---

## Phase 3: CoreDNS Configuration (3 hours)

### View Current Configuration

```bash
kubectl get cm coredns -n kube-system -o yaml > coredns-backup.yaml
kubectl describe cm coredns -n kube-system
```

### Add Custom DNS Entry

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns-custom
  namespace: kube-system
data:
  custom.server: |
    example.com:53 {
        errors
        cache 30
        forward . 8.8.8.8
    }
EOF

# Edit main CoreDNS config to import
kubectl edit cm coredns -n kube-system
# Add: import custom.server

# Restart CoreDNS
kubectl rollout restart deployment coredns -n kube-system
```

### Test Custom Configuration

```bash
kubectl exec test -- nslookup example.com
```

**✅ Checkpoint:** Custom DNS configuration working.

---

## Phase 4: Custom DNS Policies (2 hours)

### Test Default Policy

```bash
kubectl run default-policy --image=busybox --command -- sleep 3600

kubectl exec default-policy -- cat /etc/resolv.conf
# Should show CoreDNS IP
```

### Test Custom DNS Policy

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: custom-dns
spec:
  dnsPolicy: None
  dnsConfig:
    nameservers:
    - 8.8.8.8
    - 1.1.1.1
    searches:
    - custom.local
  containers:
  - name: test
    image: busybox
    command: ['sleep', '3600']
EOF

kubectl exec custom-dns -- cat /etc/resolv.conf
# Should show 8.8.8.8 and 1.1.1.1
```

**✅ Checkpoint:** DNS policies understood.

---

## Phase 5: Troubleshooting (3 hours)

### Simulate DNS Issues

```bash
# Issue 1: Service not resolving
kubectl exec test -- nslookup nonexistent
# Diagnose
kubectl get svc nonexistent  # Doesn't exist

# Issue 2: Slow DNS
kubectl exec test -- time nslookup web
# Check CoreDNS logs
kubectl logs -n kube-system -l k8s-app=kube-dns

# Issue 3: External DNS failing
# Temporarily break upstream DNS
kubectl edit cm coredns -n kube-system
# Change forward to invalid DNS
kubectl rollout restart deployment coredns -n kube-system

# Test
kubectl exec test -- nslookup google.com
# Should fail

# Fix it
kubectl edit cm coredns -n kube-system
# Restore forward . 8.8.8.8
kubectl rollout restart deployment coredns -n kube-system
```

**✅ Checkpoint:** Can diagnose DNS issues.

---

## Phase 6: Performance Optimization (2 hours)

### Increase Cache

```bash
kubectl edit cm coredns -n kube-system
# Change: cache 30
# To:     cache 300  # 5 minutes
kubectl rollout restart deployment coredns -n kube-system
```

### Add More Replicas

```bash
kubectl scale deployment coredns -n kube-system --replicas=3
kubectl get pods -n kube-system -l k8s-app=kube-dns
```

### Monitor Performance

```bash
# Check CoreDNS metrics
kubectl port-forward -n kube-system svc/kube-dns 9153:9153
curl http://localhost:9153/metrics

# Check resource usage
kubectl top pod -n kube-system -l k8s-app=kube-dns
```

**✅ Checkpoint:** DNS optimized for performance.

---

## Phase 7: Advanced Configuration (2 hours)

### Add Conditional Forwarding

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns
  namespace: kube-system
data:
  Corefile: |
    .:53 {
        errors
        health
        kubernetes cluster.local in-addr.arpa ip6.arpa {
            pods insecure
            fallthrough in-addr.arpa ip6.arpa
        }
        prometheus :9153
        forward . 8.8.8.8
        cache 30
        loop
        reload
        loadbalance
    }
    internal.company.com:53 {
        forward . 10.0.0.53
    }
EOF

kubectl rollout restart deployment coredns -n kube-system
```

### Add Logging

```bash
# Enable query logging
kubectl edit cm coredns -n kube-system
# Add: log plugin

kubectl rollout restart deployment coredns -n kube-system

# Watch logs
kubectl logs -n kube-system -l k8s-app=kube-dns -f
```

**✅ Checkpoint:** Advanced DNS features configured.

---

## ✅ Final Validation

### Complete Checklist

- [ ] CoreDNS pods running
- [ ] Service discovery working
- [ ] External DNS resolving
- [ ] Custom DNS entries added
- [ ] DNS policies understood
- [ ] Troubleshooting skills gained
- [ ] Performance optimized
- [ ] Monitoring enabled

---

## 🎓 Key Learnings

**DNS Basics:**
- CoreDNS handles all cluster DNS
- Format: service.namespace.svc.cluster.local
- Search domains simplify queries

**Configuration:**
- Corefile in ConfigMap
- Plugin-based architecture
- Restart after changes

**Troubleshooting:**
- Check CoreDNS pods first
- Verify service exists
- Check endpoints
- Test upstream DNS

**Optimization:**
- Increase cache size
- Multiple replicas
- Monitor metrics
- Resource limits

---

**Congratulations! You've mastered CoreDNS! 🌐🚀**
