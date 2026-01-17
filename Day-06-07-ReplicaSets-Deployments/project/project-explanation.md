Projects Explanation - Day 6-7
📋 Overview
Day 6-7 includes THREE main projects demonstrating different deployment strategies used in production environments.

🎯 Project 1: Complete Production Deployment
What It Is
A fully-featured, production-ready deployment with all enterprise features:

High availability (5 replicas)
Resource management
Health monitoring
Configuration management
Auto-scaling
Multi-container support

**Architecture**
┌──────────────────────────────────────────────────────────┐
│              Complete Production Deployment              │
│                                                          │
│  ┌────────────────────────────────────────────────────┐  │
│  │  ConfigMap                                         │  │
│  │  • nginx.conf                                      │  │
│  │  • application properties                          │  │
│  └────────────────────────────────────────────────────┘  │
│                       ↓                                  │
│  ┌────────────────────────────────────────────────────┐  │
│  │  Init Container                                    │  │
│  │  • Generate configuration                          │  │
│  │  • Setup logging                                   │  │
│  └────────────────────────────────────────────────────┘  │
│                       ↓                                  │
│  ┌─────────────────────────────────────────────────── ┐  │
│  │  Main Deployment (5 replicas)                      │  │
│  │  ┌──────────────┐  ┌──────────────┐                │  │
│  │  │   nginx      │  │ log-collector│                │  │
│  │  │  (main app)  │  │   (sidecar)  │                │  │
│  │  └──────────────┘  └──────────────┘                │  │
│  │                                                    │  │
│  │  • Resources: 128Mi-256Mi, 100m-200m CPU           │  │
│  │  • Health checks: Liveness, Readiness, Startup     │  │
│  │  • Rolling update: maxSurge=2, maxUnavailable=1    │  │
│  └────────────────────────────────────────────────────┘  │
│                       ↓                                  │
│  ┌────────────────────────────────────────────────────┐  │
│  │  Service (LoadBalancer)                            │  │
│  │  • Exposes port 80                                 │  │
│  │  • Load balances across 5 pods                     │  │
│  └────────────────────────────────────────────────────┘  │
│                       ↓                                  │
│  ┌────────────────────────────────────────────────────┐  │
│  │  HorizontalPodAutoscaler                           │  │
│  │  • Min: 3 replicas                                 │  │
│  │  • Max: 10 replicas                                │  │
│  │  • Target: 70% CPU, 80% Memory                     │  │
│  └────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────┘
Components Explained
1. ConfigMap
Purpose: Store configuration separately from code
yamlapiVersion: v1
kind: ConfigMap
metadata:
  name: webapp-prod-config
data:
  nginx.conf: |
    server {
      listen 80;
      location /health {
        return 200 'healthy';
      }
    }
Why?

Configuration changes don't require rebuilding images
Same image works across dev, staging, prod
Easy to update without redeployment

2. Secret
Purpose: Store sensitive data securely
yamlapiVersion: v1
kind: Secret
metadata:
  name: webapp-prod-secrets
stringData:
  database-password: "prod-db-pass-123"
  api-key: "prod-api-key-xyz"
Why?

Passwords never in code or ConfigMaps
Base64 encoded in etcd
Can be encrypted at rest

3. Init Container
Purpose: Setup before main app starts
What it does:

Generates configuration files
Creates logs directory
Waits for dependencies
Runs database migrations

Example:
yamlinitContainers:
- name: init-config
  image: busybox:1.28
  command:
  - 'sh'
  - '-c'
  - |
    echo "Initializing..."
    echo "Deployment: $(date)" > /shared/deployment.log
4. Main Container (nginx)
Purpose: Run the actual application
Features:

Resource Limits:

yaml  resources:
    requests:
      memory: "128Mi"
      cpu: "100m"
    limits:
      memory: "256Mi"
      cpu: "200m"
Prevents resource hogging

Health Probes:

yaml  livenessProbe:
    httpGet:
      path: /health
      port: 80
