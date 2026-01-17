# ReplicaSets & Deployments - Commands Cheatsheet 🚀

## 📋 Quick Reference Guide

---

## 🔄 ReplicaSets

### Create ReplicaSet
```bash
# From YAML file
kubectl apply -f replicaset.yaml

# View ReplicaSets
kubectl get rs
kubectl get replicasets
kubectl get rs -o wide

# Describe ReplicaSet
kubectl describe rs <replicaset-name>

# Get YAML output
kubectl get rs <name> -o yaml
```

### Scale ReplicaSet
```bash
# Imperative scaling
kubectl scale rs <replicaset-name> --replicas=5

# Verify scaling
kubectl get rs <replicaset-name>
```

### Delete ReplicaSet
```bash
# Delete ReplicaSet (and pods)
kubectl delete rs <replicaset-name>

# Delete ReplicaSet (keep pods running)
kubectl delete rs <replicaset-name> --cascade=orphan
```

---

## 🚀 Deployments

### Create Deployment

```bash
# Imperative (quick)
kubectl create deployment nginx --image=nginx:1.25
kubectl create deployment nginx --image=nginx:1.25 --replicas=3

# Declarative (preferred)
kubectl apply -f deployment.yaml

# Generate YAML
kubectl create deployment nginx --image=nginx:1.25 \
  --replicas=3 --dry-run=client -o yaml > deployment.yaml
```

### View Deployments

```bash
# List deployments
kubectl get deployments
kubectl get deploy
kubectl get deploy -o wide

# Describe deployment
kubectl describe deployment <name>

# Get YAML
kubectl get deployment <name> -o yaml

# View all resources (deployment, replicaset, pods)
kubectl get deploy,rs,pods
```

### Update Deployment

```bash
# Update image (triggers rolling update)
kubectl set image deployment/<name> <container>=<new-image>
kubectl set image deployment/nginx nginx=nginx:1.26

# Update with record (for rollback history)
kubectl set image deployment/nginx nginx=nginx:1.26 --record

# Edit deployment directly
kubectl edit deployment <name>

# Update from file
kubectl apply -f deployment.yaml

# Patch deployment
kubectl patch deployment <name> -p '{"spec":{"replicas":5}}'
```

### Scale Deployment

```bash
# Scale up/down
kubectl scale deployment <name> --replicas=5

# Verify
kubectl get deployment <name>
```

---

## 🔄 Rolling Updates

### Trigger Rolling Update

```bash
# Update image
kubectl set image deployment/nginx nginx=nginx:1.26 --record

# Watch rollout
kubectl rollout status deployment/nginx

# Monitor in real-time
kubectl get pods -w
```

### Pause and Resume

```bash
# Pause rollout
kubectl rollout pause deployment/<name>

# Make multiple changes
kubectl set image deployment/<name> nginx=nginx:1.26
kubectl set resources deployment/<name> -c=nginx --limits=cpu=200m

# Resume rollout (applies all changes)
kubectl rollout resume deployment/<name>
```

### Rollout History

```bash
# View rollout history
kubectl rollout history deployment/<name>

# View specific revision
kubectl rollout history deployment/<name> --revision=2

# Show detailed change cause
kubectl rollout history deployment/<name> --revision=2
```

---

## ⏮️ Rollbacks

### Rollback Deployment

```bash
# Rollback to previous revision
kubectl rollout undo deployment/<name>

# Rollback to specific revision
kubectl rollout undo deployment/<name> --to-revision=2

# Monitor rollback
kubectl rollout status deployment/<name>

# Verify rollback successful
kubectl describe deployment <name> | grep Image
```

### Rollout Status

```bash
# Check rollout status
kubectl rollout status deployment/<name>

# Restart deployment (triggers rollout)
kubectl rollout restart deployment/<name>
```

---

## 📊 Autoscaling (HPA)

### Create HPA

```bash
# Autoscale based on CPU
kubectl autoscale deployment <name> \
  --min=2 --max=10 --cpu-percent=80

# From YAML
kubectl apply -f hpa.yaml
```

### Manage HPA

```bash
# View HPA
kubectl get hpa
kubectl get horizontalpodautoscaler

# Describe HPA
kubectl describe hpa <name>

# Delete HPA
kubectl delete hpa <name>
```

---

## 🔍 Troubleshooting

### Check Deployment Status

```bash
# View deployment status
kubectl get deployment <name>

# Check events
kubectl get events --sort-by=.metadata.creationTimestamp

# Filter events for deployment
kubectl get events --field-selector involvedObject.name=<name>

# Describe deployment (shows conditions)
kubectl describe deployment <name>
```

