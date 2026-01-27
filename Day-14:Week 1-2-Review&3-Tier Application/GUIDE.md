Week 1-2 Review: Complete Kubernetes Core Concepts Guide

Comprehensive review of Days 1-15 with production-ready 3-tier application


Table of Contents

Week 1 Review: Foundation
Week 2 Review: Organization & Configuration
Integration Patterns
3-Tier Application Architecture
Best Practices Consolidated
Production Readiness Checklist
Common Patterns & Anti-Patterns


Week 1 Review: Foundation
Day 1-2: Kubernetes Architecture
Control Plane Components
1. API Server (kube-apiserver)
Role: Frontend for Kubernetes control plane
- Exposes Kubernetes API
- Validates and processes REST requests
- Updates etcd
- Only component that talks to etcd directly

Key Points:
✓ All kubectl commands go through API server
✓ Stateless - can scale horizontally
✓ Authenticates and authorizes requests
✓ Implements RBAC
2. etcd
Role: Distributed key-value store
- Stores all cluster data
- Source of truth for cluster state
- Highly available (typically 3-5 nodes)

Key Points:
✓ Use separate etcd cluster in production
✓ Regular backups critical
✓ Only API server reads/writes to etcd
✓ Uses Raft consensus algorithm
3. Scheduler (kube-scheduler)
Role: Assigns pods to nodes
- Watches for unscheduled pods
- Selects optimal node based on:
  • Resource requirements
  • Node affinity/anti-affinity
  • Taints and tolerations
  • Data locality

Key Points:
✓ Doesn't actually run the pod
✓ Just updates API server with node assignment
✓ kubelet then runs the pod
4. Controller Manager
Role: Runs controller processes
- Node Controller: Monitors node health
- Replication Controller: Maintains replica count
- Endpoints Controller: Populates endpoints
- Service Account Controller: Creates default accounts

Key Points:
✓ Watch-loop pattern
✓ Reconciliation: desired state → actual state
✓ Single binary, multiple controllers
Worker Node Components
1. kubelet
Role: Node agent
- Registers node with API server
- Watches for pod assignments
- Runs containers via container runtime
- Reports pod/node status
- Runs liveness/readiness probes

Key Points:
✓ Runs on every node
✓ Doesn't manage containers not created by K8s
✓ Uses CRI (Container Runtime Interface)
2. kube-proxy
Role: Network proxy on each node
- Maintains network rules (iptables/ipvs)
- Enables service abstraction
- Load balances across pods

Modes:
- iptables (default): NAT rules
- ipvs: Better performance at scale
- userspace: Legacy, rarely used
3. Container Runtime
Role: Runs containers
Supported:
- containerd (most common)
- CRI-O
- Docker (deprecated as of v1.24)

Key Points:
✓ Uses CRI (Container Runtime Interface)
✓ Pulls images
✓ Manages container lifecycle

Day 3-4: Pods & ReplicaSets
Pods Deep Dive
What is a Pod?
Smallest deployable unit in Kubernetes
- One or more containers
- Shared network namespace
- Shared storage volumes
- Scheduled together on same node
Pod Lifecycle States
Pending    → Waiting for scheduling
Running    → At least one container running
Succeeded  → All containers terminated successfully
Failed     → All containers terminated, at least one failed
Unknown    → State cannot be determined
Multi-Container Pod Patterns
1. Sidecar Pattern
yaml# Example: Logging sidecar
apiVersion: v1
kind: Pod
metadata:
  name: app-with-sidecar
spec:
  containers:
  - name: app
    image: myapp:1.0
    volumeMounts:
    - name: logs
      mountPath: /var/log
  
  - name: log-shipper
    image: fluentd:latest
    volumeMounts:
    - name: logs
      mountPath: /var/log
  
  volumes:
  - name: logs
    emptyDir: {}
2. Ambassador Pattern
yaml# Proxy for external services
containers:
- name: app
  image: myapp
  
- name: ambassador
  image: ambassador-proxy
  # Handles connection pooling, retries
3. Adapter Pattern
yaml# Standardize output
containers:
- name: app
  image: myapp
  
