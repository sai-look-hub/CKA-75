# 🎤 Interview Q&A: Secrets Management

## Q1: What are the limitations of Kubernetes Secrets?

**Answer:**

**Kubernetes Secrets limitations:**

**1. Not encrypted by default**
- Stored as base64 in etcd
- Base64 is encoding, NOT encryption
- Anyone with etcd access can read
```bash
# Easy to decode
echo "YWRtaW4=" | base64 -d
# Output: admin
```

**2. No built-in rotation**
- Manual update required
- Pods don't auto-reload
- Risk of stale credentials

**3. Git storage issues**
- Unsafe to commit to Git
- Manual secret creation breaks GitOps
- Secrets leak in version control

**4. Limited audit trail**
- Hard to track access
- No built-in versioning
- Compliance challenges

**5. Access control challenges**
- RBAC can be too broad
- No fine-grained control
- All-or-nothing access

**Solutions:**
- Encryption at rest (KMS)
- External secret managers
- Sealed Secrets for GitOps
- Regular rotation
- Audit logging

---

## Q2: How do Sealed Secrets work?

**Answer:**

**Sealed Secrets:** Encrypted secrets safe for Git storage.

**Architecture:**
```
1. Developer creates Secret (plaintext)
2. kubeseal CLI encrypts it
3. SealedSecret (encrypted) → Git ✅
4. Applied to cluster
5. Controller decrypts
6. K8s Secret created
```

**How encryption works:**

**Public/Private key pair:**
- Controller has private key
- Public key used for sealing
- Only controller can decrypt

**Process:**
```bash
# 1. Create secret (local, DON'T commit)
cat > secret.yaml <<EOF
apiVersion: v1
kind: Secret
stringData:
  password: supersecret
EOF

# 2. Seal it
kubeseal -f secret.yaml -w sealed-secret.yaml

# 3. Result (safe for Git)
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
spec:
  encryptedData:
    password: AgBj8v7... (encrypted!)

# 4. Commit sealed version
git add sealed-secret.yaml
git commit -m "Add credentials (sealed)"

# 5. Apply to cluster
kubectl apply -f sealed-secret.yaml

# 6. Controller creates Secret
kubectl get secret <name>
```

**Benefits:**
✅ Safe for Git
✅ GitOps friendly
✅ No manual secret creation
✅ Only cluster can decrypt

**Scopes:**
- strict: Tied to namespace+name
- namespace-wide: Any name in namespace
- cluster-wide: Any namespace

---

## Q3: What are external secret managers and why use them?

**Answer:**

**External Secret Managers:** Centralized secret storage outside Kubernetes.

**Popular options:**
1. **HashiCorp Vault** - Multi-cloud, dynamic secrets
2. **AWS Secrets Manager** - AWS native
3. **Azure Key Vault** - Azure native
4. **GCP Secret Manager** - GCP native

**Why use them:**

**1. Centralized management**
- One source of truth
- Secrets across multiple clusters
- Consistent policies

**2. Automatic rotation**
```
1. Rotate in Vault/AWS
2. External Secrets Operator syncs
3. Pods get new credentials
4. No manual intervention
```

**3. Advanced features**
- Dynamic secrets (temporary credentials)
- Encryption as a service
- Detailed audit logs
- Compliance ready

**4. Better security**
- Secrets never in Git
- Encrypted at rest
- Access control
- Versioning

**How it works (External Secrets Operator):**
```yaml
# 1. SecretStore (connection config)
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
spec:
  provider:
    aws:
      service: SecretsManager

# 2. ExternalSecret (reference)
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
spec:
  secretStoreRef:
    name: aws-secretstore
  data:
  - secretKey: password
    remoteRef:
      key: prod/database
      property: password

# 3. Operator syncs → K8s Secret created
```

**Best for:** Production environments with compliance requirements.

---

## Q4: How do you implement secret rotation?

**Answer:**

**Three approaches:**

**1. Manual rotation:**
```bash
# Update secret
kubectl create secret generic db-pass \
  --from-literal=password=newpass \
  --dry-run=client -o yaml | kubectl apply -f -

# Restart pods to pick up change
kubectl rollout restart deployment app
```
Pros: Simple
Cons: Manual, error-prone

**2. External Secret Manager (automatic):**
```
1. Rotate in Vault/AWS Secrets Manager
2. External Secrets Operator syncs (refreshInterval)
3. Secret updated in K8s
4. Pods detect change
```
Pros: Automatic, centralized
Cons: Requires external service

**3. Reloader/Stakater (automatic pod restart):**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  annotations:
    reloader.stakater.com/auto: "true"
spec:
  template:
    spec:
      containers:
      - env:
        - name: DB_PASS
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: password
```

**Workflow:**
1. Secret updated (manual or external)
2. Reloader watches secret changes
3. Deployment automatically restarted
4. Pods get new secret

**Best practice:**
- External Secret Manager + Reloader
- Automatic rotation schedule:
  - Critical: 30 days
  - Standard: 90 days
  - Certificates: Before expiry

**Implementation:**
```yaml
# ExternalSecret with refresh
spec:
  refreshInterval: 1h  # Check every hour

# Deployment with auto-reload
metadata:
  annotations:
    reloader.stakater.com/auto: "true"
```

Result: Fully automatic secret rotation!

---

## Q5: What are best practices for secrets in production?

**Answer:**

**Production secrets checklist:**

**1. Never commit secrets to Git**
```bash
# ❌ NEVER
git add secret.yaml

# ✅ Use Sealed Secrets or External Secrets
git add sealed-secret.yaml  # Encrypted, safe
```

**2. Enable encryption at rest**
```yaml
# Minimum: AES-GCM
# Best: KMS (AWS KMS, GCP KMS)
kind: EncryptionConfiguration
providers:
- kms:
    name: aws-encryption-provider
```

**3. Use external secret managers**
- Vault for multi-cloud
- AWS Secrets Manager for AWS
- Don't rely on K8s Secrets alone

**4. Implement RBAC**
```yaml
# Least privilege
rules:
- resources: ["secrets"]
  resourceNames: ["app-credentials"]  # Specific!
  verbs: ["get"]  # Not "list", "*"
```

**5. Rotate regularly**
- Critical secrets: 30 days
- Standard: 90 days
- Automate with External Secrets

**6. Never log secrets**
```python
# ❌ DON'T
print(f"Password: {password}")

# ✅ DO
print("Database connected")
```

**7. Use secret references, not values**
```yaml
# ❌ DON'T
env:
- name: DB_PASS
  value: "password123"

# ✅ DO
env:
- name: DB_PASS
  valueFrom:
    secretKeyRef:
      name: db-creds
      key: password
```

**8. Audit access**
```bash
# Enable audit logging
--audit-log-path=/var/log/audit.log
# Monitor secret access
```

**9. Separate secrets by environment**
- dev/staging/prod namespaces
- Different SecretStores
- Never share prod secrets

**10. Document everything**
- Secret rotation schedule
- Access procedures
- Emergency contacts