Auto-restart if unhealthy

Environment Variables:

From ConfigMap (config)
From Secret (passwords)



5. Sidecar Container
Purpose: Helper functionality
What it does:

Collects logs from nginx
Processes and aggregates
Sends to central logging (in real-world)

Why separate container?

Main app focuses on serving requests
Logging is independent concern
Can update separately

6. Service
Purpose: Expose deployment to network
yamltype: LoadBalancer
ports:
- port: 80
  targetPort: 80
What it does:

Creates stable endpoint
Load balances across pods
External access (LoadBalancer type)

7. HorizontalPodAutoscaler
Purpose: Auto-scale based on load
yamlminReplicas: 3
maxReplicas: 10
metrics:
- type: Resource
  resource:
    name: cpu
    target:
      averageUtilization: 70
How it works:

Monitors CPU/memory every 30 seconds
If CPU > 70%, scale up
If CPU < 70%, scale down
Keeps 3-10 replicas always

Deploy the Project
bash# 1. Deploy everything
kubectl apply -f yaml-examples/15-complete-production-deployment.yaml

# 2. Watch init container complete
kubectl get pods -w
# Init:0/1 → PodInitializing → Running

# 3. Verify all components
kubectl get configmap webapp-prod-config
kubectl get secret webapp-prod-secrets
kubectl get deployment webapp-production-complete
kubectl get service webapp-prod-service
kubectl get hpa webapp-prod-hpa

# 4. Check pods are healthy
kubectl get pods -l app=webapp-prod
# Should show 5/5 pods running

# 5. Test application
kubectl port-forward svc/webapp-prod-service 8080:80
curl http://localhost:8080/health
# Output: healthy
Test Scaling
bash# Manual scale
kubectl scale deployment webapp-production-complete --replicas=8

# Watch HPA
kubectl get hpa webapp-prod-hpa -w

# Generate load to trigger autoscaling
kubectl run -it --rm load-generator --image=busybox /bin/sh
# Inside pod:
while true; do wget -q -O- http://webapp-prod-service; done
Real-World Usage
This pattern is used by:

E-commerce sites (high traffic, need autoscaling)
Microservices (multiple deployments)
SaaS applications (multi-tenant)
API services (need health monitoring)


💙💚 Project 2: Blue-Green Deployment
What It Is
Two identical production environments running simultaneously, with instant traffic cutover.
Visual Representation
BEFORE CUTOVER:
┌──────────────┐          ┌──────────────┐
│     BLUE     │          │    GREEN     │
│   (Active)   │          │  (Standby)   │
│   v1.25      │          │   v1.26      │
│              │          │              │
│  Pod  Pod    │          │  Pod  Pod    │
│       Pod    │          │       Pod    │
└──────────────┘          └──────────────┘
       ↑                         ↑
       │                         │
  ┌────┴─────┐              (warming up)
  │ Service  │
  │ selector:│
  │version:  │
  │  blue    │
  └──────────┘

AFTER CUTOVER:
┌──────────────┐          ┌──────────────┐
│     BLUE     │          │    GREEN     │
│  (Standby)   │          │  (Active)    │
│   v1.25      │          │   v1.26      │
│              │          │              │
│  Pod  Pod    │          │  Pod  Pod    │
│       Pod    │          │       Pod    │
└──────────────┘          └──────────────┘
       ↑                         ↑
       │                         │
  (kept for rollback)       ┌────┴─────┐
                           │ Service  │
                           │ selector:│
                           │version:  │
                           │  green   │
                           └──────────┘
Step-by-Step Process
Step 1: Deploy Blue (Current)
bashkubectl apply -f blue-deployment.yaml
# Creates: 3 pods running v1.25
Step 2: Deploy Green (New)
bashkubectl apply -f green-deployment.yaml
# Creates: 3 pods running v1.26
At this point:

6 total pods running
Service points to blue
All user traffic goes to blue
Green is warming up, tested, ready