### Debug Failing Deployments

```bash
# Check ReplicaSet status
kubectl get rs -l app=<app-label>

# Check pod status
kubectl get pods -l app=<app-label>

# Describe problematic pod
kubectl describe pod <pod-name>

# Check logs
kubectl logs <pod-name>
kubectl logs <pod-name> --previous

# Check resource usage
kubectl top pods -l app=<app-label>
```

### Common Issues

```bash
# ImagePullBackOff
kubectl describe pod <pod-name> | grep -A 10 Events

# CrashLoopBackOff
kubectl logs <pod-name> --previous

# Pending pods
kubectl describe pod <pod-name> | grep -A 5 "Conditions"

# Failed rollout
kubectl rollout status deployment/<name>
kubectl rollout undo deployment/<name>
```

---

## 🎯 Deployment Strategies

### RollingUpdate (Default)

```yaml
# In deployment YAML
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
```

```bash
# Apply strategy
kubectl apply -f deployment.yaml

# Trigger update
kubectl set image deployment/app nginx=nginx:1.26
```

### Recreate Strategy

```yaml
# In deployment YAML
spec:
  strategy:
    type: Recreate
```

```bash
# Apply strategy
kubectl apply -f deployment.yaml

# Update (all pods terminated first)
kubectl set image deployment/app nginx=nginx:1.26
```

### Blue-Green Deployment

```bash
# Deploy blue (current)
kubectl apply -f blue-deployment.yaml

# Deploy green (new version)
kubectl apply -f green-deployment.yaml

# Switch service to green
kubectl patch service app-service \
  -p '{"spec":{"selector":{"version":"green"}}}'

# Verify
kubectl describe service app-service | grep Selector

# Rollback to blue if needed
kubectl patch service app-service \
  -p '{"spec":{"selector":{"version":"blue"}}}'
```

### Canary Deployment

```bash
# Deploy stable (90%)
kubectl apply -f stable-deployment.yaml
kubectl scale deployment app-stable --replicas=9

# Deploy canary (10%)
kubectl apply -f canary-deployment.yaml
kubectl scale deployment app-canary --replicas=1

# Increase canary traffic
kubectl scale deployment app-canary --replicas=3
kubectl scale deployment app-stable --replicas=7

# Full rollout
kubectl scale deployment app-canary --replicas=10
kubectl scale deployment app-stable --replicas=0
```

---

## 🏷️ Labels and Selectors

### Work with Labels

```bash
# View labels
kubectl get deployments --show-labels
kubectl get pods --show-labels

# Filter by label
kubectl get pods -l app=nginx
kubectl get pods -l app=nginx,env=prod

# Add label
kubectl label deployment <name> version=v1.0

# Remove label
kubectl label deployment <name> version-

# Update label
kubectl label deployment <name> version=v2.0 --overwrite
```

---

## 📝 Export and Backup

### Export Resources

```bash
# Export deployment YAML
kubectl get deployment <name> -o yaml > deployment-backup.yaml

# Export without cluster-specific fields
kubectl get deployment <name> -o yaml \
  --export > deployment-clean.yaml

# Export all deployments
kubectl get deployments -o yaml > all-deployments.yaml
```

---

## 🚨 Emergency Commands

### Quick Fixes

```bash
# Immediate rollback
kubectl rollout undo deployment/<name>

# Force delete stuck pod
kubectl delete pod <name> --force --grace-period=0

# Restart all pods
kubectl rollout restart deployment/<name>

# Delete and recreate deployment
kubectl delete deployment <name>
kubectl apply -f deployment.yaml

# Check if deployment is healthy
kubectl rollout status deployment/<name> --timeout=60s
```

---

## 💡 Pro Tips

### Time-Saving Commands

```bash
# Create and expose in one command
kubectl create deployment nginx --image=nginx --replicas=3
kubectl expose deployment nginx --port=80 --type=LoadBalancer

# Generate YAML quickly
alias k-deploy='kubectl create deployment'
k-deploy nginx --image=nginx --replicas=3 \
  --dry-run=client -o yaml > deploy.yaml

# Watch resources continuously
watch -n 2 'kubectl get deploy,rs,pods'

# Get pod IPs
kubectl get pods -o wide

# Get all in namespace
kubectl get all

# One-liner scale and verify
kubectl scale deploy nginx --replicas=5 && kubectl get pods -w
```

### Useful Aliases

