Namespaces & Labels - Command Cheatsheet 🚀
📋 Quick Reference Guide for Day 10-11

🗂️ Namespace Commands
Create Namespaces
bash# Create namespace (imperative)
kubectl create namespace dev

# Create with labels
kubectl create namespace dev --labels=environment=development,team=alpha

# Create from YAML
kubectl apply -f namespace.yaml

# Generate YAML
kubectl create namespace dev --dry-run=client -o yaml > dev-namespace.yaml
View Namespaces
bash# List all namespaces
kubectl get namespaces
kubectl get ns

# Show labels
kubectl get ns --show-labels

# Describe namespace
kubectl describe namespace dev

# Get YAML output
kubectl get ns dev -o yaml

# Filter by label
kubectl get ns -l environment=production
Set Default Namespace
bash# Set context to use specific namespace
kubectl config set-context --current --namespace=dev

# Verify current namespace
kubectl config view --minify | grep namespace

# Switch back to default
kubectl config set-context --current --namespace=default
Delete Namespaces
bash# Delete namespace (deletes all resources inside!)
kubectl delete namespace dev

# Delete multiple namespaces
kubectl delete ns dev staging

# Delete with selector
kubectl delete ns -l environment=development

🏷️ Label Commands
Add Labels
bash# Add label to existing resource
kubectl label pods my-pod app=frontend

# Add multiple labels
kubectl label pods my-pod tier=frontend version=v1.0

# Add label to namespace
kubectl label namespace dev team=alpha

# Label all pods
kubectl label pods --all environment=dev

# Label multiple pods
kubectl label pods -l app=backend tier=application
Update Labels
bash# Update existing label (requires --overwrite)
kubectl label pods my-pod version=v2.0 --overwrite

# Update label on all matching pods
kubectl label pods -l app=backend version=v2.0 --overwrite
Remove Labels
bash# Remove label (note the minus sign)
kubectl label pods my-pod version-

# Remove multiple labels
kubectl label pods my-pod version- release-

# Remove from all pods
kubectl label pods --all version-
View Labels
bash# Show all pod labels
kubectl get pods --show-labels

# Show specific label columns
kubectl get pods -L app,tier,version

# View labels in describe
kubectl describe pod my-pod | grep Labels

# Get YAML to see all labels
kubectl get pod my-pod -o yaml

🔍 Label Selectors
Equality-Based Selectors
bash# Select by single label
kubectl get pods -l app=frontend

# Select by multiple labels (AND)
kubectl get pods -l app=frontend,tier=presentation

# Select NOT equal
kubectl get pods -l app!=backend

# Multiple conditions
kubectl get pods -l environment=prod,app!=cache
Set-Based Selectors
bash# In operator
kubectl get pods -l 'environment in (prod,staging)'

# NotIn operator
kubectl get pods -l 'tier notin (cache,database)'

# Exists
kubectl get pods -l version

# Does not exist
kubectl get pods -l '!legacy'

# Complex selector
kubectl get pods -l 'app=backend,environment in (prod,staging),!deprecated'
Select Across Namespaces
bash# All namespaces
kubectl get pods --all-namespaces -l app=backend
kubectl get pods -A -l app=backend

# Specific namespace
kubectl get pods -n prod -l app=backend

# Multiple namespaces (use multiple commands)
kubectl get pods -n dev -l app=backend
kubectl get pods -n staging -l app=backend

📊 Resource Quota Commands
Create Resource Quotas
bash# Create quota from YAML
kubectl apply -f quota.yaml

# Create quota imperatively
kubectl create quota dev-quota --namespace=dev \
  --hard=cpu=10,memory=20Gi,pods=50

# View quotas
kubectl get quota -n dev
kubectl get resourcequota -n dev

# Describe quota (shows usage)
kubectl describe quota dev-quota -n dev
View Quota Usage
bash# See current usage vs limits
kubectl describe resourcequota dev-quota -n dev

# Output:
# Name:       dev-quota
# Namespace:  dev
# Resource    Used  Hard
# --------    ----  ----
# cpu         5     10
# memory      10Gi  20Gi
# pods        25    50

# Get quota in all namespaces
kubectl get quota --all-namespaces
Update Quotas
bash# Edit quota
kubectl edit quota dev-quota -n dev

# Replace quota
kubectl replace -f updated-quota.yaml

# Delete quota
kubectl delete quota dev-quota -n dev

📏 LimitRange Commands
Create LimitRanges
bash# Create from YAML
kubectl apply -f limitrange.yaml

# View limit ranges
kubectl get limitranges -n dev
kubectl get limits -n dev

