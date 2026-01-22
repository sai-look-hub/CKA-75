****Namespaces & Labels - Troubleshooting Guide & Project Explanation****
🔧 Troubleshooting Guide

🚨 Common Issues & Solutions
Issue 1: Namespace Stuck in "Terminating" State
Symptom:
bashkubectl delete namespace dev
# Namespace stays in "Terminating" forever
Cause:

Finalizers preventing deletion
Resources with dependencies still exist
API server can't complete cleanup

Solution:
Step 1: Check what's stuck
bashkubectl get namespace dev -o yaml

# Look for:
spec:
  finalizers:
  - kubernetes
Step 2: Force delete (careful!)
bash# Get namespace JSON
kubectl get namespace dev -o json > dev.json

# Edit: Remove finalizers
# Change: "finalizers": ["kubernetes"]
# To: "finalizers": []

# Apply change
kubectl replace --raw "/api/v1/namespaces/dev/finalize" -f ./dev.json
Step 3: Alternative method
bashkubectl get namespace dev -o json | \
  jq '.spec.finalizers = []' | \
  kubectl replace --raw "/api/v1/namespaces/dev/finalize" -f -
Prevention:

Always check what's in namespace before deleting
Use kubectl get all -n dev to see resources
Delete resources manually first if needed


Issue 2: Service Can't Find Pods (Empty Endpoints)
Symptom:
bashkubectl get endpoints my-service
# NAME         ENDPOINTS
# my-service   <none>

# Service not routing traffic
Diagnosis:
Step 1: Check service selector
bashkubectl get svc my-service -o yaml | grep -A 3 selector
# Output: selector labels
Step 2: Check pod labels
bashkubectl get pods --show-labels
# Verify pods have matching labels
Step 3: Compare
bash# Service selector
selector:
  app: frontend
  tier: web

# Pod labels
labels:
  app: frontend
  # Missing: tier: web  ← PROBLEM!
Solution:
Fix A: Add missing label to pods
bashkubectl label pods -l app=frontend tier=web
Fix B: Fix deployment/pod template
yamlspec:
  template:
    metadata:
      labels:
        app: frontend
        tier: web  # Add missing label
Fix C: Simplify service selector
yamlselector:
  app: frontend  # Remove tier requirement
Verify Fix:
bashkubectl get endpoints my-service
# Should now show pod IPs

Issue 3: Resource Quota Exceeded
Symptom:
bashkubectl apply -f deployment.yaml -n dev
# Error: exceeded quota: dev-quota

kubectl get pods -n dev
# Pod stays in Pending state
Diagnosis:
Step 1: Check quota usage
bashkubectl describe resourcequota -n dev

# Output:
# Resource    Used  Hard
# --------    ----  ----
# cpu         10    10    ← At limit!
# memory      18Gi  20Gi
# pods        50    50    ← At limit!
Step 2: Find resource hogs
bash# See pod resource usage
kubectl top pods -n dev --sort-by=cpu

# See pod resource requests
kubectl get pods -n dev -o custom-columns=\
NAME:.metadata.name,\
CPU_REQ:.spec.containers[*].resources.requests.cpu,\
MEM_REQ:.spec.containers[*].resources.requests.memory
Solutions:
Option A: Increase quota
bashkubectl edit resourcequota dev-quota -n dev
# Increase: cpu: "20", pods: "100"
Option B: Delete unused resources
bash# Find and delete old pods
kubectl delete pods -l temporary=true -n dev

# Scale down deployments
kubectl scale deployment old-app --replicas=0 -n dev
Option C: Reduce resource requests
yaml# In deployment
resources:
  requests:
    cpu: "100m"     # Reduced from 500m
    memory: "128Mi" # Reduced from 512Mi
Prevention:

Monitor quota usage regularly
Set alerts at 80% usage
Clean up old resources
Right-size resource requests


Issue 4: Pod Rejected by LimitRange
Symptom:
bashkubectl apply -f pod.yaml -n dev
# Error: Pod "my-pod" is invalid: 
# spec.containers[0].resources.requests.memory: 
# Invalid value: "4Gi": must be less than or equal to memory limit

