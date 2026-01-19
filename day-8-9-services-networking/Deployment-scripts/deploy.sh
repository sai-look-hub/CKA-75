#!/bin/bash

################################################################################
# deploy.sh - Automated Deployment Script for Day 7-8 Services Project
# Usage: ./deploy.sh [options]
# Options:
#   -n, --namespace    Specify namespace (default: multi-tier-app)
#   -d, --delete       Delete existing resources before deploying
#   -w, --wait         Wait for resources to be ready
#   -h, --help         Show this help message
################################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
NAMESPACE="multi-tier-app"
DELETE_FIRST=false
WAIT_READY=true
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFESTS_DIR="${SCRIPT_DIR}/../manifests"

# Functions
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

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check if kubectl is installed
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed. Please install kubectl first."
        exit 1
    fi
    print_success "kubectl is installed"
    
    # Check if cluster is accessible
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    print_success "Connected to Kubernetes cluster"
    
    # Check if manifests directory exists
    if [ ! -d "$MANIFESTS_DIR" ]; then
        print_error "Manifests directory not found: $MANIFESTS_DIR"
        exit 1
    fi
    print_success "Manifests directory found"
    
    echo
}

create_namespace() {
    print_header "Creating Namespace"
    
    if kubectl get namespace "$NAMESPACE" &> /dev/null; then
        print_warning "Namespace '$NAMESPACE' already exists"
    else
        kubectl create namespace "$NAMESPACE"
        print_success "Namespace '$NAMESPACE' created"
    fi
    
    kubectl label namespace "$NAMESPACE" name="$NAMESPACE" --overwrite
    echo
}

deploy_database() {
    print_header "Deploying Database Layer (MySQL)"
    
    print_info "Creating MySQL Secret..."
    kubectl apply -f "$MANIFESTS_DIR/02-database/mysql-secret.yaml" -n "$NAMESPACE"
    
    print_info "Creating MySQL ConfigMap..."
    kubectl apply -f "$MANIFESTS_DIR/02-database/mysql-configmap.yaml" -n "$NAMESPACE"
    
    print_info "Deploying MySQL StatefulSet..."
    kubectl apply -f "$MANIFESTS_DIR/02-database/mysql-statefulset.yaml" -n "$NAMESPACE"
    
    if [ "$WAIT_READY" = true ]; then
        print_info "Waiting for MySQL to be ready (this may take a minute)..."
        kubectl wait --for=condition=ready pod -l app=mysql \
            --timeout=300s -n "$NAMESPACE" || {
            print_warning "MySQL took longer than expected to start"
        }
    fi
    
    print_success "Database layer deployed"
    echo
}

deploy_cache() {
    print_header "Deploying Cache Layer (Redis)"
    
    print_info "Creating Redis ConfigMap..."
    kubectl apply -f "$MANIFESTS_DIR/03-cache/redis-configmap.yaml" -n "$NAMESPACE"
    
    print_info "Deploying Redis..."
    kubectl apply -f "$MANIFESTS_DIR/03-cache/redis-deployment.yaml" -n "$NAMESPACE"
    kubectl apply -f "$MANIFESTS_DIR/03-cache/redis-service.yaml" -n "$NAMESPACE"
    
    if [ "$WAIT_READY" = true ]; then
        print_info "Waiting for Redis to be ready..."
        kubectl wait --for=condition=ready pod -l app=redis \
            --timeout=120s -n "$NAMESPACE" || {
            print_warning "Redis took longer than expected to start"
        }
    fi
    
    print_success "Cache layer deployed"
    echo
}

deploy_backend() {
    print_header "Deploying Backend API"
    
    print_info "Creating Backend ConfigMap..."
    kubectl apply -f "$MANIFESTS_DIR/04-backend/backend-configmap.yaml" -n "$NAMESPACE"
    
    print_info "Deploying Backend..."
    kubectl apply -f "$MANIFESTS_DIR/04-backend/backend-deployment.yaml" -n "$NAMESPACE"
    kubectl apply -f "$MANIFESTS_DIR/04-backend/backend-service.yaml" -n "$NAMESPACE"
    
    if [ "$WAIT_READY" = true ]; then
        print_info "Waiting for Backend to be ready..."
        kubectl wait --for=condition=ready pod -l app=backend \
            --timeout=120s -n "$NAMESPACE" || {
            print_warning "Backend took longer than expected to start"
        }
    fi
    
    print_success "Backend API deployed"
    echo
}

deploy_frontend() {
    print_header "Deploying Frontend"
    
    print_info "Creating Frontend ConfigMap..."
    kubectl apply -f "$MANIFESTS_DIR/05-frontend/nginx-configmap.yaml" -n "$NAMESPACE"
    
    print_info "Deploying Frontend..."
    kubectl apply -f "$MANIFESTS_DIR/05-frontend/frontend-deployment.yaml" -n "$NAMESPACE"
    kubectl apply -f "$MANIFESTS_DIR/05-frontend/frontend-service.yaml" -n "$NAMESPACE"
    
    if [ "$WAIT_READY" = true ]; then
        print_info "Waiting for Frontend to be ready..."
        kubectl wait --for=condition=ready pod -l app=frontend \
            --timeout=120s -n "$NAMESPACE" || {
            print_warning "Frontend took longer than expected to start"
        }
    fi
    
    print_success "Frontend deployed"
    echo
}

