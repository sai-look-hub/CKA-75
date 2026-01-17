**Day 6-7: ReplicaSets & Deployments Deep Dive 🚀**
📋 Overview
Master ReplicaSets and Deployments - the heart of scalable, self-healing applications in Kubernetes. Learn rolling updates, rollbacks, scaling strategies, and production deployment patterns.
Duration: 2 Days
Difficulty: Intermediate
Status: ✅ Completed

🎯 What You'll Learn

ReplicaSet architecture and self-healing
Deployment strategies (Recreate, RollingUpdate)
Rolling updates and rollbacks
Scaling applications (manual and horizontal)
Update strategies and revision history
Blue-Green and Canary deployments
Production deployment patterns
Troubleshooting deployments


🔍 Understanding the Hierarchy
Deployment (Manages versions and updates)
    ↓
ReplicaSet (Maintains desired number of pods)
    ↓
Pods (Your running applications)
Key Concept:

You create Deployment
Deployment creates ReplicaSet
ReplicaSet creates Pods


📊 What is a ReplicaSet?
ReplicaSet ensures a specified number of pod replicas are running at all times.
┌─────────────────────────────────────────────┐
│           ReplicaSet (replicas: 3)          │
│                                             │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐      │
│  │  Pod 1  │  │  Pod 2  │  │  Pod 3  │      │
│  │ Running │  │ Running │  │ Running │      │
│  └─────────┘  └─────────┘  └─────────┘      │
│                                             │
│  If Pod 2 dies → ReplicaSet creates new pod │
└─────────────────────────────────────────────┘
Key Features:

Self-healing (replaces failed pods)
Scaling (increase/decrease replicas)
Load balancing (across multiple pods)
High availability


🚀 Hands-On: ReplicaSets
Create Your First ReplicaSet
yamlapiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: nginx-replicaset
  labels:
    app: nginx
    tier: frontend
spec:
  replicas: 3  # Desired number of pods
  selector:
    matchLabels:
      app: nginx  # Must match pod template labels
  template:  # Pod template
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
        ports:
        - containerPort: 80
Deploy and Test:
bash# Create ReplicaSet
kubectl apply -f nginx-replicaset.yaml

# View ReplicaSet
kubectl get rs
kubectl get rs nginx-replicaset -o wide

# View pods created by ReplicaSet
kubectl get pods -l app=nginx

# Describe ReplicaSet
kubectl describe rs nginx-replicaset
Test Self-Healing
bash# Delete one pod
kubectl delete pod <pod-name>

# Watch ReplicaSet create new pod immediately!
kubectl get pods -w

# ReplicaSet maintains 3 pods always
kubectl get pods -l app=nginx
# Should show 3 pods
Scale ReplicaSet
bash# Method 1: Imperative scaling
kubectl scale rs nginx-replicaset --replicas=5

# Watch pods being created
kubectl get pods -w

# Scale down
kubectl scale rs nginx-replicaset --replicas=2

# Method 2: Edit ReplicaSet directly
kubectl edit rs nginx-replicaset
# Change replicas: 3 to replicas: 4

🎨 What is a Deployment?
Deployment provides declarative updates for Pods and ReplicaSets.
Why Deployments over ReplicaSets?

✅ Rolling updates (zero downtime)
✅ Rollback to previous versions
✅ Pause/Resume updates
✅ Version history
✅ Declarative updates

Deployment
    ↓
ReplicaSet v2 (new) → Pod, Pod, Pod (new version)
    ↓
ReplicaSet v1 (old) → Pod (old version) → scaling down

🚀 Hands-On: Deployments
Create Your First Deployment
yamlapiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
    app: nginx
spec:
  replicas: 3
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
        image: nginx:1.25
        ports:
        - containerPort: 80
Deploy:
bash# Create deployment
kubectl apply -f nginx-deployment.yaml

# View deployment
kubectl get deployments
kubectl get deploy nginx-deployment

# View ReplicaSets (created by deployment)
kubectl get rs

# View pods
kubectl get pods

# Everything together
kubectl get deploy,rs,pods
Quick Deployment (Imperative)
bash# Create deployment imperatively
kubectl create deployment nginx --image=nginx:1.25 --replicas=3

# Expose deployment as service
kubectl expose deployment nginx --port=80 --type=NodePort

# View all resources
kubectl get all

🔄 Rolling Updates
Rolling Update = Gradually replace old pods with new ones (zero downtime).
Update Image Version
bash# Method 1: Set new image
kubectl set image deployment/nginx-deployment nginx=nginx:1.26