# Describe limit range
kubectl describe limitrange dev-limits -n dev
View Limits
bash# See all limits in namespace
kubectl get limits -n dev

# Describe shows defaults and constraints
kubectl describe limits dev-limits -n dev

# Output shows:
# - Default limits
# - Default requests
# - Max values
# - Min values

🔎 Advanced Queries
Find Resources by Labels
bash# Find all frontend pods
kubectl get pods --all-namespaces -l tier=frontend

# Find production resources
kubectl get all -l environment=production

# Find resources by team
kubectl get pods,services,deployments -l team=alpha

# Complex query
kubectl get pods -l 'app=backend,environment in (prod,staging),version!=v1.0'
Count Resources
bash# Count pods by label
kubectl get pods -l app=backend --no-headers | wc -l

# Count namespaces
kubectl get ns --no-headers | wc -l

# Resources per namespace
kubectl get pods --all-namespaces | awk '{print $1}' | sort | uniq -c
Export Resources
bash# Export all resources in namespace
kubectl get all -n dev -o yaml > dev-backup.yaml

# Export specific resources with labels
kubectl get deployments -l app=backend -o yaml > backend-deployments.yaml

# Export namespaces
kubectl get ns -o yaml > namespaces-backup.yaml

🏢 Multi-Tenant Operations
Switch Between Namespaces
bash# Create context per environment
kubectl config set-context dev --namespace=dev --cluster=my-cluster --user=my-user
kubectl config set-context staging --namespace=staging --cluster=my-cluster --user=my-user
kubectl config set-context prod --namespace=prod --cluster=my-cluster --user=my-user

# Switch contexts
kubectl config use-context dev
kubectl config use-context prod

# Quick namespace switch (current context)
kubectl config set-context --current --namespace=staging
View Resources Across Environments
bash# See same app across environments
kubectl get deployments -l app=backend --all-namespaces

# Compare pod counts
kubectl get pods -n dev -l app=backend --no-headers | wc -l
kubectl get pods -n prod -l app=backend --no-headers | wc -l

# View resource usage across namespaces
kubectl top pods --all-namespaces -l app=backend
Bulk Operations
bash# Scale across environments
kubectl scale deployment backend --replicas=3 -n dev
kubectl scale deployment backend --replicas=5 -n staging
kubectl scale deployment backend --replicas=10 -n prod

# Update image across namespaces
for ns in dev staging prod; do
  kubectl set image deployment/backend backend=backend:v2.0 -n $ns
done

# Delete resources by label across namespaces
kubectl delete pods -l temporary=true --all-namespaces

🔧 Troubleshooting Commands
Check Namespace Issues
bash# Check if namespace exists
kubectl get ns dev

# View namespace events
kubectl get events -n dev --sort-by=.metadata.creationTimestamp

# Check resource quotas
kubectl describe quota -n dev

# Check limit ranges
kubectl describe limits -n dev

# See why pod isn't starting (quota exceeded)
kubectl describe pod my-pod -n dev
# Look for: "exceeded quota"
Label Mismatches
bash# Check pod labels
kubectl get pods my-pod --show-labels

# Check selector
kubectl get deployment my-deployment -o yaml | grep -A 5 selector

# Find orphaned pods (no service selecting them)
kubectl get pods --show-labels
kubectl get svc -o yaml | grep -A 3 selector

# Find pods not matching deployment selector
kubectl get pods -l app!=myapp
Resource Quota Debugging
bash# Check current quota usage
kubectl describe quota -n dev

# See which resources are over quota
kubectl get events -n dev | grep -i quota

# List all pods with resource requests
kubectl get pods -n dev -o custom-columns=NAME:.metadata.name,CPU_REQ:.spec.containers[*].resources.requests.cpu,MEM_REQ:.spec.containers[*].resources.requests.memory

# Check total resource usage
kubectl top pods -n dev
kubectl top nodes

📝 Annotations Commands
Add Annotations
bash# Add annotation
kubectl annotate pods my-pod description="Production web server"

# Add multiple annotations
kubectl annotate pods my-pod \
  contact="admin@company.com" \
  docs="https://docs.company.com/my-pod"

# Annotate namespace
kubectl annotate namespace dev owner="dev-team@company.com"
View Annotations
bash# Show annotations
kubectl get pods my-pod -o jsonpath='{.metadata.annotations}'

# Describe shows annotations
kubectl describe pod my-pod | grep -A 10 Annotations

# Get specific annotation
kubectl get pod my-pod -o jsonpath='{.metadata.annotations.description}'
Remove Annotations
bash# Remove annotation (note the minus)
kubectl annotate pods my-pod description-

# Remove multiple annotations
kubectl annotate pods my-pod contact- docs-

