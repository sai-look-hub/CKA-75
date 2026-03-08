# 📖 GUIDEME: Week 7-8 Capstone Project

## 🎯 Complete Project Deployment (16 hours)

This is your comprehensive capstone project combining all Week 7-8 learnings.

---

## Phase 1: Environment Setup (1 hour)

### Step 1: Create Namespace
```bash
kubectl create namespace ecommerce
kubectl label namespace ecommerce name=ecommerce
kubectl label namespace kube-system name=kube-system
```

### Step 2: Install Prerequisites
```bash
# Install NGINX Ingress
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace

# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.0/cert-manager.yaml

# Wait for ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=ingress-nginx -n ingress-nginx --timeout=300s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=cert-manager -n cert-manager --timeout=300s
```

**✅ Checkpoint:** Prerequisites installed.

---

## Phase 2: Deploy Database (1 hour)

### Apply Database Resources
```bash
kubectl apply -f database/
kubectl get pods -n ecommerce -l tier=database -w
```

### Verify Database
```bash
# Check pod is running
kubectl get pods -n ecommerce -l tier=database

# Check service
kubectl get svc -n ecommerce database

# Test connectivity (from debug pod)
kubectl run netshoot -n ecommerce --rm -it --image=nicolaka/netshoot -- bash
# Inside pod:
nc -zv database 5432
nslookup database
exit
```

**✅ Checkpoint:** Database running and accessible.

---

## Phase 3: Deploy Backend API (1 hour)

### Apply Backend Resources
```bash
kubectl apply -f backend/
kubectl get pods -n ecommerce -l tier=backend -w
```

### Verify Backend
```bash
# Check deployment
kubectl get deployment -n ecommerce backend

# Check service
kubectl get svc -n ecommerce backend

# Test health endpoint
kubectl run test -n ecommerce --rm -it --image=busybox -- wget -qO- http://backend:8080/health
```

**✅ Checkpoint:** Backend API running.

---

## Phase 4: Deploy Frontend & Admin (1 hour)

### Apply Frontend Resources
```bash
kubectl apply -f frontend/
kubectl apply -f admin/

kubectl get pods -n ecommerce -l tier=frontend -w
kubectl get pods -n ecommerce -l tier=admin -w
```

### Verify All Services
```bash
kubectl get all -n ecommerce
```

**✅ Checkpoint:** All services deployed.

---

## Phase 5: Configure Ingress (2 hours)

### Step 1: Create ClusterIssuer
```bash
kubectl apply -f ingress/cluster-issuer.yaml
kubectl get clusterissuer
```

### Step 2: Apply Ingress
```bash
kubectl apply -f ingress/ecommerce-ingress.yaml
kubectl get ingress -n ecommerce -w
```

### Step 3: Get Ingress IP
```bash
INGRESS_IP=$(kubectl get ingress -n ecommerce ecommerce-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Ingress IP: $INGRESS_IP"
```

### Step 4: Test Ingress
```bash
# Test frontend
curl -H "Host: ecommerce.example.com" http://$INGRESS_IP/

# Test backend
curl -H "Host: ecommerce.example.com" http://$INGRESS_IP/api/health

# Test admin
curl -H "Host: ecommerce.example.com" http://$INGRESS_IP/admin/
```

**✅ Checkpoint:** Ingress routing working.

---

## Phase 6: Implement Network Policies (3 hours)

### Step 1: Apply Default Deny
```bash
kubectl apply -f network-policies/00-default-deny.yaml

# Test - everything should fail now
kubectl run test -n ecommerce --rm -it --image=busybox -- wget --timeout=5 -qO- http://backend:8080
# Timeout expected!
```

### Step 2: Allow DNS
```bash
kubectl apply -f network-policies/01-allow-dns.yaml

# Test DNS works
kubectl run test -n ecommerce --rm -it --image=busybox -- nslookup backend
# Should work!
```

### Step 3: Allow Ingress → Services
```bash
kubectl apply -f network-policies/02-allow-ingress.yaml

# Test from outside
curl -H "Host: ecommerce.example.com" http://$INGRESS_IP/
# Should work!
```

### Step 4: Allow Frontend → Backend
```bash
kubectl apply -f network-policies/03-frontend-egress.yaml
kubectl apply -f network-policies/04-backend-ingress.yaml

# Test from frontend pod
FRONTEND_POD=$(kubectl get pod -n ecommerce -l tier=frontend -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n ecommerce $FRONTEND_POD -- curl -s http://backend:8080/health
# Should work!
```

### Step 5: Allow Backend → Database
```bash
kubectl apply -f network-policies/05-backend-egress.yaml
kubectl apply -f network-policies/06-database-ingress.yaml

# Test from backend pod
BACKEND_POD=$(kubectl get pod -n ecommerce -l tier=backend -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n ecommerce $BACKEND_POD -- nc -zv database 5432
# Should work!
```

### Step 6: Verify Security
```bash
# Frontend should NOT reach database
kubectl exec -n ecommerce $FRONTEND_POD -- timeout 5 nc -zv database 5432
# Should timeout! ✅

# Test pod without label should fail
kubectl run test -n ecommerce --image=busybox --command -- sleep 3600
kubectl exec -n ecommerce test -- timeout 5 wget -qO- http://backend:8080
# Should timeout! ✅

kubectl delete pod test -n ecommerce
```

**✅ Checkpoint:** Zero-trust networking implemented.

---

## Phase 7: Monitoring & Observability (2 hours)

### Deploy Debug Pod
```bash
kubectl apply -f monitoring/debug-pod.yaml
```

### Create Monitoring ConfigMap
```bash
kubectl apply -f monitoring/monitoring-config.yaml
```

