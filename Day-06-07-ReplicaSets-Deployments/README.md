Day 6-7: ReplicaSets & Deployments 🚀
📅 Duration: 2 Days
Status: ✅ Completed
Difficulty: Intermediate

🎯 Learning Objectives

 Understand ReplicaSet architecture and self-healing
 Master Deployment lifecycle
 Perform rolling updates and rollbacks
 Implement different deployment strategies
 Scale applications (manual and auto)
 Configure update strategies
 Build production-grade deployments
 Troubleshoot deployment issues


📂 Repository Structure
Day-06-07-ReplicaSets-Deployments/
├── README.md (This file)
├── GUIDE.md (Complete step-by-step guide)
├── yaml-examples/
│   ├── 01-basic-replicaset.yaml
│   ├── 02-basic-deployment.yaml
│   ├── 03-rolling-update-deployment.yaml
│   ├── 04-recreate-deployment.yaml
│   ├── 05-production-deployment.yaml
│   ├── 06-blue-green-deployment.yaml
│   ├── 07-canary-deployment.yaml
│   ├── 08-multi-container-deployment.yaml
│   ├── 09-deployment-node-affinity.yaml
│   ├── 10-deployment-pod-antiaffinity.yaml
│   ├── 11-deployment-with-init.yaml
│   ├── 12-deployment-with-configmap.yaml
│   ├── 13-deployment-with-secrets.yaml
│   ├── 14-deployment-with-hpa.yaml
│   └── 15-complete-production-deployment.yaml (Main Project)
├── project/
│   └── PROJECT-EXPLANATION.md
├── interview-questions.md
└── CHEATSHEET.md

🔍 What You'll Learn
ReplicaSets

Self-healing mechanism
Label selectors
Scaling operations
Relationship with Pods

Deployments

Declarative updates
Rolling updates (zero downtime)
Rollback capabilities
Revision history
Update strategies

Deployment Strategies

RollingUpdate
Recreate
Blue-Green
Canary


🚀 Quick Start
Setup Cluster
bash# Using Minikube
minikube start --nodes 2

# Using Kind
kind create cluster --name cka-cluster
Create Your First ReplicaSet
bash# Apply ReplicaSet
kubectl apply -f yaml-examples/01-basic-replicaset.yaml

# View ReplicaSet
kubectl get rs

# View pods created by ReplicaSet
kubectl get pods
Test Self-Healing
bash# Delete a pod
kubectl delete pod <pod-name>

# Watch ReplicaSet recreate it
kubectl get pods -w
# New pod appears immediately!

💡 Key Concepts
The Hierarchy
Deployment (manages versions)
    ↓
ReplicaSet (maintains pod count)
    ↓
Pods (run containers)
Self-Healing in Action
Desired State: 3 pods
Current State: 2 pods (1 deleted)
Action: Create 1 new pod
Result: 3 pods (desired state achieved)
This happens automatically with no human intervention!

🎯 Main Projects
Project 1: Production Deployment
Complete production-grade deployment with:

5 replicas for high availability
Resource requests and limits
Health checks (liveness, readiness, startup)
Rolling update strategy
ConfigMap and Secrets
HPA (Horizontal Pod Autoscaler)

bash# Deploy
kubectl apply -f yaml-examples/15-complete-production-deployment.yaml

# Monitor deployment
kubectl rollout status deployment/webapp-production-complete

# Test application
kubectl port-forward svc/webapp-prod-service 8080:80
Project 2: Blue-Green Deployment
Zero-downtime deployment with instant cutover:
bash# Deploy both versions
kubectl apply -f yaml-examples/06-blue-green-deployment.yaml

# Service points to blue initially
kubectl get svc webapp-service -o wide

# Switch to green (instant!)
kubectl patch service webapp-service \
  -p '{"spec":{"selector":{"version":"green"}}}'

# Rollback to blue if needed
kubectl patch service webapp-service \
  -p '{"spec":{"selector":{"version":"blue"}}}'
Project 3: Canary Deployment
Gradual rollout with risk mitigation:
bash# Deploy stable + canary
kubectl apply -f yaml-examples/07-canary-deployment.yaml

# 90% stable, 10% canary
kubectl get pods -l app=webapp

# If canary looks good, increase traffic
kubectl scale deployment webapp-canary --replicas=5
kubectl scale deployment webapp-stable --replicas=5

# Eventually full rollout
kubectl scale deployment webapp-canary --replicas=10
kubectl scale deployment webapp-stable --replicas=0

🔄 Common Operations
Create Deployment
bash# Imperative (quick)
kubectl create deployment nginx --image=nginx:1.25 --replicas=3

# Declarative (recommended)
kubectl apply -f deployment.yaml

# Generate YAML
kubectl create deployment nginx --image=nginx \
  --dry-run=client -o yaml > deployment.yaml
Rolling Update
bash# Update image
kubectl set image deployment/nginx nginx=nginx:1.26 --record

# Watch rollout
kubectl rollout status deployment/nginx

# Check history
kubectl rollout history deployment/nginx
Rollback
bash# Rollback to previous version
kubectl rollout undo deployment/nginx

