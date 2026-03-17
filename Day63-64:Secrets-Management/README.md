# Day 63-64: Secrets Management

## 📋 Overview

Welcome to Day 63-64! Today we master Secrets Management in Kubernetes - learning encryption at rest, external secret managers, Sealed Secrets, and best practices for handling sensitive data. You'll build a production-grade secrets management solution that never exposes credentials.

### What You'll Learn

- Kubernetes Secrets fundamentals
- Encryption at rest
- External Secret Managers (Vault, AWS Secrets Manager)
- Sealed Secrets for GitOps
- Secret rotation strategies
- Best practices for production
- Common pitfalls and solutions

---

## 🎯 Learning Objectives

By the end of this module, you will be able to:

1. Understand Kubernetes Secrets limitations
2. Enable encryption at rest
3. Integrate external secret managers
4. Use Sealed Secrets for Git storage
5. Implement secret rotation
6. Avoid common security mistakes
7. Build production-ready secrets management
8. Audit secrets access

---

## 🔐 Kubernetes Secrets Fundamentals

### What are Secrets?

**Definition:** Kubernetes objects for storing sensitive data (passwords, tokens, keys).

**Storage:** Base64-encoded in etcd (NOT encrypted by default!)

---

### The Problem with Default Secrets

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: database-credentials
type: Opaque
data:
  username: YWRtaW4=  # base64("admin")
  password: cGFzc3dvcmQxMjM=  # base64("password123")
```

**Issues:**
1. ❌ Base64 is NOT encryption (easily decoded)
2. ❌ Stored in plaintext in etcd
3. ❌ Visible in Git if committed
4. ❌ Accessible to anyone with API access
5. ❌ No automatic rotation
6. ❌ No audit trail

---

### Base64 is NOT Security

```bash
# "Encrypted" secret
echo "YWRtaW4=" | base64 -d
# Output: admin

# Anyone can decode!
kubectl get secret database-credentials -o jsonpath='{.data.password}' | base64 -d
# Output: password123
```

**Base64 = Encoding, NOT Encryption!**

---

## 🔒 Encryption at Rest

### What is Encryption at Rest?

**Definition:** Encrypting data stored in etcd using encryption keys.

**Architecture:**
```
Secret Created
    ↓
API Server
    ↓
Encryption Provider (KMS/AES)
    ↓
Encrypted Data
    ↓
etcd (encrypted)
```

---

### Encryption Providers

**1. Identity (default)**
- No encryption
- Plaintext in etcd
- ❌ NOT secure

**2. AES-CBC**
- Encryption with AES
- Key stored on API server
- ✅ Better than plaintext
- ⚠️ Key management required

**3. AES-GCM**
- AES with authentication
- Stronger than AES-CBC
- ✅ Recommended

**4. KMS (Key Management Service)**
- External key management
- AWS KMS, GCP KMS, Azure Key Vault
- ✅ Best for production
- ✅ Automatic key rotation

---

### Encryption Configuration

**EncryptionConfiguration:**
```yaml
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
- resources:
  - secrets
  providers:
  - aescbc:
      keys:
      - name: key1
        secret: <BASE64_ENCODED_32_BYTE_KEY>
  - identity: {}  # Fallback for reading old data
```

**Apply:**
```bash
# Pass to kube-apiserver
--encryption-provider-config=/path/to/encryption-config.yaml
```

---

### KMS Encryption (Best Practice)

**AWS KMS example:**
```yaml
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
- resources:
  - secrets
  providers:
  - kms:
      name: aws-encryption-provider
      endpoint: unix:///var/run/kmsplugin/socket.sock
      cachesize: 1000
      timeout: 3s
  - identity: {}
