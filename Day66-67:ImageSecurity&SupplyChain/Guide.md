# 📖 GUIDEME: Image Security - Day 66-67

## 🎯 16-Hour Learning Path

**Day 1:** Image scanning, private registries (8 hours)  
**Day 2:** Admission control, signing, CI/CD (8 hours)

---

## Phase 1: Image Scanning with Trivy (2 hours)

### Install Trivy
```bash
# Install Trivy
wget https://github.com/aquasecurity/trivy/releases/download/v0.48.0/trivy_0.48.0_Linux-64bit.tar.gz
tar zxvf trivy_0.48.0_Linux-64bit.tar.gz
sudo mv trivy /usr/local/bin/

# Verify installation
trivy --version
```

### Scan Images
```bash
# Scan public image
trivy image nginx:latest

# Count vulnerabilities
trivy image nginx:latest | grep "Total:"

# Scan with severity filter
trivy image --severity CRITICAL,HIGH nginx:latest

# Exit code 1 on vulnerabilities
trivy image --exit-code 1 --severity CRITICAL nginx:1.20

# Generate JSON report
trivy image -f json -o nginx-scan.json nginx:latest
cat nginx-scan.json | jq '.Results[].Vulnerabilities | length'

# Scan local Docker image
docker build -t myapp:test .
trivy image myapp:test
```

**✅ Checkpoint:** Trivy installed, images scanned.

---

## Phase 2: Harbor Private Registry (3 hours)

### Install Harbor
```bash
# Download Harbor
wget https://github.com/goharbor/harbor/releases/download/v2.9.0/harbor-offline-installer-v2.9.0.tgz
tar xzvf harbor-offline-installer-v2.9.0.tgz
cd harbor

# Configure
cp harbor.yml.tmpl harbor.yml
# Edit harbor.yml:
# - hostname: harbor.local
# - harbor_admin_password: Harbor12345

# Install with Trivy
sudo ./install.sh --with-trivy

# Verify
docker ps | grep harbor
```

### Push Images to Harbor
```bash
# Add harbor.local to /etc/hosts
echo "127.0.0.1 harbor.local" | sudo tee -a /etc/hosts

# Login
docker login harbor.local
# Username: admin
# Password: Harbor12345

# Tag image
docker tag nginx:latest harbor.local/library/nginx:v1.0

# Push
docker push harbor.local/library/nginx:v1.0

# Scan in Harbor UI
# Open: https://harbor.local
# Navigate: Projects → library → nginx:v1.0 → Scan
```

**✅ Checkpoint:** Harbor running, images pushed and scanned.

---

## Phase 3: ImagePullSecrets (2 hours)

### Create Secrets
```bash
# Create Docker registry secret
kubectl create secret docker-registry harbor-creds \
  --docker-server=harbor.local \
  --docker-username=admin \
  --docker-password=Harbor12345 \
  --docker-email=admin@example.com

# Verify
kubectl get secret harbor-creds
kubectl get secret harbor-creds -o yaml

# Decode to see data
kubectl get secret harbor-creds -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d | jq
```

### Use in Pods
```bash
# Method 1: Direct in Pod
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: private-nginx
spec:
  imagePullSecrets:
  - name: harbor-creds
  containers:
  - name: nginx
    image: harbor.local/library/nginx:v1.0
EOF

kubectl get pod private-nginx
kubectl describe pod private-nginx
```

### Method 2: ServiceAccount
```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: harbor-sa
imagePullSecrets:
- name: harbor-creds
---
apiVersion: v1
kind: Pod
metadata:
  name: sa-nginx
spec:
  serviceAccountName: harbor-sa
  containers:
  - name: nginx
    image: harbor.local/library/nginx:v1.0
EOF

kubectl get pod sa-nginx
# Secret automatically used!
```

**✅ Checkpoint:** ImagePullSecrets working.

---

## Phase 4: Admission Control with Kyverno (3 hours)

### Install Kyverno
```bash
# Install via Helm
helm repo add kyverno https://kyverno.github.io/kyverno/
helm install kyverno kyverno/kyverno -n kyverno --create-namespace

# Verify
kubectl get pods -n kyverno
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=kyverno -n kyverno --timeout=300s
```

### Policy 1: Allowed Registries
```bash
kubectl apply -f - <<EOF
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: allowed-registries
spec:
  validationFailureAction: enforce
  background: false
  rules:
  - name: check-registry
    match:
      any:
      - resources:
          kinds:
          - Pod
    validate:
      message: "Images must be from harbor.local or gcr.io"
      pattern:
        spec:
          containers:
          - image: "harbor.local/* | gcr.io/*"
EOF

# Test - should FAIL
kubectl run test-bad --image=nginx:latest
# Error: Images must be from harbor.local or gcr.io

# Test - should SUCCEED  
kubectl run test-good --image=harbor.local/library/nginx:v1.0
# Pod created

kubectl delete pod test-good
```

### Policy 2: Require Image Digest
```bash
kubectl apply -f - <<EOF
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-digest
spec:
  validationFailureAction: enforce
  rules:
  - name: check-digest
    match:
      any:
      - resources:
          kinds:
          - Pod
    validate:
      message: "Images must use digest (@sha256:)"
      pattern:
        spec:
          containers:
          - image: "*@sha256:*"
EOF

# Test
kubectl run test-no-digest --image=nginx:latest
# Error: Images must use digest

kubectl run test-digest --image=nginx@sha256:4c0fdaa8b6341bfdeca5f18f7837462c80cff90527ee35ef185571e1c327beac
# Success

kubectl delete pod test-digest
```

