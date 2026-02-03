
Purpose: Automatically label all nodes with scheduling labels
File: examples/02-nodeselector/label-nodes.sh
bash#!/bin/bash

# Node Labeling Script for Scheduling Examples
# This script labels nodes for the scheduling demonstrations

set -e

echo "🏷️  Starting node labeling..."

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl not found. Please install kubectl first."
    exit 1
fi

# Get list of worker nodes (excluding control-plane)
NODES=$(kubectl get nodes -o jsonpath='{.items[?(@.metadata.labels.node-role\.kubernetes\.io/control-plane!="")].metadata.name}' 2>/dev/null || kubectl get nodes --selector='!node-role.kubernetes.io/control-plane' -o jsonpath='{.items[*].metadata.name}')

if [ -z "$NODES" ]; then
    echo "❌ No worker nodes found"
    exit 1
fi

# Convert to array
NODE_ARRAY=($NODES)
NODE_COUNT=${#NODE_ARRAY[@]}

echo "📊 Found $NODE_COUNT worker node(s)"

# Check if we have at least 3 nodes
if [ $NODE_COUNT -lt 3 ]; then
    echo "⚠️  Warning: Only $NODE_COUNT node(s) found. Some examples require 3+ nodes."
    echo "   Continuing with available nodes..."
fi

# Label first node (production, GPU, SSD, high memory, us-west-1a)
if [ $NODE_COUNT -ge 1 ]; then
    NODE1=${NODE_ARRAY[0]}
    echo ""
    echo "🔹 Labeling $NODE1 (Production, GPU, SSD, High Memory, US-West-1a)..."
    kubectl label node $NODE1 environment=production --overwrite
    kubectl label node $NODE1 hardware=gpu --overwrite
    kubectl label node $NODE1 disktype=ssd --overwrite
    kubectl label node $NODE1 memory=high --overwrite
    kubectl label node $NODE1 region=us-west --overwrite
    kubectl label node $NODE1 zone=us-west-1a --overwrite
    kubectl label node $NODE1 topology.kubernetes.io/zone=us-west-1a --overwrite
    echo "   ✅ $NODE1 labeled successfully"
fi

# Label second node (staging, CPU, SSD, medium memory, us-west-1b)
if [ $NODE_COUNT -ge 2 ]; then
    NODE2=${NODE_ARRAY[1]}
    echo ""
    echo "🔹 Labeling $NODE2 (Staging, CPU, SSD, Medium Memory, US-West-1b)..."
    kubectl label node $NODE2 environment=staging --overwrite
    kubectl label node $NODE2 hardware=cpu --overwrite
    kubectl label node $NODE2 disktype=ssd --overwrite
    kubectl label node $NODE2 memory=medium --overwrite
    kubectl label node $NODE2 region=us-west --overwrite
    kubectl label node $NODE2 zone=us-west-1b --overwrite
    kubectl label node $NODE2 topology.kubernetes.io/zone=us-west-1b --overwrite
    echo "   ✅ $NODE2 labeled successfully"
fi

# Label third node (development, CPU, HDD, medium memory, us-east-1a)
if [ $NODE_COUNT -ge 3 ]; then
    NODE3=${NODE_ARRAY[2]}
    echo ""
    echo "🔹 Labeling $NODE3 (Development, CPU, HDD, Medium Memory, US-East-1a)..."
    kubectl label node $NODE3 environment=development --overwrite
    kubectl label node $NODE3 hardware=cpu --overwrite
    kubectl label node $NODE3 disktype=hdd --overwrite
    kubectl label node $NODE3 memory=medium --overwrite
    kubectl label node $NODE3 region=us-east --overwrite
    kubectl label node $NODE3 zone=us-east-1a --overwrite
    kubectl label node $NODE3 topology.kubernetes.io/zone=us-east-1a --overwrite
    echo "   ✅ $NODE3 labeled successfully"
fi

echo ""
echo "✨ Node labeling complete!"
echo ""
echo "📋 Node Label Summary:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
kubectl get nodes -L environment,hardware,disktype,memory,region,zone

echo ""
echo "🔍 To see all labels on a specific node, run:"
echo "   kubectl get node <node-name> --show-labels"
echo ""
echo "🗑️  To remove all custom labels later, run:"
echo "   ./cleanup-labels.sh"
Usage:
bashchmod +x examples/02-nodeselector/label-nodes.sh
./examples/02-nodeselector/label-nodes.sh
