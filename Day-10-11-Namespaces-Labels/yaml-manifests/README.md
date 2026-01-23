****Namespaces & Labels - Manifests README****
Complete YAML manifests for Day 10-11: Multi-Tenant Cluster Setup

📂 Folder Structure
manifests/
├── 01-basic-namespaces/
│   ├── dev-namespace.yaml
│   ├── staging-namespace.yaml
│   └── prod-namespace.yaml
├── 02-team-namespaces/
│   ├── team-alpha.yaml
│   ├── team-beta.yaml
│   └── team-gamma.yaml
├── 03-resource-quotas/
│   ├── dev-quota.yaml
│   ├── staging-quota.yaml
│   └── prod-quota.yaml
├── 04-limit-ranges/
│   ├── dev-limits.yaml
│   └── prod-limits.yaml
├── 05-deployments-with-labels/
│   ├── frontend-deployment.yaml
│   ├── backend-deployment.yaml
│   └── database-statefulset.yaml
├── 06-services-with-labels/
│   ├── frontend-service.yaml
│   └── backend-service.yaml
├── 07-configmaps-with-labels/
│   └── app-config.yaml
└── 08-secrets-with-labels/
    └── database-credentials.yaml

examples/
├── 01-label-selector-examples.yaml
├── 02-multi-environment-deployment.yaml
├── 03-canary-deployment-labels.yaml
└── 04-annotation-examples.yaml

project/
└── complete-multi-tenant-cluster.yaml


🚀 Quick Start
Deploy Complete Multi-Tenant Cluster
bash# Method 1: All-in-one
kubectl apply -f project/complete-multi-tenant-cluster.yaml

# Method 2: Step-by-step
kubectl apply -f manifests/01-basic-namespaces/
kubectl apply -f manifests/03-resource-quotas/
kubectl apply -f manifests/04-limit-ranges/
kubectl apply -f manifests/05-deployments-with-labels/
kubectl apply -f manifests/06-services-with-labels/

# Verify
kubectl get ns,quota,limits,deploy,svc --all-namespaces
Deploy Examples
bash# Label selector examples
kubectl apply -f examples/01-label-selector-examples.yaml

# Multi-environment deployment
kubectl apply -f examples/02-multi-environment-deployment.yaml

# Canary deployment
kubectl apply -f examples/03-canary-deployment-labels.yaml

📊 Component Overview
**1. Namespaces (01-basic-namespaces/)**
Purpose: Create environment-based namespaces
Files:

dev-namespace.yaml - Development environment
staging-namespace.yaml - Staging environment
prod-namespace.yaml - Production environment

Labels Applied:
yamlenvironment: development|staging|production
team: engineering
cost-center: "1001"
critical: "true" (prod only)
Deploy:
bashkubectl apply -f manifests/01-basic-namespaces/
kubectl get ns --show-labels

**2. Team Namespaces (02-team-namespaces/)**
Purpose: Create team-based namespaces
Files:

team-alpha.yaml - Microservices team
team-beta.yaml - Data platform team
team-gamma.yaml - ML operations team

Labels Applied:
yamlteam: alpha|beta|gamma
department: engineering
project: microservices|data-platform|ml-ops
budget: high|medium
Deploy:
bashkubectl apply -f manifests/02-team-namespaces/
kubectl get ns -l department=engineering

**3. Resource Quotas (03-resource-quotas/)**
Purpose: Limit resource consumption per namespace
Dev Quota:

CPU: 10 cores
Memory: 20Gi
Pods: 50

Staging Quota:

CPU: 20 cores
Memory: 40Gi
Pods: 100

Prod Quota:

CPU: 50 cores
Memory: 100Gi
Pods: 200

Deploy:
bashkubectl apply -f manifests/03-resource-quotas/

# Check usage
kubectl describe quota dev-quota -n dev
kubectl describe quota staging-quota -n staging
kubectl describe quota prod-quota -n prod
Monitor Usage:
bash# See current vs limits
for ns in dev staging prod; do
  echo "=== $ns ==="
  kubectl describe quota -n $ns | grep -A 5 "Resource"
done

**4. LimitRanges (04-limit-ranges/)**
Purpose: Set defaults and constraints per pod/container
Dev Limits:
yamlmax: 2 CPU, 2Gi memory
default: 500m CPU, 512Mi memory
min: 50m CPU, 64Mi memory
Prod Limits:
yamlmax: 4 CPU, 8Gi memory
default: 1 CPU, 1Gi memory
min: 100m CPU, 128Mi memory
Deploy:
bashkubectl apply -f manifests/04-limit-ranges/