kubectl get events -n dev
# Failed to admit pod: memory limit exceeds maximum
Diagnosis:
Step 1: Check LimitRange
bashkubectl describe limitrange -n dev

# Output:
# Type      Resource  Min   Max   Default  DefaultRequest
# ----      --------  ---   ---   -------  --------------
# Container memory    64Mi  2Gi   512Mi    128Mi
#           cpu       50m   2     500m     100m
Step 2: Check pod resources
yaml# Pod requests 4Gi, but max is 2Gi
resources:
  requests:
    memory: "4Gi"  # ← Exceeds max!
Solutions:
Option A: Adjust pod resources
yamlresources:
  requests:
    memory: "2Gi"   # At or below max
    cpu: "1"
  limits:
    memory: "2Gi"
    cpu: "2"
Option B: Increase LimitRange maximum
bashkubectl edit limitrange dev-limits -n dev
# Increase max:
#   memory: 4Gi
Option C: Remove LimitRange constraints
bash# Not recommended, but possible
kubectl delete limitrange dev-limits -n dev
Prevention:

Document LimitRange policies
Provide developers with templates
Use admission webhooks to validate
Set reasonable maxima


Issue 5: Can't Access Resource in Different Namespace
Symptom:
bash# Pod in 'dev' namespace trying to access service in 'prod'
curl http://backend-service:8080
# Connection refused or timeout
Diagnosis:
Step 1: Check service exists
bashkubectl get svc backend-service -n prod
# Verify it exists
Step 2: Use FQDN
bash# From pod in 'dev', must use full DNS name
curl http://backend-service.prod.svc.cluster.local:8080
# <service>.<namespace>.svc.cluster.local
Step 3: Check Network Policies
bashkubectl get networkpolicies -n prod
# Network policies might block cross-namespace traffic
Solutions:
Option A: Use FQDN in application
yaml# ConfigMap
data:
  BACKEND_URL: "http://backend-service.prod.svc.cluster.local:8080"
Option B: Create ExternalName service
yaml# In 'dev' namespace
apiVersion: v1
kind: Service
metadata:
  name: backend-service
  namespace: dev
spec:
  type: ExternalName
  externalName: backend-service.prod.svc.cluster.local
  ports:
  - port: 8080
Option C: Allow cross-namespace in Network Policy
yamlapiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-dev
  namespace: prod
spec:
  podSelector:
    matchLabels:
      app: backend
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          environment: development

Issue 6: Label Selector Not Matching Pods
Symptom:
bashkubectl get pods -l app=frontend
# No resources found

# But pods exist:
kubectl get pods
# frontend-abc123
Diagnosis:
Step 1: Check pod labels
bashkubectl get pods frontend-abc123 --show-labels
# app=frontent  ← Typo!
Step 2: Check label format
bash# Wrong selector syntax
kubectl get pods -l 'app = frontend'  # Spaces cause issues

# Correct syntax
kubectl get pods -l app=frontend
Solutions:
Option A: Fix label on pods
bash# Remove wrong label
kubectl label pods frontend-abc123 app-

# Add correct label
kubectl label pods frontend-abc123 app=frontend
Option B: Fix deployment template
yamlspec:
  template:
    metadata:
      labels:
        app: frontend  # Fix typo
Option C: Label multiple pods at once
bash# Fix all pods with typo
kubectl get pods -o name | \
  xargs -I {} kubectl label {} app=frontend --overwrite
Prevention:

Use CI/CD validation
Lint YAML files
Use label templates
Review before applying


🎯 Project Explanation: Multi-Tenant Cluster Setup
Project Overview
Name: Multi-Tenant Kubernetes Cluster Simulation
Purpose: Demonstrate namespace isolation, resource quotas, and label-based organization
Complexity: Intermediate

Architecture
┌────────────────────────────────────────────────────────────┐
│              KUBERNETES CLUSTER (Multi-Tenant)              │
└────────────────────────────────────────────────────────────┘
                          │
        ┌─────────────────┼─────────────────┐
        │                 │                 │
