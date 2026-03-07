# 🔧 TROUBLESHOOTING: Quick Reference

## 🚨 Pod Cannot Connect to Another Pod

**Quick Fix:**
```bash
# 1. Check pods running
kubectl get pods -o wide

# 2. Test connectivity
kubectl exec <pod-a> -- ping <pod-b-ip>

# 3. Check network policy
kubectl get networkpolicy

# 4. Check CNI
kubectl get pods -n kube-system | grep -E 'calico|flannel|cilium'
```

---

## 🚨 DNS Not Working

**Quick Fix:**
```bash
# 1. Check CoreDNS
kubectl get pods -n kube-system -l k8s-app=kube-dns

# 2. Check service exists
kubectl get svc <service-name>

# 3. Test with FQDN
kubectl exec <pod> -- nslookup <service>.<namespace>.svc.cluster.local

# 4. Check CoreDNS logs
kubectl logs -n kube-system -l k8s-app=kube-dns | tail -20
```

---

## 🚨 Service Not Accessible

**Quick Fix:**
```bash
# 1. Check service
kubectl get svc <service>

# 2. Check endpoints
kubectl get endpoints <service>

# 3. Check backend pods
kubectl get pods -l <selector>

# 4. Test pod directly
kubectl exec <test-pod> -- curl http://<pod-ip>
```

---

## 🚨 External Connectivity Fails

**Quick Fix:**
```bash
# 1. Test DNS first
kubectl exec <pod> -- nslookup google.com

# 2. Check network policy
kubectl get networkpolicy

# 3. Test from node
ssh <node>
curl https://google.com

# 4. Check egress rules
kubectl describe networkpolicy | grep -A10 egress
```

---

## 📋 Troubleshooting Checklist

1. ☑️ Are pods Running?
2. ☑️ Does DNS work?
3. ☑️ Does service have endpoints?
4. ☑️ Can pods ping each other?
5. ☑️ Are network policies blocking?
6. ☑️ Is CoreDNS healthy?
7. ☑️ Can you reach external services?
