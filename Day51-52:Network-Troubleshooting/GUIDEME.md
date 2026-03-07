# 📖 GUIDEME: Network Troubleshooting - Complete Walkthrough

## 🎯 16-Hour Hands-On Training

**Day 1:** Basic troubleshooting, DNS issues (8 hours)
**Day 2:** Advanced scenarios, toolkit building (8 hours)

---

## Phase 1: Setup Debug Environment (1 hour)

```bash
# Deploy debug pod
kubectl run netshoot --image=nicolaka/netshoot --command -- sleep infinity

# Deploy test applications
kubectl create deployment web --image=nginx --replicas=3
kubectl expose deployment web --port=80

kubectl create deployment backend --image=nginx --replicas=2
kubectl expose deployment backend --port=80

# Verify
kubectl get pods,svc
```

**✅ Checkpoint:** Debug environment ready.

---

## Phase 2: Pod-to-Pod Connectivity (2 hours)

### Scenario 1: Basic Connectivity Test
```bash
# Get pod IPs
WEB_IP=$(kubectl get pod -l app=web -o jsonpath='{.items[0].status.podIP}')
BACKEND_IP=$(kubectl get pod -l app=backend -o jsonpath='{.items[0].status.podIP}')

# Test connectivity
kubectl exec netshoot -- ping -c 3 $WEB_IP
kubectl exec netshoot -- curl -s http://$WEB_IP

# Test from web to backend
WEB_POD=$(kubectl get pod -l app=web -o jsonpath='{.items[0].metadata.name}')
kubectl exec $WEB_POD -- curl -s http://$BACKEND_IP
```

### Scenario 2: Connectivity Failure
```bash
# Simulate failure: Apply deny-all network policy
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
spec:
  podSelector: {}
  policyTypes:
  - Ingress
EOF

# Test again
kubectl exec netshoot -- curl --connect-timeout 5 http://$WEB_IP
# Should timeout

# Diagnose
kubectl get networkpolicy
kubectl describe networkpolicy deny-all

# Fix: Remove policy
kubectl delete networkpolicy deny-all

# Verify fix
kubectl exec netshoot -- curl -s http://$WEB_IP
```

**✅ Checkpoint:** Can diagnose connectivity issues.

---

## Phase 3: DNS Troubleshooting (2 hours)

### Scenario 1: Service Resolution
```bash
# Test DNS
kubectl exec netshoot -- nslookup web
kubectl exec netshoot -- nslookup backend.default.svc.cluster.local

# Check resolv.conf
kubectl exec netshoot -- cat /etc/resolv.conf
```

### Scenario 2: DNS Not Working
```bash
# Simulate failure: Scale CoreDNS to 0
kubectl scale deployment coredns -n kube-system --replicas=0

# Test DNS
kubectl exec netshoot -- nslookup web
# Should fail

# Diagnose
kubectl get pods -n kube-system -l k8s-app=kube-dns
# No pods!

# Fix
kubectl scale deployment coredns -n kube-system --replicas=2

# Wait for ready
kubectl wait --for=condition=ready pod -l k8s-app=kube-dns -n kube-system --timeout=60s

# Verify
kubectl exec netshoot -- nslookup web
```

**✅ Checkpoint:** Can troubleshoot DNS.

---

## Phase 4: Service Issues (2 hours)

### Scenario 1: No Endpoints
```bash
# Create service without pods
kubectl create service clusterip broken-svc --tcp=80:80

# Test
kubectl exec netshoot -- curl --connect-timeout 5 http://broken-svc
# Fails

# Diagnose
kubectl get svc broken-svc
kubectl get endpoints broken-svc
# No endpoints!

# Check why
kubectl describe svc broken-svc
# No selector!

# Fix: Add selector
kubectl delete svc broken-svc
kubectl expose deployment web --name=broken-svc --port=80

# Verify
kubectl get endpoints broken-svc
kubectl exec netshoot -- curl http://broken-svc
```

### Scenario 2: Wrong Port
```bash
# Create service with wrong port
kubectl expose deployment backend --name=wrong-port --port=8080 --target-port=80

# Test
kubectl exec netshoot -- curl http://wrong-port:8080
# Works (nginx listens on 80)

# Now create with correct mapping
kubectl delete svc wrong-port
kubectl expose deployment backend --name=correct-port --port=8080 --target-port=80

kubectl exec netshoot -- curl http://correct-port:8080
```

**✅ Checkpoint:** Can debug service issues.

---

## Phase 5: Network Policy Debugging (2 hours)

