################################################################################
# test.sh - Testing Script
################################################################################

cat > "${SCRIPT_DIR}/test.sh" << 'TEST_EOF'
#!/bin/bash

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

NAMESPACE="multi-tier-app"

print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

test_service() {
    local service_name=$1
    local port=$2
    local expected_status=${3:-200}
    
    print_info "Testing $service_name service..."
    
    # Check if service exists
    if ! kubectl get svc "$service_name" -n "$NAMESPACE" &> /dev/null; then
        print_error "Service $service_name not found"
        return 1
    fi
    
    # Check endpoints
    ENDPOINTS=$(kubectl get ep "$service_name" -n "$NAMESPACE" -o jsonpath='{.subsets[*].addresses[*].ip}')
    if [ -z "$ENDPOINTS" ]; then
        print_error "No endpoints for service $service_name"
        return 1
    fi
    print_success "Service $service_name has endpoints: $ENDPOINTS"
    
    # Test connectivity
    if kubectl run test-$service_name --image=curlimages/curl -it --rm -n "$NAMESPACE" --restart=Never -- \
        curl -s -o /dev/null -w "%{http_code}" "http://$service_name:$port" | grep -q "$expected_status"; then
        print_success "Service $service_name is responding correctly"
        return 0
    else
        print_error "Service $service_name is not responding as expected"
        return 1
    fi
}

test_dns() {
    local service_name=$1
    
    print_info "Testing DNS resolution for $service_name..."
    
    if kubectl run test-dns-$service_name --image=busybox -it --rm -n "$NAMESPACE" --restart=Never -- \
        nslookup "$service_name.$NAMESPACE.svc.cluster.local" &> /dev/null; then
        print_success "DNS resolution working for $service_name"
        return 0
    else
        print_error "DNS resolution failed for $service_name"
        return 1
    fi
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  -n, --namespace NAME    Specify namespace (default: multi-tier-app)"
            echo "  -h, --help             Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

print_header "Service Testing Script"
echo "Namespace: $NAMESPACE"
echo

# Check if namespace exists
if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
    print_error "Namespace '$NAMESPACE' does not exist"
    exit 1
fi

# Test services
print_header "Testing Services"

# Test backend
test_service "backend" "8080" || true

# Test frontend
test_service "frontend" "80" || true

# Test redis
test_service "redis" "6379" || true

# Test DNS
print_header "Testing DNS Resolution"
test_dns "backend" || true
test_dns "frontend" || true
test_dns "redis" || true
test_dns "mysql" || true

# Show service status
print_header "Service Status"
kubectl get svc -n "$NAMESPACE"

print_header "Pod Status"
kubectl get pods -n "$NAMESPACE"

print_header "Endpoint Status"
kubectl get ep -n "$NAMESPACE"

print_header "Tests Complete!"
TEST_EOF

chmod +x "${SCRIPT_DIR}/test.sh"


################################################################################
# monitor.sh - Monitoring Script
################################################################################

cat > "${SCRIPT_DIR}/monitor.sh" << 'MONITOR_EOF'
#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

NAMESPACE="multi-tier-app"
REFRESH_INTERVAL=2

print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -i|--interval)
            REFRESH_INTERVAL="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  -n, --namespace NAME    Specify namespace (default: multi-tier-app)"
            echo "  -i, --interval SEC      Refresh interval in seconds (default: 2)"
            echo "  -h, --help             Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Continuous monitoring
while true; do
    clear
    print_header "Kubernetes Services Monitor - $NAMESPACE"
    echo "Refresh interval: ${REFRESH_INTERVAL}s | Press Ctrl+C to exit"
    echo
    
    echo -e "${BLUE}📦 Pods:${NC}"
    kubectl get pods -n "$NAMESPACE" -o wide
    echo
    
    echo -e "${BLUE}🌐 Services:${NC}"
    kubectl get svc -n "$NAMESPACE"
    echo
    
    echo -e "${BLUE}📍 Endpoints:${NC}"
    kubectl get ep -n "$NAMESPACE"
    echo
    
    echo -e "${BLUE}📊 Resource Usage:${NC}"
    kubectl top pods -n "$NAMESPACE" 2>/dev/null || echo "Metrics not available (metrics-server may not be installed)"
    echo
    
    echo -e "${BLUE}🔔 Recent Events:${NC}"
    kubectl get events -n "$NAMESPACE" --sort-by='.lastTimestamp' | tail -5
    
    sleep "$REFRESH_INTERVAL"
done
MONITOR_EOF

chmod +x "${SCRIPT_DIR}/monitor.sh"

echo "All scripts created successfully!"
echo "- deploy.sh: Deployment script"
echo "- cleanup.sh: Cleanup script"
echo "- test.sh: Testing script"
echo "- monitor.sh: Monitoring script"