┌───────▼────────┐ ┌─────▼──────┐ ┌───────▼────────┐
│ DEV Namespace  │ │  STAGING   │ │ PROD Namespace │
│ environment:   │ │  Namespace │ │ environment:   │
│ development    │ │environment:│ │ production     │
│                │ │  staging   │ │ critical: true │
└────────────────┘ └────────────┘ └────────────────┘
│                │                │                │
│ Quota:         │ Quota:         │ Quota:         │
│ CPU: 10        │ CPU: 20        │ CPU: 50        │
│ Memory: 20Gi   │ Memory: 40Gi   │ Memory: 100Gi  │
│ Pods: 50       │ Pods: 100      │ Pods: 200      │
│                │                │                │
│ LimitRange:    │ LimitRange:    │ LimitRange:    │
│ Default: 512Mi │ Default: 1Gi   │ Default: 1Gi   │
│ Max: 2Gi       │ Max: 4Gi       │ Max: 8Gi       │
└────────────────┘ └────────────┘ └────────────────┘
        │                 │                 │
   ┌────▼────┐       ┌────▼────┐       ┌────▼────┐
   │Frontend │       │Frontend │       │Frontend │
   │Backend  │       │Backend  │       │Backend  │
   │Database │       │Database │       │Database │
   └─────────┘       └─────────┘       └─────────┘
     2 replicas        3 replicas        5 replicas

Components
1. Namespace Structure
Environment-based:

dev - Development environment
staging - Pre-production testing
prod - Production environment

Team-based:

team-alpha - Microservices team
team-beta - Data platform team
team-gamma - ML operations team

Labels on Namespaces:
yamllabels:
  environment: development
  team: engineering
  cost-center: "1001"
  critical: "false"
Why This Matters:

Clear ownership
Cost tracking
Priority management
Compliance requirements


2. Resource Quotas
Purpose: Prevent resource hogging, ensure fair allocation
Development (Small):
yamlhard:
  requests.cpu: "10"
  requests.memory: 20Gi
  pods: "50"
Staging (Medium):
yamlhard:
  requests.cpu: "20"
  requests.memory: 40Gi
  pods: "100"
Production (Large):
yamlhard:
  requests.cpu: "50"
  requests.memory: 100Gi
  pods: "200"
  services.loadbalancers: "10"
Why Different Quotas:

Dev: Lower usage, experimental
Staging: Similar to prod, but less traffic
Prod: High availability, peak traffic


3. LimitRanges
Purpose: Set defaults, prevent accidents
Development:
yamllimits:
- type: Container
  max:
    cpu: "2"
    memory: 2Gi
  default:
    cpu: "500m"
    memory: 512Mi
Production:
yamllimits:
- type: Container
  max:
    cpu: "4"
    memory: 8Gi
  default:
    cpu: "1"
    memory: 1Gi
Why Important:

Developers don't need to specify limits
Prevents single pod from consuming node
Consistent resource allocation
Easier capacity planning


4. Label Strategy
Standard Labels Applied:
yaml# Application identification
app: myapp
component: frontend
tier: presentation

# Operational metadata
environment: production
version: v1.0.0
release: stable

# Organizational
team: alpha
owner: alice@company.com
cost-center: "1001"

# Feature flags
critical: "true"
monitored: "true"
Benefits:

Easy querying across namespaces
Bulk operations
Cost allocation
Monitoring & alerting
Service selection


Deployment Workflow
Step 1: Create Namespace Infrastructure
bash# Create namespaces
kubectl apply -f manifests/01-basic-namespaces/

# Set quotas
kubectl apply -f manifests/03-resource-quotas/

# Set limit ranges
kubectl apply -f manifests/04-limit-ranges/

# Verify
kubectl get ns,quota,limits --all-namespaces
Step 2: Deploy Applications
bash# Deploy to dev
kubectl apply -f manifests/05-deployments-with-labels/ -n dev

# Deploy to staging
kubectl apply -f manifests/05-deployments-with-labels/ -n staging

