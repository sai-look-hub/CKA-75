# 🔧 TROUBLESHOOTING: Network Security

## 🚨 ISSUE 1: mTLS Connection Fails

**Error:**
```
upstream connect error or disconnect/reset before headers
```

**Cause:** mTLS misconfiguration or sidecar missing.

**Diagnosis:**
```bash
# Check sidecars
kubectl get pods -n <namespace>
# Should show 2/2 containers

# Check mTLS mode
kubectl get peerauthentication -n <namespace>

# Check Envoy config
istioctl proxy-config cluster <pod> -n <namespace>
```

**Solution:**
- Ensure sidecars injected
- Verify PeerAuthentication mode
- Check both services in mesh

---

## 🚨 ISSUE 2: Authorization Denied

**Error:**
```
RBAC: access denied
```

**Cause:** No matching authorization policy.

**Diagnosis:**
```bash
# List policies
kubectl get authorizationpolicies -n <namespace>

# Check ServiceAccount
kubectl get pod <pod> -o jsonpath='{.spec.serviceAccountName}'

# Verify principal format
kubectl describe authorizationpolicy <policy>
```

**Solution:**
```yaml
# Correct principal format
principals:
- "cluster.local/ns/<namespace>/sa/<serviceaccount>"
```

---

## 🚨 ISSUE 3: Network Policy Blocking Traffic

**Symptoms:** Timeout on connections.

**Diagnosis:**
```bash
# List policies
kubectl get networkpolicies -n <namespace>

# Check pod labels
kubectl get pods --show-labels -n <namespace>

# Describe policy
kubectl describe networkpolicy <policy> -n <namespace>
```

**Solution:**
- Verify podSelector matches
- Check port numbers
- Ensure DNS egress allowed

---

## 🚨 ISSUE 4: Sidecar Not Injected

**Symptoms:** Pod has only 1/1 containers.

**Diagnosis:**
```bash
# Check namespace label
kubectl get namespace <namespace> --show-labels

# Check webhook
kubectl get mutatingwebhookconfigurations
```

**Solution:**
```bash
# Label namespace
kubectl label namespace <namespace> istio-injection=enabled

# Restart pods
kubectl rollout restart deployment -n <namespace>
```

---

## 📋 Debug Checklist

1. ☑️ Sidecars injected? `kubectl get pods`
2. ☑️ Namespace labeled? `kubectl get ns --show-labels`
3. ☑️ mTLS configured? `istioctl authn tls-check`
4. ☑️ Auth policies exist? `kubectl get authorizationpolicies`
5. ☑️ Network policies exist? `kubectl get networkpolicies`
6. ☑️ DNS working? `kubectl exec <pod> -- nslookup <service>`
7. ☑️ ServiceAccounts correct? `kubectl get sa`
