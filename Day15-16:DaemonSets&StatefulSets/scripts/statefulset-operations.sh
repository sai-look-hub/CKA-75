# ============================================
# 2. STATEFULSET OPERATIONS
# ============================================

# Create basic StatefulSet
create_basic_statefulset() {
    local NAME=${1:-"web"}
    local NAMESPACE=${2:-"default"}
    local REPLICAS=${3:-3}
    
    echo -e "${BLUE}Creating StatefulSet: $NAME with $REPLICAS replicas${NC}"
    
    # Create Headless Service
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: ${NAME}-svc
  namespace: $NAMESPACE
spec:
  clusterIP: None
  selector:
    app: $NAME
  ports:
  - port: 80
    name: web
EOF
    
    # Create StatefulSet
    cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: $NAME
  namespace: $NAMESPACE
spec:
  serviceName: "${NAME}-svc"
  replicas: $REPLICAS
  selector:
    matchLabels:
      app: $NAME
  template:
    metadata:
      labels:
        app: $NAME
    spec:
      containers:
      - name: nginx
        image: nginx:1.21
        ports:
        - containerPort: 80
          name: web
        volumeMounts:
        - name: www
          mountPath: /usr/share/nginx/html
  volumeClaimTemplates:
  - metadata:
      name: www
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: "standard"
      resources:
        requests:
          storage: 1Gi
EOF
    
    echo -e "${GREEN}StatefulSet created successfully!${NC}"
    kubectl get statefulset $NAME -n $NAMESPACE
}

# Deploy MongoDB StatefulSet
deploy_mongodb_statefulset() {
    local NAMESPACE=${1:-"database"}
    local REPLICAS=${2:-3}
    
    echo -e "${BLUE}Deploying MongoDB StatefulSet with $REPLICAS replicas...${NC}"
    
    # Create namespace
    kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
    
    # Create Secret
    kubectl create secret generic mongodb-secret \
        --from-literal=username=admin \
        --from-literal=password=SecurePassword123! \
        --namespace=$NAMESPACE \
        --dry-run=client -o yaml | kubectl apply -f -
    
    # Create Headless Service
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: mongodb-svc
  namespace: $NAMESPACE
spec:
  clusterIP: None
  selector:
    app: mongodb
  ports:
  - port: 27017
    name: mongodb
EOF
    
    # Create StatefulSet
    cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mongodb
  namespace: $NAMESPACE
spec:
  serviceName: mongodb-svc
  replicas: $REPLICAS
  selector:
    matchLabels:
      app: mongodb
  template:
    metadata:
      labels:
        app: mongodb
    spec:
      containers:
      - name: mongodb
        image: mongo:6.0
        command:
        - mongod
        - --replSet
        - rs0
        - --bind_ip_all
        ports:
        - containerPort: 27017
          name: mongodb
        env:
        - name: MONGO_INITDB_ROOT_USERNAME
          valueFrom:
            secretKeyRef:
              name: mongodb-secret
              key: username
        - name: MONGO_INITDB_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mongodb-secret
              key: password
        volumeMounts:
        - name: mongodb-data
          mountPath: /data/db
        resources:
          requests:
            memory: "1Gi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "1000m"
  volumeClaimTemplates:
  - metadata:
      name: mongodb-data
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: "standard"
      resources:
        requests:
          storage: 10Gi
EOF
    
    echo -e "${GREEN}MongoDB StatefulSet deployed!${NC}"
    echo -e "${YELLOW}Waiting for pods to be ready...${NC}"
    kubectl wait --for=condition=ready pod -l app=mongodb -n $NAMESPACE --timeout=300s
    
    echo -e "${GREEN}MongoDB is ready!${NC}"
    kubectl get statefulset,pods,pvc -n $NAMESPACE
}

# Initialize MongoDB ReplicaSet
initialize_mongodb_replicaset() {
    local NAMESPACE=${1:-"database"}
    local REPLICAS=${2:-3}
    
    echo -e "${BLUE}Initializing MongoDB ReplicaSet...${NC}"
    
    # Wait for all pods to be ready
    echo "Waiting for all MongoDB pods to be ready..."
    kubectl wait --for=condition=ready pod -l app=mongodb -n $NAMESPACE --timeout=300s
    
    # Get credentials
    USERNAME=$(kubectl get secret mongodb-secret -n $NAMESPACE -o jsonpath='{.data.username}' | base64 -d)
    PASSWORD=$(kubectl get secret mongodb-secret -n $NAMESPACE -o jsonpath='{.data.password}' | base64 -d)
    
    # Build replica set members
    MEMBERS="["
    for i in $(seq 0 $((REPLICAS-1))); do
        MEMBERS="${MEMBERS}{ _id: $i, host: \"mongodb-$i.mongodb-svc.$NAMESPACE.svc.cluster.local:27017\" }"
        if [[ $i -lt $((REPLICAS-1)) ]]; then
            MEMBERS="${MEMBERS},"
        fi
    done
    MEMBERS="${MEMBERS}]"
    
    # Initialize replica set
    kubectl exec mongodb-0 -n $NAMESPACE -- mongosh --eval "
        rs.initiate({
            _id: 'rs0',
            members: $MEMBERS
        })
    "
    
    echo -e "${GREEN}ReplicaSet initialized!${NC}"
    sleep 5
    
    echo -e "${BLUE}Checking ReplicaSet status...${NC}"
    kubectl exec mongodb-0 -n $NAMESPACE -- mongosh --eval "rs.status()"
}