# Check limits
kubectl describe limits dev-limits -n dev
kubectl describe limits prod-limits -n prod
Test Defaults:
bash# Create pod without resource specs
kubectl run test --image=nginx -n dev

# Check assigned resources (should have defaults)
kubectl get pod test -n dev -o yaml | grep -A 10 resources

**5. Deployments with Labels (05-deployments-with-labels/)**
Purpose: Deploy applications with comprehensive labeling
Frontend Deployment:
yamllabels:
  app: frontend
  tier: presentation
  environment: development
  version: v1.0.0
  team: alpha
Backend Deployment:
yamllabels:
  app: backend
  tier: application
  environment: development
  version: v2.1.0
  team: alpha
  language: nodejs
Database StatefulSet:
yamllabels:
  app: database
  tier: data
  environment: development
  version: v8.0
  team: alpha
  stateful: "true"
Deploy:
bashkubectl apply -f manifests/05-deployments-with-labels/ -n dev

# View with labels
kubectl get pods -n dev --show-labels

# Query by label
kubectl get pods -n dev -l tier=presentation
kubectl get pods -n dev -l team=alpha

6. Services with Labels (06-services-with-labels/)
Frontend Service (LoadBalancer):
yamllabels:
  app: frontend
  tier: presentation
  service-type: loadbalancer
selector:
  app: frontend
  tier: presentation
Backend Service (ClusterIP):
yamllabels:
  app: backend
  tier: application
  service-type: clusterip
selector:
  app: backend
  tier: application
sessionAffinity: ClientIP
Deploy:
bashkubectl apply -f manifests/06-services-with-labels/ -n dev

# Verify selectors match pods
kubectl get svc -n dev
kubectl get endpoints -n dev

7. ConfigMaps with Labels (07-configmaps-with-labels/)
Purpose: Configuration with metadata labels
Labels Applied:
yamlapp: backend
environment: development
config-type: application
version: v1.0
Annotations:
yamldescription: "Application configuration"
last-updated: "2026-01-21"
Deploy:
bashkubectl apply -f manifests/07-configmaps-with-labels/ -n dev

# View config
kubectl describe configmap app-config -n dev

8. Secrets with Labels (08-secrets-with-labels/)
Purpose: Credentials with metadata labels
Labels Applied:
yamlapp: database
environment: development
secret-type: credentials
tier: data
Annotations:
yamldescription: "Database credentials"
rotation-policy: "monthly"
Deploy:
bashkubectl apply -f manifests/08-secrets-with-labels/ -n dev

# View secret (not data!)
kubectl describe secret database-credentials -n dev

🧪 Examples Explained
Example 1: Label Selector Examples
Demonstrates:

Equality-based selectors
Set-based selectors (In, NotIn, Exists, DoesNotExist)
Complex selector combinations

Deploy:
bashkubectl apply -f examples/01-label-selector-examples.yaml

# Test selectors
kubectl get pods -l app=myapp
kubectl get pods -l 'environment in (prod,staging)'
kubectl get pods -l version

Example 2: Multi-Environment Deployment
Demonstrates:

Same app across dev/staging/prod
Different replicas per environment
Different resource limits
Environment-specific labels

Deploy:
bashkubectl apply -f examples/02-multi-environment-deployment.yaml

# View across environments
kubectl get deploy -A -l app=myapp

Example 3: Canary Deployment with Labels
Demonstrates:

Stable vs Canary versions
Traffic distribution via replicas
Version labels (track: stable/canary)
Single service selecting both

Deploy:
bashkubectl apply -f examples/03-canary-deployment-labels.yaml

# Monitor canary
kubectl get pods -l track=canary -w
kubectl logs -l track=canary -f

# Promote canary
kubectl scale deployment app-canary --replicas=10
kubectl scale deployment app-stable --replicas=0

Example 4: Annotation Examples
Demonstrates:

Build information
Contact details
Documentation links
Monitoring integration
Custom metadata

Deploy:
bashkubectl apply -f examples/04-annotation-examples.yaml

# View annotations
kubectl describe deployment annotation-examples | grep -A 20 Annotations

🔍 Common Operations
Query Resources by Labels
bash# Find all frontend pods across namespaces
kubectl get pods -A -l tier=presentation