```

**Benefits:**
- ✅ Keys never leave KMS
- ✅ Automatic rotation
- ✅ Audit logging
- ✅ Compliance ready

---

## 🗝️ External Secret Managers

### Why External Secret Managers?

**Problems with K8s Secrets:**
1. Manual creation
2. No rotation
3. Limited audit
4. Git storage issues

**External Secret Managers:**
1. ✅ Centralized secret storage
2. ✅ Automatic rotation
3. ✅ Audit trails
4. ✅ Access control
5. ✅ Never in Git

---

### Popular Secret Managers

**1. HashiCorp Vault**
- Most popular for K8s
- Dynamic secrets
- Encryption as a service
- Multi-cloud

**2. AWS Secrets Manager**
- Native AWS integration
- Automatic rotation
- KMS integration

**3. Azure Key Vault**
- Native Azure integration
- RBAC integration

**4. GCP Secret Manager**
- Native GCP integration
- Versioning

---

### External Secrets Operator

**Architecture:**
```
┌─────────────────────────────────────┐
│  External Secrets Operator          │
├─────────────────────────────────────┤
│                                      │
│  1. SecretStore (connection config) │
│     ↓                                │
│  2. ExternalSecret (reference)      │
│     ↓                                │
│  3. Operator syncs →                │
│     ↓                                │
│  4. K8s Secret created              │
│                                      │
│  External:                          │
│  Vault / AWS / Azure / GCP          │
└─────────────────────────────────────┘
```

---

### External Secrets Example

**1. SecretStore (AWS Secrets Manager):**
```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: aws-secretstore
  namespace: production
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-east-1
      auth:
        jwt:
          serviceAccountRef:
            name: external-secrets-sa
```

**2. ExternalSecret:**
```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: database-credentials
  namespace: production
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secretstore
    kind: SecretStore
  target:
    name: database-credentials
    creationPolicy: Owner
  data:
  - secretKey: username
    remoteRef:
      key: prod/database
      property: username
  - secretKey: password
    remoteRef:
      key: prod/database
      property: password
```

**3. Result:**
```yaml
# Automatically created K8s Secret
apiVersion: v1
kind: Secret
metadata:
  name: database-credentials
data:
  username: <from AWS>
  password: <from AWS>
```

**Benefits:**
- ✅ Secret never in Git
- ✅ Synced from AWS
- ✅ Automatic refresh
- ✅ Rotation handled externally

---

## 🔏 Sealed Secrets

### The GitOps Problem

**Problem:**
```
Want: Store everything in Git
Issue: Secrets are sensitive!

❌ Can't commit Secrets to Git
❌ Manual secret creation breaks GitOps
❌ Chicken and egg problem
```

**Solution:** Sealed Secrets

---

### What are Sealed Secrets?

**Concept:** Encrypted Secrets that are safe for Git.

**How it works:**
```
1. SealedSecret (encrypted) → Git ✅
2. Sealed Secrets Controller → Decrypts
3. K8s Secret (decrypted) → Created
```

**Architecture:**
```
Developer
    ↓
kubeseal CLI (encrypts Secret)
    ↓
SealedSecret (encrypted YAML)
    ↓
Git ✅ (safe to commit)
    ↓
Applied to cluster
    ↓
Sealed Secrets Controller (decrypts)
    ↓
K8s Secret (created)
```

---

### Sealed Secrets Example

**1. Install Sealed Secrets Controller:**
```bash
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml
```

**2. Create regular Secret:**
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: database-credentials
  namespace: production
stringData:
  username: admin
  password: password123
```

**3. Seal it:**
```bash
kubeseal -f secret.yaml -w sealed-secret.yaml

# OR pipe:
cat secret.yaml | kubeseal > sealed-secret.yaml
```

**4. Sealed Secret (safe for Git):**
```yaml
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: database-credentials
  namespace: production
spec:
  encryptedData:
    username: AgBj8v7... (encrypted!)
    password: AgCW9qk... (encrypted!)
  template:
    metadata:
      name: database-credentials
```

**5. Commit to Git:**
```bash
git add sealed-secret.yaml
git commit -m "Add database credentials (sealed)"
git push
```

**6. Apply to cluster:**
```bash
kubectl apply -f sealed-secret.yaml

# Controller automatically creates Secret
kubectl get secret database-credentials
```

**Benefits:**
- ✅ Safe to commit to Git
- ✅ GitOps friendly
- ✅ Only cluster can decrypt
- ✅ No manual secret creation

---

### Sealed Secrets Scopes

**1. strict (default)**
- Tied to namespace and name
- Can't rename or move

**2. namespace-wide**
- Any name in same namespace
```bash
kubeseal --scope namespace-wide
```

**3. cluster-wide**
- Any namespace, any name
```bash
kubeseal --scope cluster-wide
```

---

## 🔄 Secret Rotation

### Why Rotate Secrets?

**Reasons:**
1. Compromised credentials
2. Employee departure
3. Compliance requirements
4. Best practice (periodic rotation)

---

### Rotation Strategies

**1. Manual Rotation**
```bash
# Update secret
kubectl create secret generic db-pass \
  --from-literal=password=newpassword123 \
  --dry-run=client -o yaml | kubectl apply -f -

# Restart pods
kubectl rollout restart deployment app
```

