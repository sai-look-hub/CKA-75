# 🎤 Interview Q&A: Image Security - Day 66-67

## Q1: What are the main security risks in container images?

**Answer:**

Container images contain multiple layers of potential vulnerabilities:

**1. Base OS vulnerabilities**
```dockerfile
FROM ubuntu:20.04  # May contain outdated packages
```
- Outdated system packages
- Known CVEs in libc, openssl, etc.
- Unpatched security holes

**2. Application dependencies**
```dockerfile
RUN npm install  # May pull vulnerable packages
```
- Log4Shell (CVE-2021-44228) - CVSS 10.0
- Spring4Shell
- Vulnerable npm/pip/maven packages

**3. Embedded secrets**
```dockerfile
ENV API_KEY=abc123  # Hardcoded secret!
COPY .env /app/     # Committed secrets!
```
- Hardcoded passwords
- API keys in environment variables
- Certificates in layers

**4. Supply chain attacks**
- Typosquatting (installing fake packages)
- Compromised base images
- Malicious dependencies

**5. Excessive permissions**
```dockerfile
USER root  # Running as root
```
- Running as UID 0
- Unnecessary capabilities
- Writable filesystems

**Detection methods:**
- **Image scanning**: Trivy, Grype, Snyk
- **SBOM analysis**: Track all components
- **Secret detection**: GitLeaks, TruffleHog

**Mitigation:**
```dockerfile
# Use minimal base
FROM alpine:3.18

# No secrets
# Use K8s Secrets instead

# Non-root user
USER 1000

# Scan before deploy
# trivy image --exit-code 1 --severity CRITICAL
```

---

## Q2: How do you implement image scanning in a CI/CD pipeline?

**Answer:**

**Complete implementation approach:**

**Step 1: Choose scanning tool**
- Trivy (free, fast, accurate)
- Snyk (commercial, dev-friendly)
- Grype (open source, Anchore)

**Step 2: Add to CI/CD**

**GitHub Actions example:**
```yaml
name: Secure Build

on: [push, pull_request]

jobs:
  scan:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    
    - name: Build image
      run: docker build -t app:${{ github.sha }} .
    
    - name: Scan with Trivy
      uses: aquasecurity/trivy-action@master
      with:
        image-ref: app:${{ github.sha }}
        severity: 'CRITICAL,HIGH'
        exit-code: '1'  # Fail pipeline on vulnerabilities
        format: 'sarif'
        output: 'trivy-results.sarif'
    
    - name: Upload to GitHub Security
      uses: github/codeql-action/upload-sarif@v2
      if: always()
      with:
        sarif_file: 'trivy-results.sarif'
    
    - name: Sign image
      run: cosign sign --key ${{ secrets.COSIGN_KEY }} app:${{ github.sha }}
    
    - name: Push image
      run: docker push myregistry.com/app:${{ github.sha }}
```

**Step 3: Define policies**
```
Development:  Block CRITICAL
Staging:      Block CRITICAL, HIGH  
Production:   Block CRITICAL, HIGH, MEDIUM
```

**Step 4: Handle failures**
```yaml
# Option 1: Fail pipeline
exit-code: '1'

# Option 2: Create issue
- name: Create issue
  if: failure()
  uses: actions/create-issue@v2

# Option 3: Alert team
- name: Notify team
  run: slack-notify "Vulnerabilities found!"
```

**Step 5: Regular rescans**
```yaml
# CronJob in cluster
schedule: "0 2 * * *"  # Daily at 2 AM
# Scan all running images
```

**Benefits:**
- Shift left (find early)
- Automated (no human error)
- Consistent enforcement
- Audit trail

---

## Q3: Explain ImagePullSecrets and their use cases.

**Answer:**

**ImagePullSecrets** = Kubernetes credentials for pulling images from private registries.

**Why needed:**
Private registries require authentication. Without credentials, Kubernetes can't pull images.

**Creating:**
```bash
kubectl create secret docker-registry my-secret \
  --docker-server=myregistry.com \
  --docker-username=user \
  --docker-password=pass \
  --docker-email=user@example.com
```

**Three usage methods:**

**1. Direct in Pod (simple but repetitive):**
```yaml
spec:
  imagePullSecrets:
  - name: my-secret
  containers:
  - image: myregistry.com/app:v1.0
```

**2. ServiceAccount (recommended):**
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-sa
imagePullSecrets:
- name: my-secret
---
spec:
  serviceAccountName: app-sa
  # imagePullSecrets inherited automatically
```

**3. Default ServiceAccount:**
```bash
# Add to default SA in namespace
kubectl patch serviceaccount default \
  -p '{"imagePullSecrets": [{"name": "my-secret"}]}'
