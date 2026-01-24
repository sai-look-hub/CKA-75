# Day 12-13: Configuration Management Deep Dive Guide

## Table of Contents
1. [Introduction](#introduction)
2. [ConfigMaps](#configmaps)
3. [Secrets](#secrets)
4. [Environment Variables](#environment-variables)
5. [Best Practices](#best-practices)
6. [Real-World Scenarios](#real-world-scenarios)
7. [Security Considerations](#security-considerations)

---

## Introduction

Configuration Management in Kubernetes separates application code from configuration, enabling:
- **Environment Portability**: Same image across dev/staging/prod
- **Dynamic Updates**: Change config without rebuilding images
- **Security**: Separate sensitive data from application code
- **Flexibility**: Manage configurations externally

### Key Components
- **ConfigMaps**: Non-confidential configuration data
- **Secrets**: Sensitive information (passwords, tokens, keys)
- **Environment Variables**: Runtime configuration injection

---

## ConfigMaps

### What are ConfigMaps?

ConfigMaps store non-confidential data in key-value pairs. They decouple environment-specific configuration from container images.

### Creating ConfigMaps

#### Method 1: From Literal Values
```bash
kubectl create configmap app-config \
  --from-literal=APP_ENV=production \
  --from-literal=LOG_LEVEL=info \
  --from-literal=MAX_CONNECTIONS=100
```

#### Method 2: From Files
```bash
# Create config file
cat > app.properties <<EOF
database.host=db.example.com
database.port=5432
cache.enabled=true
EOF

# Create ConfigMap from file
kubectl create configmap app-properties \
  --from-file=app.properties
```

#### Method 3: From Directory
```bash
mkdir config-files
echo "production" > config-files/environment
echo "info" > config-files/log-level

kubectl create configmap app-config-dir \
  --from-file=config-files/
```

#### Method 4: From YAML Manifest
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: default
data:
  # Simple key-value pairs
  APP_ENV: "production"
  LOG_LEVEL: "info"
  
  # Multi-line configuration
  app.properties: |
    database.host=db.example.com
    database.port=5432
    cache.enabled=true
    
  nginx.conf: |
    server {
      listen 80;
      server_name example.com;
      location / {
        proxy_pass http://backend:8080;
      }
    }
```

### Using ConfigMaps

#### As Environment Variables
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: configmap-env-pod
spec:
  containers:
  - name: app
    image: nginx:1.21
    env:
    # Single environment variable
    - name: APP_ENV
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: APP_ENV
    
    # All keys as environment variables
    envFrom:
    - configMapRef:
        name: app-config
```

#### As Volume Mounts
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: configmap-volume-pod
spec:
  containers:
  - name: app
    image: nginx:1.21
    volumeMounts:
    - name: config-volume
      mountPath: /etc/config
      readOnly: true
  
  volumes:
  - name: config-volume
    configMap:
      name: app-config
      # Optional: specify individual items
      items:
      - key: nginx.conf
        path: nginx.conf
        mode: 0644
```

#### Specific Keys as Files
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: selective-config-pod
spec:
  containers:
  - name: app
    image: myapp:1.0
    volumeMounts:
    - name: config
      mountPath: /app/config/app.properties
      subPath: app.properties
  
  volumes:
  - name: config
    configMap:
      name: app-properties
```

### ConfigMap Management

#### View ConfigMaps
```bash
# List all ConfigMaps
kubectl get configmaps

# Describe specific ConfigMap
kubectl describe configmap app-config

# View ConfigMap YAML
kubectl get configmap app-config -o yaml

# View specific key
kubectl get configmap app-config -o jsonpath='{.data.APP_ENV}'
```

#### Update ConfigMaps
```bash
# Edit interactively
kubectl edit configmap app-config

# Update from file
kubectl create configmap app-config \
  --from-file=app.properties \
  --dry-run=client -o yaml | kubectl apply -f -

# Patch specific key
kubectl patch configmap app-config \
  -p '{"data":{"LOG_LEVEL":"debug"}}'
```

---

## Secrets

### What are Secrets?

Secrets store sensitive information such as passwords, OAuth tokens, and SSH keys. Data is base64-encoded (not encrypted by default).

### Types of Secrets

1. **Opaque** (default): Arbitrary user-defined data
2. **kubernetes.io/service-account-token**: Service account token
3. **kubernetes.io/dockercfg**: Docker registry credentials
4. **kubernetes.io/tls**: TLS certificate and key
5. **kubernetes.io/ssh-auth**: SSH authentication
6. **kubernetes.io/basic-auth**: Basic authentication

### Creating Secrets

#### Method 1: From Literal Values
```bash
kubectl create secret generic db-credentials \
  --from-literal=username=admin \
  --from-literal=password='MyS3cr3tP@ss!'
```

#### Method 2: From Files
```bash
# Create credential files
echo -n 'admin' > username.txt
echo -n 'MyS3cr3tP@ss!' > password.txt

kubectl create secret generic db-credentials \
  --from-file=username=username.txt \
  --from-file=password=password.txt

# Cleanup
rm username.txt password.txt
```

#### Method 3: TLS Secret
```bash
kubectl create secret tls tls-secret \
  --cert=path/to/tls.crt \
  --key=path/to/tls.key
```

#### Method 4: Docker Registry Secret
```bash
kubectl create secret docker-registry regcred \
  --docker-server=myregistry.com \
  --docker-username=myuser \
  --docker-password=mypassword \
  --docker-email=myemail@example.com
```

#### Method 5: From YAML (Base64 Encoded)
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-credentials
type: Opaque
data:
  # Base64 encoded values
  username: YWRtaW4=          # "admin"
  password: TXlTM2NyM3RQQHNzIQ==  # "MyS3cr3tP@ss!"
```

#### Method 6: From YAML (Plain Text)
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-credentials
type: Opaque
stringData:
  # Plain text - Kubernetes will encode
  username: admin
  password: MyS3cr3tP@ss!
```

### Using Secrets

#### As Environment Variables
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secret-env-pod
spec:
  containers:
  - name: app
    image: myapp:1.0
    env:
    # Single secret value
    - name: DB_USERNAME
      valueFrom:
        secretKeyRef:
          name: db-credentials
          key: username
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: db-credentials
          key: password
    
    # All keys as environment variables
    envFrom:
    - secretRef:
        name: db-credentials
```

#### As Volume Mounts
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secret-volume-pod
spec:
  containers:
  - name: app
    image: myapp:1.0
    volumeMounts:
    - name: secret-volume
      mountPath: /etc/secrets
      readOnly: true
  
  volumes:
  - name: secret-volume
    secret:
      secretName: db-credentials
      defaultMode: 0400  # Read-only for owner
```

#### For Image Pull
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: private-image-pod
spec:
  containers:
  - name: app
    image: myregistry.com/myapp:1.0
  imagePullSecrets:
  - name: regcred
```

### Secret Management

#### View Secrets (Without Decoding)
```bash
# List secrets
kubectl get secrets

# Describe secret (hides values)
kubectl describe secret db-credentials

# View secret YAML (base64 encoded)
kubectl get secret db-credentials -o yaml
```

#### Decode Secrets
```bash
# Decode specific key
kubectl get secret db-credentials \
  -o jsonpath='{.data.password}' | base64 -d

# Decode all keys
kubectl get secret db-credentials -o json | \
  jq '.data | map_values(@base64d)'
```

#### Update Secrets
```bash
# Create new version
kubectl create secret generic db-credentials \
  --from-literal=username=newadmin \
  --from-literal=password='NewP@ss!' \
  --dry-run=client -o yaml | kubectl apply -f -

# Edit interactively
kubectl edit secret db-credentials
```

---

## Environment Variables

### Direct Environment Variables

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: env-pod
spec:
  containers:
  - name: app
    image: myapp:1.0
    env:
    # Static value
    - name: ENVIRONMENT
      value: "production"
    
    # From ConfigMap
    - name: APP_CONFIG
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: APP_ENV
    
    # From Secret
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: db-credentials
          key: password
    
    # From field reference
    - name: POD_NAME
      valueFrom:
        fieldRef:
          fieldPath: metadata.name
    
    - name: POD_IP
      valueFrom:
        fieldRef:
          fieldPath: status.podIP
    
    # From resource limits
    - name: MEMORY_LIMIT
      valueFrom:
        resourceFieldRef:
          containerName: app
          resource: limits.memory
```

### Environment Variable Sources

#### Field References
```yaml
env:
- name: NODE_NAME
  valueFrom:
    fieldRef:
      fieldPath: spec.nodeName

- name: NAMESPACE
  valueFrom:
    fieldRef:
      fieldPath: metadata.namespace

- name: SERVICE_ACCOUNT
  valueFrom:
    fieldRef:
      fieldPath: spec.serviceAccountName
```

#### Resource References
```yaml
env:
- name: CPU_REQUEST
  valueFrom:
    resourceFieldRef:
      containerName: app
      resource: requests.cpu
      divisor: "1m"  # Convert to millicores

- name: MEMORY_REQUEST_MB
  valueFrom:
    resourceFieldRef:
      resource: requests.memory
      divisor: "1Mi"  # Convert to Mi
```

### Bulk Environment Loading

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: bulk-env-pod
spec:
  containers:
  - name: app
    image: myapp:1.0
    envFrom:
    # Load all ConfigMap keys
    - configMapRef:
        name: app-config
      prefix: CONFIG_  # Optional prefix
    
    # Load all Secret keys
    - secretRef:
        name: db-credentials
      prefix: DB_
```

---

## Best Practices

### Configuration Management

1. **Separation of Concerns**
   - Use ConfigMaps for non-sensitive data
   - Use Secrets for sensitive information
   - Never hardcode configuration in images

2. **Naming Conventions**
   ```bash
   # Good naming patterns
   app-config-prod
   app-config-dev
   db-credentials-mysql
   tls-cert-ingress
   ```

3. **Versioning**
   ```yaml
   # Include version in name for immutability
   apiVersion: v1
   kind: ConfigMap
   metadata:
     name: app-config-v2
   ```

4. **Size Limits**
   - ConfigMaps/Secrets limited to 1MB
   - Split large configurations across multiple objects
   - Use external configuration stores for very large configs

### Security Best Practices

1. **Encrypt Secrets at Rest**
   ```yaml
   # Enable encryption in API server
   apiVersion: apiserver.config.k8s.io/v1
   kind: EncryptionConfiguration
   resources:
   - resources:
     - secrets
     providers:
     - aescbc:
         keys:
         - name: key1
           secret: <base64-encoded-32-byte-key>
   ```

2. **RBAC for Secrets**
   ```yaml
   apiVersion: rbac.authorization.k8s.io/v1
   kind: Role
   metadata:
     name: secret-reader
   rules:
   - apiGroups: [""]
     resources: ["secrets"]
     resourceNames: ["db-credentials"]
     verbs: ["get"]
   ```

3. **Use External Secret Managers**
   - HashiCorp Vault
   - AWS Secrets Manager
   - Azure Key Vault
   - Google Secret Manager

4. **Avoid Logging Secrets**
   ```yaml
   env:
   - name: DB_PASSWORD
     valueFrom:
       secretKeyRef:
         name: db-credentials
         key: password
   # Don't echo or log this variable in application code
   ```

### Update Strategies

1. **ConfigMap Updates**
   - Mounted volumes update automatically (with delay)
   - Environment variables require pod restart
   - Use immutable ConfigMaps for critical configs

2. **Immutable ConfigMaps/Secrets**
   ```yaml
   apiVersion: v1
   kind: ConfigMap
   metadata:
     name: app-config
   immutable: true
   data:
     key: value
   ```

3. **Rolling Updates**
   ```yaml
   # Add checksum annotation to trigger rolling update
   apiVersion: apps/v1
   kind: Deployment
   metadata:
     name: myapp
   spec:
     template:
       metadata:
         annotations:
           configmap-hash: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
   ```

---

## Real-World Scenarios

### Scenario 1: Multi-Environment Application

```yaml
# Production ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config-prod
  namespace: production
data:
  environment: "production"
  log_level: "warn"
  database_host: "prod-db.example.com"
  cache_enabled: "true"
  max_connections: "100"

---
# Development ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config-dev
  namespace: development
data:
  environment: "development"
  log_level: "debug"
  database_host: "dev-db.example.com"
  cache_enabled: "false"
  max_connections: "10"

---
# Deployment using environment-specific config
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  namespace: production
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
        envFrom:
        - configMapRef:
            name: app-config-prod
        env:
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: password
```

### Scenario 2: Database Connection Management

```yaml
# Database credentials secret
apiVersion: v1
kind: Secret
metadata:
  name: postgres-credentials
type: Opaque
stringData:
  username: postgres
  password: securepassword
  database: myapp_db

---
# Database configuration
apiVersion: v1
kind: ConfigMap
metadata:
  name: postgres-config
data:
  host: "postgres.default.svc.cluster.local"
  port: "5432"
  max_connections: "50"
  connection_timeout: "30"

---
# Application deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web-app
  template:
    metadata:
      labels:
        app: web-app
    spec:
      containers:
      - name: app
        image: web-app:1.0
        env:
        - name: DB_HOST
          valueFrom:
            configMapKeyRef:
              name: postgres-config
              key: host
        - name: DB_PORT
          valueFrom:
            configMapKeyRef:
              name: postgres-config
              key: port
        - name: DB_NAME
          valueFrom:
            secretKeyRef:
              name: postgres-credentials
              key: database
        - name: DB_USER
          valueFrom:
            secretKeyRef:
              name: postgres-credentials
              key: username
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-credentials
              key: password
```

### Scenario 3: Application with Configuration Files

```yaml
# Nginx ConfigMap with full config file
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-config
data:
  nginx.conf: |
    user nginx;
    worker_processes auto;
    error_log /var/log/nginx/error.log;
    
    events {
        worker_connections 1024;
    }
    
    http {
        include /etc/nginx/mime.types;
        default_type application/octet-stream;
        
        server {
            listen 80;
            server_name example.com;
            
            location / {
                proxy_pass http://backend:8080;
                proxy_set_header Host $host;
                proxy_set_header X-Real-IP $remote_addr;
            }
        }
    }

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.21
        volumeMounts:
        - name: nginx-config
          mountPath: /etc/nginx/nginx.conf
          subPath: nginx.conf
        ports:
        - containerPort: 80
      volumes:
      - name: nginx-config
        configMap:
          name: nginx-config
```

---

## Security Considerations

### 1. Encryption at Rest

Enable encryption for Secrets stored in etcd:

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
              secret: <32-byte base64 encoded secret>
      - identity: {}
```

### 2. Access Control

```yaml
# Limit secret access to specific service accounts
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-sa

---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: secret-reader
rules:
- apiGroups: [""]
  resources: ["secrets"]
  resourceNames: ["app-secrets"]
  verbs: ["get", "list"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-secrets
subjects:
- kind: ServiceAccount
  name: app-sa
roleRef:
  kind: Role
  name: secret-reader
  apiGroup: rbac.authorization.k8s.io
```

### 3. External Secrets Integration

Example with External Secrets Operator:

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
          role: "my-app"

---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: app-secrets
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: app-secrets
    creationPolicy: Owner
  data:
  - secretKey: password
    remoteRef:
      key: secret/data/myapp
      property: password
```

### 4. Secret Rotation

```bash
# Script for rotating secrets
#!/bin/bash
NEW_PASSWORD=$(openssl rand -base64 32)

kubectl create secret generic db-credentials \
  --from-literal=username=admin \
  --from-literal=password="$NEW_PASSWORD" \
  --dry-run=client -o yaml | kubectl apply -f -

# Trigger rolling restart
kubectl rollout restart deployment/myapp
```

---

## Summary

Configuration Management in Kubernetes provides:

✅ **Flexibility**: Separate config from code  
✅ **Security**: Protect sensitive data  
✅ **Portability**: Same images across environments  
✅ **Manageability**: Centralized configuration  
✅ **Scalability**: Dynamic updates without rebuilds

**Key Takeaways**:
- Use ConfigMaps for non-sensitive configuration
- Use Secrets for passwords, tokens, and keys
- Enable encryption at rest for Secrets
- Implement RBAC for fine-grained access control
- Consider external secret managers for production
- Follow immutability patterns for critical configs
- Never commit secrets to version control

**Next Steps**: Day 14-15 - Persistent Storage (PV, PVC, StorageClass)
