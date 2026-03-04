# 🔧 TROUBLESHOOTING: CoreDNS

## 🚨 ISSUE 1: Service Not Resolving

**Symptoms:**
```bash
nslookup backend
# Can't find backend
```

**Diagnosis:**
```bash
# Check service exists
kubectl get svc backend

# Check endpoints
kubectl get endpoints backend

# Check CoreDNS
kubectl get pods -n kube-system -l k8s-app=kube-dns
```

**Solutions:**
- Service doesn't exist: Create it
- Wrong namespace: Use FQDN
- No endpoints: Check pod labels

---

## 🚨 ISSUE 2: External DNS Not Working

**Symptoms:**
```bash
nslookup google.com
# Timeout
```

**Diagnosis:**
```bash
# Check CoreDNS logs
kubectl logs -n kube-system -l k8s-app=kube-dns

# Check forward config
kubectl get cm coredns -n kube-system -o yaml | grep forward
```

**Solutions:**
- Fix upstream DNS in forward directive
- Check network policies allow port 53
- Verify node DNS works

---

## 🚨 ISSUE 3: CoreDNS Pods CrashLooping

**Diagnosis:**
```bash
kubectl describe pod -n kube-system <coredns-pod>
kubectl logs -n kube-system <coredns-pod>
```

**Common Causes:**
- Invalid Corefile syntax
- Resource limits too low
- Loop detected

**Solutions:**
- Validate Corefile
- Increase resources
- Fix forward configuration

---

## 📊 Debug Checklist

1. Check CoreDNS pods: `kubectl get pods -n kube-system -l k8s-app=kube-dns`
2. Check service exists: `kubectl get svc <service>`
3. Check endpoints: `kubectl get ep <service>`
4. Test DNS: `kubectl exec <pod> -- nslookup <service>`
5. Check logs: `kubectl logs -n kube-system -l k8s-app=kube-dns`
