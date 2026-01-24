# Configuration Management Interview Q&A

## Basic Level Questions

### Q1: What is a ConfigMap in Kubernetes?
**Answer**: A ConfigMap is a Kubernetes API object used to store non-confidential configuration data in key-value pairs. It allows you to decouple environment-specific configuration from container images, making applications more portable.

**Key points**:
- Stores configuration data as key-value pairs
- Can contain simple values or entire configuration files
- Not designed for sensitive data (use Secrets instead)
- Can be consumed as environment variables or mounted as files
- Maximum size: 1MB

**Example**:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  database_host: "mysql.default.svc.cluster.local"
  log_level: "info"
```

---

### Q2: What is the difference between ConfigMap and Secret?
**Answer**:

| Aspect | ConfigMap | Secret |
|--------|-----------|--------|
| **Purpose** | Non-sensitive configuration | Sensitive data (passwords, tokens) |
| **Storage** | Plain text | Base64 encoded |
| **Encryption** | Not encrypted | Can be encrypted at rest |
| **Use Case** | App settings, config files | Credentials, API keys, certificates |
| **Display** | Visible in kubectl describe | Hidden in kubectl describe |

**When to use**:
- **ConfigMap**: Database host, logging level, feature flags, config files
- **Secret**: Database passwords, API tokens, TLS certificates, SSH keys

---

### Q3: How do you create a ConfigMap from literal values?
**Answer**:
```bash
# Single key-value
kubectl create configmap app-config \
  --from-literal=environment=production

# Multiple key-values
kubectl create configmap app-config \
  --from-literal=environment=production \
  --from-literal=log_level=info \
  --from-literal=max_connections=100

# Verify
kubectl get configmap app-config -o yaml
```

---

### Q4: How can you use a ConfigMap in a Pod?
**Answer**: There are three main ways:

**1. As environment variables**:
```yaml
env:
- name: LOG_LEVEL
  valueFrom:
    configMapKeyRef:
      name: app-config
      key: log_level
```

**2. As volume mount**:
```yaml
volumeMounts:
- name: config
  mountPath: /etc/config
volumes:
- name: config
  configMap:
    name: app-config
```

**3. Load all keys using envFrom**:
```yaml
envFrom:
- configMapRef:
    name: app-config
```

---

### Q5: How do you create a Secret in Kubernetes?
**Answer**:

**Method 1: From literal values**:
```bash
kubectl create secret generic db-secret \
  --from-literal=username=admin \
  --from-literal=password='MyP@ssw0rd'
```

**Method 2: From files**:
```bash
echo -n 'admin' > ./username
echo -n 'MyP@ssw0rd' > ./password

kubectl create secret generic db-secret \
  --from-file=./username \
  --from-file=./password
```

**Method 3: From YAML**:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-secret
type: Opaque
stringData:
  username: admin
  password: MyP@ssw0rd
```

---

## Intermediate Level Questions

### Q6: How do you update a ConfigMap without causing downtime?
**Answer**:

**Challenge**: Pods using ConfigMaps via environment variables don't automatically see updates.

**Solutions**:

**1. Volume mounts (automatic update)**:
```yaml
# Changes reflect automatically (with delay)
volumeMounts:
- name: config
  mountPath: /etc/config
volumes:
- name: config
  configMap:
    name: app-config
```

**2. Versioned ConfigMaps**:
```yaml
# Create new version
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config-v2
data:
  key: new-value

# Update deployment to use new version
env:
- name: CONFIG_VERSION
  valueFrom:
    configMapKeyRef:
      name: app-config-v2
      key: key
```

**3. Deployment annotation pattern**:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  template:
    metadata:
      annotations:
        configmap/checksum: {{ configmap-hash }}
```

**4. Rolling restart**:
```bash
kubectl rollout restart deployment/myapp
```

---

### Q7: What are the different types of Secrets in Kubernetes?
**Answer**:

| Type | Purpose | Example Use |
|------|---------|-------------|
| **Opaque** | Generic secret (default) | Passwords, tokens |
| **kubernetes.io/service-account-token** | Service account token | Automatic mounting |
| **kubernetes.io/dockercfg** | Docker config (legacy) | Registry auth |
| **kubernetes.io/dockerconfigjson** | Docker config | Registry auth |
| **kubernetes.io/basic-auth** | Basic authentication | Username/password |
| **kubernetes.io/ssh-auth** | SSH authentication | SSH private key |
| **kubernetes.io/tls** | TLS certificate | HTTPS certificates |

**Examples**:

```bash
# TLS secret
kubectl create secret tls tls-secret \
  --cert=path/to/cert.crt \
  --key=path/to/cert.key

