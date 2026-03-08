# 🔧 TROUBLESHOOTING: Common Project Issues

## 🚨 ISSUE 1: Ingress Not Accessible

**Symptoms:**
```bash
curl http://<INGRESS-IP>/
# Connection refused or timeout
```

**Diagnosis:**
```bash
# Check Ingress controller
kubectl get pods -n ingress-nginx

# Check Ingress resource
kubectl get ingress -n ecommerce
kubectl describe ingress -n ecommerce

# Check service endpoints
kubectl get endpoints -n ecommerce frontend
```

**Solutions:**
- Ingress controller not running → Install/restart
- No external IP → Wait or check cloud provider
- Wrong service name in Ingress → Fix YAML
- Pods not ready → Check pod logs

---

## 🚨 ISSUE 2: DNS Resolution Failing

**Symptoms:**
```bash
kubectl exec -n ecommerce $FRONTEND_POD -- nslookup backend
# Can't find backend
```

**Diagnosis:**
```bash
# Check CoreDNS
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Check network policy
kubectl get networkpolicy -n ecommerce allow-dns

# Check service exists
kubectl get svc -n ecommerce backend
```

**Solutions:**
- CoreDNS not running → Scale deployment
- Network policy blocking DNS → Apply allow-dns policy
- Service doesn't exist → Deploy service

---

## 🚨 ISSUE 3: Network Policy Blocking Traffic

**Symptoms:**
```bash
kubectl exec -n ecommerce $FRONTEND_POD -- curl http://backend:8080
# Timeout
```

**Diagnosis:**
```bash
# List all policies
kubectl get networkpolicy -n ecommerce

# Check labels
kubectl get pods -n ecommerce --show-labels

# Describe policy
kubectl describe networkpolicy -n ecommerce
```

**Solutions:**
- Missing allow policy → Apply appropriate policy
- Wrong labels → Fix pod/policy labels
- DNS not allowed → Apply allow-dns policy

---

## 🚨 ISSUE 4: All Pods Can't Communicate

**Diagnosis:**
```bash
# Check if default-deny applied
kubectl get networkpolicy -n ecommerce default-deny-all

# Check DNS egress
kubectl get networkpolicy -n ecommerce allow-dns
```

**Solution:**
Apply policies in order:
1. Default deny
2. Allow DNS
3. Allow specific traffic

---

## 📋 Quick Debug Checklist

1. ☑️ All pods Running?
2. ☑️ Services have endpoints?
3. ☑️ DNS resolution works?
4. ☑️ Network policies correct?
5. ☑️ Ingress has external IP?
6. ☑️ CoreDNS healthy?