**2. External Secret Manager (Automatic)**
- Rotate in Vault/AWS
- External Secrets Operator syncs
- Pods detect change and reload

**3. Reloader/Stakater**
- Watches Secret changes
- Automatically restarts pods
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  annotations:
    reloader.stakater.com/auto: "true"
```

---

## 🎯 Best Practices

### 1. Never Commit Secrets to Git

```bash
# ❌ NEVER DO THIS
git add secret.yaml
git commit -m "Add database password"

# ✅ Use Sealed Secrets or External Secrets
git add sealed-secret.yaml  # Safe!
```

---

### 2. Use RBAC to Limit Access

```yaml
# Only specific ServiceAccount can read
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: secret-reader
rules:
- apiGroups: [""]
  resources: ["secrets"]
  resourceNames: ["database-credentials"]
  verbs: ["get"]
```

---

### 3. Enable Encryption at Rest

**Minimum: AES-GCM**
**Best: KMS encryption**

---

### 4. Use External Secret Managers

**Production recommendation:**
- Vault for multi-cloud
- AWS Secrets Manager for AWS
- Azure Key Vault for Azure
- GCP Secret Manager for GCP

---

### 5. Rotate Regularly

**Recommended:**
- Critical secrets: 30 days
- Database passwords: 90 days
- API keys: 90 days
- Certificates: Before expiry

---

### 6. Audit Secret Access

```bash
# Enable audit logging
--audit-log-path=/var/log/audit.log
--audit-policy-file=/etc/kubernetes/audit-policy.yaml
```

**Audit policy:**
```yaml
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
- level: Metadata
  resources:
  - group: ""
    resources: ["secrets"]
```

---

### 7. Least Privilege

**Principle:** Grant minimum necessary access.

```yaml
# ❌ DON'T: Give access to all secrets
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["*"]

# ✅ DO: Specific secrets only
rules:
- apiGroups: [""]
  resources: ["secrets"]
  resourceNames: ["app-credentials"]
  verbs: ["get"]
```

---

## 📊 Comparison: Secret Management Solutions

| Feature | K8s Secrets | Sealed Secrets | External Secrets | Vault |
|---------|-------------|----------------|------------------|--------|
| Encryption at rest | Optional | ✅ | Via external | ✅ |
| Safe for Git | ❌ | ✅ | Config only | Config only |
| Auto rotation | ❌ | ❌ | ✅ | ✅ |
| Audit trail | Limited | Limited | Via external | ✅ Full |
| Dynamic secrets | ❌ | ❌ | ✅ | ✅ |
| Complexity | Low | Low | Medium | High |
| Best for | Development | GitOps | Production | Enterprise |

---

## 🚨 Common Mistakes

### 1. Base64 != Encryption

```bash
# This is NOT secure!
echo -n "password123" | base64
# YXBhc3N3b3JkMTIz

# Anyone can decode:
echo "YXBhc3N3b3JkMTIz" | base64 -d
# password123
```

---

### 2. Secrets in Environment Variables

```yaml
# ❌ Visible in process list
env:
- name: DB_PASSWORD
  value: "password123"

# ✅ Use Secret reference
env:
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: database-credentials
      key: password
```

---

### 3. Logging Secrets

```python
# ❌ DON'T
print(f"Password: {os.environ['DB_PASSWORD']}")

# ✅ DO
print("Connecting to database...")
```

---

### 4. No Encryption at Rest

**Default:** Secrets stored plaintext in etcd

**Solution:** Enable encryption at rest (minimum AES-GCM)

---

## 📖 Key Takeaways

✅ K8s Secrets are base64-encoded (not encrypted!)
✅ Enable encryption at rest (KMS best)
✅ Use external secret managers for production
✅ Sealed Secrets for GitOps workflows
✅ Never commit secrets to Git
✅ Rotate secrets regularly
✅ Use RBAC to limit access
✅ Audit secret access
✅ Least privilege always
✅ External > Sealed Secrets > K8s Secrets

---

## 🔗 Additional Resources

- [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets)
- [External Secrets Operator](https://external-secrets.io/)
- [HashiCorp Vault](https://www.vaultproject.io/)
- [Kubernetes Encryption](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/)

---

## 🚀 Next Steps

1. Complete hands-on exercises in GUIDEME.md
2. Enable encryption at rest
3. Install External Secrets Operator
4. Configure Sealed Secrets
5. Implement secret rotation
6. Build production secrets workflow
7. Move to advanced security topics

**Happy Securing! 🔒**
