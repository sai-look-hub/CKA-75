# Day 66-67: Image Security & Supply Chain

## 📋 Overview

Welcome to Day 66-67! Master Container Image Security and Supply Chain - learn image scanning, vulnerability management, private registries, and build secure CI/CD pipelines that prevent vulnerable containers from reaching production.

### What You'll Learn

- Container image vulnerabilities
- Image scanning (Trivy, Grype, Clair)
- Private container registries
- ImagePullSecrets
- Admission controllers for images
- Supply chain security
- Image signing (Cosign)
- Secure CI/CD pipelines

---

## 🎯 Learning Objectives

1. Understand container image security risks
2. Scan images for vulnerabilities
3. Configure private registries
4. Use ImagePullSecrets
5. Implement admission control
6. Sign and verify images
7. Build secure CI/CD pipelines
8. Manage supply chain security

---

## 🔍 Container Image Security Risks

### The Problem

```
Container Image Layers:
├── Base OS (Ubuntu/Alpine)
├── System Packages
├── Application Dependencies
└── Your Code

Each layer = Potential vulnerabilities!
```

**Common vulnerabilities:**
- Outdated base images
- Known CVEs in packages
- Malicious dependencies
- Embedded secrets
- Supply chain attacks

### Real Impact: Log4Shell

**CVE-2021-44228:**
- CVSS: 10.0 (CRITICAL)
- Affected: Millions of Java apps
- Impact: Remote code execution

**Without scanning:** Unknown until exploited  
**With scanning:** Detected before deployment ✅

---

## 🔎 Image Scanning Tools

### Popular Options

**1. Trivy (Aqua Security)**
- Free & open source
- Fast and accurate
- Easy to use
- Best for Kubernetes

**2. Grype (Anchore)**
- Open source
- Multiple vulnerability sources
- CLI friendly

**3. Snyk**
- Commercial
- Developer-friendly
- Fix suggestions
- CI/CD integration

**4. Harbor**
- Registry + scanning
- Integrated solution
- Project-based access

---

### Trivy Quick Start

```bash
# Install
brew install trivy  # macOS
apt install trivy   # Ubuntu

# Scan image
trivy image nginx:latest

# Output:
nginx:latest (debian 11.6)
Total: 147 (CRITICAL: 12, HIGH: 45, MEDIUM: 68, LOW: 22)

┌──────────┬──────────────┬──────────┬───────────┐
│ Library  │ CVE          │ Severity │ Version   │
├──────────┼──────────────┼──────────┼───────────┤
│ openssl  │ CVE-2022-360│ HIGH     │ 1.1.1n-0  │
│ curl     │ CVE-2022-351│ CRITICAL │ 7.74.0-1  │
└──────────┴──────────────┴──────────┴───────────┘

# Fail on CRITICAL/HIGH
trivy image --exit-code 1 --severity CRITICAL,HIGH nginx:latest

# JSON report
trivy image -f json -o report.json nginx:latest
```

---

## 📊 Vulnerability Severity (CVSS)

| Severity | Score | Action Required |
|----------|-------|-----------------|
| CRITICAL | 9.0-10.0 | Fix immediately |
| HIGH | 7.0-8.9 | Fix within 7 days |
| MEDIUM | 4.0-6.9 | Fix within 30 days |
| LOW | 0.1-3.9 | Fix when convenient |

### Policy Examples

**Development:**
- Block: CRITICAL
- Warn: HIGH
- Allow: MEDIUM, LOW

**Production:**
- Block: CRITICAL, HIGH, MEDIUM
- Allow: LOW (with approval)

---

## 🏗️ Private Container Registries

### Why Private Registries?

**Docker Hub issues:**
- ❌ Rate limits (100 pulls/6h)
- ❌ Public by default
- ❌ No organizational control
- ❌ Limited scanning

**Private registry benefits:**
- ✅ No rate limits
- ✅ Access control (RBAC)
- ✅ Integrated scanning
- ✅ Compliance-ready
- ✅ Audit trails

