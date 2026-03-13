# 📖 GUIDEME: Pod Security Standards - Complete Walkthrough

## 🎯 16-Hour Learning Path

**Day 1:** Understanding profiles, namespace configuration (8 hours)
**Day 2:** Enforcement, migration, production setup (8 hours)

---

## Phase 1: Understanding Security Profiles (2 hours)

### Step 1: Create Test Namespaces
```bash
# Privileged namespace
kubectl create namespace pss-privileged
kubectl label namespace pss-privileged \
  pod-security.kubernetes.io/enforce=privileged \
  pod-security.kubernetes.io/audit=privileged \
  pod-security.kubernetes.io/warn=privileged

# Baseline namespace
kubectl create namespace pss-baseline
kubectl label namespace pss-baseline \
  pod-security.kubernetes.io/enforce=baseline \
  pod-security.kubernetes.io/audit=baseline \
  pod-security.kubernetes.io/warn=baseline

# Restricted namespace
kubectl create namespace pss-restricted
kubectl label namespace pss-restricted \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/audit=restricted \
  pod-security.kubernetes.io/warn=restricted

# Verify
kubectl get namespaces --show-labels | grep pss
```

**✅ Checkpoint:** Three namespaces with different profiles created.

---

## Phase 2: Test Privileged Profile (1 hour)

### Deploy Privileged Pod
```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: privileged-pod
  namespace: pss-privileged
spec:
  containers:
  - name: nginx
    image: nginx
    securityContext:
      privileged: true  # Dangerous!
EOF

# Check status
kubectl get pod -n pss-privileged privileged-pod
# Should be Running (privileged profile allows everything)

# Try in baseline namespace
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: privileged-pod
  namespace: pss-baseline
spec:
  containers:
  - name: nginx
    image: nginx
    securityContext:
      privileged: true
EOF

# Should be REJECTED!
# Error: violates PodSecurity "baseline:latest"
```

**✅ Checkpoint:** Privileged profile allows dangerous pods, baseline blocks them.

---

## Phase 3: Test Baseline Profile (2 hours)

### Test Various Violations
```bash
# 1. Privileged container (should fail)
kubectl run test-privileged -n pss-baseline --image=nginx \
  --overrides='{"spec":{"containers":[{"name":"nginx","image":"nginx","securityContext":{"privileged":true}}]}}'
# Error: privileged

# 2. Host network (should fail)
kubectl run test-hostnet -n pss-baseline --image=nginx \
  --overrides='{"spec":{"hostNetwork":true}}'
# Error: host namespaces

# 3. Running as root (should SUCCEED in baseline!)
kubectl run test-root -n pss-baseline --image=nginx
kubectl get pod -n pss-baseline test-root
# Running (baseline allows root)

kubectl exec -n pss-baseline test-root -- id
# uid=0(root) - Allowed in baseline!

# Cleanup
kubectl delete pod -n pss-baseline test-root
```

**✅ Checkpoint:** Baseline prevents major violations but allows root.

---

## Phase 4: Test Restricted Profile (2 hours)

### Deploy Non-Compliant Pod
```bash
# Try running as root (should fail in restricted)
kubectl run test-root -n pss-restricted --image=nginx
# Error: runAsNonRoot, allowPrivilegeEscalation, seccompProfile
```

### Deploy Compliant Pod
```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: restricted-compliant
  namespace: pss-restricted
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    fsGroup: 2000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: nginx
    image: nginx:1.21
    securityContext:
      allowPrivilegeEscalation: false
      runAsNonRoot: true
      capabilities:
        drop:
        - ALL
    ports:
    - containerPort: 8080
EOF

# Check status
kubectl get pod -n pss-restricted restricted-compliant
# Should be Running

# Verify security
kubectl exec -n pss-restricted restricted-compliant -- id
# uid=1000 (non-root!)

kubectl exec -n pss-restricted restricted-compliant -- capsh --print
# No capabilities!
```

**✅ Checkpoint:** Restricted profile enforces hardened security.

---

## Phase 5: Multi-Mode Configuration (2 hours)

### Create Gradual Rollout Namespace
```bash
kubectl create namespace pss-gradual
kubectl label namespace pss-gradual \
  pod-security.kubernetes.io/enforce=baseline \
  pod-security.kubernetes.io/audit=restricted \
  pod-security.kubernetes.io/warn=restricted

# Deploy baseline-compliant pod (should work)
kubectl run baseline-pod -n pss-gradual --image=nginx

# Check for warnings
kubectl get pod -n pss-gradual baseline-pod
# Pod runs but you'll see warnings about restricted violations

# View audit events (if audit logging enabled)
kubectl get events -n pss-gradual
```

**✅ Checkpoint:** Multi-mode allows gradual policy tightening.

---

## Phase 6: Profile Comparison (2 hours)

