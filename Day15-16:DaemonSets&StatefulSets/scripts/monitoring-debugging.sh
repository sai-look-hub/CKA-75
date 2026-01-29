# ============================================
# 4. MONITORING AND DEBUGGING
# ============================================

# Watch DaemonSet rollout
watch_daemonset_rollout() {
    local NAME=${1}
    local NAMESPACE=${2:-"default"}
    
    if [[ -z $NAME ]]; then
        echo "Usage: watch_daemonset_rollout <name> [namespace]"
        return 1
    fi
    
    echo -e "${BLUE}Watching DaemonSet rollout: $NAME${NC}"
    watch -n 2 "kubectl get daemonset $NAME -n $NAMESPACE && echo && kubectl get pods -n $NAMESPACE -l app=$NAME -o wide"
}

# Watch StatefulSet rollout
watch_statefulset_rollout() {
    local NAME=${1}
    local NAMESPACE=${2:-"default"}
    
    if [[ -z $NAME ]]; then
        echo "Usage: watch_statefulset_rollout <name> [namespace]"
        return 1
    fi
    
    echo -e "${BLUE}Watching StatefulSet rollout: $NAME${NC}"
    watch -n 2 "kubectl get statefulset $NAME -n $NAMESPACE && echo && kubectl get pods -n $NAMESPACE -l app=$NAME -o wide"
}

# Get pod logs from DaemonSet
get_daemonset_logs() {
    local NAME=${1}
    local NAMESPACE=${2:-"default"}
    local NODE=${3}
    
    if [[ -z $NAME ]]; then
        echo "Usage: get_daemonset_logs <name> [namespace] [node]"
        return 1
    fi
    
    if [[ -z $NODE ]]; then
        echo -e "${BLUE}Getting logs from all DaemonSet pods...${NC}"
        kubectl logs -n $NAMESPACE -l app=$NAME --tail=50
    else
        echo -e "${BLUE}Getting logs from pod on node: $NODE${NC}"
        POD=$(kubectl get pods -n $NAMESPACE -l app=$NAME --field-selector spec.nodeName=$NODE -o jsonpath='{.items[0].metadata.name}')
        kubectl logs -n $NAMESPACE $POD --tail=100
    fi
}

# Get pod logs from StatefulSet
get_statefulset_logs() {
    local NAME=${1}
    local ORDINAL=${2:-0}
    local NAMESPACE=${3:-"default"}
    
    if [[ -z $NAME ]]; then
        echo "Usage: get_statefulset_logs <name> [ordinal] [namespace]"
        return 1
    fi
    
    POD_NAME="${NAME}-${ORDINAL}"
    echo -e "${BLUE}Getting logs from pod: $POD_NAME${NC}"
    kubectl logs -n $NAMESPACE $POD_NAME --tail=100
}

# Check resource usage
check_resource_usage() {
    local TYPE=${1}  # daemonset or statefulset
    local NAME=${2}
    local NAMESPACE=${3:-"default"}
    
    if [[ -z $TYPE ]] || [[ -z $NAME ]]; then
        echo "Usage: check_resource_usage <daemonset|statefulset> <name> [namespace]"
        return 1
    fi
    
    echo -e "${BLUE}=== Resource Usage for $TYPE: $NAME ===${NC}"
    
    kubectl top pods -n $NAMESPACE -l app=$NAME 2>/dev/null || \
        echo "Metrics server not available. Install metrics-server to view resource usage."
}