# All pods in namespace can pull
```

**Use cases:**

**1. Private registries:**
- Harbor (self-hosted)
- AWS ECR
- GCP Artifact Registry
- Azure ACR

**2. Multi-cloud:**
```bash
# Different secret per cloud
aws-secret → ECR images
gcp-secret → GCR images
azure-secret → ACR images
```

**3. Different environments:**
```bash
# Different registries per env
dev-secret → dev-registry.com
prod-secret → prod-registry.com
```

**Best practices:**
- Use ServiceAccount method
- One secret per namespace
- Rotate credentials regularly
- Different secrets per environment

---

## Q4: How do admission controllers enforce image security policies?

**Answer:**

**Admission controllers** intercept K8s API requests BEFORE objects are created, allowing policy enforcement.

**For image security, enforce:**
1. Only signed images
2. Only scanned images
3. Only approved registries
4. Require image digests
5. Block :latest tag

**How it works:**
```
User: kubectl apply -f pod.yaml
   ↓
API Server
   ↓
Admission Webhook (Kyverno/OPA)
   ↓
Check image policies
   ↓
Pass → Create pod
Fail → Reject with error
```

**Implementation tools:**

**1. Kyverno (K8s-native):**
```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-digest
spec:
  validationFailureAction: enforce
  rules:
  - name: check-digest
    match:
      resources:
        kinds: [Pod]
    validate:
      message: "Must use image digest (@sha256:)"
      pattern:
        spec:
          containers:
          - image: "*@sha256:*"
```

**2. OPA Gatekeeper (Rego-based):**
```rego
package kubernetes.admission

deny[msg] {
  input.request.kind.kind == "Pod"
  image := input.request.object.spec.containers[_].image
  not startswith(image, "myregistry.com/")
  msg = "Image not from approved registry"
}
```

**3. Sigstore Policy Controller (image signing):**
```yaml
apiVersion: policy.sigstore.dev/v1beta1
kind: ClusterImagePolicy
spec:
  images:
  - glob: "myregistry.com/**"
  authorities:
  - key:
      data: <public-key>
# Only signed images allowed
```

**Enforcement flow:**
```
1. Developer pushes image
2. CI/CD scans & signs image
3. Push to registry
4. Deploy to K8s
5. Admission controller checks:
   - Registry approved? ✅
   - Image signed? ✅
   - Has digest? ✅
6. Allow deployment
```

**Benefits:**
- Centralized enforcement
- No bypassing
- Audit trail
- Compliance-ready

**Testing:**
```bash
# Dry-run to test policy
kubectl run test --image=nginx:latest --dry-run=server
# Error: Using :latest not allowed
```

---

## Q5: What is image signing and why is it critical for supply chain security?

**Answer:**

**Image signing** = Cryptographically signing container images to prove authenticity and integrity.

**Why critical:**

**Problem without signing:**
```
Attacker pushes malicious image → Same name/tag → Deployed to prod → Breach
```

**With signing:**
```
Only signed images from trusted CI/CD → Cryptographically verified → Deployment succeeds
Unsigned/tampered images → Verification fails → Deployment blocked ✅
```

**How signing works (Cosign):**

**1. Generate keys:**
```bash
cosign generate-key-pair
# Creates: cosign.key (private), cosign.pub (public)
```

**2. Sign image:**
```bash
cosign sign --key cosign.key myregistry.com/app:v1.0
# Creates cryptographic signature
# Signature stored in registry
```

**3. Verify image:**
```bash
cosign verify --key cosign.pub myregistry.com/app:v1.0
# Checks signature is valid
# Verifies image not tampered
```

**What's signed:**
- Image digest (SHA256)
- Image manifest
- Metadata (who, when, where built)

**Enforcement in Kubernetes:**
```yaml
apiVersion: policy.sigstore.dev/v1beta1
kind: ClusterImagePolicy
spec:
  images:
  - glob: "myregistry.com/**"
  authorities:
  - key:
      data: <public-key-pem>
```

**Result:**
```bash
# Unsigned image
kubectl run bad --image=myregistry.com/unsigned:v1.0
# Error: no matching signatures ❌

# Signed image
kubectl run good --image=myregistry.com/signed:v1.0
# Pod created ✅
```

**Keyless signing (modern approach):**
```bash
# No key management!
cosign sign myregistry.com/app:v1.0
# Uses OIDC identity (GitHub, Google)
# Certificate transparency log

cosign verify \
  --certificate-identity=user@company.com \
  --certificate-oidc-issuer=https://github.com/login/oauth \
  myregistry.com/app:v1.0
```

**Supply chain benefits:**
1. **Provenance**: Know who built it
2. **Integrity**: Detect tampering
3. **Non-repudiation**: Can't deny signing
4. **Compliance**: Audit trail
5. **Trust chain**: From code to production

**Best practice:**
```
Code → CI/CD → Build → Scan → Sign → Push → Verify → Deploy
         ↑                      ↑                ↑
     Automated              Automated      Enforced
```

This creates unbreakable trust chain from source to deployment.