- name: adapter
  image: log-adapter
  # Converts app logs to standard format
Init Containers
yamlapiVersion: v1
kind: Pod
metadata:
  name: init-demo
spec:
  initContainers:
  - name: wait-for-db
    image: busybox
    command: ['sh', '-c', 'until nslookup db; do sleep 2; done']
  
  containers:
  - name: app
    image: myapp
    # Only starts after init containers succeed
Key Pod Concepts for Project:
✓ Each tier (frontend/backend/database) runs in pods
✓ Multiple replicas for high availability
✓ Init containers for database migration
✓ Sidecar for logging/monitoring
✓ Shared volumes for logs
ReplicaSets
Purpose:
Maintains stable set of replica pods
- Ensures specified number of pods running
- Replaces failed pods
- Scales horizontally
How it Works:
1. Define desired number of replicas
2. ReplicaSet controller watches pods
3. If too few: creates new pods
4. If too many: deletes excess pods
5. Uses label selector to identify pods
ReplicaSet vs Deployment:
ReplicaSet:
✓ Basic replication
✗ No rolling updates
✗ No rollback capability

Deployment (uses ReplicaSets):
✓ Rolling updates
✓ Rollback capability
✓ Update strategies
✓ Better for production
In Our Project:
We use Deployments, which create ReplicaSets
- Frontend: 3 replicas
- Backend: 5 replicas
- Database: StatefulSet (not ReplicaSet)

Day 5-6: Deployments
Deployment Strategies
1. Rolling Update (Default)
yamlapiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
spec:
  replicas: 5
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1        # Max pods above desired
      maxUnavailable: 0  # Min pods available
  template:
    spec:
      containers:
      - name: api
        image: backend:v2
Process:
1. Create 1 new pod (v2)
2. Wait for it to be ready
3. Terminate 1 old pod (v1)
4. Repeat until all updated
5. Zero downtime!
2. Recreate Strategy
yamlstrategy:
  type: Recreate
  # Kills all old pods, then creates new ones
  # Downtime occurs!
3. Blue-Green Deployment
yaml# Blue (current)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-blue
  labels:
    version: blue
spec:
  replicas: 5
  selector:
    matchLabels:
      app: myapp
      version: blue

---
# Green (new)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-green
  labels:
    version: green
spec:
  replicas: 5
  selector:
    matchLabels:
      app: myapp
      version: green

---
# Service switches between them
apiVersion: v1
kind: Service
metadata:
  name: myapp
spec:
  selector:
    app: myapp
    version: blue  # Change to 'green' to switch
4. Canary Deployment
yaml# Stable (90%)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-stable
spec:
  replicas: 9
  selector:
    matchLabels:
      app: myapp

---
# Canary (10%)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-canary
spec:
  replicas: 1
  selector:
    matchLabels:
      app: myapp
  template:
    spec:
      containers:
      - name: app
        image: myapp:v2  # New version

---
# Service selects both
apiVersion: v1
kind: Service
metadata:
  name: myapp
spec:
  selector:
    app: myapp  # Selects both stable and canary
Deployment Management
bash# Create deployment
kubectl create deployment backend --image=backend:v1 --replicas=5

# Update image (triggers rolling update)
kubectl set image deployment/backend api=backend:v2

# Check rollout status
kubectl rollout status deployment/backend

# View rollout history
kubectl rollout history deployment/backend

# Rollback to previous version
kubectl rollout undo deployment/backend

# Rollback to specific revision
kubectl rollout undo deployment/backend --to-revision=2

# Pause rollout
kubectl rollout pause deployment/backend

# Resume rollout
kubectl rollout resume deployment/backend
In Our 3-Tier Project:
Frontend Deployment:
- Rolling update strategy
- maxSurge: 1, maxUnavailable: 0
- Ensures zero downtime
- Gradual rollout

Backend Deployment:
- Rolling update strategy
- maxSurge: 2, maxUnavailable: 1
- Faster updates (more replicas)
- Can tolerate 1 pod down

Database:
- Uses StatefulSet (not Deployment)
- Ordered, graceful updates
- Data persistence critical