# Watch rolling update
kubectl rollout status deployment/nginx-deployment

# See new ReplicaSet being created
kubectl get rs -w

# Method 2: Edit deployment
kubectl edit deployment nginx-deployment
# Change image: nginx:1.25 to nginx:1.26
Rolling Update Process
Step 1: Old ReplicaSet (3 pods)
  Pod-old, Pod-old, Pod-old

Step 2: New ReplicaSet created (1 pod)
  Pod-old, Pod-old, Pod-old, Pod-new

Step 3: Scale down old, scale up new
  Pod-old, Pod-old, Pod-new, Pod-new

Step 4: Continue until complete
  Pod-new, Pod-new, Pod-new

Step 5: Old ReplicaSet kept (for rollback)
  ReplicaSet-old (0 pods)
  ReplicaSet-new (3 pods)
Monitor Rolling Update
bash# Watch rollout status
kubectl rollout status deployment/nginx-deployment

# View rollout history
kubectl rollout history deployment/nginx-deployment

# Detailed history for specific revision
kubectl rollout history deployment/nginx-deployment --revision=2

# Pause rollout (if issues found)
kubectl rollout pause deployment/nginx-deployment

# Resume rollout
kubectl rollout resume deployment/nginx-deployment

⏮️ Rollback Deployments
Rollback = Return to previous working version.
Rollback to Previous Version
bash# Rollback to previous revision
kubectl rollout undo deployment/nginx-deployment

# Watch rollback
kubectl rollout status deployment/nginx-deployment

# Verify old version is back
kubectl describe deployment nginx-deployment | grep Image
Rollback to Specific Version
bash# View history with revision numbers
kubectl rollout history deployment/nginx-deployment

# Rollback to specific revision
kubectl rollout undo deployment/nginx-deployment --to-revision=2

# Verify
kubectl rollout status deployment/nginx-deployment
Why Rollback is Important
bash# Scenario: Bad update deployed
kubectl set image deployment/nginx nginx=nginx:broken

# Pods fail to start
kubectl get pods
# STATUS: ImagePullBackOff or CrashLoopBackOff

# Quick rollback!
kubectl rollout undo deployment/nginx

# Deployment healthy again
kubectl get pods
# All pods Running

📈 Scaling Deployments
Manual Scaling
bash# Scale up
kubectl scale deployment nginx-deployment --replicas=5

# Scale down
kubectl scale deployment nginx-deployment --replicas=2

# Auto-scale based on CPU (HPA - covered later)
kubectl autoscale deployment nginx --min=2 --max=10 --cpu-percent=80
Declarative Scaling
yaml# Update deployment YAML
spec:
  replicas: 5  # Changed from 3
bash# Apply changes
kubectl apply -f nginx-deployment.yaml

# Verify
kubectl get deployment nginx-deployment

🎯 Deployment Strategies
1. RollingUpdate (Default)
Gradually replace old pods with new ones.
yamlspec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1  # Max pods unavailable during update
      maxSurge: 1        # Max extra pods during update
Pros: Zero downtime
Cons: Both versions run simultaneously
2. Recreate
Delete all old pods, then create new ones.
yamlspec:
  strategy:
    type: Recreate
Pros: Simple, no version mixing
Cons: Downtime during update
Example Comparison
bash# RollingUpdate (default)
kubectl create deployment app --image=nginx:1.25 --replicas=3

# Update image
kubectl set image deployment/app nginx=nginx:1.26

# Watch: Old pods gradually replaced
kubectl get pods -w
# app-old-1  Terminating
# app-new-1  Running
# app-old-2  Terminating
# app-new-2  Running
bash# Recreate strategy
kubectl patch deployment app -p '{"spec":{"strategy":{"type":"Recreate"}}}'

# Update image
kubectl set image deployment/app nginx=nginx:1.26

# Watch: All pods deleted, then recreated
kubectl get pods -w
# All pods: Terminating
# ... brief downtime ...
# All new pods: Running

🎯 Day 6-7 Project: Production Deployment Pipeline
Project: Multi-Environment Deployment with Rollback Capability
What we'll build:

Development deployment (3 replicas)
Production deployment (5 replicas with resources)
Rolling update simulation
Rollback scenario
Blue-Green deployment pattern

Part 1: Production Deployment
yaml# File: production-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-production
  labels:
    app: webapp
    environment: production
spec:
  replicas: 5
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 2
      maxUnavailable: 1
  selector:
    matchLabels:
      app: webapp
      environment: production
  template:
    metadata:
      labels:
        app: webapp
        environment: production
        version: v1.0
    spec:
      containers:
      - name: webapp
        image: nginx:1.25
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 5
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 3
        env:
        - name: ENVIRONMENT
          value: "production"
        - name: VERSION
          value: "v1.0"
