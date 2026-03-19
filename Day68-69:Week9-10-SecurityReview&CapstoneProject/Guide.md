# 📖 GUIDEME: Security Capstone - Day 68-69

## 🎯 Complete Walkthrough (8-10 hours)

This is your **final security project** - building SecureShop with complete security hardening.

---

## Phase 1: Environment Setup (30 min)

### Create Namespace
```bash
# Create namespace with Pod Security label
kubectl create namespace secureshop

kubectl label namespace secureshop \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/audit=restricted \
  pod-security.kubernetes.io/warn=restricted

# Verify
kubectl get namespace secureshop --show-labels
```

**✅ Checkpoint:** Namespace created with restricted PSS.

---

## Phase 2: RBAC Configuration (1 hour)

### Create ServiceAccounts
```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: frontend-sa
  namespace: secureshop
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: backend-sa
  namespace: secureshop
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: database-sa
  namespace: secureshop
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: redis-sa
  namespace: secureshop
EOF
```

### Create Roles
```bash
# Frontend Role: Read ConfigMaps
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: frontend-role
  namespace: secureshop
rules:
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get", "list"]
- apiGroups: [""]
  resources: ["pods", "pods/log"]
  verbs: ["get", "list"]
EOF

# Backend Role: Read Secrets
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: backend-role
  namespace: secureshop
rules:
- apiGroups: [""]
  resources: ["secrets"]
  resourceNames: ["db-credentials", "api-keys"]
  verbs: ["get"]
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get", "list"]
EOF

# Create RoleBindings
kubectl create rolebinding frontend-binding \
  --role=frontend-role \
  --serviceaccount=secureshop:frontend-sa \
  -n secureshop

kubectl create rolebinding backend-binding \
  --role=backend-role \
  --serviceaccount=secureshop:backend-sa \
  -n secureshop
```

### Test RBAC
```bash
# Backend should access secrets
kubectl auth can-i get secrets \
  --as=system:serviceaccount:secureshop:backend-sa \
  -n secureshop
# yes

# Frontend should NOT
kubectl auth can-i get secrets \
  --as=system:serviceaccount:secureshop:frontend-sa \
  -n secureshop
# no
```

**✅ Checkpoint:** RBAC configured and tested.

---

## Phase 3: Secrets Management (1 hour)

### Create Secrets
```bash
# Database credentials
kubectl create secret generic db-credentials \
  -n secureshop \
  --from-literal=username=shopuser \
  --from-literal=password=SecurePass123!

# API keys
kubectl create secret generic api-keys \
  -n secureshop \
  --from-literal=stripe-key=sk_test_xxx \
  --from-literal=sendgrid-key=SG.xxx
```

**✅ Checkpoint:** Secrets created.

---

## Phase 4: Network Policies (1 hour)

### Deploy Network Policies
```bash
# 1. Default deny-all
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: secureshop
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
EOF

# 2. Allow DNS
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
  namespace: secureshop
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: kube-system
    ports:
    - protocol: UDP
      port: 53
EOF

# 3. Frontend ingress from Ingress controller
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: frontend-ingress
  namespace: secureshop
spec:
  podSelector:
    matchLabels:
      tier: frontend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
    ports:
    - protocol: TCP
      port: 80
EOF

# 4. Frontend → Backend
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: frontend-to-backend
  namespace: secureshop
spec:
  podSelector:
    matchLabels:
      tier: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          tier: frontend
    ports:
    - protocol: TCP
      port: 8080
EOF

# 5. Backend → Database
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-to-database
  namespace: secureshop
spec:
  podSelector:
    matchLabels:
      tier: database
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          tier: backend
    ports:
    - protocol: TCP
      port: 5432
EOF

# 6. Backend → Redis
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-to-redis
  namespace: secureshop
spec:
  podSelector:
    matchLabels:
      tier: redis
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          tier: backend
    ports:
    - protocol: TCP
      port: 6379
EOF
```

**✅ Checkpoint:** Network policies deployed (zero-trust).

---

## Phase 5: Deploy Application (2 hours)