Day 7-8: Services & Networking
Service Types in Our Project
1. Frontend: LoadBalancer
yamlapiVersion: v1
kind: Service
metadata:
  name: frontend
  namespace: production
spec:
  type: LoadBalancer
  selector:
    app: frontend
    tier: web
  ports:
  - port: 80
    targetPort: 3000
    protocol: TCP

# Why LoadBalancer?
# ✓ External access from internet
# ✓ Cloud provider manages load balancer
# ✓ Gets public IP address
# ✓ Production standard
2. Backend: ClusterIP
yamlapiVersion: v1
kind: Service
metadata:
  name: backend
  namespace: production
spec:
  type: ClusterIP  # Default
  selector:
    app: backend
    tier: api
  ports:
  - port: 8080
    targetPort: 8080
    protocol: TCP

# Why ClusterIP?
# ✓ Internal only (not exposed externally)
# ✓ Frontend talks to backend internally
# ✓ More secure
# ✓ Better performance
3. Database: Headless Service
yamlapiVersion: v1
kind: Service
metadata:
  name: postgres
  namespace: production
spec:
  clusterIP: None  # Headless
  selector:
    app: postgres
  ports:
  - port: 5432
    targetPort: 5432

# Why Headless?
# ✓ StatefulSet requires it
# ✓ Direct pod-to-pod communication
# ✓ Stable DNS for each pod
# ✓ postgres-0.postgres.production.svc.cluster.local
4. Redis Cache: ClusterIP
yamlapiVersion: v1
kind: Service
metadata:
  name: redis
  namespace: production
spec:
  type: ClusterIP
  selector:
    app: redis
  ports:
  - port: 6379
    targetPort: 6379
Service Discovery in Project
DNS Names:
Frontend → Backend:
  http://backend.production.svc.cluster.local:8080

Backend → Database:
  postgres.production.svc.cluster.local:5432

Backend → Redis:
  redis.production.svc.cluster.local:6379

Same namespace? Short form:
  http://backend:8080
  postgres:5432
  redis:6379
Network Flow:
Internet
    ↓
LoadBalancer (External IP)
    ↓
Frontend Pods (port 3000)
    ↓
ClusterIP Service (backend:8080)
    ↓
Backend Pods (port 8080)
    ↓
├─→ Redis ClusterIP (redis:6379)
│   └─→ Redis Pod
└─→ Postgres Headless (postgres:5432)
    └─→ StatefulSet Pods

Week 2 Review: Organization & Configuration
Day 10-11: Namespaces & Labels
Namespace Strategy in Project
Three Environments:
yaml# Development
apiVersion: v1
kind: Namespace
metadata:
  name: development
  labels:
    environment: development
  annotations:
    description: "Development environment"

---
# Staging
apiVersion: v1
kind: Namespace
metadata:
  name: staging
  labels:
    environment: staging
  annotations:
    description: "Staging environment for testing"

---
# Production
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    environment: production
  annotations:
    description: "Production environment"
    criticality: "high"
Resource Quotas per Namespace:
yaml# Production has more resources
apiVersion: v1
kind: ResourceQuota
metadata:
  name: production-quota
  namespace: production
spec:
  hard:
    requests.cpu: "20"
    requests.memory: "40Gi"
    limits.cpu: "40"
    limits.memory: "80Gi"
    pods: "100"

---
# Development has fewer resources
apiVersion: v1
kind: ResourceQuota
metadata:
  name: development-quota
  namespace: development
spec:
  hard:
    requests.cpu: "4"
    requests.memory: "8Gi"
    limits.cpu: "8"
    limits.memory: "16Gi"
    pods: "20"
Label Taxonomy in Project
Recommended Labels (used everywhere):
yamlmetadata:
  labels:
    # Application identification
    app.kubernetes.io/name: ecommerce
    app.kubernetes.io/instance: ecommerce-prod
    app.kubernetes.io/version: "2.1.0"
    app.kubernetes.io/component: frontend  # or backend, database
    app.kubernetes.io/part-of: ecommerce-platform
    app.kubernetes.io/managed-by: kubectl
    
    # Custom organization
    environment: production
    tier: frontend  # or backend, database, cache
    team: platform
    cost-center: engineering