# Rollback to specific revision
kubectl rollout undo deployment/nginx --to-revision=2

# Verify rollback
kubectl rollout status deployment/nginx
Scaling
bash# Scale manually
kubectl scale deployment nginx --replicas=10

# Autoscale (HPA)
kubectl autoscale deployment nginx \
  --min=3 --max=10 --cpu-percent=80

🏥 Health Checks
Configure Probes
yamllivenessProbe:
  httpGet:
    path: /healthz
    port: 80
  initialDelaySeconds: 10
  periodSeconds: 5

readinessProbe:
  httpGet:
    path: /ready
    port: 80
  initialDelaySeconds: 5
  periodSeconds: 3
Why Important:

Liveness: Restarts unhealthy pods
Readiness: Removes unready pods from service endpoints
Critical for zero-downtime updates


🎨 Deployment Strategies Comparison
StrategyDowntimeRollback SpeedResource UsageUse CaseRollingUpdateNoneFastNormalMost deploymentsRecreateYesManualNormalBreaking changesBlue-GreenNoneInstant2x TemporaryMajor releasesCanaryNoneFastSlight increaseRisk mitigation

🔧 Troubleshooting
Deployment Stuck
bash# Check status
kubectl rollout status deployment/<n>

# Check events
kubectl get events --sort-by=.metadata.creationTimestamp

# Check pods
kubectl get pods

# Describe problematic pod
kubectl describe pod <pod-name>

# Check logs
kubectl logs <pod-name>

# Rollback if needed
kubectl rollout undo deployment/<n>
Common Issues
ImagePullBackOff:
bashkubectl describe pod <n> | grep -A 5 Events
# Check image name/tag
CrashLoopBackOff:
bashkubectl logs <pod-name> --previous
# Check application logs
Pending Pods:
bashkubectl describe pod <n> | grep -A 5 Conditions
# Check resource availability

📚 Best Practices
1. Always Use Deployments (Not Bare ReplicaSets)
bash✅ kubectl create deployment app --image=nginx
❌ kubectl create replicaset app --image=nginx
2. Set Resource Limits
yamlresources:
  requests:
    memory: "128Mi"
    cpu: "100m"
  limits:
    memory: "256Mi"
    cpu: "200m"
3. Configure Health Probes
yamllivenessProbe: ...
readinessProbe: ...
4. Use Declarative Management
bash✅ kubectl apply -f deployment.yaml
❌ kubectl create deployment ...
5. Record Changes
bashkubectl set image deploy/app nginx=nginx:1.26 --record
6. Test in Non-Production First
bash# Test in dev
kubectl apply -f deployment.yaml -n dev


# Then production
kubectl apply -f deployment.yaml -n prod

🎓 Key Learnings
1. Self-Healing
ReplicaSets automatically replace failed pods. No human intervention needed!
2. Rolling Updates
Update applications with zero downtime. Kubernetes handles it!
3. Easy Rollback
One command to rollback to any previous version.
4. Declarative Management
Define desired state, Kubernetes makes it happen.
5. Scalability
Scale from 1 to 1000 pods with one command.

📖 Additional Resources

Complete Guide (GUIDE.md)
Interview Questions (interview-questions.md)
Commands Cheatsheet (CHEATSHEET.md)
Project Explanation (project/PROJECT-EXPLANATION.md)

Official Documentation

Kubernetes Deployments
ReplicaSets
Deployment Strategies
HPA


✅ Completion Checklist
ReplicaSets

 Created ReplicaSet
 Tested self-healing
 Scaled ReplicaSet up and down
 Understood label selectors

Deployments

 Created Deployment
 Performed rolling update
 Rolled back deployment
 Scaled deployment
 Configured update strategy

Strategies

 Tested RollingUpdate
 Tested Recreate
 Implemented Blue-Green
 Implemented Canary

Advanced

 Configured HPA
 Added health probes
 Set resource limits
 Tested troubleshooting scenarios


**🎯 CKA Exam Tips**
Must-Know Commands
bash# 
Create deployment
kubectl create deploy <n> --image=<i> --replicas=3

# Update image
kubectl set image deploy/<n> <c>=<new-image>

# Scale
kubectl scale deploy/<n> --replicas=5

# Rollback
kubectl rollout undo deploy/<n>

# Check status
kubectl rollout status deploy/<n>

**Common Exam Tasks**
Create deployment with specific replicas
Update image (rolling update)
Rollback after failed update
Scale deployment
Configure update strategy
Troubleshoot stuck deployment

**Time-Saving Tips**
Use kubectl create deploy for speed
Use --record flag for history
Know kubectl rollout commands
Practice rollback scenarios
Use --dry-run=client -o yaml to generate YAML


🚀 What's Next?
Day 8-9: Services & Networking - Exposing applications and service discovery

💬 Questions or Issues?

Open an issue on GitHub
Tag me on LinkedIn with #CKA75Challenge
Check GUIDE.md for detailed explanations
Review CHEATSHEET.md for quick reference


⭐ Found this helpful? Star the repo!
📢 Share with others preparing for CKA!
#CKA #Kubernetes #Deployments #ReplicaSets #DevOps #CloudNative