# Docker registry secret
kubectl create secret docker-registry regcred \
  --docker-server=myregistry.com \
  --docker-username=user \
  --docker-password=pass
```

---

### Q8: How do you decode a Secret value?
**Answer**:

**Using kubectl and base64**:
```bash
# Get base64 encoded value
kubectl get secret db-secret -o jsonpath='{.data.password}'

# Decode the value
kubectl get secret db-secret -o jsonpath='{.data.password}' | base64 -d

# Decode all keys
kubectl get secret db-secret -o json | \
  jq '.data | map_values(@base64d)'
```

**Why base64?**: Secrets are base64-encoded, NOT encrypted. This encoding:
- Handles binary data
- Prevents accidental exposure in logs
- NOT a security measure (easily reversible)

**Security note**: Always enable encryption at rest for actual security.

---

### Q9: What is the difference between env and envFrom?
**Answer**:

**`env` - Individual environment variables**:
```yaml
env:
- name: DB_HOST
  valueFrom:
    configMapKeyRef:
      name: db-config
      key: host
- name: DB_PORT
  valueFrom:
    configMapKeyRef:
      name: db-config
      key: port
```
- Select specific keys
- Rename variables
- More control, more verbose

**`envFrom` - Bulk loading**:
```yaml
envFrom:
- configMapRef:
    name: db-config
  prefix: DB_
```
- Loads all keys from ConfigMap/Secret
- Optional prefix for all variables
- Less verbose, less control

**When to use**:
- **env**: When you need specific keys or want to rename variables
- **envFrom**: When you want all keys from a ConfigMap/Secret

---

### Q10: How can you make a ConfigMap immutable?
**Answer**:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
immutable: true
data:
  key: value
```

**Benefits**:
1. **Performance**: Reduces load on API server (no watch for changes)
2. **Safety**: Prevents accidental modifications
3. **Reliability**: Guarantees config stability
4. **Updates**: Requires creating a new ConfigMap version

**Use case**: Critical production configurations that shouldn't change

**Update pattern**:
```bash
# Create new version
kubectl create configmap app-config-v2 --from-literal=key=newvalue
kubectl set immutable configmap app-config-v2

# Update deployment
kubectl set env deployment/myapp --from=configmap/app-config-v2
```

---

## Advanced Level Questions

### Q11: How do you implement encryption at rest for Secrets?
**Answer**:

Secrets are base64-encoded by default, NOT encrypted. To encrypt at rest:

**1. Create encryption configuration**:
```yaml
# /etc/kubernetes/enc/encryption-config.yaml
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              # Generate with: head -c 32 /dev/urandom | base64
              secret: <32-byte-base64-encoded-secret>
      - identity: {}  # Fallback for unencrypted data
```

**2. Update API server configuration**:
```yaml
# /etc/kubernetes/manifests/kube-apiserver.yaml
spec:
  containers:
  - command:
    - kube-apiserver
    - --encryption-provider-config=/etc/kubernetes/enc/encryption-config.yaml
    volumeMounts:
    - name: encryption-config
      mountPath: /etc/kubernetes/enc
      readOnly: true
  volumes:
  - name: encryption-config
    hostPath:
      path: /etc/kubernetes/enc
      type: DirectoryOrCreate
```

**3. Encrypt existing secrets**:
```bash
kubectl get secrets --all-namespaces -o json | \
  kubectl replace -f -
```

**Verification**:
```bash
# Check etcd directly (encrypted data looks like garbage)
ETCDCTL_API=3 etcdctl get /registry/secrets/default/my-secret
```

---

### Q12: How would you integrate external secret management systems like Vault?
**Answer**:

**Using External Secrets Operator**:

**1. Install External Secrets Operator**:
```bash
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets
```

**2. Create SecretStore**:
```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: vault-backend
spec:
  provider:
    vault:
      server: "https://vault.example.com"
      path: "secret"
      version: "v2"
      auth:
        kubernetes:
          mountPath: "kubernetes"
          role: "myapp-role"
          serviceAccountRef:
            name: myapp-sa
```