### Popular Options

**1. Harbor (CNCF)**
- Free & open source
- Built-in Trivy scanning
- RBAC & replication
- Best self-hosted option

**2. AWS ECR**
- Native AWS integration
- IAM-based access
- Integrated scanning
- Pay per GB storage

**3. Google Artifact Registry**
- Native GCP integration
- Vulnerability scanning
- Maven/npm/Docker support

**4. Azure ACR**
- Native Azure integration
- Geo-replication
- Content trust

---

## 🔑 ImagePullSecrets

### What Are They?

**Purpose:** Kubernetes credentials for pulling from private registries.

**Without ImagePullSecret:**
```yaml
spec:
  containers:
  - image: private-registry.com/app:v1.0
# Error: 401 Unauthorized
```

**With ImagePullSecret:**
```yaml
spec:
  imagePullSecrets:
  - name: registry-creds
  containers:
  - image: private-registry.com/app:v1.0
# Success! ✅
```

### Creating Secrets

**Docker registry:**
```bash
kubectl create secret docker-registry registry-creds \
  --docker-server=private-registry.com \
  --docker-username=myuser \
  --docker-password=mypass \
  --docker-email=user@example.com
```

**AWS ECR:**
```bash
TOKEN=$(aws ecr get-login-password --region us-east-1)

kubectl create secret docker-registry ecr-creds \
  --docker-server=123456789.dkr.ecr.us-east-1.amazonaws.com \
  --docker-username=AWS \
  --docker-password=$TOKEN
```

**GCP GCR:**
```bash
kubectl create secret docker-registry gcr-creds \
  --docker-server=gcr.io \
  --docker-username=_json_key \
  --docker-password="$(cat keyfile.json)"
```

### Using ImagePullSecrets

**Method 1: Per Pod**
```yaml
spec:
  imagePullSecrets:
  - name: registry-creds
```

**Method 2: ServiceAccount (Recommended)**
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-sa
imagePullSecrets:
- name: registry-creds
---
spec:
  serviceAccountName: app-sa
  # imagePullSecrets inherited automatically!
```

---

## 🛡️ Admission Controllers

### Policy Enforcement

**Block deployments if:**
- Image not signed
- Image has CRITICAL vulnerabilities
- Image not from approved registry
- Image uses :latest tag
- Image without digest

### Tools

**1. Kyverno**
```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: allowed-registries
spec:
  validationFailureAction: enforce
  rules:
  - name: check-registry
    validate:
      message: "Only approved registries allowed"
      pattern:
        spec:
          containers:
          - image: "myregistry.com/* | gcr.io/myproject/*"
```

**2. OPA Gatekeeper**
```yaml
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sAllowedRepos
spec:
  parameters:
    repos:
    - "myregistry.com"
    - "gcr.io/myproject"
```

**3. Sigstore Policy Controller**
```yaml
apiVersion: policy.sigstore.dev/v1beta1
kind: ClusterImagePolicy
spec:
  images:
  - glob: "myregistry.com/**"
  authorities:
  - key:
      data: <public-key>
```

---

## 🔏 Image Signing (Cosign)

### Why Sign Images?

**Without signing:**
- ❌ Anyone can push images
- ❌ No authenticity guarantee
- ❌ Supply chain attacks possible

**With signing:**
- ✅ Cryptographic verification
- ✅ Verify who built it
- ✅ Detect tampering
- ✅ Trust chain

### Using Cosign

**Install:**
```bash
# macOS
brew install cosign

# Linux
wget https://github.com/sigstore/cosign/releases/download/v2.2.0/cosign-linux-amd64
chmod +x cosign-linux-amd64
sudo mv cosign-linux-amd64 /usr/local/bin/cosign
```

**Generate keys:**
```bash
cosign generate-key-pair
# Creates: cosign.key, cosign.pub
```

**Sign image:**
```bash
cosign sign --key cosign.key myregistry.com/app:v1.0
```

**Verify:**
```bash
cosign verify --key cosign.pub myregistry.com/app:v1.0
```

**Keyless signing (OIDC):**
```bash
# No key management needed!
cosign sign myregistry.com/app:v1.0
# Uses your GitHub/Google identity