### Deploy Same Pod to All Namespaces
```bash
# Create test pod spec
cat > test-pod.yaml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: security-test
spec:
  containers:
  - name: nginx
    image: nginx
    securityContext:
      runAsUser: 0  # Root
EOF

# Try in privileged
kubectl apply -f test-pod.yaml -n pss-privileged
kubectl get pod -n pss-privileged security-test
# Running ✅

# Try in baseline
kubectl apply -f test-pod.yaml -n pss-baseline
kubectl get pod -n pss-baseline security-test
# Running ✅ (baseline allows root)

# Try in restricted
kubectl apply -f test-pod.yaml -n pss-restricted
# Error ❌ (restricted requires non-root)

# Cleanup
kubectl delete -f test-pod.yaml -n pss-privileged
kubectl delete -f test-pod.yaml -n pss-baseline
rm test-pod.yaml
```

**✅ Checkpoint:** Understand profile differences.

---

## Phase 7: Production Deployment Pattern (3 hours)

### Create Production Namespace
```bash
kubectl create namespace production
kubectl label namespace production \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/audit=restricted \
  pod-security.kubernetes.io/warn=restricted
```

### Deploy Secure Application
```bash
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: secure-app
  namespace: production
spec:
  replicas: 3
  selector:
    matchLabels:
      app: secure-app
  template:
    metadata:
      labels:
        app: secure-app
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 2000
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: app
        image: nginx:1.21
        securityContext:
          allowPrivilegeEscalation: false
          runAsNonRoot: true
          capabilities:
            drop:
            - ALL
        ports:
        - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: secure-app
  namespace: production
spec:
  selector:
    app: secure-app
  ports:
  - port: 80
    targetPort: 8080
EOF

# Verify deployment
kubectl get deployment -n production secure-app
kubectl get pods -n production -l app=secure-app

# Test
kubectl run test -n production --rm -it --image=busybox -- wget -qO- http://secure-app
```

**✅ Checkpoint:** Production deployment with restricted profile.

---

## Phase 8: Violation Testing (2 hours)

### Create Violations and Observe
```bash
# Test 1: Missing runAsNonRoot
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: missing-runasnonroot
  namespace: pss-restricted
spec:
  containers:
  - name: nginx
    image: nginx
    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop:
        - ALL
EOF
# Error: runAsNonRoot != true

# Test 2: Missing capabilities drop
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: missing-caps-drop
  namespace: pss-restricted
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
  containers:
  - name: nginx
    image: nginx
    securityContext:
      allowPrivilegeEscalation: false
EOF
# Error: must drop ALL capabilities

# Test 3: Missing seccompProfile
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: missing-seccomp
  namespace: pss-restricted
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
  containers:
  - name: nginx
    image: nginx
    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop:
        - ALL
EOF
# Error: seccompProfile
```

**✅ Checkpoint:** Understand all restricted requirements.

---

## Phase 9: Namespace Audit (2 hours)

### Audit All Namespaces
```bash
# List all namespace security levels
kubectl get namespaces -o json | \
  jq -r '.items[] | 
    "\(.metadata.name): enforce=\(.metadata.labels["pod-security.kubernetes.io/enforce"] // "none")"'

# Find namespaces without PSS
kubectl get namespaces -o json | \
  jq -r '.items[] | select(.metadata.labels["pod-security.kubernetes.io/enforce"] == null) | 
    .metadata.name'

# Create audit script
cat > audit-pss.sh <<'SCRIPT'
#!/bin/bash
echo "=== Pod Security Standards Audit ==="

echo -e "\nNamespaces by security level:"
echo "Privileged:"
kubectl get ns -l pod-security.kubernetes.io/enforce=privileged -o name

echo -e "\nBaseline:"
kubectl get ns -l pod-security.kubernetes.io/enforce=baseline -o name

echo -e "\nRestricted:"
kubectl get ns -l pod-security.kubernetes.io/enforce=restricted -o name

echo -e "\nNo PSS (⚠️):"
kubectl get ns -o json | \
  jq -r '.items[] | select(.metadata.labels["pod-security.kubernetes.io/enforce"] == null) | 
    .metadata.name'

echo -e "\n=== Audit Complete ==="
SCRIPT

chmod +x audit-pss.sh
./audit-pss.sh
```

**✅ Checkpoint:** Cluster audit complete.

---

## ✅ Final Validation

### Checklist
- [ ] Created namespaces with all three profiles
- [ ] Tested privileged profile (allows everything)
- [ ] Tested baseline profile (prevents major violations)
- [ ] Tested restricted profile (enforces hardening)
- [ ] Deployed compliant pods to restricted namespace
- [ ] Used multi-mode configuration (enforce/audit/warn)
- [ ] Created production deployment with restricted
- [ ] Tested various violations
- [ ] Audited all namespaces

### Cleanup (Optional)
```bash
kubectl delete namespace pss-privileged pss-baseline pss-restricted pss-gradual production
rm audit-pss.sh
```

---

**Congratulations! You've mastered Pod Security Standards! 🔒🚀**
