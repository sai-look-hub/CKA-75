#!/bin/bash

echo "🚀 Deploying to STAGING environment"
echo "===================================="
echo ""

echo "Deploying backend..."
kubectl apply -f ../examples/03-staging/backend-staging.yaml

echo "Deploying frontend..."
kubectl apply -f ../examples/03-staging/frontend-staging.yaml

echo "Deploying database..."
kubectl apply -f ../examples/03-staging/database-staging.yaml

echo "Setting up backup cronjob..."
kubectl apply -f ../examples/03-staging/cronjob-staging.yaml

echo ""
echo "✅ Staging deployment complete!"
echo ""
echo "Check status:"
kubectl get all -n staging
echo ""
echo "Check resource usage:"
kubectl describe resourcequota staging-quota -n staging