Label Selectors in Use:
bash# Get all frontend pods
kubectl get pods -l tier=frontend -n production

# Get all production resources
kubectl get all -l environment=production -n production

# Get specific version
kubectl get pods -l app.kubernetes.io/version=2.1.0 -n production

# Complex selector
kubectl get pods -l 'tier in (frontend,backend),environment=production'
Service Selectors:
yaml# Frontend service selects frontend pods
apiVersion: v1
kind: Service
metadata:
  name: frontend
spec:
  selector:
    app.kubernetes.io/name: ecommerce
    app.kubernetes.io/component: frontend
    tier: frontend

Day 12-13: Configuration Management
ConfigMaps in Project
1. Frontend ConfigMap
yamlapiVersion: v1
kind: ConfigMap
metadata:
  name: frontend-config
  namespace: production
data:
  API_URL: "http://backend:8080"
  ENVIRONMENT: "production"
  LOG_LEVEL: "info"
  FEATURE_NEW_UI: "true"
  FEATURE_DARK_MODE: "false"
  
  # nginx.conf as file
  nginx.conf: |
    server {
      listen 3000;
      location / {
        root /usr/share/nginx/html;
        try_files $uri /index.html;
      }
      location /api {
        proxy_pass http://backend:8080;
      }
    }
2. Backend ConfigMap
yamlapiVersion: v1
kind: ConfigMap
metadata:
  name: backend-config
  namespace: production
data:
  NODE_ENV: "production"
  PORT: "8080"
  DB_HOST: "postgres.production.svc.cluster.local"
  DB_PORT: "5432"
  DB_NAME: "ecommerce"
  REDIS_HOST: "redis.production.svc.cluster.local"
  REDIS_PORT: "6379"
  LOG_LEVEL: "info"
  RATE_LIMIT: "1000"
3. Database ConfigMap
yamlapiVersion: v1
kind: ConfigMap
metadata:
  name: postgres-config
  namespace: production
data:
  POSTGRES_DB: "ecommerce"
  POSTGRES_MAX_CONNECTIONS: "200"
  
  postgresql.conf: |
    max_connections = 200
    shared_buffers = 256MB
    effective_cache_size = 1GB
    maintenance_work_mem = 64MB
    checkpoint_completion_target = 0.9
Secrets in Project
1. Database Secrets
yamlapiVersion: v1
kind: Secret
metadata:
  name: postgres-secret
  namespace: production
type: Opaque
stringData:  # Auto-encodes to base64
  POSTGRES_USER: "ecommerce_user"
  POSTGRES_PASSWORD: "SuperSecurePassword123!"
  POSTGRES_REPLICATION_PASSWORD: "ReplicationPass456!"
2. Backend Secrets
yamlapiVersion: v1
kind: Secret
metadata:
  name: backend-secret
  namespace: production
type: Opaque
stringData:
  DB_PASSWORD: "SuperSecurePassword123!"
  JWT_SECRET: "MyJWTSecretKey789XYZ"
  API_KEY: "sk_live_abcd1234efgh5678"
  SMTP_PASSWORD: "EmailPassword999"
3. TLS Secrets
yamlapiVersion: v1
kind: Secret
metadata:
  name: tls-secret
  namespace: production
type: kubernetes.io/tls
data:
  tls.crt: <base64-encoded-cert>
  tls.key: <base64-encoded-key>
Using ConfigMaps and Secrets
Environment Variables:
yamlspec:
  containers:
  - name: backend
    image: backend:2.1.0
    env:
    # Individual keys from ConfigMap
    - name: NODE_ENV
      valueFrom:
        configMapKeyRef:
          name: backend-config
          key: NODE_ENV
    
    # Individual keys from Secret
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: backend-secret
          key: DB_PASSWORD
    
    # All keys from ConfigMap
    envFrom:
    - configMapRef:
        name: backend-config
    
    # All keys from Secret
    - secretRef:
        name: backend-secret