### Database
```bash
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: database
  namespace: secureshop
spec:
  serviceName: database
  replicas: 1
  selector:
    matchLabels:
      app: database
      tier: database
  template:
    metadata:
      labels:
        app: database
        tier: database
    spec:
      serviceAccountName: database-sa
      securityContext:
        runAsNonRoot: true
        runAsUser: 999
        fsGroup: 999
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: postgres
        image: postgres:15-alpine
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop:
            - ALL
        env:
        - name: POSTGRES_USER
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: username
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: password
        - name: POSTGRES_DB
          value: secureshop
        ports:
        - containerPort: 5432
        volumeMounts:
        - name: data
          mountPath: /var/lib/postgresql/data
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 1Gi
---
apiVersion: v1
kind: Service
metadata:
  name: database
  namespace: secureshop
spec:
  selector:
    app: database
  ports:
  - port: 5432
  clusterIP: None
EOF
```

### Redis
```bash
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis
  namespace: secureshop
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis
      tier: redis
  template:
    metadata:
      labels:
        app: redis
        tier: redis
    spec:
      serviceAccountName: redis-sa
      securityContext:
        runAsNonRoot: true
        runAsUser: 999
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: redis
        image: redis:7-alpine
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop:
            - ALL
        ports:
        - containerPort: 6379
---
apiVersion: v1
kind: Service
metadata:
  name: redis
  namespace: secureshop
spec:
  selector:
    app: redis
  ports:
  - port: 6379
EOF
```

### Backend
```bash
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: secureshop
spec:
  replicas: 3
  selector:
    matchLabels:
      app: backend
      tier: backend
  template:
    metadata:
      labels:
        app: backend
        tier: backend
    spec:
      serviceAccountName: backend-sa
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 1000
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: api
        image: your-registry/secureshop-backend:v1.0
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - ALL
        env:
        - name: DB_HOST
          value: database
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
        - name: REDIS_HOST
          value: redis
        ports:
        - containerPort: 8080
        volumeMounts:
        - name: tmp
          mountPath: /tmp
      volumes:
      - name: tmp
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: backend
  namespace: secureshop
spec:
  selector:
    app: backend
  ports:
  - port: 8080
EOF
```

### Frontend
```bash
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: secureshop
spec:
  replicas: 3
  selector:
    matchLabels:
      app: frontend
      tier: frontend
  template:
    metadata:
      labels:
        app: frontend
        tier: frontend
    spec:
      serviceAccountName: frontend-sa
      securityContext:
        runAsNonRoot: true
        runAsUser: 101
        fsGroup: 101
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: nginx
        image: your-registry/secureshop-frontend:v1.0
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - ALL
        ports:
        - containerPort: 8080
        volumeMounts:
        - name: cache
          mountPath: /var/cache/nginx
        - name: run
          mountPath: /var/run
      volumes:
      - name: cache
        emptyDir: {}
      - name: run
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: frontend
  namespace: secureshop
spec:
  selector:
    app: frontend
  ports:
  - port: 80
    targetPort: 8080
EOF
```

**✅ Checkpoint:** Application deployed.

---

## Phase 6: Security Validation (1 hour)

### Test Security
```bash
# Check all pods running
kubectl get pods -n secureshop

# Verify non-root
kubectl get pods -n secureshop -o json | \
  jq -r '.items[] | "\(.metadata.name): UID=\(.spec.securityContext.runAsUser)"'

# Test network policies
FRONTEND=$(kubectl get pod -n secureshop -l tier=frontend -o jsonpath='{.items[0].metadata.name}')
BACKEND=$(kubectl get pod -n secureshop -l tier=backend -o jsonpath='{.items[0].metadata.name}')

# Frontend → Backend (should work)
kubectl exec -n secureshop $FRONTEND -- curl -s http://backend:8080/health

# Frontend → Database (should timeout)
kubectl exec -n secureshop $FRONTEND -- timeout 3 nc -zv database 5432

# Backend → Database (should work)
kubectl exec -n secureshop $BACKEND -- nc -zv database 5432
```

**✅ Checkpoint:** Security validated.

---

## ✅ Final Checklist

- [ ] Namespace with restricted PSS
- [ ] 4 ServiceAccounts created
- [ ] RBAC roles configured
- [ ] Secrets encrypted
- [ ] 6 Network policies deployed
- [ ] All pods running as non-root
- [ ] Read-only filesystems
- [ ] Network isolation tested
- [ ] Application accessible
- [ ] Security audit passed

---

**Congratulations! You've built a production-grade secure application! 🔒🚀**
