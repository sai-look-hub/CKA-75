# Day 15-16: DaemonSets & StatefulSets - Complete Guide

## Table of Contents
1. [Introduction](#introduction)
2. [DaemonSets](#daemonsets)
3. [StatefulSets](#statefulsets)
4. [Persistent Storage](#persistent-storage)
5. [Headless Services](#headless-services)
6. [Update Strategies](#update-strategies)
7. [Real-World Projects](#real-world-projects)
8. [Best Practices](#best-practices)
9. [Troubleshooting](#troubleshooting)

---

## Introduction

### What are Specialized Workload Controllers?

While Deployments are great for stateless applications, Kubernetes provides specialized controllers for specific use cases:

- **DaemonSets**: Run one pod per node (system services)
- **StatefulSets**: Manage stateful applications (databases)

### When to Use Each

| Controller | Use Case | Examples |
|-----------|----------|----------|
| **Deployment** | Stateless apps | Web servers, APIs |
| **DaemonSet** | Node-level services | Monitoring, logging |
| **StatefulSet** | Stateful apps | Databases, message queues |

---

## DaemonSets

### What is a DaemonSet?

A DaemonSet ensures that a copy of a Pod runs on all (or some) nodes in the cluster. When nodes are added, pods are automatically added. When nodes are removed, pods are garbage collected.

### Core Concepts

**Characteristics**:
- One pod per node (by default)
- Automatically schedules on new nodes
- Survives node drain operations
- Perfect for cluster-wide services

**Use Cases**:
1. **Monitoring**: Collect metrics from every node
2. **Logging**: Aggregate logs from all containers
3. **Networking**: CNI plugins, network proxies
4. **Storage**: Distributed storage daemons
5. **Security**: Security monitoring agents

### Basic DaemonSet Example

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: node-exporter
  namespace: monitoring
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
      # Host network for accessing node metrics
      hostNetwork: true
      hostPID: true
      
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
```

### Node Selection

#### 1. Run on All Nodes
```yaml
# Default behavior - no restrictions
spec:
  template:
    spec:
      containers:
      - name: app
        image: myapp:1.0
```

#### 2. Run on Specific Nodes (nodeSelector)
```yaml
spec:
  template:
    spec:
      nodeSelector:
        node-type: worker  # Only on nodes with this label
        disk: ssd
      containers:
      - name: app
        image: myapp:1.0
```

#### 3. Run on Master Nodes (Tolerations)
```yaml
spec:
  template:
    spec:
      # Tolerate master node taints
      tolerations:
      - key: node-role.kubernetes.io/control-plane
        operator: Exists
        effect: NoSchedule
      - key: node-role.kubernetes.io/master
        operator: Exists
        effect: NoSchedule
      
      containers:
      - name: app
        image: myapp:1.0
```

#### 4. Advanced Node Affinity
```yaml
spec:
  template:
    spec:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: kubernetes.io/os
                operator: In
                values:
                - linux
              - key: node-type
                operator: NotIn
                values:
                - gpu  # Don't run on GPU nodes
      
      containers:
      - name: app
        image: myapp:1.0
```

### DaemonSet Update Strategies

#### 1. RollingUpdate (Default)
```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluentd
spec:
  updateStrategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1  # Update one pod at a time
  
  template:
    metadata:
      labels:
        app: fluentd
    spec:
      containers:
      - name: fluentd
        image: fluent/fluentd:v1.16
```

#### 2. OnDelete (Manual Updates)
```yaml
spec:
  updateStrategy:
    type: OnDelete  # Manual pod deletion required
```

### Complete Monitoring Agent Example

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: monitoring-agent
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: monitoring-agent
  
  updateStrategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
  
  template:
    metadata:
      labels:
        app: monitoring-agent
    spec:
      serviceAccountName: monitoring-agent
      
      # Run on all nodes including masters
      tolerations:
      - effect: NoSchedule
        key: node-role.kubernetes.io/control-plane
      - effect: NoSchedule
        key: node-role.kubernetes.io/master
      
      hostNetwork: true
      hostPID: true
      
      containers:
      - name: agent
        image: monitoring-agent:1.0
        
        env:
        - name: NODE_NAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
        - name: NODE_IP
          valueFrom:
            fieldRef:
              fieldPath: status.hostIP
        
        ports:
        - containerPort: 9100
          hostPort: 9100
          name: metrics
        
        resources:
          limits:
            memory: "500Mi"
            cpu: "500m"
          requests:
            memory: "200Mi"
            cpu: "200m"
        
        securityContext:
          privileged: true
          capabilities:
            add:
            - SYS_ADMIN
        
        volumeMounts:
        - name: host-root
          mountPath: /host
          readOnly: true
        - name: config
          mountPath: /etc/agent
      
      volumes:
      - name: host-root
        hostPath:
          path: /
      - name: config
        configMap:
          name: monitoring-agent-config
```

---

## StatefulSets

### What is a StatefulSet?

StatefulSet is a workload controller for managing stateful applications that require:
- Stable, unique network identifiers
- Stable, persistent storage
- Ordered, graceful deployment and scaling
- Ordered, automated rolling updates

### Core Concepts

**Key Features**:
1. **Stable Network Identity**: Each pod gets predictable hostname
2. **Ordered Deployment**: Pods created sequentially (0, 1, 2...)
3. **Persistent Storage**: Each pod gets dedicated PVC
4. **Stable DNS**: Predictable DNS via Headless Service
5. **Ordered Scaling**: Scale up/down in order

**Pod Naming**:
```
<statefulset-name>-<ordinal>
mongodb-0
mongodb-1
mongodb-2
```

**DNS Names**:
```
<pod-name>.<service-name>.<namespace>.svc.cluster.local
mongodb-0.mongodb-svc.database.svc.cluster.local
```

### Basic StatefulSet Example

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: web
spec:
  serviceName: "web-svc"  # Required: Headless Service
  replicas: 3
  
  selector:
    matchLabels:
      app: web
  
  template:
    metadata:
      labels:
        app: web
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
  
  # Volume claim template - creates PVC per pod
  volumeClaimTemplates:
  - metadata:
      name: www
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: "standard"
      resources:
        requests:
          storage: 1Gi
```

### Headless Service for StatefulSet

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web-svc
spec:
  clusterIP: None  # Headless service
  selector:
    app: web
  ports:
  - port: 80
    name: web
```

This creates DNS entries:
```
web-0.web-svc.default.svc.cluster.local
web-1.web-svc.default.svc.cluster.local
web-2.web-svc.default.svc.cluster.local
```

### StatefulSet Lifecycle

#### Deployment
```
1. Pod web-0 created
2. Wait for web-0 to be Running and Ready
3. Pod web-1 created
4. Wait for web-1 to be Running and Ready
5. Pod web-2 created
```

#### Scaling Up (replicas 3 → 5)
```
1. Create web-3
2. Wait for web-3 Ready
3. Create web-4
```

#### Scaling Down (replicas 5 → 3)
```
1. Delete web-4
2. Wait for web-4 to terminate
3. Delete web-3
```

### MongoDB StatefulSet Example

```yaml
apiVersion: v1
kind: Service
metadata:
  name: mongodb-svc
  namespace: database
spec:
  clusterIP: None
  selector:
    app: mongodb
  ports:
  - port: 27017
    name: mongodb

---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mongodb
  namespace: database
spec:
  serviceName: mongodb-svc
  replicas: 3
  
  selector:
    matchLabels:
      app: mongodb
  
  template:
    metadata:
      labels:
        app: mongodb
    spec:
      # Init container to set up replica set
      initContainers:
      - name: install
        image: busybox:1.34
        command:
        - sh
        - -c
        - |
          # Create data directory with proper permissions
          mkdir -p /data/db
          chmod 755 /data/db
        volumeMounts:
        - name: mongodb-data
          mountPath: /data/db
      
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
        
        livenessProbe:
          exec:
            command:
            - mongo
            - --eval
            - "db.adminCommand('ping')"
          initialDelaySeconds: 30
          periodSeconds: 10
        
        readinessProbe:
          exec:
            command:
            - mongo
            - --eval
            - "db.adminCommand('ping')"
          initialDelaySeconds: 10
          periodSeconds: 5
  
  volumeClaimTemplates:
  - metadata:
      name: mongodb-data
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: "standard"
      resources:
        requests:
          storage: 10Gi
```

---

## Persistent Storage

### Understanding PersistentVolumes (PV) and PersistentVolumeClaims (PVC)

#### Architecture
```
┌─────────────────────┐
│   StatefulSet       │
│                     │
│  ┌─────┐  ┌─────┐  │
│  │Pod-0│  │Pod-1│  │
│  └──┬──┘  └──┬──┘  │
└─────┼────────┼─────┘
      │        │
      ↓        ↓
┌─────────────────────┐
│   PVC (Claims)      │
│  ┌─────┐  ┌─────┐  │
│  │PVC-0│  │PVC-1│  │
│  └──┬──┘  └──┬──┘  │
└─────┼────────┼─────┘
      │        │
      ↓        ↓
┌─────────────────────┐
│ PV (Volumes)        │
│  ┌─────┐  ┌─────┐  │
│  │ PV-0│  │ PV-1│  │
│  └─────┘  └─────┘  │
└─────────────────────┘
```

### StorageClass

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
provisioner: kubernetes.io/aws-ebs
parameters:
  type: gp3
  iops: "3000"
  throughput: "125"
reclaimPolicy: Retain
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
```

### Volume Claim Template in StatefulSet

```yaml
volumeClaimTemplates:
- metadata:
    name: data
    labels:
      app: myapp
  spec:
    accessModes: ["ReadWriteOnce"]
    storageClassName: "fast-ssd"
    resources:
      requests:
        storage: 20Gi
```

This creates PVCs:
```
data-myapp-0 (20Gi)
data-myapp-1 (20Gi)
data-myapp-2 (20Gi)
```

### PostgreSQL with Persistent Storage

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
  namespace: database
spec:
  serviceName: postgres-svc
  replicas: 3
  
  selector:
    matchLabels:
      app: postgres
  
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:15
        
        ports:
        - containerPort: 5432
          name: postgres
        
        env:
        - name: POSTGRES_USER
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: username
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: password
        - name: POSTGRES_DB
          value: myapp
        - name: PGDATA
          value: /var/lib/postgresql/data/pgdata
        
        volumeMounts:
        - name: postgres-data
          mountPath: /var/lib/postgresql/data
        - name: config
          mountPath: /etc/postgresql
        
        resources:
          requests:
            memory: "2Gi"
            cpu: "1000m"
          limits:
            memory: "4Gi"
            cpu: "2000m"
        
        livenessProbe:
          exec:
            command:
            - pg_isready
            - -U
            - postgres
          initialDelaySeconds: 30
          periodSeconds: 10
        
        readinessProbe:
          exec:
            command:
            - pg_isready
            - -U
            - postgres
          initialDelaySeconds: 5
          periodSeconds: 5
      
      volumes:
      - name: config
        configMap:
          name: postgres-config
  
  volumeClaimTemplates:
  - metadata:
      name: postgres-data
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: "fast-ssd"
      resources:
        requests:
          storage: 50Gi
```

---

## Headless Services

### What is a Headless Service?

A Headless Service (clusterIP: None) doesn't allocate a cluster IP. Instead, it returns the IP addresses of the pods directly.

### Regular Service vs Headless Service

#### Regular Service
```yaml
apiVersion: v1
kind: Service
metadata:
  name: web
spec:
  selector:
    app: web
  ports:
  - port: 80
  # ClusterIP assigned automatically
```

DNS returns: Single Cluster IP

#### Headless Service
```yaml
apiVersion: v1
kind: Service
metadata:
  name: web-headless
spec:
  clusterIP: None  # Headless
  selector:
    app: web
  ports:
  - port: 80
```

DNS returns: All pod IPs

### DNS Records Created

For StatefulSet with Headless Service:
```yaml
serviceName: "mongodb-svc"
replicas: 3
```

DNS records created:
```
# Individual pods
mongodb-0.mongodb-svc.database.svc.cluster.local → 10.1.1.5
mongodb-1.mongodb-svc.database.svc.cluster.local → 10.1.1.6
mongodb-2.mongodb-svc.database.svc.cluster.local → 10.1.1.7

# Service (returns all pod IPs)
mongodb-svc.database.svc.cluster.local → 10.1.1.5, 10.1.1.6, 10.1.1.7
```

### Using Headless Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: cassandra
  namespace: database
spec:
  clusterIP: None
  selector:
    app: cassandra
  ports:
  - port: 9042
    name: cql
  - port: 7000
    name: intra-node
  - port: 7001
    name: tls-intra-node

---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: cassandra
  namespace: database
spec:
  serviceName: cassandra  # Links to headless service
  replicas: 3
  selector:
    matchLabels:
      app: cassandra
  template:
    metadata:
      labels:
        app: cassandra
    spec:
      containers:
      - name: cassandra
        image: cassandra:4.1
        env:
        - name: CASSANDRA_SEEDS
          value: "cassandra-0.cassandra.database.svc.cluster.local"
        - name: CASSANDRA_CLUSTER_NAME
          value: "MyCluster"
        ports:
        - containerPort: 9042
          name: cql
        volumeMounts:
        - name: data
          mountPath: /var/lib/cassandra
  
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 100Gi
```

---

## Update Strategies

### DaemonSet Update Strategies

#### RollingUpdate
```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluentd
spec:
  updateStrategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1  # Update one node at a time
      maxSurge: 0        # DaemonSets don't support surge
```

#### OnDelete
```yaml
spec:
  updateStrategy:
    type: OnDelete
```

Manual update process:
```bash
# Update DaemonSet spec
kubectl apply -f daemonset.yaml

# Manually delete pods to trigger update
kubectl delete pod -l app=fluentd --field-selector spec.nodeName=node1
kubectl delete pod -l app=fluentd --field-selector spec.nodeName=node2
```

### StatefulSet Update Strategies

#### RollingUpdate (Default)
```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: web
spec:
  updateStrategy:
    type: RollingUpdate
    rollingUpdate:
      partition: 0  # Update all pods
```

Updates pods in reverse order: N-1, N-2, ..., 0

#### Partitioned Rolling Update
```yaml
spec:
  updateStrategy:
    type: RollingUpdate
    rollingUpdate:
      partition: 2  # Only update pods >= 2
```

With 5 replicas (0-4), only pods 2, 3, 4 are updated.

#### OnDelete
```yaml
spec:
  updateStrategy:
    type: OnDelete
```

### Canary Deployment with StatefulSet

```yaml
# Step 1: Update with partition
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: web
spec:
  replicas: 5
  updateStrategy:
    type: RollingUpdate
    rollingUpdate:
      partition: 4  # Only update pod-4
  template:
    spec:
      containers:
      - name: nginx
        image: nginx:1.22  # New version
```

```bash
# Step 2: Verify pod-4
kubectl exec web-4 -- nginx -v

# Step 3: Gradually decrease partition
kubectl patch statefulset web -p '{"spec":{"updateStrategy":{"rollingUpdate":{"partition":3}}}}'
kubectl patch statefulset web -p '{"spec":{"updateStrategy":{"rollingUpdate":{"partition":2}}}}'
# Continue until partition: 0
```

---

## Real-World Projects

### Project 1: Complete Monitoring Stack with DaemonSets

#### Architecture
```
Every Node:
  ├── Node Exporter (System metrics)
  ├── Fluent Bit (Log collection)
  └── cAdvisor (Container metrics)
```

#### Deployment

**Namespace**:
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: monitoring
```

**Node Exporter DaemonSet**:
```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: node-exporter
  namespace: monitoring
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
      containers:
      - name: node-exporter
        image: prom/node-exporter:v1.6.1
        args:
        - --path.procfs=/host/proc
        - --path.sysfs=/host/sys
        - --collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)
        ports:
        - containerPort: 9100
          hostPort: 9100
        volumeMounts:
        - name: proc
          mountPath: /host/proc
          readOnly: true
        - name: sys
          mountPath: /host/sys
          readOnly: true
      volumes:
      - name: proc
        hostPath:
          path: /proc
      - name: sys
        hostPath:
          path: /sys
```

**Fluent Bit DaemonSet**:
```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluent-bit
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: fluent-bit
  template:
    metadata:
      labels:
        app: fluent-bit
    spec:
      serviceAccountName: fluent-bit
      tolerations:
      - effect: NoSchedule
        key: node-role.kubernetes.io/control-plane
      containers:
      - name: fluent-bit
        image: fluent/fluent-bit:2.1
        volumeMounts:
        - name: varlog
          mountPath: /var/log
        - name: varlibdockercontainers
          mountPath: /var/lib/docker/containers
          readOnly: true
        - name: config
          mountPath: /fluent-bit/etc/
      volumes:
      - name: varlog
        hostPath:
          path: /var/log
      - name: varlibdockercontainers
        hostPath:
          path: /var/lib/docker/containers
      - name: config
        configMap:
          name: fluent-bit-config
```

### Project 2: MongoDB Replica Set with StatefulSet

#### Complete MongoDB Deployment

**Secret**:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: mongodb-secret
  namespace: database
type: Opaque
stringData:
  username: admin
  password: SecurePassword123!
  replicaset-key: |
    veryLongRandomStringForReplicaSetKeyAuth
    ThisShouldBeAtLeast1024Characters
```

**ConfigMap**:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: mongodb-config
  namespace: database
data:
  mongod.conf: |
    storage:
      dbPath: /data/db
      journal:
        enabled: true
    systemLog:
      destination: file
      path: /var/log/mongodb/mongod.log
      logAppend: true
    net:
      port: 27017
      bindIp: 0.0.0.0
    replication:
      replSetName: rs0
    security:
      keyFile: /etc/mongodb-keyfile/replicaset-key
      authorization: enabled
```

**Headless Service**:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: mongodb-svc
  namespace: database
spec:
  clusterIP: None
  selector:
    app: mongodb
  ports:
  - port: 27017
    name: mongodb
```

**StatefulSet**:
```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mongodb
  namespace: database
spec:
  serviceName: mongodb-svc
  replicas: 3
  selector:
    matchLabels:
      app: mongodb
  template:
    metadata:
      labels:
        app: mongodb
    spec:
      initContainers:
      - name: setup-keyfile
        image: busybox
        command:
        - sh
        - -c
        - |
          cp /tmp/keyfile/replicaset-key /data/keyfile/
          chmod 400 /data/keyfile/replicaset-key
          chown 999:999 /data/keyfile/replicaset-key
        volumeMounts:
        - name: keyfile-secret
          mountPath: /tmp/keyfile
        - name: keyfile
          mountPath: /data/keyfile
      
      containers:
      - name: mongodb
        image: mongo:6.0
        command:
        - mongod
        - --config=/etc/mongodb/mongod.conf
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
        - name: config
          mountPath: /etc/mongodb
        - name: keyfile
          mountPath: /etc/mongodb-keyfile
        resources:
          requests:
            memory: "2Gi"
            cpu: "1"
          limits:
            memory: "4Gi"
            cpu: "2"
        livenessProbe:
          exec:
            command:
            - mongo
            - --eval
            - "db.adminCommand('ping')"
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          exec:
            command:
            - mongo
            - --eval
            - "db.adminCommand('ping')"
          initialDelaySeconds: 5
          periodSeconds: 5
      
      volumes:
      - name: config
        configMap:
          name: mongodb-config
      - name: keyfile-secret
        secret:
          secretName: mongodb-secret
          items:
          - key: replicaset-key
            path: replicaset-key
      - name: keyfile
        emptyDir: {}
  
  volumeClaimTemplates:
  - metadata:
      name: mongodb-data
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: "standard"
      resources:
        requests:
          storage: 20Gi
```

**Initialize Replica Set**:
```bash
# Connect to mongodb-0
kubectl exec -it mongodb-0 -n database -- mongo -u admin -p SecurePassword123!

# Initialize replica set
rs.initiate({
  _id: "rs0",
  members: [
    { _id: 0, host: "mongodb-0.mongodb-svc.database.svc.cluster.local:27017" },
    { _id: 1, host: "mongodb-1.mongodb-svc.database.svc.cluster.local:27017" },
    { _id: 2, host: "mongodb-2.mongodb-svc.database.svc.cluster.local:27017" }
  ]
})

# Check status
rs.status()
```

---

## Best Practices

### DaemonSet Best Practices

1. **Resource Limits**
   ```yaml
   resources:
     limits:
       memory: "500Mi"
       cpu: "500m"
     requests:
       memory: "200Mi"
       cpu: "200m"
   ```

2. **Health Checks**
   ```yaml
   livenessProbe:
     httpGet:
       path: /health
       port: 8080
     periodSeconds: 10
   ```

3. **Node Tolerations**
   ```yaml
   tolerations:
   - effect: NoSchedule
     key: node-role.kubernetes.io/control-plane
   ```

4. **Priority Class**
   ```yaml
   priorityClassName: system-node-critical
   ```

### StatefulSet Best Practices

1. **Always Use Headless Service**
2. **Define Resource Limits**
3. **Implement Health Checks**
4. **Use Init Containers for Setup**
5. **Plan for Backups**
6. **Use Pod Disruption Budgets**
7. **Set Appropriate Storage Size**

---

## Summary

**DaemonSets** ensure cluster-wide services run on every node.
**StatefulSets** manage stateful applications with stable identities and persistent storage.

Both are essential for production Kubernetes deployments!
