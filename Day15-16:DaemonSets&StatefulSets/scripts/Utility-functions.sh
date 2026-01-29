# ============================================
# 6. UTILITY FUNCTIONS
# ============================================

# List all DaemonSets
list_all_daemonsets() {
    echo -e "${BLUE}=== All DaemonSets ===${NC}"
    kubectl get daemonsets --all-namespaces -o custom-columns=\
NAMESPACE:.metadata.namespace,\
NAME:.metadata.name,\
DESIRED:.status.desiredNumberScheduled,\
CURRENT:.status.currentNumberScheduled,\
READY:.status.numberReady,\
UP-TO-DATE:.status.updatedNumberScheduled,\
AGE:.metadata.creationTimestamp
}

# List all StatefulSets
list_all_statefulsets() {
    echo -e "${BLUE}=== All StatefulSets ===${NC}"
    kubectl get statefulsets --all-namespaces -o custom-columns=\
NAMESPACE:.metadata.namespace,\
NAME:.metadata.name,\
READY:.status.readyReplicas,\
DESIRED:.spec.replicas,\
AGE:.metadata.creationTimestamp
}

# Cleanup resources
cleanup_demo_resources() {
    echo -e "${YELLOW}Cleaning up demo resources...${NC}"
    
    read -p "Delete monitoring namespace? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        kubectl delete namespace monitoring --ignore-not-found
    fi
    
    read -p "Delete database namespace? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        kubectl delete namespace database --ignore-not-found
    fi
    
    echo -e "${GREEN}Cleanup completed!${NC}"
}