# Scale StatefulSet
scale_statefulset() {
    local NAME=${1}
    local REPLICAS=${2}
    local NAMESPACE=${3:-"default"}
    
    if [[ -z $NAME ]] || [[ -z $REPLICAS ]]; then
        echo "Usage: scale_statefulset <name> <replicas> [namespace]"
        return 1
    fi
    
    echo -e "${BLUE}Scaling StatefulSet $NAME to $REPLICAS replicas${NC}"
    kubectl scale statefulset $NAME --replicas=$REPLICAS -n $NAMESPACE
    
    echo -e "${BLUE}Waiting for scale operation...${NC}"
    kubectl rollout status statefulset/$NAME -n $NAMESPACE
    
    echo -e "${GREEN}Scale operation completed!${NC}"
    kubectl get statefulset $NAME -n $NAMESPACE
    kubectl get pods -l app=$NAME -n $NAMESPACE
}

# Get StatefulSet status
get_statefulset_status() {
    local NAME=${1}
    local NAMESPACE=${2:-"default"}
    
    if [[ -z $NAME ]]; then
        echo "Usage: get_statefulset_status <name> [namespace]"
        return 1
    fi
    
    echo -e "${BLUE}=== StatefulSet Status ===${NC}"
    kubectl get statefulset $NAME -n $NAMESPACE
    
    echo -e "\n${BLUE}=== StatefulSet Details ===${NC}"
    kubectl describe statefulset $NAME -n $NAMESPACE | head -30
    
    echo -e "\n${BLUE}=== Pods ===${NC}"
    kubectl get pods -n $NAMESPACE -l app=$NAME -o wide
    
    echo -e "\n${BLUE}=== Persistent Volume Claims ===${NC}"
    kubectl get pvc -n $NAMESPACE -l app=$NAME
    
    echo -e "\n${BLUE}=== Services ===${NC}"
    kubectl get svc -n $NAMESPACE -l app=$NAME
}

# Verify StatefulSet ordering
verify_statefulset_ordering() {
    local NAME=${1}
    local NAMESPACE=${2:-"default"}
    
    if [[ -z $NAME ]]; then
        echo "Usage: verify_statefulset_ordering <name> [namespace]"
        return 1
    fi
    
    echo -e "${BLUE}=== Pod Creation Order ===${NC}"
    kubectl get pods -n $NAMESPACE -l app=$NAME \
        -o custom-columns=NAME:.metadata.name,CREATED:.metadata.creationTimestamp \
        --sort-by=.metadata.creationTimestamp
    
    echo -e "\n${BLUE}=== DNS Names ===${NC}"
    SERVICE_NAME="${NAME}-svc"
    REPLICAS=$(kubectl get statefulset $NAME -n $NAMESPACE -o jsonpath='{.spec.replicas}')
    
    for i in $(seq 0 $((REPLICAS-1))); do
        POD_NAME="${NAME}-$i"
        DNS="${POD_NAME}.${SERVICE_NAME}.${NAMESPACE}.svc.cluster.local"
        echo "$POD_NAME → $DNS"
    done
}

# Test StatefulSet DNS
test_statefulset_dns() {
    local NAME=${1}
    local NAMESPACE=${2:-"default"}
    
    if [[ -z $NAME ]]; then
        echo "Usage: test_statefulset_dns <name> [namespace]"
        return 1
    fi
    
    SERVICE_NAME="${NAME}-svc"
    POD_NAME="${NAME}-0"
    
    echo -e "${BLUE}Testing DNS resolution from ${POD_NAME}...${NC}"
    
    REPLICAS=$(kubectl get statefulset $NAME -n $NAMESPACE -o jsonpath='{.spec.replicas}')
    
    for i in $(seq 0 $((REPLICAS-1))); do
        TARGET="${NAME}-$i.${SERVICE_NAME}.${NAMESPACE}.svc.cluster.local"
        echo -e "\n${YELLOW}Resolving: $TARGET${NC}"
        kubectl exec $POD_NAME -n $NAMESPACE -- nslookup $TARGET 2>/dev/null || \
        kubectl exec $POD_NAME -n $NAMESPACE -- getent hosts $TARGET 2>/dev/null || \
        echo "DNS resolution test requires nslookup or getent in the pod"
    done
}
