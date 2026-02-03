Purpose: Test all scheduling examples
File: test-scheduling.sh
bash#!/bin/bash

# Test Scheduling Examples Script

set -e

echo "🧪 Testing Kubernetes Node Scheduling Examples"
echo "================================================"
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counter
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Function to run test
run_test() {
    local test_name=$1
    local yaml_file=$2
    local expected_count=$3
    local selector=$4
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Test $TOTAL_TESTS: $test_name"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Apply manifest
    echo "📝 Applying: $yaml_file"
    kubectl apply -f $yaml_file >/dev/null 2>&1
    
    # Wait for pods
    echo "⏳ Waiting for pods to be ready..."
    sleep 5
    
    # Check pod count
    ACTUAL_COUNT=$(kubectl get pods -l $selector --no-headers 2>/dev/null | wc -l)
    
    if [ "$ACTUAL_COUNT" -eq "$expected_count" ]; then
        echo -e "${GREEN}✅ PASSED${NC} - Found $ACTUAL_COUNT/$expected_count pods"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        
        # Show pod distribution
        echo "📊 Pod Distribution:"
        kubectl get pods -l $selector -o wide 2>/dev/null || true
    else
        echo -e "${RED}❌ FAILED${NC} - Expected $expected_count pods, found $ACTUAL_COUNT"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        
        # Show what went wrong
        echo "🔍 Debugging info:"
        kubectl get pods -l $selector 2>/dev/null || true
        kubectl describe pods -l $selector 2>/dev/null | grep -A 5 "Events:" || true
    fi
    
    echo ""
}

# Cleanup function
cleanup() {
    echo "🧹 Cleaning up test resources..."
    kubectl delete pods,deployments,statefulsets,jobs -l test=scheduling --ignore-not-found=true >/dev/null 2>&1
    echo "✅ Cleanup complete"
}

# Trap cleanup on exit
trap cleanup EXIT

echo "🏷️  Step 1: Labeling nodes..."
./examples/02-nodeselector/label-nodes.sh

echo ""
echo "🧪 Step 2: Running tests..."
echo ""

# Test 1: nodeSelector
run_test "nodeSelector - GPU Pod" \
    "examples/02-nodeselector/pod-nodeselector.yaml" \
    1 \
    "app=ml-training"

# Test 2: Node Affinity Required
run_test "Node Affinity - Required" \
    "examples/03-node-affinity/pod-affinity-required.yaml" \
    1 \
    "app=regional-app"

# Test 3: Node Affinity Preferred
run_test "Node Affinity - Preferred" \
    "examples/03-node-affinity/pod-affinity-preferred.yaml" \
    1 \
    "app=flexible-app"

# Test 4: Pod Anti-Affinity
run_test "Pod Anti-Affinity - HA Deployment" \
    "examples/04-anti-affinity/pod-anti-affinity.yaml" \
    3 \
    "app=web-ha"

# Final Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 TEST SUMMARY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Total Tests:  $TOTAL_TESTS"
echo -e "Passed:       ${GREEN}$PASSED_TESTS${NC}"
echo -e "Failed:       ${RED}$FAILED_TESTS${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}🎉 All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}❌ Some tests failed${NC}"
    exit 1
fi
Usage:
bashchmod +x test-scheduling.sh
./test-scheduling.sh