Volume Mounts:
yamlspec:
  containers:
  - name: frontend
    image: frontend:2.1.0
    volumeMounts:
    - name: config
      mountPath: /etc/nginx/nginx.conf
      subPath: nginx.conf
  
  volumes:
  - name: config
    configMap:
      name: frontend-config

Integration Patterns
How Components Work Together
1. Frontend → Backend Communication
Frontend Pod:
├─ Environment: API_URL from ConfigMap
├─ Makes request to: http://backend:8080/api/products
│
└─→ ClusterIP Service (backend)
    ├─ DNS: backend.production.svc.cluster.local
    ├─ Selects pods with label: app=backend
    │
    └─→ Backend Pod (one of 5 replicas)
        ├─ Receives request
        ├─ Processes logic
        └─ Responds to frontend
2. Backend → Database Communication
Backend Pod:
├─ DB_HOST from ConfigMap: postgres.production.svc.cluster.local
├─ DB_PASSWORD from Secret
├─ Opens connection to postgres:5432
│
└─→ Headless Service (postgres)
    ├─ No ClusterIP (headless)
    ├─ DNS returns pod IPs directly
    │
    └─→ StatefulSet Pod (postgres-0)
        ├─ Primary database
        ├─ Persistent storage (PVC)
        └─ Handles queries
3. Backend → Redis Communication
Backend Pod:
├─ REDIS_HOST from ConfigMap: redis
├─ Connects to redis:6379
│
└─→ ClusterIP Service (redis)
    │
    └─→ Redis Pod
        └─ Returns cached data
Complete Request Flow
1. User visits http://<external-ip>
   ↓
2. LoadBalancer Service routes to Frontend Pod
   ↓
3. Frontend serves React app to browser
   ↓
4. Browser makes API call: /api/products
   ↓
5. Nginx proxy forwards to backend:8080
   ↓
6. ClusterIP Service routes to Backend Pod
   ↓
7. Backend checks Redis cache (redis:6379)
   ├─ Cache hit: return data
   └─ Cache miss: query database
       ↓
8. Backend queries PostgreSQL (postgres:5432)
   ↓
9. Backend caches result in Redis
   ↓
10. Backend returns JSON to frontend
    ↓
11. Frontend displays products to user

3-Tier Application Architecture
Frontend Tier Implementation
Deployment:
yamlapiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: production
  labels:
    app.kubernetes.io/name: ecommerce
    app.kubernetes.io/component: frontend
    tier: frontend
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  selector:
    matchLabels:
      app.kubernetes.io/name: ecommerce
      app.kubernetes.io/component: frontend
  template:
    metadata:
      labels:
        app.kubernetes.io/name: ecommerce
        app.kubernetes.io/component: frontend
        app.kubernetes.io/version: "2.1.0"
        tier: frontend
    spec:
      containers:
      - name: nginx
        image: ecommerce-frontend:2.1.0
        ports:
        - containerPort: 3000
          name: http
        
        # Environment variables from ConfigMap
        envFrom:
        - configMapRef:
            name: frontend-config
        
        # Volume mount for nginx.conf
        volumeMounts:
        - name: nginx-config
          mountPath: /etc/nginx/nginx.conf
          subPath: nginx.conf
        
        # Health checks
        livenessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 30
          periodSeconds: 10
        
        readinessProbe:
          httpGet:
            path: /ready
            port: 3000
          initialDelaySeconds: 5
          periodSeconds: 5
        
        # Resource limits
        resources:
          requests:
            cpu: "100m"
            memory: "128Mi"
          limits:
            cpu: "200m"
            memory: "256Mi"
      
      volumes:
      - name: nginx-config
        configMap:
          name: frontend-config