cosign verify \
  --certificate-identity=user@example.com \
  --certificate-oidc-issuer=https://github.com/login/oauth \
  myregistry.com/app:v1.0
```

---

## 🔄 Secure CI/CD Pipeline

### Complete Flow

```
1. Code Commit
   ↓
2. Build Image
   ↓
3. Scan Image (Trivy)
   ↓
4. Block if CRITICAL/HIGH
   ↓
5. Sign Image (Cosign)
   ↓
6. Push to Registry
   ↓
7. Deploy to K8s
   ↓
8. Admission Control Verifies
   ↓
9. Pod Runs ✅
```

### GitHub Actions Example

```yaml
name: Secure Build Pipeline

on:
  push:
    branches: [main]

jobs:
  build-scan-deploy:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    
    - name: Build image
      run: docker build -t myapp:${{ github.sha }} .
    
    - name: Scan with Trivy
      uses: aquasecurity/trivy-action@master
      with:
        image-ref: myapp:${{ github.sha }}
        severity: 'CRITICAL,HIGH'
        exit-code: '1'  # Fail on vulnerabilities
    
    - name: Sign image
      run: |
        cosign sign --key ${{ secrets.COSIGN_KEY }} \
          myregistry.com/myapp:${{ github.sha }}
    
    - name: Push image
      run: docker push myregistry.com/myapp:${{ github.sha }}
```

---

## 📋 Best Practices

### 1. Minimal Base Images

```dockerfile
# ❌ BAD: Full OS (large attack surface)
FROM ubuntu:latest

# ✅ GOOD: Minimal base
FROM alpine:3.18

# ✅ BETTER: Distroless
FROM gcr.io/distroless/static

# ✅ BEST: Scratch + static binary
FROM scratch
COPY myapp /
ENTRYPOINT ["/myapp"]
```

### 2. Specific Tags

```yaml
# ❌ DON'T
image: nginx:latest

# ✅ DO
image: nginx:1.25.3

# ✅ BETTER
image: nginx@sha256:4c0fdaa8b6341bfdeca5f18f7837462c80cff90527ee35ef185571e1c327beac
```

### 3. Scan Everywhere

- **Local:** Developer machine
- **CI/CD:** Every build
- **Registry:** Periodic rescans
- **Runtime:** Admission control

### 4. Regular Updates

```bash
# Scan all running images
kubectl get pods -A -o json | \
  jq -r '.items[].spec.containers[].image' | \
  sort -u | \
  xargs -I {} trivy image {}
```

### 5. Never Hardcode Secrets

```dockerfile
# ❌ NEVER DO THIS
ENV DATABASE_PASSWORD=secret123
ENV API_KEY=abc123def456

# ✅ Use Kubernetes Secrets
# ✅ Use External Secret Managers
```

---

## 📖 Key Takeaways

✅ Scan all images before deployment  
✅ Use private registries for production  
✅ ImagePullSecrets for authentication  
✅ Admission controllers enforce policies  
✅ Sign images for authenticity  
✅ Minimal base images reduce risk  
✅ Use specific tags/digests  
✅ Automate scanning in CI/CD  
✅ Regular rescans for new CVEs  
✅ Never hardcode secrets  

---

## 🔗 Resources

- [Trivy](https://aquasecurity.github.io/trivy/)
- [Harbor](https://goharbor.io/)
- [Cosign](https://docs.sigstore.dev/cosign/overview/)
- [Kyverno](https://kyverno.io/)

---

## 🚀 Next Steps

1. Complete GUIDEME.md exercises
2. Scan your current images
3. Set up private registry
4. Configure ImagePullSecrets
5. Implement CI/CD scanning
6. Deploy admission controller
7. Sign and verify images

**Happy Securing! 🔒**