**3. Create ExternalSecret**:
```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: db-credentials
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: db-credentials  # K8s Secret name
    creationPolicy: Owner
  data:
  - secretKey: password
    remoteRef:
      key: secret/data/database
      property: password
  - secretKey: username
    remoteRef:
      key: secret/data/database
      property: username
```

**Benefits**:
- Centralized secret management
- Automatic rotation
- Audit logging
- Fine-grained access control
- Secret versioning

---

### Q13: How do you handle ConfigMap size limitations?
**Answer**:

**Limitation**: ConfigMaps are limited to 1MB (etcd limitation).

**Solutions**:

**1. Split large configs**:
```yaml
# app-config-database.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config-database
data:
  db-config: |
    # Large database configuration

---
# app-config-cache.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config-cache
data:
  cache-config: |
    # Large cache configuration
```

**2. Use external configuration stores**:
```yaml
# Store config in external system (S3, Git, etc.)
env:
- name: CONFIG_URL
  value: "s3://my-bucket/configs/app-config.json"
```

**3. Use init containers to fetch config**:
```yaml
initContainers:
- name: fetch-config
  image: amazon/aws-cli
  command:
  - sh
  - -c
  - |
    aws s3 cp s3://my-bucket/config/app.conf /config/
  volumeMounts:
  - name: config
    mountPath: /config
```

**4. ConfigMap references**:
```yaml
# Reference to external config
data:
  config_location: "https://config-server.example.com/app-config"
```

---

### Q14: How do you implement RBAC for Secrets?
**Answer**:

**Principle of least privilege**: Grant minimal necessary access.

**1. Create ServiceAccount**:
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-sa
  namespace: production
```

**2. Create Role (namespace-scoped)**:
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: secret-reader
  namespace: production
rules:
- apiGroups: [""]
  resources: ["secrets"]
  resourceNames: ["db-credentials", "api-keys"]  # Specific secrets only
  verbs: ["get", "list"]
```

**3. Create RoleBinding**:
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: app-read-secrets
  namespace: production
subjects:
- kind: ServiceAccount
  name: app-sa
  namespace: production
roleRef:
  kind: Role
  name: secret-reader
  apiGroup: rbac.authorization.k8s.io
```

**4. Use ServiceAccount in Pod**:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: myapp
spec:
  serviceAccountName: app-sa
  containers:
  - name: app
    image: myapp:1.0
    env:
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: db-credentials
          key: password
```

**Best practices**:
- One ServiceAccount per application
- Namespace-level Roles (not ClusterRoles)
- Specific resourceNames when possible
- Regular access audits

---

### Q15: Explain the concept of projected volumes with ConfigMaps and Secrets.
**Answer**:

Projected volumes allow you to mount multiple volume sources into a single directory.

**Use case**: Combine ConfigMaps, Secrets, and other sources.

**Example**:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: projected-volume-pod
spec:
  containers:
  - name: app
    image: myapp:1.0
    volumeMounts:
    - name: all-in-one
      mountPath: /projected-volume
      readOnly: true
  
  volumes:
  - name: all-in-one
    projected:
      sources:
      # ConfigMap
      - configMap:
          name: app-config
          items:
          - key: app.properties
            path: config/app.properties
      
      # Secret
      - secret:
          name: db-credentials
          items:
          - key: username
            path: secrets/username
          - key: password
            path: secrets/password
      
      # Downward API
      - downwardAPI:
          items:
          - path: "labels"
            fieldRef:
              fieldPath: metadata.labels
          - path: "annotations"
            fieldRef:
              fieldPath: metadata.annotations
      
      # ServiceAccount token
      - serviceAccountToken:
          path: token
          expirationSeconds: 3600
```

**Result in container**:
```
/projected-volume/
  ├── config/
  │   └── app.properties
  ├── secrets/
  │   ├── username
  │   └── password
  ├── labels
  ├── annotations
  └── token
```

**Benefits**:
- Single mount point for multiple sources
- Simplified application configuration
- Atomic updates across all sources

---

## Scenario-Based Questions

### Q16: Your application needs different database credentials for dev, staging, and prod. How would you manage this?
**Answer**:

**Strategy**: Use namespaces + environment-specific Secrets.

**Implementation**:

```yaml
# Development namespace
apiVersion: v1
kind: Namespace
metadata:
  name: development

---
apiVersion: v1
kind: Secret
metadata:
  name: db-credentials
  namespace: development
type: Opaque
stringData:
  host: dev-db.internal
  username: dev_user
  password: dev_password
  database: dev_db