# Find production resources
kubectl get all -A -l environment=production

# Find Team Alpha resources
kubectl get all -A -l team=alpha

# Complex query
kubectl get pods -A -l 'app=backend,environment in (prod,staging)'
Update Labels
bash# Add label to existing resources
kubectl label pods --all environment=dev -n dev

# Update label
kubectl label deployment frontend version=v2.0 --overwrite -n dev

# Remove label
kubectl label pods -l app=frontend version- -n dev
Check Quotas and Limits
bash# Quota usage
kubectl describe quota -n dev
kubectl describe quota -n staging
kubectl describe quota -n prod

# Limit ranges
kubectl describe limits -n dev
kubectl describe limits -n prod

# Resources per pod
kubectl get pods -n dev -o custom-columns=\
NAME:.metadata.name,\
CPU:.spec.containers[*].resources.requests.cpu,\
MEMORY:.spec.containers[*].resources.requests.memory
Switch Between Environments
bash# Set context to dev
kubectl config set-context --current --namespace=dev

# Quick commands
kubectl get pods  # Gets pods from dev

# Switch to prod
kubectl config set-context --current --namespace=prod

# View across all
kubectl get pods -A -l app=backend

🚨 Troubleshooting
Issue: Service Not Finding Pods
bash# Check service selector
kubectl get svc my-service -o yaml | grep -A 3 selector

# Check pod labels
kubectl get pods --show-labels

# Check endpoints
kubectl get endpoints my-service
# Empty = selector mismatch
Issue: Quota Exceeded
bash# Check usage
kubectl describe quota -n dev

# Find resource hogs
kubectl top pods -n dev --sort-by=cpu

# Clean up
kubectl delete pods -l temporary=true -n dev
Issue: Namespace Stuck Terminating
bash# Force delete
kubectl get namespace dev -o json | \
  jq '.spec.finalizers = []' | \
  kubectl replace --raw "/api/v1/namespaces/dev/finalize" -f -

📚 Best Practices
Namespace Strategy
✅ Do:

One namespace per environment (dev/staging/prod)
One namespace per team for isolation
Always set resource quotas
Always set limit ranges
Label namespaces for organization

❌ Don't:

Create too many namespaces (hard to manage)
Share production namespace with non-prod
Delete namespace without checking contents
Skip resource limits

Label Strategy
✅ Do:
yaml# Use consistent, meaningful labels
labels:
  app: myapp
  tier: frontend
  environment: production
  version: v1.0.0
  team: alpha
❌ Don't:
yaml# Avoid changing data in labels
labels:
  timestamp: "2026-01-21"  # Use annotations
  build-number: "12345"    # Use annotations
Resource Management
✅ Do:

Set quotas for all namespaces
Monitor quota usage
Set reasonable default limits
Plan for bursts (limits > requests)

❌ Don't:

Skip limit ranges
Set quotas too low
Ignore quota warnings
Delete quotas in production


🎯 Testing Scenarios
Test 1: Resource Isolation
bash# Try to exceed dev quota
kubectl run test1 --image=nginx --replicas=100 -n dev
# Should fail when quota exceeded

# Check quota
kubectl describe quota dev-quota -n dev
Test 2: Cross-Namespace Access
bash# From pod in dev
kubectl exec -it <pod> -n dev -- sh
curl http://backend-service.staging.svc.cluster.local:8080
Test 3: Label-Based Operations
bash# Scale all frontend deployments
kubectl scale deployment -l tier=frontend --replicas=5 -n dev

# Delete temporary pods
kubectl delete pods -l temporary=true -A

# Update version label
kubectl label pods -l app=backend version=v2.0 --overwrite -n dev

🎓 Key Concepts
Namespace Isolation

Logical separation of resources
Separate quotas and limits
Cross-namespace communication possible
RBAC boundary

Label Selectors

Equality-based: app=frontend
Set-based: environment in (prod,staging)
Used by Services, Deployments, queries

Resource Quotas

Total limits per namespace
Prevents resource hogging
Fair allocation

LimitRanges

Per-resource limits
Default values
Prevents accidents


📖 Additional Resources

Complete Guide
Troubleshooting Guide
Interview Questions
Command Cheatsheet


All manifests tested and production-ready! ✅
Deploy with confidence! 🚀
#CKA #Kubernetes #Namespaces #Labels #MultiTenant
