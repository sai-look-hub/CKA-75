################################################################################
# cleanup.sh - Cleanup Script
################################################################################

cat > "${SCRIPT_DIR}/cleanup.sh" << 'CLEANUP_EOF'
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

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
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
            echo "  -n, --namespace NAME    Specify namespace to delete (default: multi-tier-app)"
            echo "  -h, --help             Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

print_header "Cleanup Script"
echo "Namespace: $NAMESPACE"
echo

# Confirm deletion
read -p "Are you sure you want to delete namespace '$NAMESPACE' and all its resources? (yes/no): " -r
echo
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    print_warning "Cleanup cancelled"
    exit 0
fi

print_info "Deleting namespace '$NAMESPACE'..."

if kubectl get namespace "$NAMESPACE" &> /dev/null; then
    kubectl delete namespace "$NAMESPACE" --grace-period=30
    
    print_info "Waiting for namespace to be deleted..."
    while kubectl get namespace "$NAMESPACE" &> /dev/null; do
        echo -n "."
        sleep 2
    done
    echo
    print_success "Namespace '$NAMESPACE' deleted successfully"
else
    print_warning "Namespace '$NAMESPACE' does not exist"
fi

print_header "Cleanup Complete! 🧹"
CLEANUP_EOF

chmod +x "${SCRIPT_DIR}/cleanup.sh"