Step 3: Test Green
bash# Port-forward to green pods directly
kubectl port-forward deployment/webapp-green 8081:80

# Run tests
curl http://localhost:8081
curl http://localhost:8081/health

# If tests pass, proceed to cutover
Step 4: Cutover (THE BIG MOMENT!)
bash# Switch service selector from blue to green
kubectl patch service webapp-service \
  -p '{"spec":{"selector":{"version":"green"}}}'

# INSTANT! All traffic now goes to green
Step 5: Monitor Green
bash# Watch logs
kubectl logs -l version=green -f

# Monitor errors
kubectl logs -l version=green | grep ERROR

# Check metrics
kubectl top pods -l version=green
Step 6a: If Green is Healthy
bash# Delete blue after validation period (e.g., 1 hour)
kubectl delete deployment webapp-blue
Step 6b: If Green Has Issues
bash# INSTANT ROLLBACK to blue
kubectl patch service webapp-service \
  -p '{"spec":{"selector":{"version":"blue"}}}'

# Back to old version in seconds!
Why Blue-Green?
Pros:

✅ Instant cutover (0 seconds)
✅ Instant rollback (0 seconds)
✅ Full testing before cutover
✅ No mixed versions in production

Cons:

❌ 2x resources temporarily
❌ Database migrations tricky
❌ More complex setup

Use Cases:

Major version releases
High-risk deployments
Need instant rollback capability
Can't tolerate mixed versions

Real-World Examples:

Netflix: Uses red-black (similar to blue-green)
GitHub: Uses blue-green for releases
Etsy: Blue-green with feature flags


🟡 Project 3: Canary Deployment
What It Is
Gradual rollout where small percentage of traffic goes to new version first.
Visual Representation
STAGE 1: Initial Canary (10%)
┌─────────────────────────────────┐
│      100 users/sec              │
└────────────┬────────────────────┘
             │
      ┌──────┴────────┐
      │               │
   90 users        10 users
      ↓               ↓
┌──────────┐    ┌──────────┐
│  STABLE  │    │  CANARY  │
│  v1.25   │    │  v1.26   │
│          │    │          │
│ 9 pods   │    │  1 pod   │
└──────────┘    └──────────┘
     ↓               ↓
  90% traffic    10% traffic


STAGE 2: Increase Canary (30%)
┌─────────────────────────────────┐
│      100 users/sec              │
└────────────┬────────────────────┘
             │
      ┌──────┴────────┐
      │               │
   70 users        30 users
      ↓               ↓
┌──────────┐    ┌──────────┐
│  STABLE  │    │  CANARY  │
│  v1.25   │    │  v1.26   │
│          │    │          │
│ 7 pods   │    │  3 pods  │
└──────────┘    └──────────┘


STAGE 3: Full Rollout (100%)
┌─────────────────────────────────┐
│      100 users/sec              │
└────────────┬────────────────────┘
             │
             │
         100 users
             ↓
        ┌──────────┐
        │  CANARY  │
        │  v1.26   │
        │          │
        │ 10 pods  │
        └──────────┘
   (now becomes stable)
Detailed Process
Stage 1: Deploy Canary (10%)
bash# Deploy stable (90% of pods)
kubectl apply -f stable-deployment.yaml
kubectl scale deployment app-stable --replicas=9

# Deploy canary (10% of pods)
kubectl apply -f canary-deployment.yaml
kubectl scale deployment app-canary --replicas=1

# Service load-balances across both
# Result: ~10% of requests go to canary
Stage 2: Monitor Canary
bash# Watch canary pods
kubectl get pods -l track=canary -w

# Check logs for errors
kubectl logs -l track=canary -f | grep -i error

# Compare error rates
STABLE_ERRORS=$(kubectl logs -l track=stable --since=5m | grep -c ERROR)
CANARY_ERRORS=$(kubectl logs -l track=canary --since=5m | grep -c ERROR)

echo "Stable errors: $STABLE_ERRORS"
echo "Canary errors: $CANARY_ERRORS"