---
apiVersion: v1
kind: Service
metadata:
  name: webapp-service
spec:
  selector:
    app: webapp
    environment: production
  ports:
  - port: 80
    targetPort: 80
  type: LoadBalancer
Part 2: Deploy and Test
bash# 1. Deploy production app
kubectl apply -f production-deployment.yaml

# 2. Watch deployment
kubectl rollout status deployment/webapp-production

# 3. Verify pods
kubectl get pods -l app=webapp
# Should show 5 pods running

# 4. Check service
kubectl get svc webapp-service

# 5. Test application
kubectl port-forward svc/webapp-service 8080:80
# Visit: http://localhost:8080
Part 3: Rolling Update Simulation
bash# Record the change (important for rollback)
kubectl set image deployment/webapp-production \
  webapp=nginx:1.26 \
  --record

# Watch rolling update in real-time
kubectl rollout status deployment/webapp-production

# See new ReplicaSet created
kubectl get rs -l app=webapp

# View rollout history
kubectl rollout history deployment/webapp-production
Part 4: Rollback Scenario
bash# Simulate bad deployment
kubectl set image deployment/webapp-production \
  webapp=nginx:broken \
  --record

# Pods will fail
kubectl get pods -w
# STATUS: ImagePullBackOff

# Check deployment status
kubectl rollout status deployment/webapp-production
# Waiting for rollout...

# Quick rollback!
kubectl rollout undo deployment/webapp-production

# Verify rollback
kubectl rollout status deployment/webapp-production
# Successfully rolled back

# Confirm pods healthy
kubectl get pods -l app=webapp
# All pods: Running
Part 5: Blue-Green Deployment
yaml# File: blue-green-deployment.yaml

# Blue deployment (current production)
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-blue
  labels:
    app: webapp
    version: blue
spec:
  replicas: 3
  selector:
    matchLabels:
      app: webapp
      version: blue
  template:
    metadata:
      labels:
        app: webapp
        version: blue
    spec:
      containers:
      - name: webapp
        image: nginx:1.25
        ports:
        - containerPort: 80

# Green deployment (new version)
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-green
  labels:
    app: webapp
    version: green
spec:
  replicas: 3
  selector:
    matchLabels:
      app: webapp
      version: green
  template:
    metadata:
      labels:
        app: webapp
        version: green
    spec:
      containers:
      - name: webapp
        image: nginx:1.26  # New version
        ports:
        - containerPort: 80

# Service (points to blue initially)
---
apiVersion: v1
kind: Service
metadata:
  name: webapp-bluegreen-service
spec:
  selector:
    app: webapp
    version: blue  # Traffic goes to blue
  ports:
  - port: 80
    targetPort: 80
Blue-Green Deployment Process:
bash# 1. Deploy both versions
kubectl apply -f blue-green-deployment.yaml

# 2. Verify both running
kubectl get deployments -l app=webapp
# webapp-blue   3/3
# webapp-green  3/3

# 3. Service points to blue
kubectl get svc webapp-bluegreen-service -o yaml | grep version
# version: blue

# 4. Test green version (before switching)
kubectl port-forward deployment/webapp-green 8081:80

# 5. Switch traffic to green (zero downtime!)
kubectl patch service webapp-bluegreen-service \
  -p '{"spec":{"selector":{"version":"green"}}}'

# 6. Verify switch
kubectl describe svc webapp-bluegreen-service | grep Selector
# Selector: app=webapp,version=green

# 7. If issues, instant rollback!
kubectl patch service webapp-bluegreen-service \
  -p '{"spec":{"selector":{"version":"blue"}}}'

# 8. After validation, delete old blue deployment
kubectl delete deployment webapp-blue

🎨 Canary Deployment
Canary = Deploy new version to small subset of users first.
yaml# File: canary-deployment.yaml

# Stable deployment (90% traffic)
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-stable
spec:
  replicas: 9  # 90% of traffic
  selector:
    matchLabels:
      app: webapp
  template:
    metadata:
      labels:
        app: webapp
        version: stable
    spec:
      containers:
      - name: webapp
        image: nginx:1.25

# Canary deployment (10% traffic)
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-canary
spec:
  replicas: 1  # 10% of traffic
  selector:
    matchLabels:
      app: webapp
  template:
    metadata:
      labels:
        app: webapp
        version: canary
    spec:
      containers:
      - name: webapp
        image: nginx:1.26  # New version

