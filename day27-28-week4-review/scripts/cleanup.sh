#!/bin/bash

echo "🗑️  Cleaning up Multi-Environment Deployment"
echo "=========================================="
echo ""
echo "⚠️  WARNING: This will delete all resources in dev/staging/prod namespaces"
read -p "Are you sure? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "❌ Cleanup cancelled"
    exit 1
fi

echo ""
echo "Deleting development namespace..."
kubectl delete namespace development --timeout=60s

echo "Deleting staging namespace..."
kubectl delete namespace staging --timeout=60s

echo "Deleting production namespace..."
kubectl delete namespace production --timeout=60s

echo ""
echo "Removing node labels..."
kubectl label nodes --all environment- tier- zone- 2>/dev/null || true

echo ""
echo "✅ Cleanup complete!"
echo ""
echo "Remaining namespaces:"
kubectl get namespaces
