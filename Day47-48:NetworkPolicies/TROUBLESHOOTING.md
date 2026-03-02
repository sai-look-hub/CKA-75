# 🔧 TROUBLESHOOTING: Network Policies

## 🚨 ISSUE 1: Policy Not Working

**Symptoms:**
- Applied policy but traffic not blocked

**Diagnosis:**
```bash
# Check CNI supports network policies
kubectl get pods -n kube-system | grep -E 'calico|cilium|weave'

# Check policy exists
kubectl get netpol

# Check pod labels match
kubectl get pods --show-labels
```

**Solution:**
- Verify CNI supports policies (Calico/Cilium/Weave)
- Check podSelector matches pod labels
- Ensure policy in correct namespace

---

## 🚨 ISSUE 2: DNS Not Working

**Symptoms:**
```bash
kubectl exec <pod> -- nslookup kubernetes.default
# Connection timeout
```

**Solution:**
```yaml
# Add DNS egress rule
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

## 🚨 ISSUE 3: Can't Reach Service

**Cause:** Egress rule missing

**Solution:**
```yaml
egress:
- to:
  - podSelector:
      matchLabels:
        app: backend
  ports:
  - protocol: TCP
    port: 8080
```

---

## 📊 Debug Checklist

```bash
# 1. Check policy exists
kubectl get netpol -A

# 2. Check pod labels
kubectl get pods --show-labels

# 3. Test connectivity
kubectl exec <pod> -- curl <target>

# 4. Check logs
kubectl logs <pod>
```