### Complex Policy Scenario
```bash
# Create three-tier app simulation
kubectl label pod $WEB_POD tier=frontend
BACKEND_POD=$(kubectl get pod -l app=backend -o jsonpath='{.items[0].metadata.name}')
kubectl label pod $BACKEND_POD tier=backend

# Apply policy: backend only accepts from frontend
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-policy
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
EOF

# Test: netshoot (no label) should fail
kubectl exec netshoot -- curl --connect-timeout 5 http://$BACKEND_IP
# Timeout

# Test: web (frontend label) should work
kubectl exec $WEB_POD -- curl -s http://$BACKEND_IP
# Works!

# Diagnose
kubectl describe networkpolicy backend-policy
kubectl get pods --show-labels

# Fix for netshoot: Add label
kubectl label pod netshoot tier=frontend
kubectl exec netshoot -- curl http://$BACKEND_IP
```

**✅ Checkpoint:** Can debug network policies.

---

## Phase 6: External Connectivity (2 hours)

### Test External Access
```bash
# Test external DNS
kubectl exec netshoot -- nslookup google.com

# Test external connectivity
kubectl exec netshoot -- curl -I https://google.com

# Simulate failure: Block egress
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-egress
spec:
  podSelector: {}
  policyTypes:
  - Egress
EOF

# Test again
kubectl exec netshoot -- curl --connect-timeout 5 https://google.com
# Timeout

# Even DNS fails!
kubectl exec netshoot -- nslookup google.com
# Timeout

# Fix: Allow DNS
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
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
  - to:
    - ipBlock:
        cidr: 0.0.0.0/0
    ports:
    - protocol: TCP
      port: 443
EOF

# Delete deny-egress
kubectl delete networkpolicy deny-egress

# Verify
kubectl exec netshoot -- curl -I https://google.com
```

**✅ Checkpoint:** Can troubleshoot egress.

---

## Phase 7: Performance Issues (2 hours)

### Diagnose Slow Connections
```bash
# Test latency
kubectl exec netshoot -- time curl http://web

# Multiple tests
for i in {1..10}; do
  kubectl exec netshoot -- time curl -s http://web > /dev/null
done

# Check if DNS is slow
kubectl exec netshoot -- time nslookup web

# Check CoreDNS performance
kubectl top pod -n kube-system -l k8s-app=kube-dns

# Check pod resources
kubectl top pod $WEB_POD
```

**✅ Checkpoint:** Can diagnose performance.

---

## Phase 8: Build Troubleshooting Runbook (3 hours)

### Document Findings
```bash
cat > network-runbook.md << 'EOF'
# Network Troubleshooting Runbook

## Issue: Service Not Accessible

**Symptoms:** Connection timeout/refused

**Diagnosis:**
1. Check service: `kubectl get svc <service>`
2. Check endpoints: `kubectl get ep <service>`
3. Check pods: `kubectl get pods -l <selector>`
4. Test pod directly: `curl http://<pod-ip>`

**Solutions:**
- No endpoints → Fix selector/labels
- Pods not ready → Check pod logs
- Service wrong port → Fix targetPort

## Issue: DNS Not Working

**Symptoms:** nslookup fails

**Diagnosis:**
1. Check CoreDNS: `kubectl get pods -n kube-system -l k8s-app=kube-dns`
2. Check logs: `kubectl logs -n kube-system -l k8s-app=kube-dns`
3. Test: `kubectl exec <pod> -- nslookup kubernetes.default`

**Solutions:**
- CoreDNS not running → Scale deployment
- Network policy → Allow port 53
- Service doesn't exist → Create it

EOF
```

**✅ Checkpoint:** Runbook created.

---

## ✅ Final Validation

### Complete Troubleshooting Test
```bash
# 1. Pod-to-pod
kubectl exec netshoot -- curl http://$WEB_IP

# 2. DNS resolution
kubectl exec netshoot -- nslookup web

# 3. Service access
kubectl exec netshoot -- curl http://web

# 4. External access
kubectl exec netshoot -- curl -I https://google.com

# 5. Cross-namespace (if tested)
kubectl exec netshoot -- nslookup web.default.svc.cluster.local
```

### Skills Checklist
- [ ] Can diagnose pod connectivity
- [ ] Can troubleshoot DNS
- [ ] Can debug services
- [ ] Can debug network policies
- [ ] Can test external connectivity
- [ ] Can use netshoot effectively
- [ ] Can read network logs
- [ ] Built troubleshooting runbook

---

**Congratulations! You're a network troubleshooting expert! 🔍🚀**