```bash
# Add to ~/.bashrc or ~/.zshrc
alias k='kubectl'
alias kg='kubectl get'
alias kd='kubectl describe'
alias kdel='kubectl delete'
alias kl='kubectl logs'
alias kex='kubectl exec -it'
alias kapply='kubectl apply -f'

# Deployment specific
alias kgd='kubectl get deployments'
alias kdd='kubectl describe deployment'
alias ksd='kubectl scale deployment'
alias krollout='kubectl rollout'
```

---

## 🎯 CKA Exam Speed Commands

### Must-Know Fast Commands

```bash
# Create deployment (fastest)
kubectl create deploy nginx --image=nginx --replicas=3

# Update image (fastest)
kubectl set image deploy/nginx nginx=nginx:1.26

# Scale (fastest)
kubectl scale deploy nginx --replicas=5

# Rollback (fastest)
kubectl rollout undo deploy/nginx

# Check status (fastest)
kubectl rollout status deploy/nginx

# Generate YAML (for modification)
kubectl create deploy nginx --image=nginx \
  --dry-run=client -o yaml | kubectl apply -f -
```

---

## 📊 Monitoring Commands

### Real-Time Monitoring

```bash
# Watch pods being created/terminated
kubectl get pods -w

# Monitor deployment rollout
kubectl rollout status deployment/<name> -w

# Watch all resources
kubectl get deploy,rs,pods -w

# Monitor resource usage
kubectl top pods -l app=<name> --watch

# Tail logs from deployment
kubectl logs -f deployment/<name>

# Logs from all pods
kubectl logs -l app=<name> --all-containers=true -f
```

---

## 🔢 Resource Management

### Set Resource Limits

```bash
# Set resources for deployment
kubectl set resources deployment <name> \
  -c=<container> \
  --requests=cpu=100m,memory=128Mi \
  --limits=cpu=200m,memory=256Mi

# Verify
kubectl describe deployment <name> | grep -A 5 "Limits"
```

---

## 🧪 Testing Commands

### Validation

```bash
# Dry-run (test without creating)
kubectl apply -f deployment.yaml --dry-run=client

# Validate YAML syntax
kubectl apply -f deployment.yaml --validate=true --dry-run=client

# Diff before applying
kubectl diff -f deployment.yaml

# Validate with server
kubectl apply -f deployment.yaml --dry-run=server
```

---

## 📖 Context and Configuration

### Work with Contexts

```bash
# View current context
kubectl config current-context

# List contexts
kubectl config get-contexts

# Switch context
kubectl config use-context <context-name>

# Set namespace for context
kubectl config set-context --current --namespace=<namespace>
```

---

## 🎓 Common Exam Scenarios

### Scenario 1: Create and Scale

```bash
# Create deployment with 3 replicas
kubectl create deployment web --image=nginx:1.25 --replicas=3

# Scale to 5
kubectl scale deployment web --replicas=5

# Verify
kubectl get pods -l app=web
```

### Scenario 2: Update and Rollback

```bash
# Update image
kubectl set image deployment/web nginx=nginx:1.26 --record

# If fails, rollback
kubectl rollout undo deployment/web

# Verify
kubectl rollout status deployment/web
```

### Scenario 3: Troubleshoot Failed Deployment

```bash
# Check deployment
kubectl get deployment web

# Check ReplicaSet
kubectl get rs -l app=web

# Check pods
kubectl get pods -l app=web

# Describe problematic pod
kubectl describe pod <pod-name>

# Check logs
kubectl logs <pod-name>

# Rollback
kubectl rollout undo deployment/web
```

---

## 🚀 Advanced Techniques

### Multi-Step Operations

```bash
# Create, expose, and scale in one go
kubectl create deploy app --image=nginx --replicas=1 && \
kubectl expose deploy app --port=80 && \
kubectl scale deploy app --replicas=5 && \
kubectl rollout status deploy app
```

### Bulk Operations

```bash
# Scale all deployments in namespace
kubectl get deploy -o name | xargs -I {} kubectl scale {} --replicas=3

# Restart all deployments
kubectl get deploy -o name | xargs -I {} kubectl rollout restart {}

# Delete all deployments
kubectl delete deployments --all
```

---

## 📌 Remember

**For CKA Exam:**
- Practice typing commands fast
- Use `--dry-run=client -o yaml` to generate YAML
- Know rollback commands by heart
- Understand maxSurge/maxUnavailable
- Can troubleshoot stuck deployments quickly

**Speed matters!** Practice until commands are muscle memory.

---

**Print this cheatsheet!** Keep it handy during practice. 📄

#CKA #Kubernetes #Deployments #Cheatsheet