### Test Monitoring
```bash
# Access metrics
kubectl port-forward -n ecommerce svc/backend 8080:8080 &
curl http://localhost:8080/metrics

# Check CoreDNS metrics
kubectl port-forward -n kube-system svc/kube-dns 9153:9153 &
curl http://localhost:9153/metrics | grep coredns_dns
```

**✅ Checkpoint:** Monitoring configured.

---

## Phase 8: Testing & Validation (3 hours)

### Comprehensive Testing Script
```bash
cat > test-all.sh << 'EOF'
#!/bin/bash
set -e

echo "=== Testing E-Commerce Platform ==="

# Test 1: Ingress
echo "1. Testing Ingress..."
INGRESS_IP=$(kubectl get ingress -n ecommerce ecommerce-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl -f -H "Host: ecommerce.example.com" http://$INGRESS_IP/ > /dev/null && echo "✅ Frontend accessible"
curl -f -H "Host: ecommerce.example.com" http://$INGRESS_IP/api/health > /dev/null && echo "✅ Backend API accessible"

# Test 2: DNS
echo "2. Testing DNS..."
kubectl run dnstest -n ecommerce --rm -it --image=busybox -- nslookup backend > /dev/null && echo "✅ DNS working"

# Test 3: Service connectivity
echo "3. Testing Service Connectivity..."
FRONTEND_POD=$(kubectl get pod -n ecommerce -l tier=frontend -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n ecommerce $FRONTEND_POD -- curl -f -s http://backend:8080/health > /dev/null && echo "✅ Frontend → Backend"

BACKEND_POD=$(kubectl get pod -n ecommerce -l tier=backend -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n ecommerce $BACKEND_POD -- nc -zv database 5432 2>&1 | grep -q succeeded && echo "✅ Backend → Database"

# Test 4: Network Policies
echo "4. Testing Network Policies..."
kubectl exec -n ecommerce $FRONTEND_POD -- timeout 3 nc -zv database 5432 2>&1 | grep -q timeout && echo "✅ Frontend ✗ Database (blocked)"

# Test 5: All pods running
echo "5. Checking Pod Status..."
kubectl get pods -n ecommerce | grep -v NAME | awk '{if($3!="Running") exit 1}' && echo "✅ All pods running"

echo ""
echo "=== All Tests Passed! ✅ ==="
EOF

chmod +x test-all.sh
./test-all.sh
```

**✅ Checkpoint:** All tests passing!

---

## Phase 9: Failure Scenarios (2 hours)

### Scenario 1: DNS Failure
```bash
# Break it
kubectl scale deployment coredns -n kube-system --replicas=0

# Observe
kubectl exec -n ecommerce $FRONTEND_POD -- nslookup backend
# Fails!

# Fix it
kubectl scale deployment coredns -n kube-system --replicas=2
kubectl wait --for=condition=ready pod -l k8s-app=kube-dns -n kube-system --timeout=60s

# Verify
kubectl exec -n ecommerce $FRONTEND_POD -- nslookup backend
# Works!
```

### Scenario 2: Network Policy Error
```bash
# Break it
kubectl delete networkpolicy allow-dns -n ecommerce

# Observe
kubectl exec -n ecommerce $FRONTEND_POD -- nslookup backend
# Timeout!

# Fix it
kubectl apply -f network-policies/01-allow-dns.yaml

# Verify
kubectl exec -n ecommerce $FRONTEND_POD -- nslookup backend
```

### Scenario 3: Service Endpoint Failure
```bash
# Break it
kubectl scale deployment backend -n ecommerce --replicas=0

# Observe
kubectl get endpoints -n ecommerce backend
# No endpoints!
curl -H "Host: ecommerce.example.com" http://$INGRESS_IP/api/health
# 503 error

# Fix it
kubectl scale deployment backend -n ecommerce --replicas=2

# Verify
kubectl get endpoints -n ecommerce backend
curl -H "Host: ecommerce.example.com" http://$INGRESS_IP/api/health
```

**✅ Checkpoint:** Can handle failures!

---

## ✅ Final Validation

### Complete Checklist
- [ ] All pods running: `kubectl get pods -n ecommerce`
- [ ] Ingress has IP: `kubectl get ingress -n ecommerce`
- [ ] Services have endpoints: `kubectl get endpoints -n ecommerce`
- [ ] DNS working: `kubectl exec -n ecommerce $FRONTEND_POD -- nslookup backend`
- [ ] Frontend → Backend: `kubectl exec -n ecommerce $FRONTEND_POD -- curl http://backend:8080/health`
- [ ] Backend → Database: `kubectl exec -n ecommerce $BACKEND_POD -- nc -zv database 5432`
- [ ] Frontend ✗ Database: Blocked by network policy
- [ ] External access via Ingress working
- [ ] Network policies enforcing security
- [ ] Can troubleshoot failures

### Documentation
```bash
# Generate architecture diagram
kubectl get all -n ecommerce -o wide > architecture.txt

# Export network policies
kubectl get networkpolicies -n ecommerce -o yaml > network-policies-backup.yaml

# Export Ingress config
kubectl get ingress -n ecommerce -o yaml > ingress-config.yaml
```

---

## 🎓 Project Complete!

**You've successfully built:**
✅ Production-ready microservices platform
✅ Secure network architecture with zero-trust
✅ Advanced Ingress routing with TLS
✅ Complete monitoring and observability
✅ Comprehensive troubleshooting capabilities

**Congratulations! You're a Kubernetes Networking Expert! 🚀**

---

## 🚀 Next Steps

1. Add to your GitHub portfolio
2. Write technical blog post
3. Update LinkedIn with project
4. Share learnings with team
5. Continue to advanced topics

**Well done! 🎉**
