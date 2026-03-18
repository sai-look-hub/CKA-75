# 🔧 TROUBLESHOOTING: Image Security - Day 66-67

## 🚨 ISSUE 1: ImagePullBackOff Error

**Symptoms:**
```
Failed to pull image "private-registry.com/app:v1.0"
Back-off pulling image
ImagePullBackOff
```

**Diagnosis:**
```bash
# Check pod events
kubectl describe pod <pod-name>

# Look for specific error
# "unauthorized" = wrong credentials
# "not found" = image doesn't exist
# "connection refused" = registry unreachable

# Check if secret exists
kubectl get secret <secret-name> -n <namespace>

# Verify secret content
kubectl get secret <secret-name> -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d | jq
```

**Common Causes & Solutions:**

**1. Secret doesn't exist**
```bash
# Create it
kubectl create secret docker-registry <name> \
  --docker-server=<registry> \
  --docker-username=<user> \
  --docker-password=<pass>
```

**2. Wrong credentials**
```bash
# Test manually
docker login <registry> -u <user> -p <pass>

# Update secret
kubectl delete secret <name>
kubectl create secret docker-registry <name> ...
```

**3. Secret in wrong namespace**
```bash
# Secrets must be in same namespace as pod
kubectl get secret <name> -n <pod-namespace>
```

**4. Pod not using secret**
```yaml
# Add to pod spec
spec:
  imagePullSecrets:
  - name: <secret-name>
```

**5. ServiceAccount not configured**
```bash
# Add to ServiceAccount
kubectl patch serviceaccount default \
  -p '{"imagePullSecrets": [{"name": "<secret-name>"}]}'
```

---

## 🚨 ISSUE 2: Admission Policy Blocking Valid Images

**Symptoms:**
```
Error from server: admission webhook denied the request
Image validation failed
```

**Diagnosis:**
```bash
# Check Kyverno policies
kubectl get clusterpolicies

# Describe specific policy
kubectl describe clusterpolicy <policy-name>

# Check policy reports
kubectl get policyreports -A

# Test with dry-run
kubectl run test --image=<image> --dry-run=server
```

**Common Causes & Solutions:**

**1. Image not from allowed registry**
```bash
# Check policy
kubectl get clusterpolicy allowed-registries -o yaml

# Solution: Use approved registry
# Change: docker.io/nginx
# To: myregistry.com/nginx
```

**2. Missing image digest**
```bash
# Get image digest
docker pull nginx:1.25
docker inspect nginx:1.25 | jq -r '.[0].RepoDigests[0]'

# Use digest
image: nginx@sha256:4c0fdaa...
```

**3. Using :latest tag**
```bash
# Policy blocks :latest
# Solution: Use specific version
image: nginx:1.25.3
```

**4. Policy too restrictive**
```bash
# Temporarily set to audit mode
kubectl patch clusterpolicy <name> \
  --type=merge \
  -p '{"spec":{"validationFailureAction":"audit"}}'

# Fix images, then re-enable enforce
kubectl patch clusterpolicy <name> \
  --type=merge \
  -p '{"spec":{"validationFailureAction":"enforce"}}'
```

---

## 🚨 ISSUE 3: Image Signature Verification Failed

**Symptoms:**
```
no matching signatures found
signature verification failed
```

**Diagnosis:**
```bash
# Check if image is signed
cosign verify --key cosign.pub <image>

# Check Policy Controller logs
kubectl logs -n cosign-system -l app=policy-controller

# Check ClusterImagePolicy
kubectl describe clusterimagepolicy <policy>
```

**Common Causes & Solutions:**

**1. Image not signed**
```bash
# Sign the image
cosign sign --key cosign.key <image>
```

**2. Wrong public key in policy**
```yaml
# Update ClusterImagePolicy with correct key
kubectl edit clusterimagepolicy <policy>
# Update authorities.key.data field
```

**3. Signature in different registry**
```bash
# Signatures stored with image
# Ensure using same registry URL
```

**4. Expired signature**
```bash
# Re-sign image
cosign sign --key cosign.key <image>
```

---

## 🚨 ISSUE 4: Trivy Scan False Positives

**Symptoms:**
```
Trivy reports vulnerabilities in base image
CVEs that don't apply to your use case
```

**Diagnosis:**
```bash
# Check specific CVE
trivy image <image> | grep <CVE-ID>

# Check if fixed in newer version
trivy image <image>:<newer-tag>

# Check CVE details
trivy image --format json <image> | \
  jq '.Results[].Vulnerabilities[] | select(.VulnerabilityID=="<CVE>")'
```

**Solutions:**

**1. Update base image**
```dockerfile
# FROM alpine:3.15
FROM alpine:3.18  # Latest version
```

**2. Use distroless images**
```dockerfile
FROM gcr.io/distroless/static
# Minimal attack surface
```

**3. Ignore specific vulnerabilities (with justification)**
```yaml
# .trivyignore file
CVE-2022-1234  # False positive - not applicable
```

**4. Accept risk and document**
```bash
# Document in security review
# Track in security dashboard
```

---

## 🚨 ISSUE 5: High Scan Times in CI/CD

**Symptoms:**
```
Trivy scan taking 5+ minutes
CI/CD pipeline timeout
```

**Solutions:**

**1. Use cache**
```bash
# Cache Trivy DB
trivy image --cache-dir /path/to/cache <image>
```

**2. Skip DB update**
```bash
# Use existing DB
trivy image --skip-db-update <image>
```

**3. Parallel scans**
```bash
# Scan multiple images in parallel
cat images.txt | xargs -P 4 -I {} trivy image {}
```

**4. Use Harbor registry scanning**
```
# Let Harbor scan automatically
# Query results via API
```

---

## 📋 Debug Checklist

1. ☑️ ImagePullSecret exists in correct namespace?
2. ☑️ Secret has valid credentials?
3. ☑️ Pod spec references secret?
4. ☑️ Image exists in registry?
5. ☑️ Network connectivity to registry?
6. ☑️ Admission policy allows this image?
7. ☑️ Image signed (if required)?
8. ☑️ Correct public key in policy?
9. ☑️ Image uses digest (not :latest)?
10. ☑️ Registry accessible from cluster?

---

## 🔍 Diagnostic Commands

```bash
# Test registry connectivity
kubectl run test -it --rm --image=busybox -- \
  wget --spider https://myregistry.com

# Test image pull manually
docker pull <image>

# Check Kyverno webhook
kubectl get validatingwebhookconfigurations | grep kyverno

# Check Policy Controller webhook
kubectl get validatingwebhookconfigurations | grep policy.sigstore.dev

# View all admission webhooks
kubectl get validatingwebhookconfigurations
kubectl get mutatingwebhookconfigurations
```