deploy_monitoring() {
    print_header "Deploying Monitoring (Optional)"
    
    if [ -d "$MANIFESTS_DIR/06-monitoring" ]; then
        print_info "Deploying Monitoring..."
        kubectl apply -f "$MANIFESTS_DIR/06-monitoring/" -n "$NAMESPACE"
        print_success "Monitoring deployed"
    else
        print_warning "Monitoring manifests not found, skipping..."
    fi
    echo
}

show_status() {
    print_header "Deployment Status"
    
    echo "📦 Pods:"
    kubectl get pods -n "$NAMESPACE" -o wide
    echo
    
    echo "🌐 Services:"
    kubectl get svc -n "$NAMESPACE"
    echo
    
    echo "📍 Endpoints:"
    kubectl get ep -n "$NAMESPACE"
    echo
}

show_access_info() {
    print_header "Access Information"
    
    # Get frontend service info
    FRONTEND_TYPE=$(kubectl get svc frontend -n "$NAMESPACE" -o jsonpath='{.spec.type}')
    
    case $FRONTEND_TYPE in
        "LoadBalancer")
            print_info "Frontend Service Type: LoadBalancer"
            EXTERNAL_IP=$(kubectl get svc frontend -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
            
            if [ -z "$EXTERNAL_IP" ] || [ "$EXTERNAL_IP" = "<none>" ]; then
                print_warning "External IP is pending. This may take a few minutes."
                print_info "Run this command to watch for the external IP:"
                echo "  kubectl get svc frontend -n $NAMESPACE -w"
            else
                print_success "Access your application at: http://$EXTERNAL_IP"
            fi
            ;;
        "NodePort")
            print_info "Frontend Service Type: NodePort"
            NODE_PORT=$(kubectl get svc frontend -n "$NAMESPACE" -o jsonpath='{.spec.ports[0].nodePort}')
            NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}')
            
            if [ -z "$NODE_IP" ]; then
                NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
                print_info "Access your application at: http://$NODE_IP:$NODE_PORT"
                print_warning "Using internal IP. If accessing from outside, use your node's external IP."
            else
                print_success "Access your application at: http://$NODE_IP:$NODE_PORT"
            fi
            ;;
        "ClusterIP")
            print_info "Frontend Service Type: ClusterIP (internal only)"
            print_info "To access from outside, use port-forward:"
            echo "  kubectl port-forward svc/frontend 8080:80 -n $NAMESPACE"
            echo "  Then access: http://localhost:8080"
            ;;
    esac
    
    echo
    print_info "To test backend from within cluster:"
    echo "  kubectl run test --image=curlimages/curl -it --rm -n $NAMESPACE -- curl http://backend:8080"
    echo
}

cleanup_existing() {
    print_header "Cleaning Up Existing Resources"
    
    if kubectl get namespace "$NAMESPACE" &> /dev/null; then
        print_warning "Deleting namespace '$NAMESPACE' and all its resources..."
        kubectl delete namespace "$NAMESPACE" --grace-period=30
        
        # Wait for namespace to be deleted
        print_info "Waiting for namespace to be deleted..."
        while kubectl get namespace "$NAMESPACE" &> /dev/null; do
            sleep 2
        done
        print_success "Cleanup completed"
    else
        print_info "Namespace '$NAMESPACE' does not exist, nothing to clean up"
    fi
    echo
}

show_help() {
    cat << EOF
Kubernetes Services Deployment Script

Usage: $0 [OPTIONS]

Options:
    -n, --namespace NAME    Specify namespace (default: multi-tier-app)
    -d, --delete           Delete existing resources before deploying
    -w, --wait             Wait for resources to be ready (default: true)
    --no-wait              Don't wait for resources
    -h, --help             Show this help message

Examples:
    # Deploy with defaults
    $0

    # Deploy to custom namespace
    $0 --namespace production

    # Clean deploy (delete existing first)
    $0 --delete

    # Deploy without waiting
    $0 --no-wait

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -d|--delete)
            DELETE_FIRST=true
            shift
            ;;
        -w|--wait)
            WAIT_READY=true
            shift
            ;;
        --no-wait)
            WAIT_READY=false
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Main execution
main() {
    print_header "Kubernetes Services Deployment"
    echo "Namespace: $NAMESPACE"
    echo "Delete first: $DELETE_FIRST"
    echo "Wait for ready: $WAIT_READY"
    echo
    
    # Check prerequisites
    check_prerequisites
    
    # Cleanup if requested
    if [ "$DELETE_FIRST" = true ]; then
        cleanup_existing
    fi
    
    # Create namespace
    create_namespace
    
    # Deploy layers
    deploy_database
    deploy_cache
    deploy_backend
    deploy_frontend
    deploy_monitoring
    
    # Show status
    show_status
    show_access_info
    
    print_header "Deployment Complete! 🎉"
    print_success "All resources have been deployed successfully"
    echo
    print_info "Useful commands:"
    echo "  # Watch pods"
    echo "  kubectl get pods -n $NAMESPACE -w"
    echo
    echo "  # View logs"
    echo "  kubectl logs -f -l app=backend -n $NAMESPACE"
    echo
    echo "  # Describe service"
    echo "  kubectl describe svc frontend -n $NAMESPACE"
    echo
    echo "  # Port forward"
    echo "  kubectl port-forward svc/frontend 8080:80 -n $NAMESPACE"
    echo
}

# Run main function
main


