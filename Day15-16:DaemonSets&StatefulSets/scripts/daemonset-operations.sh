# ============================================
# 1. DAEMONSET OPERATIONS
# ============================================

# Create a basic DaemonSet
create_basic_daemonset() {
    local NAME=${1:-"example-daemonset"}
    local NAMESPACE=${2:-"default"}
    local IMAGE=${3:-"nginx:1.21"}
    
    echo -e "${BLUE}Creating DaemonSet: $NAME in namespace: $NAMESPACE${NC}"
    
    cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: $NAME
  namespace: $NAMESPACE
spec:
  selector:
    matchLabels:
      app: $NAME
  template:
    metadata:
      labels:
        app: $NAME
    spec:
      containers:
      - name: $(echo $NAME | tr '-' ' ' | awk '{print $1}')
        image: $IMAGE
        resources:
          limits:
            memory: "200Mi"
            cpu: "200m"
          requests:
            memory: "100Mi"
            cpu: "100m"
EOF
    
    echo -e "${GREEN}DaemonSet created successfully!${NC}"
    kubectl get daemonset $NAME -n $NAMESPACE
}

# Deploy Node Exporter DaemonSet
deploy_node_exporter() {
    local NAMESPACE=${1:-"monitoring"}
    
    echo -e "${BLUE}Deploying Node Exporter DaemonSet...${NC}"
    
    # Create namespace
    kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
    
    cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: node-exporter
  namespace: $NAMESPACE
  labels:
    app: node-exporter
spec:
  selector:
    matchLabels:
      app: node-exporter
  template:
    metadata:
      labels:
        app: node-exporter
    spec:
      hostNetwork: true
      hostPID: true
      tolerations:
      - effect: NoSchedule
        key: node-role.kubernetes.io/control-plane
        operator: Exists
      containers:
      - name: node-exporter
        image: prom/node-exporter:v1.6.1
        args:
        - --path.procfs=/host/proc
        - --path.sysfs=/host/sys
        - --path.rootfs=/host/root
        ports:
        - containerPort: 9100
          hostPort: 9100
          name: metrics
        resources:
          limits:
            memory: "200Mi"
            cpu: "200m"
          requests:
            memory: "100Mi"
            cpu: "100m"
        volumeMounts:
        - name: proc
          mountPath: /host/proc
          readOnly: true
        - name: sys
          mountPath: /host/sys
          readOnly: true
        - name: root
          mountPath: /host/root
          readOnly: true
      volumes:
      - name: proc
        hostPath:
          path: /proc
      - name: sys
        hostPath:
          path: /sys
      - name: root
        hostPath:
          path: /
EOF
    
    echo -e "${GREEN}Node Exporter deployed successfully!${NC}"
    kubectl get daemonset -n $NAMESPACE
    kubectl get pods -n $NAMESPACE -o wide
}

# Get DaemonSet status
get_daemonset_status() {
    local NAME=${1}
    local NAMESPACE=${2:-"default"}
    
    if [[ -z $NAME ]]; then
        echo "Usage: get_daemonset_status <name> [namespace]"
        return 1
    fi
    
    echo -e "${BLUE}=== DaemonSet Status ===${NC}"
    kubectl get daemonset $NAME -n $NAMESPACE
    
    echo -e "\n${BLUE}=== DaemonSet Details ===${NC}"
    kubectl describe daemonset $NAME -n $NAMESPACE
    
    echo -e "\n${BLUE}=== Pods ===${NC}"
    kubectl get pods -n $NAMESPACE -l app=$NAME -o wide
    
    echo -e "\n${BLUE}=== Rollout Status ===${NC}"
    kubectl rollout status daemonset/$NAME -n $NAMESPACE
}

# Update DaemonSet image
update_daemonset_image() {
    local NAME=${1}
    local IMAGE=${2}
    local NAMESPACE=${3:-"default"}
    
    if [[ -z $NAME ]] || [[ -z $IMAGE ]]; then
        echo "Usage: update_daemonset_image <name> <image> [namespace]"
        return 1
    fi
    
    echo -e "${BLUE}Updating DaemonSet $NAME to image $IMAGE${NC}"
    kubectl set image daemonset/$NAME *=$IMAGE -n $NAMESPACE
    
    echo -e "${BLUE}Waiting for rollout...${NC}"
    kubectl rollout status daemonset/$NAME -n $NAMESPACE
    
    echo -e "${GREEN}Update completed!${NC}"
}

# Verify DaemonSet distribution
verify_daemonset_distribution() {
    local NAME=${1}
    local NAMESPACE=${2:-"default"}
    
    if [[ -z $NAME ]]; then
        echo "Usage: verify_daemonset_distribution <name> [namespace]"
        return 1
    fi
    
    echo -e "${BLUE}=== Node Distribution ===${NC}"
    
    echo -e "\n${YELLOW}Nodes in cluster:${NC}"
    kubectl get nodes -o custom-columns=NAME:.metadata.name,STATUS:.status.conditions[-1].type
    
    echo -e "\n${YELLOW}Pods per node:${NC}"
    kubectl get pods -n $NAMESPACE -l app=$NAME -o wide | \
        awk 'NR>1 {print $7}' | sort | uniq -c | \
        awk '{print "Node:", $2, "- Pods:", $1}'
    
    TOTAL_NODES=$(kubectl get nodes --no-headers | wc -l)
    TOTAL_PODS=$(kubectl get pods -n $NAMESPACE -l app=$NAME --no-headers | wc -l)
    
    echo -e "\n${YELLOW}Summary:${NC}"
    echo "Total Nodes: $TOTAL_NODES"
    echo "Total DaemonSet Pods: $TOTAL_PODS"
    
    if [[ $TOTAL_NODES -eq $TOTAL_PODS ]]; then
        echo -e "${GREEN}✓ Pod on every node${NC}"
    else
        echo -e "${RED}✗ Mismatch detected!${NC}"
    fi
}

