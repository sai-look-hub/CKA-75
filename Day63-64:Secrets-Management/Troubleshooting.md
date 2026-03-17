# 🔧 TROUBLESHOOTING: Secrets Management

## 🚨 ISSUE 1: Secret Not Found

**Error:**
```
Error: secret "db-credentials" not found
```

**Diagnosis:**
```bash
# Check secret exists
kubectl get secret db-credentials

# Check namespace
kubectl get secret db-credentials -n <correct-namespace>

# Check External Secret status
kubectl describe externalsecret <name>
```

**Solutions:**
- Secret in different namespace
- ExternalSecret not syncing (check SecretStore)
- SealedSecret not unsealed (check controller)

---

## 🚨 ISSUE 2: Sealed Secret Won't Decrypt

**Error:**
```
SealedSecret controller: no key could decrypt secret
```

**Cause:** Wrong cluster or controller redeployed

**Diagnosis:**
```bash
# Check controller logs
kubectl logs -n kube-system -l name=sealed-secrets-controller

# Check sealing key
kubeseal --fetch-cert
```

**Solution:**
- Re-seal with current cert
- Or restore old sealing key

---

## 🚨 ISSUE 3: External Secret Not Syncing

**Symptoms:** Secret not created or not updating

**Diagnosis:**
```bash
# Check ExternalSecret status
kubectl describe externalsecret <name>

# Check SecretStore
kubectl describe secretstore <name>

# Check operator logs
kubectl logs -n external-secrets-system \
  -l app.kubernetes.io/name=external-secrets
```

**Common causes:**
- SecretStore misconfigured
- Authentication failed
- Remote secret doesn't exist
- Network connectivity

---

## 🚨 ISSUE 4: Pod Can't Read Secret

**Error:**
```
Error: couldn't find key password in Secret default/db-credentials
```

**Diagnosis:**
```bash
# Check secret has the key
kubectl get secret db-credentials -o yaml

# Check RBAC
kubectl auth can-i get secrets --as=system:serviceaccount:default:app-sa
```

**Solutions:**
- Secret missing key
- Wrong secret name
- RBAC missing
- Wrong namespace

---

## 📋 Debug Checklist

1. ☑️ Secret exists? `kubectl get secret`
2. ☑️ Correct namespace? Check `-n` flag
3. ☑️ For Sealed: Controller running?
4. ☑️ For External: SecretStore valid?
5. ☑️ RBAC allows access?
6. ☑️ Secret has correct keys?
7. ☑️ Pod using correct secretKeyRef?
