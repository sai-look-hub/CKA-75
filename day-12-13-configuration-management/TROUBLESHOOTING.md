# Configuration Management Troubleshooting Guide

## Table of Contents
1. [ConfigMap Issues](#configmap-issues)
2. [Secret Issues](#secret-issues)
3. [Environment Variable Issues](#environment-variable-issues)
4. [Volume Mount Issues](#volume-mount-issues)
5. [Permission Issues](#permission-issues)
6. [Update and Sync Issues](#update-and-sync-issues)
7. [Common Errors](#common-errors)
8. [Performance Issues](#performance-issues)

---

## ConfigMap Issues

### Issue 1: ConfigMap Not Found

**Symptoms**:
```
Error: configmaps "app-config" not found
```

**Diagnosis**:
```bash
# Check if ConfigMap exists
kubectl get configmap app-config

# Check in specific namespace
kubectl get configmap app-config -n production

# List all ConfigMaps
kubectl get configmap --all-namespaces
```

**Common Causes**:
1. ConfigMap not created
2. Wrong namespace
3. Typo in name
4. ConfigMap deleted

**Solutions**:

**1. Create the ConfigMap**:
```bash
kubectl create configmap app-config \
  --from-literal=key=value
```

**2. Check namespace**:
```bash
# Ensure Pod and ConfigMap are in same namespace
kubectl get pod mypod -o jsonpath='{.metadata.namespace}'
kubectl get configmap app-config -n 
```

**3. Verify in Pod spec**:
```yaml
spec:
  containers:
  - name: app
    env:
    - name: CONFIG_KEY
      valueFrom:
        configMapKeyRef:
          name: app-config  # Must match exactly
          key: key
```

---

### Issue 2: ConfigMap Data Not Appearing in Pod

**Symptoms**:
- Environment variables are empty
- Mounted files don't exist
- Application can't read configuration

**Diagnosis**:
```bash
# Check ConfigMap data
kubectl get configmap app-config -o yaml

# Check Pod environment
kubectl exec mypod -- env | grep CONFIG

# Check mounted files
kubectl exec mypod -- ls -la /etc/config
kubectl exec mypod -- cat /etc/config/key
```

**Solutions**:

**1. Verify ConfigMap has data**:
```bash
kubectl describe configmap app-config
```

**2. Check Pod spec matches ConfigMap keys**:
```yaml
# ConfigMap
data:
  log_level: "info"  # Key must match

# Pod
env:
- name: LOG_LEVEL
  valueFrom:
    configMapKeyRef:
      name: app-config
      key: log_level  # Must match exactly (case-sensitive)
```

**3. For volume mounts, check mount path**:
```bash
kubectl exec mypod -- ls -la /etc/config
```

---

### Issue 3: ConfigMap Changes Not Reflected

**Symptoms**:
- Updated ConfigMap but Pod still uses old values
- Environment variables don't update
- Application doesn't see new configuration

**Diagnosis**:
```bash
# Check ConfigMap current state
kubectl get configmap app-config -o yaml

# Check when Pod was started
kubectl get pod mypod -o jsonpath='{.status.startTime}'

# Check ConfigMap update time
kubectl get configmap app-config -o jsonpath='{.metadata.creationTimestamp}'
```

**Root Cause**:
Environment variables are set at container startup and don't update automatically.

**Solutions**:

**1. For environment variables - Restart Pods**:
```bash
# Delete pod (if using Deployment, will recreate)
kubectl delete pod mypod

# Or rollout restart deployment
kubectl rollout restart deployment myapp
```

**2. For volume mounts - Wait or verify**:
```bash
# Volume mounts update automatically with delay (1-2 minutes)
# Check current mounted content
kubectl exec mypod -- cat /etc/config/log_level

# Force update by deleting pod
kubectl delete pod mypod
```

**3. Use versioned ConfigMaps**:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config-v2  # Version in name
data:
  key: new-value

# Update Deployment
spec:
  template:
    spec:
      containers:
      - name: app
        envFrom:
        - configMapRef:
            name: app-config-v2  # Point to new version
```

---

### Issue 4: ConfigMap Size Limit Exceeded

**Symptoms**:
```
Error: ConfigMap "large-config" exceeds maximum size (1MB)
```

**Diagnosis**:
```bash
# Check ConfigMap size
kubectl get configmap large-config -o yaml | wc -c
```

**Solutions**:

**1. Split into multiple ConfigMaps**:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: config-part-1
data:
  config-section-1: |
    ... (large config)

---
apiVersion: v1
kind: ConfigMap
metadata:
  name: config-part-2
data:
  config-section-2: |
    ... (large config)

# Use both in Pod
volumes:
- name: config1
  configMap:
    name: config-part-1
- name: config2
  configMap:
    name: config-part-2
```

**2. Use external configuration store**:
```yaml
# Store config URL in ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: config-url
data:
  config_location: "s3://bucket/config/large-config.json"

# Fetch in init container
initContainers:
- name: fetch-config
  image: amazon/aws-cli
  command:
  - sh
  - -c
  - aws s3 cp $(cat /config-url/config_location) /config/
  volumeMounts:
  - name: config-url
    mountPath: /config-url
  - name: config
    mountPath: /config
```

---

## Secret Issues

### Issue 5: Secret Not Found

**Symptoms**:
```
Error: secrets "db-credentials" not found
Warning: FailedMount: MountVolume.SetUp failed for volume "secret-volume"
```

**Diagnosis**:
```bash
# Check if Secret exists
kubectl get secret db-credentials

# Check in correct namespace
kubectl get secret db-credentials -n production

# List all Secrets
kubectl get secrets --all-namespaces
```

**Solutions**:

**1. Create the Secret**:
```bash
kubectl create secret generic db-credentials \
  --from-literal=username=admin \
  --from-literal=password=secretpass
```

**2. Verify namespace match**:
```bash
# Pod and Secret must be in same namespace
kubectl get pod mypod -o jsonpath='{.metadata.namespace}'
kubectl get secret db-credentials -o jsonpath='{.metadata.namespace}'
```

---

### Issue 6: Cannot Decode Secret Values

**Symptoms**:
- Base64 encoded values are garbled
- Decoding returns incorrect values
- Special characters not handled properly

**Diagnosis**:
```bash
# Get encoded value
kubectl get secret db-credentials -o jsonpath='{.data.password}'

# Decode
kubectl get secret db-credentials -o jsonpath='{.data.password}' | base64 -d
```

**Common Issues**:

**1. Newline in encoded value**:
```bash
# Wrong - includes newline
echo 'mypassword' | base64

# Correct - no newline
echo -n 'mypassword' | base64
```

**2. Special characters not escaped**:
```bash
# When creating Secret with special chars
kubectl create secret generic db-credentials \
  --from-literal=password='P@$$w0rd!'  # Use single quotes
```

**3. Verify decoding**:
```bash
# Create and verify
PASSWORD='MyP@$$w0rd!'
kubectl create secret generic test-secret \
  --from-literal=password="$PASSWORD"

# Verify
DECODED=$(kubectl get secret test-secret -o jsonpath='{.data.password}' | base64 -d)
if [ "$PASSWORD" = "$DECODED" ]; then
  echo "✓ Password matches"
else
  echo "✗ Password mismatch"
fi
```

---

### Issue 7: Permission Denied - Cannot Access Secret

**Symptoms**:
```
Error: secrets "db-credentials" is forbidden
User "system:serviceaccount:default:myapp-sa" cannot get resource "secrets"
```

**Diagnosis**:
```bash
# Check ServiceAccount
kubectl get pod mypod -o jsonpath='{.spec.serviceAccountName}'

# Check permissions
kubectl auth can-i get secrets \
  --as=system:serviceaccount:default:myapp-sa

# List roles for ServiceAccount
kubectl get rolebindings,clusterrolebindings \
  --all-namespaces -o json | \
  jq '.items[] | select(.subjects[]? | select(.name=="myapp-sa"))'
```

**Solutions**:

**1. Create Role with Secret access**:
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: secret-reader
  namespace: default
rules:
- apiGroups: [""]
  resources: ["secrets"]
  resourceNames: ["db-credentials"]  # Specific Secret
  verbs: ["get", "list"]
```

**2. Create RoleBinding**:
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-db-credentials
  namespace: default
subjects:
- kind: ServiceAccount
  name: myapp-sa
  namespace: default
roleRef:
  kind: Role
  name: secret-reader
  apiGroup: rbac.authorization.k8s.io
```

**3. Apply and verify**:
```bash
kubectl apply -f role.yaml
kubectl apply -f rolebinding.yaml

# Verify
kubectl auth can-i get secrets \
  --as=system:serviceaccount:default:myapp-sa
```

---

### Issue 8: Secret Values Not Base64 Encoded

**Symptoms**:
- Creating Secret with `data` field fails
- Values appear as plain text in Secret

**Diagnosis**:
```bash
kubectl get secret mysecret -o yaml
```

**Solution**:

**Use `stringData` instead of `data`**:
```yaml
# Wrong - requires base64 encoding
apiVersion: v1
kind: Secret
metadata:
  name: mysecret
type: Opaque
data:
  password: mypassword  # ERROR: Not base64 encoded

---
# Correct - auto-encodes
apiVersion: v1
kind: Secret
metadata:
  name: mysecret
type: Opaque
stringData:
  password: mypassword  # OK: Will be base64 encoded

---
# Or manually encode
apiVersion: v1
kind: Secret
metadata:
  name: mysecret
type: Opaque
data:
  password: bXlwYXNzd29yZA==  # echo -n 'mypassword' | base64
```

---

## Environment Variable Issues

### Issue 9: Environment Variable Not Set

**Symptoms**:
- `env` command shows variable missing
- Application can't find configuration
- Variable is empty string

**Diagnosis**:
```bash
# Check environment in Pod
kubectl exec mypod -- env | sort

# Check specific variable
kubectl exec mypod -- env | grep DB_PASSWORD

# Check Pod spec
kubectl get pod mypod -o yaml | grep -A 10 env:
```

**Solutions**:

**1. Verify ConfigMap/Secret key exists**:
```bash
kubectl get configmap app-config -o jsonpath='{.data}'
kubectl get secret db-credentials -o jsonpath='{.data}' | base64 -d
```

**2. Check env variable definition**:
```yaml
env:
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: db-credentials
      key: password  # Must exist in Secret
```

**3. Check for typos**:
```yaml
# Common mistakes
secretKeyRef:
  name: db-credential   # Missing 's'
  key: pasword          # Missing 's'
```

---

### Issue 10: Environment Variable Name Conflicts

**Symptoms**:
- Variables overwriting each other
- Unexpected variable values
- Only last defined variable value appears

**Diagnosis**:
```bash
kubectl exec mypod -- env | grep -i database
```

**Solution**:

**Use prefixes with envFrom**:
```yaml
envFrom:
- configMapRef:
    name: app-config
  prefix: APP_      # Prefix all keys

- secretRef:
    name: db-credentials
  prefix: DB_       # Different prefix

# Results in:
# APP_log_level=info
# DB_password=secret
```

---

## Volume Mount Issues

### Issue 11: Mounted Files Not Visible

**Symptoms**:
- Directory is empty
- Files don't appear at mount path
- `ls` shows nothing

**Diagnosis**:
```bash
# Check mount
kubectl exec mypod -- ls -la /etc/config

# Check volume definition
kubectl get pod mypod -o yaml | grep -A 20 volumes:

# Check Pod events
kubectl describe pod mypod | grep -A 10 Events:
```

**Solutions**:

**1. Verify volume mount syntax**:
```yaml
volumeMounts:
- name: config-volume     # Must match volume name
  mountPath: /etc/config
volumes:
- name: config-volume     # Must match volumeMount name
  configMap:
    name: app-config
```

**2. Check ConfigMap exists and has data**:
```bash
kubectl describe configmap app-config
```

**3. Verify mount path doesn't overwrite existing directory**:
```yaml
# If /etc/config exists in image, it will be hidden
# Use different path or subPath
volumeMounts:
- name: config
  mountPath: /etc/config/app.conf
  subPath: app.conf  # Mount single file
```

---

### Issue 12: SubPath Mount Not Working

**Symptoms**:
- Single file mount creates directory instead
- File content is wrong
- Multiple files appear instead of one

**Diagnosis**:
```bash
kubectl exec mypod -- ls -la /app/config/
kubectl exec mypod -- cat /app/config/app.properties
```

**Solution**:

**Correct subPath usage**:
```yaml
# Wrong
volumeMounts:
- name: config
  mountPath: /app/config/
  subPath: app.properties  # Wrong: trailing slash on mountPath

# Correct
volumeMounts:
- name: config
  mountPath: /app/config/app.properties  # File path
  subPath: app.properties                 # Key from ConfigMap

volumes:
- name: config
  configMap:
    name: app-config
    # app.properties must exist as key in ConfigMap
```

---

### Issue 13: Volume Permissions Issues

**Symptoms**:
```
Permission denied when accessing mounted files
ls: cannot access '/etc/config': Permission denied
```

**Diagnosis**:
```bash
# Check file permissions
kubectl exec mypod -- ls -la /etc/config

# Check Pod security context
kubectl get pod mypod -o yaml | grep -A 10 securityContext:
```

**Solutions**:

**1. Set defaultMode on volume**:
```yaml
volumes:
- name: config
  configMap:
    name: app-config
    defaultMode: 0644  # Readable by all
```

**2. Set specific file modes**:
```yaml
volumes:
- name: config
  configMap:
    name: app-config
    items:
    - key: app.properties
      path: app.properties
      mode: 0600  # Owner read/write only
```

**3. Set securityContext**:
```yaml
spec:
  securityContext:
    fsGroup: 1000        # Group ID
    runAsUser: 1000      # User ID
  containers:
  - name: app
    volumeMounts:
    - name: config
      mountPath: /etc/config
```

---

## Update and Sync Issues

### Issue 14: Slow ConfigMap/Secret Updates

**Symptoms**:
- Changes take several minutes to appear
- Inconsistent update times across Pods
- Some Pods have old config, some have new

**Root Cause**:
Kubelet syncs ConfigMaps/Secrets periodically (default: every 1 minute)

**Diagnosis**:
```bash
# Check kubelet sync frequency
kubectl get node  -o yaml | grep sync-frequency

# Monitor file updates
kubectl exec mypod -- watch -n 1 cat /etc/config/key
```

**Solutions**:

**1. Force Pod restart for immediate update**:
```bash
kubectl delete pod mypod
# Or
kubectl rollout restart deployment myapp
```

**2. Use immutable ConfigMaps with versioning**:
```yaml
# Create new version
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config-v2
immutable: true
data:
  key: new-value

# Update Deployment
spec:
  template:
    spec:
      volumes:
      - name: config
        configMap:
          name: app-config-v2  # New version
```

**3. Implement config file watching in application**:
```go
// Example: Watch config file for changes
watcher, _ := fsnotify.NewWatcher()
watcher.Add("/etc/config/app.conf")

for {
    select {
    case event := <-watcher.Events:
        if event.Op&fsnotify.Write == fsnotify.Write {
            reloadConfig()
        }
    }
}
```

---

### Issue 15: Rolling Update Doesn't Pick Up New Config

**Symptoms**:
- Deployment rolled out but Pods use old config
- New Pods have old configuration
- Rollout completes but no config change

**Root Cause**:
Pod template doesn't change, so no rolling update triggered.

**Solutions**:

**1. Add annotation to force update**:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  template:
    metadata:
      annotations:
        # Change this to trigger rolling update
        configmap-version: "v2"
```

**2. Use ConfigMap checksum**:
```bash
# Calculate ConfigMap checksum
CHECKSUM=$(kubectl get configmap app-config -o yaml | sha256sum | cut -d' ' -f1)

# Update Deployment with checksum
kubectl patch deployment myapp -p \
  "{\"spec\":{\"template\":{\"metadata\":{\"annotations\":{\"configmap-checksum\":\"$CHECKSUM\"}}}}}"
```

**3. Use Helm with built-in checksums**:
```yaml
# In Helm template
metadata:
  annotations:
    checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
```

---

## Common Errors

### Error 1: "MountVolume.SetUp failed"

**Full Error**:
```
MountVolume.SetUp failed for volume "config-volume" : 
configmap "app-config" not found
```

**Solution**: Create ConfigMap before deploying Pod:
```bash
kubectl create configmap app-config --from-literal=key=value
kubectl apply -f pod.yaml
```

---

### Error 2: "error: error validating data"

**Full Error**:
```
error: error validating data: 
ValidationError(ConfigMap.data): invalid type for io.k8s.api.core.v1.ConfigMap.data: 
got "string", expected "map"
```

**Cause**: Incorrect YAML indentation

**Solution**:
```yaml
# Wrong
data:
  "key: value"

# Correct
data:
  key: value
```

---

### Error 3: "spec.containers[0].env[0].name: Required value"

**Cause**: Missing environment variable name

**Solution**:
```yaml
# Wrong
env:
- valueFrom:
    configMapKeyRef:
      name: app-config
      key: log_level

# Correct
env:
- name: LOG_LEVEL  # Required
  valueFrom:
    configMapKeyRef:
      name: app-config
      key: log_level
```

---

### Error 4: "invalid base64 data"

**Full Error**:
```
error: error parsing secret-data.yaml: 
error converting YAML to JSON: invalid base64 data
```

**Solution**:
```yaml
# Use stringData instead
apiVersion: v1
kind: Secret
metadata:
  name: mysecret
stringData:
  password: my-plain-text-password

# Or properly encode data
data:
  password: bXktcGxhaW4tdGV4dC1wYXNzd29yZA==
```

---

## Performance Issues

### Issue 16: Too Many ConfigMaps/Secrets

**Symptoms**:
- API server slow
- etcd storage issues
- Slow Pod startup times

**Diagnosis**:
```bash
# Count ConfigMaps
kubectl get configmaps --all-namespaces --no-headers | wc -l

# Count Secrets
kubectl get secrets --all-namespaces --no-headers | wc -l

# Check etcd size
kubectl get --raw /metrics | grep etcd_db_total_size_in_bytes
```

**Solutions**:

**1. Consolidate ConfigMaps**:
```yaml
# Instead of multiple ConfigMaps
# app-config-1, app-config-2, app-config-3

# Use one ConfigMap with multiple keys
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  config-1: |
    ...
  config-2: |
    ...
  config-3: |
    ...
```

**2. Use external configuration store**:
- Store large configs in Git, S3, etc.
- Fetch at runtime using init containers

**3. Clean up unused ConfigMaps/Secrets**:
```bash
# Find unused ConfigMaps
for cm in $(kubectl get configmap -o name); do
  name=$(echo $cm | cut -d/ -f2)
  if ! kubectl get pods --all-namespaces -o yaml | grep -q "$name"; then
    echo "Unused: $name"
  fi
done
```

---

## Debugging Checklist

### ConfigMap Debugging
- [ ] ConfigMap exists in correct namespace
- [ ] ConfigMap has expected data keys
- [ ] Pod spec references correct ConfigMap name
- [ ] Key names match exactly (case-sensitive)
- [ ] Volume mount path is correct
- [ ] For env vars: Pod has been restarted after ConfigMap update

### Secret Debugging
- [ ] Secret exists in correct namespace
- [ ] Secret data is properly base64 encoded
- [ ] ServiceAccount has permission to access Secret
- [ ] Pod spec references correct Secret name
- [ ] Key names match exactly
- [ ] For Docker secrets: imagePullSecrets is specified

### General Debugging Commands
```bash
# Describe resources
kubectl describe configmap 
kubectl describe secret 
kubectl describe pod 

# Check logs
kubectl logs 

# Check events
kubectl get events --sort-by='.lastTimestamp'

# Exec into Pod
kubectl exec -it  -- sh

# Check RBAC
kubectl auth can-i get secrets --as=system:serviceaccount:namespace:sa-name
```

---

## Quick Fixes

### Quick Fix 1: Force ConfigMap Reload
```bash
kubectl rollout restart deployment/
```

### Quick Fix 2: Verify Secret Access
```bash
kubectl auth can-i get secrets \
  --as=system:serviceaccount:$(kubectl get pod  -o jsonpath='{.metadata.namespace}'):$(kubectl get pod  -o jsonpath='{.spec.serviceAccountName}')
```

### Quick Fix 3: Test ConfigMap in Temporary Pod
```bash
kubectl run test --rm -it --restart=Never \
  --image=busybox \
  --overrides='{"spec":{"containers":[{"name":"test","image":"busybox","command":["sh"],"envFrom":[{"configMapRef":{"name":"app-config"}}]}]}}' \
  -- sh -c "env | sort"
```

### Quick Fix 4: Decode All Secret Values
```bash
kubectl get secret  -o json | \
  jq -r '.data | to_entries[] | "\(.key): \(.value | @base64d)"'
```

---

## Prevention Best Practices

1. **Use Descriptive Names**: `app-config-prod`, not `config1`
2. **Document ConfigMaps/Secrets**: Add labels and annotations
3. **Version Control**: Store YAML in Git (not Secret values!)
4. **Use Namespaces**: Isolate environments
5. **Implement RBAC**: Least privilege access
6. **Enable Encryption at Rest**: For Secrets
7. **Monitor Changes**: Set up alerts for config changes
8. **Test in Dev First**: Never test directly in production
9. **Automate Backups**: Regular ConfigMap/Secret backups
10. **Use External Secret Managers**: Vault, AWS Secrets Manager, etc.

---

## Additional Resources

- [Kubernetes ConfigMap Documentation](https://kubernetes.io/docs/concepts/configuration/configmap/)
- [Kubernetes Secret Documentation](https://kubernetes.io/docs/concepts/configuration/secret/)
- [RBAC Documentation](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- [External Secrets Operator](https://external-secrets.io/)

---

**Remember**: Configuration issues are often namespace-related. Always verify that resources are in the same namespace!