🎯 Common Workflows
Deploy to Multiple Environments
bash# Create namespaces
kubectl create ns dev
kubectl create ns staging
kubectl create ns prod

# Label them
kubectl label ns dev environment=development
kubectl label ns staging environment=staging
kubectl label ns prod environment=production

# Deploy to each
kubectl apply -f app.yaml -n dev
kubectl apply -f app.yaml -n staging
kubectl apply -f app.yaml -n prod

# Verify
kubectl get all -l app=myapp --all-namespaces
Organize by Team
bash# Create team namespaces
kubectl create ns team-alpha
kubectl create ns team-beta

# Label by team
kubectl label ns team-alpha team=alpha department=engineering
kubectl label ns team-beta team=beta department=engineering

# Set quotas per team
kubectl create quota alpha-quota --namespace=team-alpha \
  --hard=cpu=20,memory=40Gi,pods=100

# View team resources
kubectl get all -n team-alpha
kubectl get all -n team-beta
Canary Deployments with Labels
bash# Create stable deployment (v1.0)
kubectl apply -f stable-deployment.yaml
kubectl label deployment stable track=stable version=v1.0

# Create canary deployment (v1.1)
kubectl apply -f canary-deployment.yaml
kubectl label deployment canary track=canary version=v1.1

# Scale for 10% canary traffic
kubectl scale deployment stable --replicas=9
kubectl scale deployment canary --replicas=1

# Monitor canary
kubectl logs -l track=canary -f

# Promote canary
kubectl scale deployment canary --replicas=10
kubectl scale deployment stable --replicas=0

🚀 Advanced Label Selection
Field Selectors Combined with Labels
bash# Running pods with label
kubectl get pods -l app=backend --field-selector=status.phase=Running

# Pods on specific node with label
kubectl get pods -l app=backend --field-selector=spec.nodeName=worker-1

# Pending pods
kubectl get pods --all-namespaces --field-selector=status.phase=Pending
JSON Path Queries
bash# Get pod names with specific label
kubectl get pods -l app=backend -o jsonpath='{.items[*].metadata.name}'

# Get labels of all pods
kubectl get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.labels}{"\n"}{end}'

# Get pods and their namespace
kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\n"}{end}'

💡 Pro Tips
Alias for Common Commands
bash# Add to ~/.bashrc or ~/.zshrc
alias kgn='kubectl get ns'
alias kgp='kubectl get pods'
alias kgpl='kubectl get pods --show-labels'
alias kgd='kubectl get deployments'
alias kgs='kubectl get svc'
alias kga='kubectl get all'
alias kdp='kubectl describe pod'
alias kdn='kubectl describe namespace'

# Namespace shortcuts
alias kdev='kubectl config set-context --current --namespace=dev'
alias kstag='kubectl config set-context --current --namespace=staging'
alias kprod='kubectl config set-context --current --namespace=prod'
Quick Label Operations
bash# Label all pods in namespace
kubectl label pods --all environment=dev -n dev

# Label resources by type
kubectl label deployments --all tier=application

# Bulk relabel
kubectl label pods -l app=old-name app=new-name --overwrite

# Copy labels from one resource to another
SRC_LABELS=$(kubectl get pod src-pod -o jsonpath='{.metadata.labels}')
kubectl label pod dest-pod $SRC_LABELS
Namespace Cleanup
bash# Delete all resources in namespace (keep namespace)
kubectl delete all --all -n dev

# Delete specific resources by label
kubectl delete pods,services -l temporary=true -n dev

# Force delete stuck namespace
kubectl get namespace dev -o json | jq '.spec.finalizers = []' | kubectl replace --raw "/api/v1/namespaces/dev/finalize" -f -

🎓 CKA Exam Tips
Must-Know Commands
bash# Quickly create namespace
kubectl create ns test

# Add label to existing pod
kubectl label pod nginx app=web

# Get resources by label
kubectl get pods -l app=web

# Set namespace context
kubectl config set-context --current --namespace=test

# Check resource quota
kubectl describe quota -n test

# View limit ranges
kubectl describe limits -n test
Time-Saving Shortcuts
bash# Use -l for label selectors
kubectl get pods -l app=backend

# Use -A for all namespaces
kubectl get pods -A

# Use -n for namespace
kubectl get pods -n prod

# Combine flags
kubectl get pods -n prod -l app=backend --show-labels

# Use --dry-run for YAML generation
kubectl create ns test --dry-run=client -o yaml

# Quick delete
kubectl delete pods -l temporary=true

Print this cheatsheet! Keep it handy during practice and exam. 📄
#CKA #Kubernetes #Namespaces #Labels #Cheatsheet
