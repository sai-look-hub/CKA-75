#!/bin/bash

echo "🚀 Deploying to PRODUCTION environment"
echo "======================================"
echo ""
echo "⚠️  WARNING: Deploying to PRODUCTION"
read -p "Are you sure? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "❌ Deployment cancelled"
    exit 1
fi

echo ""
echo "Deploying backend..."
kubectl apply -f ../examples/04-production/backend-prod.yaml

echo "Deploying frontend..."
kubectl apply -f ../examples/04-production/frontend-prod.yaml

echo "Deploying database..."
kubectl apply -f ../examples/04-production/database-prod.yaml

echo "Deploying cache..."
kubectl apply -f ../examples/04-production/cache-prod.yaml

echo "Deploying monitoring..."
kubectl apply -f ../examples/04-production/monitoring-prod.yaml

echo ""
echo "Waiting for deployments to be ready..."
kubectl rollout status deployment/backend -n production
kubectl rollout status deployment/frontend -n production

echo ""
echo "✅ Production deployment complete!"
echo ""
echo "Check status:"
kubectl get all -n production
echo ""
echo "Check HPAs:"
kubectl get hpa -n production
echo ""
echo "Check resource usage:"
kubectl describe resourcequota prod-quota -n production