# Deploy to prod (scaled up)
kubectl apply -f manifests/05-deployments-with-labels/ -n prod
kubectl scale deployment frontend --replicas=5 -n prod
kubectl scale deployment backend --replicas=5 -n prod
Step 3: Create Services
bashkubectl apply -f manifests/06-services-with-labels/
Step 4: Add Configuration
bashkubectl apply -f manifests/07-configmaps-with-labels/
kubectl apply -f manifests/08-secrets-with-labels/

Testing the Multi-Tenant Setup
Test 1: Resource Isolation
bash# Try to exceed quota in dev
kubectl run test --image=nginx -n dev --replicas=100
# Should fail if quota exceeded

# Check quota usage
kubectl describe quota dev-quota -n dev
Test 2: Cross-Namespace Communication
bash# From pod in dev, access service in prod
kubectl exec -it <dev-pod> -n dev -- sh
curl http://backend-service.prod.svc.cluster.local:8080
Test 3: Label Selection
bash# Find all frontend pods across all environments
kubectl get pods -A -l tier=presentation

# Find all production resources
kubectl get all -A -l environment=production

# Find Team Alpha resources
kubectl get all -A -l team=alpha
Test 4: LimitRange Enforcement
bash# Create pod without resource limits
# Should get defaults from LimitRange
kubectl run test --image=nginx -n dev

# Check assigned resources
kubectl get pod test -n dev -o yaml | grep -A 5 resources

Real-World Use Cases
Use Case 1: Multi-Team Organization
Scenario: Company has 3 teams sharing one cluster
Solution:

Namespace per team (team-alpha, team-beta, team-gamma)
Resource quotas based on team budget
Labels for cost tracking
RBAC for access control

Benefits:

Cost attribution per team
Resource fairness
Team autonomy
Centralized management


Use Case 2: Environment Separation
Scenario: Need dev/staging/prod environments
Solution:

Namespace per environment
Different resource limits
Different replica counts
Label-based deployment automation

Benefits:

Clear separation
Test before production
Gradual rollout
Easy troubleshooting


Use Case 3: Canary Deployments
Scenario: Roll out new version gradually
Implementation:
bash# Stable: 9 replicas (90%)
kubectl scale deployment app-stable --replicas=9

# Canary: 1 replica (10%)
kubectl scale deployment app-canary --replicas=1

# Service selects both via label: app=myapp

# Gradually increase canary
kubectl scale deployment app-canary --replicas=3
kubectl scale deployment app-stable --replicas=7
Benefits:

Minimal risk
Real user testing
Easy rollback
Gradual validation


Monitoring & Observability
Check Resource Usage
bash# Per namespace
kubectl top pods -n dev
kubectl top pods -n staging
kubectl top pods -n prod

# By label
kubectl top pods -A -l environment=production

# Quota usage
for ns in dev staging prod; do
  echo "=== $ns ==="
  kubectl describe quota -n $ns
done
Cost Allocation
bash# Resources by cost center
kubectl get all -A -l cost-center=1001

# Resources by team
kubectl get all -A -l team=alpha

# Production critical resources
kubectl get all -A -l critical=true

Key Learnings

Namespace Isolation

Logical separation
Resource quotas prevent hogging
Cross-namespace communication possible


Label Strategy

Consistent labeling enables powerful queries
Labels for both Kubernetes and operations
Use standard label keys


Resource Management

Quotas for total limits
LimitRanges for per-resource limits
Both needed for effective control


Multi-Tenancy

Namespaces + RBAC = effective multi-tenancy
Labels for cross-cutting concerns
Quotas for fair resource allocation




Cleanup
bash# Delete all test namespaces
kubectl delete ns dev staging prod team-alpha team-beta team-gamma

# Or delete by label
kubectl delete ns -l environment=development

🎓 Summary
Namespaces provide:

Resource isolation
Logical organization
Quota boundaries
RBAC scope

Labels provide:

Resource selection
Bulk operations
Cost tracking
Monitoring

Together they enable:

Multi-tenancy
Environment separation
Team organization
Effective resource management


Master these concepts for CKA exam and production Kubernetes! ✅
