#!/bin/bash

echo "🚀 Setting up Multi-Environment Kubernetes Cluster"
echo "=================================================="
echo ""

# Check kubectl
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl not found. Please install kubectl first."
    exit 1
fi

# Check cluster access
kubectl cluster-info > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "❌ Cannot connect to Kubernetes cluster"
    exit 1
fi

echo "✅ Kubectl configured and cluster accessible"
echo ""

# Step 1: Label nodes
echo "📋 Step 1: Labeling nodes..."
echo "----------------------------"

# Get nodes
NODES=$(kubectl get nodes --no-headers | awk '{print $1}')
NODE_COUNT=$(echo "$NODES" | wc -w)

echo "Found $NODE_COUNT node(s)"

if [ $NODE_COUNT -lt 1 ]; then
    echo "❌ No nodes found"
    exit 1
fi

# Convert to array
NODE_ARRAY=($NODES)

# Label first node as production
if [ $NODE_COUNT -ge 1 ]; then
    echo "Labeling ${NODE_ARRAY[0]} as production..."
    kubectl label nodes ${NODE_ARRAY[0]} environment=production tier=high-performance zone=us-west-1a --overwrite
fi

# Label second node as staging
if [ $NODE_COUNT -ge 2 ]; then
    echo "Labeling ${NODE_ARRAY[1]} as staging..."
    kubectl label nodes ${NODE_ARRAY[1]} environment=staging tier=medium-performance zone=us-west-1b --overwrite
fi

# Label third node as development
if [ $NODE_COUNT -ge 3 ]; then
    echo "Labeling ${NODE_ARRAY[2]} as development..."
    kubectl label nodes ${NODE_ARRAY[2]} environment=development tier=standard zone=us-west-1c --overwrite
fi

echo "✅ Node labeling complete"
kubectl get nodes -L environment,tier,zone
echo ""

# Step 2: Create namespaces
echo "📋 Step 2: Creating namespaces..."
echo "----------------------------"
kubectl apply -f ../examples/01-infrastructure/namespaces.yaml
echo "✅ Namespaces created"
echo ""

# Step 3: Apply resource quotas and limit ranges
echo "📋 Step 3: Applying resource policies..."
echo "----------------------------"
kubectl apply -f ../examples/01-infrastructure/resource-quotas.yaml
echo "✅ Resource policies applied"
echo ""

# Step 4: Verify setup
echo "📋 Step 4: Verifying setup..."
echo "----------------------------"
echo ""
echo "Namespaces:"
kubectl get namespaces | grep -E 'development|staging|production'
echo ""
echo "ResourceQuotas:"
kubectl get resourcequota -A | grep -E 'development|staging|production'
echo ""
echo "LimitRanges:"
kubectl get limitrange -A | grep -E 'development|staging|production'
echo ""

echo "✅ Multi-environment cluster setup complete!"
echo ""
echo "Next steps:"
echo "  1. Deploy to development: ./deploy-dev.sh"
echo "  2. Deploy to staging: ./deploy-staging.sh"
echo "  3. Deploy to production: ./deploy-prod.sh"
