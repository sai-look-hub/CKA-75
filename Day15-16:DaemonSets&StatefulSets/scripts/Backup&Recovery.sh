# ============================================
# 5. BACKUP AND RECOVERY
# ============================================

# Backup StatefulSet configuration
backup_statefulset() {
    local NAME=${1}
    local NAMESPACE=${2:-"default"}
    local BACKUP_DIR=${3:-"backups"}
    
    if [[ -z $NAME ]]; then
        echo "Usage: backup_statefulset <name> [namespace] [backup_dir]"
        return 1
    fi
    
    mkdir -p $BACKUP_DIR
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    
    echo -e "${BLUE}Backing up StatefulSet: $NAME${NC}"
    
    # Backup StatefulSet
    kubectl get statefulset $NAME -n $NAMESPACE -o yaml > "$BACKUP_DIR/${NAME}-statefulset-${TIMESTAMP}.yaml"
    
    # Backup Service
    kubectl get service ${NAME}-svc -n $NAMESPACE -o yaml > "$BACKUP_DIR/${NAME}-service-${TIMESTAMP}.yaml" 2>/dev/null || true
    
    # Backup PVCs
    kubectl get pvc -n $NAMESPACE -l app=$NAME -o yaml > "$BACKUP_DIR/${NAME}-pvcs-${TIMESTAMP}.yaml"
    
    echo -e "${GREEN}Backup completed in: $BACKUP_DIR${NC}"
    ls -lh $BACKUP_DIR/*${TIMESTAMP}*
}
