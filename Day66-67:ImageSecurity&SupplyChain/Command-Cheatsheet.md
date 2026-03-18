# 📋 Command Cheatsheet: Image Security - Day 66-67

## 🔍 Trivy Image Scanning

```bash
# Install Trivy
brew install trivy  # macOS
apt-get install trivy  # Debian/Ubuntu
wget <url> && tar xzf trivy.tar.gz  # Manual

# Basic scan
trivy image nginx:latest

# Scan with severity filter
trivy image --severity HIGH,CRITICAL nginx:latest
trivy image --severity CRITICAL nginx:latest

# Exit code on vulnerabilities (for CI/CD)
trivy image --exit-code 1 --severity CRITICAL nginx:latest

# Generate reports
trivy image -f json -o report.json nginx:latest
trivy image -f table -o report.txt nginx:latest
trivy image -f sarif -o trivy-results.sarif nginx:latest

# Scan local Dockerfile
trivy config Dockerfile

# Scan filesystem
trivy fs /path/to/project

# Scan tarball
docker save nginx:latest -o nginx.tar
trivy image --input nginx.tar

# Quiet mode
trivy image --quiet nginx:latest

# Scan all running images
kubectl get pods -A -o json | \
  jq -r '.items[].spec.containers[].image' | \
  sort -u | \
  xargs -I {} trivy image {}
```

## 🔑 ImagePullSecrets

```bash
# Create Docker registry secret
kubectl create secret docker-registry <name> \
  --docker-server=<registry-url> \
  --docker-username=<username> \
  --docker-password=<password> \
  --docker-email=<email>

# Create from Docker config file
kubectl create secret generic <name> \
  --from-file=.dockerconfigjson=$HOME/.docker/config.json \
  --type=kubernetes.io/dockerconfigjson

# AWS ECR secret
TOKEN=$(aws ecr get-login-password --region us-east-1)
kubectl create secret docker-registry ecr-creds \
  --docker-server=<account-id>.dkr.ecr.us-east-1.amazonaws.com \
  --docker-username=AWS \
  --docker-password=$TOKEN

# GCP GCR secret
kubectl create secret docker-registry gcr-creds \
  --docker-server=gcr.io \
  --docker-username=_json_key \
  --docker-password="$(cat keyfile.json)"

# View secret
kubectl get secret <name> -o yaml
kubectl get secret <name> -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d

# Add to ServiceAccount
kubectl patch serviceaccount <sa-name> \
  -p '{"imagePullSecrets": [{"name": "<secret-name>"}]}'

# Delete secret
kubectl delete secret <name>
```

## 🔏 Cosign (Image Signing)

```bash
# Install Cosign
brew install cosign  # macOS
# OR download from GitHub releases

# Generate key pair
cosign generate-key-pair
# Creates: cosign.key, cosign.pub

# Sign image
cosign sign --key cosign.key <image>

# Verify signature
cosign verify --key cosign.pub <image>

# Keyless signing (OIDC)
cosign sign <image>

# Verify keyless
cosign verify \
  --certificate-identity=<email> \
  --certificate-oidc-issuer=<issuer> \
  <image>

# Attach SBOM
cosign attach sbom --sbom sbom.json <image>

# Verify SBOM
cosign verify-attestation --key cosign.pub <image>

# Download public key from signature
cosign public-key --key cosign.key > cosign.pub
```

## 🛡️ Kyverno Policies

```bash
# Install Kyverno
helm repo add kyverno https://kyverno.github.io/kyverno/
helm install kyverno kyverno/kyverno -n kyverno --create-namespace

# List policies
kubectl get clusterpolicies
kubectl get policies -A

# Describe policy
kubectl describe clusterpolicy <policy-name>

# View policy reports
kubectl get policyreports -A
kubectl describe policyreport <report> -n <namespace>

# Test policy (dry-run)
kubectl run test --image=nginx:latest --dry-run=server

# Delete policy
kubectl delete clusterpolicy <policy-name>
```

## 📊 Image Inventory & Audit

```bash
# List all unique images in cluster
kubectl get pods -A -o json | \
  jq -r '.items[].spec.containers[].image' | sort -u

# Count total images
kubectl get pods -A -o json | \
  jq -r '.items[].spec.containers[].image' | sort -u | wc -l

# Find images using :latest tag
kubectl get pods -A -o json | \
  jq -r '.items[].spec.containers[].image' | grep ':latest'

# Find images without digest
kubectl get pods -A -o json | \
  jq -r '.items[].spec.containers[].image' | grep -v '@sha256'

# List images by namespace
kubectl get pods -n <namespace> -o json | \
  jq -r '.items[].spec.containers[].image' | sort -u

# Find pods using specific registry
kubectl get pods -A -o json | \
  jq -r '.items[] | select(.spec.containers[].image | startswith("docker.io")) | 
    "\(.metadata.namespace)/\(.metadata.name)"'
```

## 🏗️ Harbor Registry

```bash
# Login to Harbor
docker login <harbor-url>

# Tag image for Harbor
docker tag <image> <harbor-url>/<project>/<image>:<tag>

# Push to Harbor
docker push <harbor-url>/<project>/<image>:<tag>

# Pull from Harbor
docker pull <harbor-url>/<project>/<image>:<tag>

# Harbor CLI (if installed)
harbor-cli project list
harbor-cli repository list <project>
```

## 💡 Useful One-Liners

```bash
# Scan and count vulnerabilities
trivy image nginx:latest --format json | \
  jq '.Results[].Vulnerabilities | length'

# Find CRITICAL vulnerabilities only
trivy image nginx:latest --severity CRITICAL --format json | \
  jq -r '.Results[].Vulnerabilities[].VulnerabilityID'

# Update all ImagePullSecrets
kubectl get secret <old-secret> -o yaml | \
  sed 's/name: <old-secret>/name: <new-secret>/' | \
  kubectl apply -f -

# Scan all namespaces for images without secrets
kubectl get pods -A -o json | \
  jq -r '.items[] | select(.spec.imagePullSecrets == null) | 
    "\(.metadata.namespace)/\(.metadata.name)"'

# Export all images to file
kubectl get pods -A -o json | \
  jq -r '.items[].spec.containers[].image' | \
  sort -u > cluster-images.txt
```

## 🔄 CI/CD Integration

```bash
# GitHub Actions Trivy scan
- uses: aquasecurity/trivy-action@master
  with:
    image-ref: 'myimage:tag'
    severity: 'CRITICAL,HIGH'
    exit-code: '1'

# GitLab CI
trivy image --exit-code 1 --severity CRITICAL $IMAGE

# Jenkins
sh 'trivy image --exit-code 1 --severity HIGH,CRITICAL ${IMAGE_NAME}'
```