# Service (load balances across both)
---
apiVersion: v1
kind: Service
metadata:
  name: webapp-canary-service
spec:
  selector:
    app: webapp  # Selects both stable and canary
  ports:
  - port: 80
Canary Process:
bash# 1. Deploy canary
kubectl apply -f canary-deployment.yaml

# 2. Monitor canary pods
kubectl get pods -l version=canary -w

# 3. Check logs for errors
kubectl logs -l version=canary -f

# 4. If canary looks good, increase traffic
kubectl scale deployment webapp-canary --replicas=5
kubectl scale deployment webapp-stable --replicas=5

# 5. Eventually, full rollout
kubectl scale deployment webapp-canary --replicas=10
kubectl scale deployment webapp-stable --replicas=0

# 6. Rename canary to stable
kubectl delete deployment webapp-stable
kubectl patch deployment webapp-canary -p '{"metadata":{"name":"webapp-stable"}}'

🏥 Deployment Health Checks
Configure Probes
yamlspec:
  template:
    spec:
      containers:
      - name: webapp
        image: nginx:1.25
        livenessProbe:
          httpGet:
            path: /healthz
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 10
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /ready
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
          successThreshold: 1
Why Important:

Liveness: Restarts unhealthy pods during rollout
Readiness: Ensures new pods ready before routing traffic


🔧 Troubleshooting Deployments
Common Issues
1. ImagePullBackOff
bash# Check image name
kubectl describe deployment <name> | grep Image

# View pod events
kubectl describe pod <pod-name>
2. CrashLoopBackOff
bash# View logs
kubectl logs <pod-name>

# Check previous container logs
kubectl logs <pod-name> --previous
3. Deployment Stuck
bash# Check rollout status
kubectl rollout status deployment/<name>

# View events
kubectl get events --sort-by=.metadata.creationTimestamp

# Check pod status
kubectl get pods
4. Rollout Timeout
bash# Pause rollout
kubectl rollout pause deployment/<name>

# Fix issue
kubectl set image deployment/<name> container=correct-image

# Resume rollout
kubectl rollout resume deployment/<name>

**📚 Best Practices**
1. Always Use Deployments (Not ReplicaSets Directly)
yaml✅ Good:
kubectl create deployment app --image=nginx

❌ Bad:
kubectl create replicaset app --image=nginx
2. Set Resource Limits
yaml✅ Good:
resources:
  requests:
    memory: "128Mi"
    cpu: "100m"
  limits:
    memory: "256Mi"
    cpu: "200m"
3. Configure Update Strategy
yaml✅ Good:
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxUnavailable: 1
    maxSurge: 1
4. Use Health Probes
yaml✅ Good:
livenessProbe: ...
readinessProbe: ...
5. Record Changes
bash✅ Good:
kubectl set image deployment/app nginx=nginx:1.26 --record

✅ Better:
Use GitOps (commit YAML to Git)
6. Test Before Production
bash# Test in dev first
kubectl apply -f deployment.yaml -n dev

# Verify
kubectl rollout status deployment/app -n dev

# Then production
kubectl apply -f deployment.yaml -n prod

**🎓 Deployment Lifecycle**
1. Create Deployment
   kubectl apply -f deployment.yaml
   ↓
2. Deployment creates ReplicaSet
   ReplicaSet-v1 created
   ↓
3. ReplicaSet creates Pods
   3 pods running
   ↓
4. Update Deployment
   kubectl set image deployment/app ...
   ↓
5. New ReplicaSet created
   ReplicaSet-v2 created
   ↓
6. Rolling Update
   Old pods → Terminating
   New pods → Running
   ↓
7. Old ReplicaSet scaled to 0
   ReplicaSet-v1 (0 pods) - kept for rollback
   ReplicaSet-v2 (3 pods) - active
   ↓
8. Rollback if needed
   kubectl rollout undo ...
   ↓
9. Returns to ReplicaSet-v1

**✅ Day 6-7 Checklist**
 Created ReplicaSet and tested self-healing
 Created Deployment
 Performed rolling update
 Rolled back deployment
 Scaled deployment up and down
 Tested different update strategies
 Implemented Blue-Green deployment
 Implemented Canary deployment
 Configured health probes
 Completed production deployment project
 Practiced troubleshooting scenarios


🔗 Additional Resources

Kubernetes Deployments
ReplicaSets
Deployment Strategies
Rolling Updates


Next: Day 8-9: Services & Networking 🚀
#CKA #Kubernetes #Deployments #DevOps #CloudNative