### Policy 3: Block :latest Tag
```bash
kubectl apply -f - <<EOF
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: disallow-latest
spec:
  validationFailureAction: enforce
  rules:
  - name: no-latest
    match:
      any:
      - resources:
          kinds:
          - Pod
    validate:
      message: "Using :latest tag is not allowed"
      pattern:
        spec:
          containers:
          - image: "!*:latest"
EOF

# Test
kubectl run test-latest --image=nginx:latest
# Error: Using :latest tag is not allowed
```

**✅ Checkpoint:** Admission policies enforcing.

---

## Phase 5: Image Signing with Cosign (3 hours)

### Install Cosign
```bash
# Download Cosign
wget https://github.com/sigstore/cosign/releases/download/v2.2.0/cosign-linux-amd64
chmod +x cosign-linux-amd64
sudo mv cosign-linux-amd64 /usr/local/bin/cosign

# Verify
cosign version
```

### Generate Keys and Sign
```bash
# Generate key pair
cosign generate-key-pair
# Enter password (remember it!)
# Creates: cosign.key, cosign.pub

# Build test image
docker build -t harbor.local/library/signed-app:v1.0 -<<EOF
FROM alpine:3.18
CMD ["echo", "Hello from signed image"]
EOF

# Push image
docker push harbor.local/library/signed-app:v1.0

# Sign image
cosign sign --key cosign.key harbor.local/library/signed-app:v1.0
# Enter password

# Verify signature
cosign verify --key cosign.pub harbor.local/library/signed-app:v1.0
# Shows signature verification ✅
```

### Install Policy Controller
```bash
# Install Sigstore Policy Controller
kubectl apply -f https://github.com/sigstore/policy-controller/releases/download/v0.8.0/release.yaml

# Wait for ready
kubectl wait --for=condition=ready pod -l app=policy-controller -n cosign-system --timeout=300s
```

### Create Signature Policy
```bash
# Create policy requiring signatures
kubectl apply -f - <<EOF
apiVersion: policy.sigstore.dev/v1beta1
kind: ClusterImagePolicy
metadata:
  name: require-signature
spec:
  images:
  - glob: "harbor.local/**"
  authorities:
  - key:
      data: |
$(cat cosign.pub | sed 's/^/        /')
EOF

# Test unsigned image (should FAIL)
kubectl run unsigned --image=harbor.local/library/nginx:v1.0
# Error: no matching signatures

# Test signed image (should SUCCEED)
kubectl run signed --image=harbor.local/library/signed-app:v1.0
# Pod created

kubectl delete pod signed
```

**✅ Checkpoint:** Image signing working.

---

## Phase 6: CI/CD Pipeline (3 hours)

### GitHub Actions Workflow
```bash
mkdir -p .github/workflows
cat > .github/workflows/image-security.yaml <<'EOF'
name: Secure Image Pipeline

on:
  push:
    branches: [main]
  pull_request:

jobs:
  build-scan-sign:
    runs-on: ubuntu-latest
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v3
    
    - name: Set up Docker Buildx
      uses: docker/setup-buildx-action@v2
    
    - name: Build image
      uses: docker/build-push-action@v4
      with:
        context: .
        load: true
        tags: ${{ github.repository }}:${{ github.sha }}
    
    - name: Run Trivy scan
      uses: aquasecurity/trivy-action@master
      with:
        image-ref: ${{ github.repository }}:${{ github.sha }}
        format: 'sarif'
        output: 'trivy-results.sarif'
        severity: 'CRITICAL,HIGH'
        exit-code: '1'
    
    - name: Upload Trivy results to GitHub Security
      uses: github/codeql-action/upload-sarif@v2
      if: always()
      with:
        sarif_file: 'trivy-results.sarif'
    
    - name: Install Cosign
      uses: sigstore/cosign-installer@v3
    
    - name: Sign image
      run: |
        cosign sign --key env://COSIGN_KEY \
          ${{ github.repository }}:${{ github.sha }}
      env:
        COSIGN_KEY: ${{ secrets.COSIGN_PRIVATE_KEY }}
        COSIGN_PASSWORD: ${{ secrets.COSIGN_PASSWORD }}
    
    - name: Login to Harbor
      uses: docker/login-action@v2
      with:
        registry: harbor.local
        username: ${{ secrets.HARBOR_USERNAME }}
        password: ${{ secrets.HARBOR_PASSWORD }}
    
    - name: Push image
      run: |
        docker tag ${{ github.repository }}:${{ github.sha }} \
          harbor.local/library/${{ github.event.repository.name }}:${{ github.sha }}
        docker push harbor.local/library/${{ github.event.repository.name }}:${{ github.sha }}
EOF
```

**✅ Checkpoint:** CI/CD pipeline configured.

---

## ✅ Final Validation

### Security Checklist
- [ ] Trivy installed and scanning
- [ ] Harbor private registry running
- [ ] Images pushed to Harbor
- [ ] ImagePullSecrets created
- [ ] Kyverno policies blocking unapproved images
- [ ] Cosign installed and keys generated
- [ ] Images signed with Cosign
- [ ] Policy Controller verifying signatures
- [ ] CI/CD pipeline with security checks

### Test Complete Pipeline
```bash
# 1. Build image
docker build -t test-app:v1.0 .

# 2. Scan
trivy image --severity CRITICAL,HIGH test-app:v1.0

# 3. Sign
cosign sign --key cosign.key test-app:v1.0

# 4. Push to registry
docker tag test-app:v1.0 harbor.local/library/test-app:v1.0
docker push harbor.local/library/test-app:v1.0

# 5. Deploy (should succeed if signed)
kubectl run test --image=harbor.local/library/test-app:v1.0

# Verify running
kubectl get pod test
```

---

**Congratulations! You've mastered Image Security! 🔒🚀**