---
# Staging namespace
apiVersion: v1
kind: Namespace
metadata:
  name: staging

---
apiVersion: v1
kind: Secret
metadata:
  name: db-credentials
  namespace: staging
type: Opaque
stringData:
  host: staging-db.internal
  username: staging_user
  password: staging_password
  database: staging_db

---
# Production namespace
apiVersion: v1
kind: Namespace
metadata:
  name: production

---
apiVersion: v1
kind: Secret
metadata:
  name: db-credentials
  namespace: production
type: Opaque
stringData:
  host: prod-db.internal
  username: prod_user
  password: prod_password
  database: prod_db

---
# Same deployment template for all environments
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  # Deploy to specific namespace: kubectl apply -f deployment.yaml -n 
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: app
        image: myapp:1.0
        env:
        - name: DB_HOST
          valueFrom:
            secretKeyRef:
              name: db-credentials  # Same name across environments
              key: host
        - name: DB_USER
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: username
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: password
        - name: DB_NAME
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: database
```

**Deployment**:
```bash
# Deploy to development
kubectl apply -f deployment.yaml -n development

# Deploy to production
kubectl apply -f deployment.yaml -n production
```

**Benefits**:
- Same deployment manifests across environments
- Environment isolation via namespaces
- Easy to promote between environments

---

### Q17: How would you rotate database credentials without application downtime?
**Answer**:

**Strategy**: Blue-Green credential rotation.

**Steps**:

**1. Prepare new credentials in database**:
```sql
-- Create new user with same permissions
CREATE USER 'app_user_v2'@'%' IDENTIFIED BY 'new_secure_password';
GRANT ALL PRIVILEGES ON myapp.* TO 'app_user_v2'@'%';
```

**2. Create new Secret version**:
```bash
kubectl create secret generic db-credentials-v2 \
  --from-literal=username=app_user_v2 \
  --from-literal=password=new_secure_password \
  --dry-run=client -o yaml | kubectl apply -f -
```

**3. Update deployment to use new secret**:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  template:
    spec:
      containers:
      - name: app
        env:
        - name: DB_USER
          valueFrom:
            secretKeyRef:
              name: db-credentials-v2  # Changed
              key: username
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-credentials-v2  # Changed
              key: password
```

**4. Apply with rolling update**:
```bash
kubectl apply -f deployment.yaml
kubectl rollout status deployment/myapp
```

**5. Verify and cleanup**:
```bash
# Verify application health
kubectl get pods
kubectl logs -l app=myapp

# After verification, remove old credentials
kubectl delete secret db-credentials
# DROP USER 'old_user'@'%';
```

**Automated script**:
```bash
#!/bin/bash
NEW_PASSWORD=$(openssl rand -base64 32)

# Create new secret
kubectl create secret generic db-credentials-new \
  --from-literal=username=dbuser \
  --from-literal=password="$NEW_PASSWORD" \
  --dry-run=client -o yaml | kubectl apply -f -

# Patch deployment
kubectl patch deployment myapp -p '
{
  "spec": {
    "template": {
      "spec": {
        "containers": [{
          "name": "app",
          "env": [{
            "name": "DB_PASSWORD",
            "valueFrom": {
              "secretKeyRef": {
                "name": "db-credentials-new",
                "key": "password"
              }
            }
          }]
        }]
      }
    }
  }
}'

# Wait for rollout
kubectl rollout status deployment/myapp

# Cleanup old secret
kubectl delete secret db-credentials
kubectl create secret generic db-credentials \
  --from-literal=username=dbuser \
  --from-literal=password="$NEW_PASSWORD"
```

---

### Q18: You need to inject a large JSON configuration file. What's the best approach?
**Answer**:

**Scenario**: 500KB+ JSON configuration file.

**Best approach**: ConfigMap with volume mount.

```yaml
# configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  config.json: |
    {
      "database": {
        "connections": {
          "primary": {
            "host": "db-primary.example.com",
            "port": 5432,
            "pool_size": 20
          },
          "replica": {
            "host": "db-replica.example.com",
            "port": 5432,
            "pool_size": 10
          }
        }
      },
      "cache": {
        "redis": {
          "nodes": [
            "redis-1.example.com:6379",
            "redis-2.example.com:6379",
            "redis-3.example.com:6379"
          ],
          "ttl": 3600
        }
      },
      "features": {
        "feature_a": true,
        "feature_b": false
      }
    }

---
# deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: app
        image: myapp:1.0
        volumeMounts:
        - name: config
          mountPath: /etc/app/config.json
          subPath: config.json  # Mount specific file
          readOnly: true
        env:
        - name: CONFIG_FILE
          value: /etc/app/config.json
      volumes:
      - name: config
        configMap:
          name: app-config
```