# Check performance metrics
kubectl top pods -l track=canary
kubectl top pods -l track=stable
Stage 3: Gradual Increase
If canary looks good after 30 minutes:
bash# Increase to 30%
kubectl scale deployment app-canary --replicas=3
kubectl scale deployment app-stable --replicas=7

# Wait and monitor...
If still healthy after 1 hour:
bash# Increase to 50%
kubectl scale deployment app-canary --replicas=5
kubectl scale deployment app-stable --replicas=5

# Wait and monitor...
If all metrics green after 2 hours:
bash# Full rollout
kubectl scale deployment app-canary --replicas=10
kubectl scale deployment app-stable --replicas=0

# After validation, delete stable
kubectl delete deployment app-stable
Stage 4: Rollback (If Issues)
bash# If canary shows problems at ANY stage:

# Quick rollback: Scale canary to 0
kubectl scale deployment app-canary --replicas=0

# OR delete canary entirely
kubectl delete deployment app-canary

# All traffic back to stable!
Canary Metrics to Monitor
Application Metrics:

Error rate (should be same as stable)
Response time (should be similar)
Success rate (should be same)

Infrastructure Metrics:

CPU usage
Memory usage
Network traffic

Business Metrics:

Conversion rate
User satisfaction
Revenue impact

Real Implementation Example
bash#!/bin/bash
# Automated canary deployment script

CANARY_NAME="app-canary"
STABLE_NAME="app-stable"

# Stage 1: 10% canary
echo "Stage 1: Deploying 10% canary"
kubectl scale deployment $CANARY_NAME --replicas=1
kubectl scale deployment $STABLE_NAME --replicas=9
sleep 1800  # Wait 30 minutes

# Check metrics
ERROR_RATE=$(get_error_rate $CANARY_NAME)
if [ $ERROR_RATE -gt 5 ]; then
  echo "High error rate! Rolling back..."
  kubectl scale deployment $CANARY_NAME --replicas=0
  exit 1
fi

# Stage 2: 30% canary
echo "Stage 2: Increasing to 30%"
kubectl scale deployment $CANARY_NAME --replicas=3
kubectl scale deployment $STABLE_NAME --replicas=7
sleep 3600  # Wait 1 hour

# Continue...
Why Canary?
Pros:

✅ Minimal risk (small % affected)
✅ Real user testing
✅ Can catch issues early
✅ Gradual rollout

Cons:

❌ Takes longer than blue-green
❌ Requires good monitoring
❌ Complex traffic splitting

Best For:

High-risk changes
New features
Performance optimizations
When you want real user feedback

Companies Using Canary:

Google: Canary for search algorithm
Facebook: Canary for feed changes
Netflix: Canary for recommendations
Uber: Canary for pricing changes


**📊 Comparing the Three Projects**
FeatureProduction DeploymentBlue-GreenCanaryComplexityMediumHighVery HighRiskMediumLowVery LowSpeedFastInstant switchGradualRollbackVia kubectlInstantFastResources1x2x temporary~1.1xBest ForStandard updatesMajor releasesRisky changesMonitoringStandardIntensiveVery intensiveUser ImpactBrief mixed stateNoneMinimal

🎓 Key Takeaways
Production Deployment

One deployment to rule them all
All features in one place
Good for most scenarios

Blue-Green

Two environments
Instant switch
Perfect for major releases

Canary

Gradual rollout
Minimal risk
Best for high-stakes changes


💡 Which to Use When?
Use Production Deployment when:

Regular bug fixes
Minor feature additions
Standard updates
Low-risk changes

Use Blue-Green when:

Major version upgrades
Need instant rollback
Breaking changes
High-visibility releases

Use Canary when:

Risky features
Performance optimizations
Algorithm changes
Want real user feedback


🚀 Try All Three!
Each project teaches different production patterns. Practice all three to master Kubernetes deployments!
#CKA #Kubernetes #Deployments #ProductionPatterns
