#!/bin/bash

echo "🚀 Deploying to DEVELOPMENT environment"
echo "========================================"
echo ""

# Apply development manifests
echo "Deploying backend..."
kubectl apply -f ../examples/02-development/backend-dev.yaml

echo "Deploying frontend..."
kubectl apply -f ../examples/02-development/frontend-dev.yaml

echo "Deploying database..."
kubectl apply -f ../examples/02-development/database-dev.yaml

echo "Running migration job..."
kubectl apply -f ../examples/02-development/jobs-dev.yaml

echo ""
echo "✅ Development deployment complete!"
echo ""
echo "Check status:"
kubectl get all -n development
echo ""
echo "Check resource usage:"
kubectl describe resourcequota dev-quota -n development