**Alternative for very large files (>500KB)**:

```yaml
# Use init container to fetch from external source
initContainers:
- name: fetch-config
  image: curlimages/curl:latest
  command:
  - sh
  - -c
  - |
    curl -o /config/config.json \
      https://config-server.example.com/app-config.json
  volumeMounts:
  - name: config
    mountPath: /config
```

---

## Troubleshooting Questions

### Q19: Pods are not picking up ConfigMap changes. Why?
**Answer**:

**Causes**:

**1. Using environment variables** (won't update automatically):
```yaml
# This WON'T update without pod restart
env:
- name: LOG_LEVEL
  valueFrom:
    configMapKeyRef:
      name: app-config
      key: log_level
```

**Solution**: Use volume mounts for automatic updates:
```yaml
# This WILL update automatically (with delay)
volumeMounts:
- name: config
  mountPath: /etc/config
volumes:
- name: config
  configMap:
    name: app-config
```

**2. Application not watching for file changes**:
- Some applications only read config at startup
- Solution: Implement file watching or use signals (SIGHUP)

**3. Kubelet sync delay**:
- Changes can take 1-2 minutes to propagate
- Controlled by `--sync-frequency` flag (default: 1m)

**Verification steps**:
```bash
# 1. Verify ConfigMap updated
kubectl get configmap app-config -o yaml

# 2. Check mounted file in pod
kubectl exec mypod -- cat /etc/config/log_level

# 3. Force sync by deleting and recreating pod
kubectl delete pod mypod
```

**Best practice**: For critical config changes, use rolling restart:
```bash
kubectl rollout restart deployment/myapp
```

---

### Q20: How do you debug Secret-related permission issues?
**Answer**:

**Symptoms**: Pods can't access Secrets, receiving "forbidden" errors.

**Debugging steps**:

**1. Check if Secret exists**:
```bash
kubectl get secret db-credentials
kubectl describe secret db-credentials
```

**2. Verify pod's ServiceAccount**:
```bash
kubectl get pod mypod -o jsonpath='{.spec.serviceAccountName}'
```

**3. Check RBAC permissions**:
```bash
# Check what the ServiceAccount can do
kubectl auth can-i get secrets \
  --as=system:serviceaccount:default:myapp-sa

# List roles for ServiceAccount
kubectl get rolebindings,clusterrolebindings \
  --all-namespaces \
  -o json | jq '.items[] | 
    select(.subjects[]? | 
    select(.name=="myapp-sa"))'
```

**4. Verify Role has correct permissions**:
```bash
kubectl get role secret-reader -o yaml
```

**5. Check namespace mismatch**:
```bash
# Secret and Pod must be in same namespace
kubectl get secret db-credentials -n production
kubectl get pod mypod -n production
```

**Common fixes**:

```yaml
# Grant Secret access
apiVersion: rbac.authorization.k8s.io/v1
kind:Role
metadata:
  name: secret-reader
  namespace: production
rules:
- apiGroups: [""]
  resources: ["secrets"]
  resourceNames: ["db-credentials"]  # Specific secret
  verbs: ["get"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-secrets
  namespace: production
subjects:
- kind: ServiceAccount
  name: myapp-sa
  namespace: production
roleRef:
  kind: Role
  name: secret-reader
  apiGroup: rbac.authorization.k8s.io
```

---

## Best Practices Summary

✅ **Do's**:
- Use ConfigMaps for non-sensitive data
- Use Secrets for sensitive information
- Enable encryption at rest for Secrets
- Implement RBAC for Secret access
- Use immutable ConfigMaps for critical configs
- Version your ConfigMaps/Secrets
- Use volume mounts for automatic updates
- Integrate external secret managers for production

❌ **Don'ts**:
- Don't hardcode configuration in images
- Don't commit Secrets to version control
- Don't rely on base64 encoding for security
- Don't use environment variables if you need automatic updates
- Don't exceed 1MB ConfigMap size
- Don't grant broad Secret access
- Don't log Secret values

---

**Next Topic**: Day 14-15 - Persistent Storage (PV, PVC, StorageClass)
