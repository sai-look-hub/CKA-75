# ============================================
# 3. STORAGE OPERATIONS
# ============================================

# List PVCs for StatefulSet
list_statefulset_pvcs() {
    local NAME=${1}
    local NAMESPACE=${2:-"default"}
    
    if [[ -z $NAME ]]; then
        echo "Usage: list_statefulset_pvcs <name> [namespace]"
        return 1
    fi
    
    echo -e "${BLUE}=== Persistent Volume Claims ===${NC}"
    kubectl get pvc -n $NAMESPACE | grep $NAME
    
    echo -e "\n${BLUE}=== PVC Details ===${NC}"
    kubectl get pvc -n $NAMESPACE -l app=$NAME \
        -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,VOLUME:.spec.volumeName,CAPACITY:.status.capacity.storage,STORAGECLASS:.spec.storageClassName
}

# Check PVC binding status
check_pvc_status() {
    local NAMESPACE=${1:-"default"}
    
    echo -e "${BLUE}=== PVC Status in namespace: $NAMESPACE ===${NC}"
    
    kubectl get pvc -n $NAMESPACE -o custom-columns=\
NAME:.metadata.name,\
STATUS:.status.phase,\
VOLUME:.spec.volumeName,\
CAPACITY:.status.capacity.storage,\
ACCESS:.spec.accessModes[0],\
STORAGECLASS:.spec.storageClassName,\
AGE:.metadata.creationTimestamp
    
    echo -e "\n${BLUE}=== Pending PVCs ===${NC}"
    PENDING=$(kubectl get pvc -n $NAMESPACE --field-selector=status.phase=Pending --no-headers 2>/dev/null | wc -l)
    
    if [[ $PENDING -gt 0 ]]; then
        echo -e "${RED}Found $PENDING pending PVC(s)${NC}"
        kubectl get pvc -n $NAMESPACE --field-selector=status.phase=Pending
    else
        echo -e "${GREEN}All PVCs are bound${NC}"
    fi
}

# Delete StatefulSet with PVCs
delete_statefulset_with_pvcs() {
    local NAME=${1}
    local NAMESPACE=${2:-"default"}
    local DELETE_PVCS=${3:-"no"}
    
    if [[ -z $NAME ]]; then
        echo "Usage: delete_statefulset_with_pvcs <name> [namespace] [delete_pvcs: yes/no]"
        return 1
    fi
    
    echo -e "${YELLOW}Deleting StatefulSet: $NAME${NC}"
    kubectl delete statefulset $NAME -n $NAMESPACE
    
    if [[ $DELETE_PVCS == "yes" ]]; then
        echo -e "${YELLOW}Deleting PVCs...${NC}"
        kubectl delete pvc -n $NAMESPACE -l app=$NAME
        echo -e "${GREEN}PVCs deleted${NC}"
    else
        echo -e "${BLUE}PVCs retained (use delete_pvcs=yes to delete)${NC}"
        kubectl get pvc -n $NAMESPACE -l app=$NAME
    fi
}
