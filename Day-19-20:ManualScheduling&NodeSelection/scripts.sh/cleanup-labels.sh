Purpose: Remove all custom labels from nodes
File: examples/02-nodeselector/cleanup-labels.sh
bash#!/bin/bash

# Cleanup Script - Remove all custom labels from nodes

set -e

echo "🗑️  Starting label cleanup..."

# Get all worker nodes
NODES=$(kubectl get nodes -o jsonpath='{.items[?(@.metadata.labels.node-role\.kubernetes\.io/control-plane!="")].metadata.name}' 2>/dev/null || kubectl get nodes --selector='!node-role.kubernetes.io/control-plane' -o jsonpath='{.items[*].metadata.name}')

if [ -z "$NODES" ]; then
    echo "❌ No worker nodes found"
    exit 1
fi

NODE_ARRAY=($NODES)

echo "📊 Found ${#NODE_ARRAY[@]} worker node(s)"
echo ""

# Labels to remove
LABELS=(
    "environment"
    "hardware"
    "disktype"
    "memory"
    "region"
    "zone"
    "topology.kubernetes.io/zone"
    "instance-type"
)

# Remove labels from each node
for NODE in "${NODE_ARRAY[@]}"; do
    echo "🔹 Cleaning labels from $NODE..."
    for LABEL in "${LABELS[@]}"; do
        kubectl label node $NODE $LABEL- 2>/dev/null || true
    done
    echo "   ✅ $NODE cleaned"
done

echo ""
echo "✨ Label cleanup complete!"
echo ""
echo "📋 Remaining Labels:"
kubectl get nodes --show-labels
Usage:
bashchmod +x examples/02-nodeselector/cleanup-labels.sh
./examples/02-nodeselector/cleanup-labels.sh
