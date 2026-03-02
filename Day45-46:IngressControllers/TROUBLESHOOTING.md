# 🔧 TROUBLESHOOTING: Ingress Controllers

---

## 🚨 ISSUE 1: Ingress Not Getting External IP

**Symptoms:**
```bash
kubectl get ing
# ADDRESS column shows <pending>
```

**Diagnosis:**
```bash
# Check ingress controller service
kubectl get svc -n ingress-nginx

# Check LoadBalancer status
kubectl describe svc -n ingress-nginx ingress-nginx-controller
```

**Causes & Solutions:**

**Cause 1: Not on cloud provider**
- LoadBalancer type needs cloud support
- Solution: Use NodePort or install MetalLB

**Cause 2: Cloud provider issue**
- Check cloud provider quotas
- Check IAM permissions
- Solution: Check cloud provider console

**Cause 3: Controller not ready**
```bash
kubectl get pods -n ingress-nginx
# If not Running, check logs
kubectl logs -n ingress-nginx <controller-pod>
```

---

## 🚨 ISSUE 2: 404 Not Found

**Symptoms:**
```bash
curl http://<ingress-ip>/path
# 404 page not found
```

**Diagnosis:**
```bash
# Check ingress exists
kubectl get ing

# Check rules
kubectl describe ing <ingress-name>

# Check service exists
kubectl get svc <backend-service>

# Check endpoints
kubectl get ep <backend-service>
```

**Solutions:**

**Solution 1: Wrong path**
```yaml
# Check pathType
pathType: Prefix  # vs Exact vs ImplementationSpecific
```

**Solution 2: Service doesn't exist**
```bash
kubectl create svc clusterip <service> --tcp=80:8080
```

**Solution 3: No pods behind service**
```bash
# Check selector matches
kubectl get pods -l app=<label>
```

---

## 🚨 ISSUE 3: TLS Certificate Not Working

**Symptoms:**
```bash
curl https://<ingress-ip>
# SSL certificate problem
```

**Diagnosis:**
```bash
# Check TLS secret exists
kubectl get secret <tls-secret>

# Verify secret type
kubectl get secret <tls-secret> -o jsonpath='{.type}'
# Should be: kubernetes.io/tls

# Check certificate
kubectl get secret <tls-secret> -o jsonpath='{.data.tls\.crt}' | \
  base64 -d | openssl x509 -text -noout
```

**Solutions:**

**Solution 1: Secret doesn't exist**
```bash
kubectl create secret tls <name> --cert=tls.crt --key=tls.key
```

**Solution 2: Wrong secret name in ingress**
```yaml
tls:
- secretName: correct-secret-name  # Must match
```

**Solution 3: Certificate expired**
```bash
# Check expiry
kubectl get secret <secret> -o jsonpath='{.data.tls\.crt}' | \
  base64 -d | openssl x509 -noout -dates
```

---

## 🚨 ISSUE 4: cert-manager Not Creating Certificate

**Symptoms:**
```bash
kubectl get cert
# READY: False
```

**Diagnosis:**
```bash
# Describe certificate
kubectl describe cert <cert-name>

# Check certificate status
kubectl get cert <cert-name> -o jsonpath='{.status.conditions}'

# Check cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager
```

**Solutions:**

**Solution 1: Wrong issuer**
```bash
# Verify issuer exists
kubectl get clusterissuer
kubectl get issuer
```

**Solution 2: DNS not resolving**
- For Let's Encrypt, domain must resolve to ingress IP
- Check: `nslookup your-domain.com`

**Solution 3: HTTP01 challenge failing**
```bash
# Check challenge
kubectl get challenge

# Describe challenge
kubectl describe challenge <challenge-name>
```

---

## 🚨 ISSUE 5: Backend Service Unreachable

**Symptoms:**
```bash
curl http://<ingress-ip>
# 503 Service Temporarily Unavailable
```

**Diagnosis:**
```bash
# Check service
kubectl get svc <service>

# Check endpoints
kubectl get ep <service>

# Check if pods are ready
kubectl get pods -l app=<label>

# Test service directly
kubectl run test --rm -it --image=busybox -- \
  wget -qO- http://<service>
```

**Solutions:**

**Solution 1: No ready pods**
```bash
# Check pod status
kubectl describe pod <pod>
# Fix pod issues
```

**Solution 2: Service selector wrong**
```yaml
# Match service selector to pod labels
selector:
  app: correct-label
```

---

## 🚨 ISSUE 6: Path Rewriting Not Working

**Symptoms:**
- Backend receives wrong path
- 404 on backend

**Diagnosis:**
```bash
# Check rewrite annotation
kubectl get ing <ingress> -o jsonpath='{.metadata.annotations}'

# Check controller logs
kubectl logs -n ingress-nginx <controller-pod> | grep rewrite
```

**Solution:**
```yaml
# Correct rewrite syntax
annotations:
  nginx.ingress.kubernetes.io/rewrite-target: /$2
# With path: /api(/|$)(.*)
```

---

## 📊 Common Error Messages

| Error | Cause | Solution |
|-------|-------|----------|
| `404 not found` | Path doesn't match | Fix path or pathType |
| `503 unavailable` | No backend pods | Check service/pods |
| `SSL error` | Wrong certificate | Check TLS secret |
| `Connection refused` | Service wrong port | Fix targetPort |
| `Host not found` | DNS issue | Configure DNS |

---

## 🔍 Debug Checklist

```bash
# 1. Check ingress
kubectl get ing <ingress>
kubectl describe ing <ingress>

# 2. Check controller
kubectl get pods -n ingress-nginx
kubectl logs -n ingress-nginx <controller-pod>

# 3. Check service
kubectl get svc <service>
kubectl get ep <service>

# 4. Check pods
kubectl get pods -l app=<label>
kubectl logs <pod>

# 5. Test connectivity
kubectl run test --rm -it --image=nicolaka/netshoot -- bash
```

---

**Pro Tip:** Enable debug logging in NGINX controller for troubleshooting!

```bash
kubectl edit cm -n ingress-nginx ingress-nginx-controller
# Add: error-log-level: debug
```
