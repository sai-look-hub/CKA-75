#!/bin/bash

echo "🔍 Validating Multi-Environment Deployment"
echo "=========================================="
echo ""

# Function to check namespace
check_namespace() {
    local ns=$1
    echo "Checking $ns environment..."
    echo "----------------------------"
    
    # Check pods
    pod_count=$(kubectl get pods -n $ns --no-headers 2>/dev/null | wc -l)
    running_count=$(kubectl get pods -n $ns --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
    
    echo "  Pods: $running_count/$pod_count running"
    
    # Check services
    svc_count=$(kubectl get svc -n $ns --no-headers 2>/dev/null | wc -l)
    echo "  Services: $svc_count"
    
    # Check quota usage
    echo "  Resource Quota:"
    kubectl describe resourcequota -n $ns 2>/dev/null | grep -A 10 "Resource.*Used.*Hard" | head -12 | sed 's/^/    /'
    
    echo ""
}

# Check each environment
check_namespace "development"
check_namespace "staging"
check_namespace "production"

# Check pod distribution
echo "Pod Distribution Across Nodes:"
echo "------------------------------"
kubectl get pods -A -o wide | grep -E 'development|staging|production' | awk '{print $8}' | sort | uniq -c

echo ""
echo "QoS Class Distribution:"
echo "----------------------"
kubectl get pods -A -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,QOS:.status.qosClass | grep -E 'development|staging|production' | awk '{print $1, $3}' | sort | uniq -c

echo ""
echo "✅ Validation complete!"