Horizontal Pod Autoscaler:
yamlapiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: frontend-hpa
  namespace: production
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: frontend
  minReplicas: 3
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
Backend Tier Implementation
Deployment:
yamlapiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: production
spec:
  replicas: 5
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 2
      maxUnavailable: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: ecommerce
      app.kubernetes.io/component: backend
  template:
    metadata:
      labels:
        app.kubernetes.io/name: ecommerce
        app.kubernetes.io/component: backend
        app.kubernetes.io/version: "2.1.0"
        tier: backend
    spec:
      # Init container for database migration
      initContainers:
      - name: db-migration
        image: ecommerce-backend:2.1.0
        command: ['npm', 'run', 'migrate']
        env:
        - name: DB_HOST
          valueFrom:
            configMapKeyRef:
              name: backend-config
              key: DB_HOST
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: backend-secret
              key: DB_PASSWORD
      
      containers:
      - name: api
        image: ecommerce-backend:2.1.0
        ports:
        - containerPort: 8080
          name: http
        
        # Environment variables
        envFrom:
        - configMapRef:
            name: backend-config
        - secretRef:
            name: backend-secret
        
        # Health checks
        livenessProbe:
          httpGet:
            path: /api/health
            port: 8080
          initialDelaySeconds: 60
          periodSeconds: 10
          timeoutSeconds: 5
        
        readinessProbe:
          httpGet:
            path: /api/ready
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 5
          timeoutSeconds: 3
        
        # Resource limits
        resources:
          requests:
            cpu: "250m"
            memory: "256Mi"
          limits:
            cpu: "500m"
            memory: "512Mi"
      
      # Security context
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 1000
Database Tier Implementation
StatefulSet:
yamlapiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
  namespace: production
spec:
  serviceName: postgres
  replicas: 3
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
        tier: database
    spec:
      containers:
      - name: postgres
        image: postgres:14
        ports:
        - containerPort: 5432
          name: postgres
        
        # Environment from ConfigMap and Secret
        envFrom:
        - configMapRef:
            name: postgres-config
        - secretRef:
            name: postgres-secret
        
        # Volume mounts
        volumeMounts:
        - name: postgres-data
          mountPath: /var/lib/postgresql/data
        - name: postgres-config
          mountPath: /etc/postgresql/postgresql.conf
          subPath: postgresql.conf
        
        # Health checks
        livenessProbe:
          exec:
            command:
            - pg_isready
            - -U
            - postgres
          initialDelaySeconds: 30
          periodSeconds: 10
        
        readinessProbe:
          exec:
            command:
            - pg_isready
            - -U
            - postgres
          initialDelaySeconds: 5
          periodSeconds: 5
        
        # Resources
        resources:
          requests:
            cpu: "500m"
            memory: "1Gi"
          limits:
            cpu: "1000m"
            memory: "2Gi"
      
      volumes:
      - name: postgres-config
        configMap:
          name: postgres-config
  
  # Persistent volume claim template
  volumeClaimTemplates:
  - metadata:
      name: postgres-data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 100Gi

Best Practices Consolidated
1. Resource Management
Always Set Requests and Limits:
yamlresources:
  requests:  # Guaranteed minimum
    cpu: "250m"
    memory: "256Mi"
  limits:    # Maximum allowed
    cpu: "500m"
    memory: "512Mi"
Why:

Ensures predictable scheduling
Prevents resource exhaustion
Enables accurate cost calculation
Improves cluster stability

2. Health Checks
Always Implement Both:
yamllivenessProbe:  # Restart if unhealthy
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 10

readinessProbe:  # Remove from service if not ready
  httpGet:
    path: /ready
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 5
Why:

Automatic recovery from failures
Zero-downtime deployments
Better load balancing
Faster issue detection

3. Labels and Selectors
Use Recommended Labels:
yamllabels:
  app.kubernetes.io/name: myapp
  app.kubernetes.io/instance: myapp-prod
  app.kubernetes.io/version: "2.1.0"
  app.kubernetes.io/component: frontend
  app.kubernetes.io/part-of: platform
  app.kubernetes.io/managed-by: kubectl
  environment: production
  tier: frontend
Why:

Standardization across team
Better tooling integration
Easier troubleshooting
Automated operations

4. Configuration Management
ConfigMaps for Non-Sensitive:
yamlapiVersion: v1
kind: ConfigMap
data:
  API_URL: "https://api.example.com"
  FEATURE_FLAG: "true"
Secrets for Sensitive:
yamlapiVersion: v1
kind: Secret
stringData:
  DB_PASSWORD: "secret"
  API_KEY: "key123"
Why:

Separation of concerns
Better security
Easy environment promotion
