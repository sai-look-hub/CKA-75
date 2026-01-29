# DaemonSets & StatefulSets Interview Questions & Answers

## Table of Contents
- [Basic Level Questions](#basic-level-questions)
- [Intermediate Level Questions](#intermediate-level-questions)
- [Advanced Level Questions](#advanced-level-questions)
- [Scenario-Based Questions](#scenario-based-questions)

---

## Basic Level Questions

### Q1: What is a DaemonSet in Kubernetes?

**Answer**: A DaemonSet is a Kubernetes workload controller that ensures a copy of a pod runs on all (or some) nodes in the cluster. When new nodes are added, pods are automatically scheduled on them, and when nodes are removed, those pods are garbage collected.

**Key Characteristics**:
- One pod per node (by default)
- Automatic scheduling on new nodes
- Survives node drain operations
- No replica count specification needed

**Use Cases**:
- Node monitoring (Node Exporter, cAdvisor)
- Log collection (Fluentd, Fluent Bit, Filebeat)
- Cluster networking (Calico, Weave)
- Storage drivers (GlusterFS, Ceph)
- Security agents (Falco, Aqua)

**Example**:
```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: node-exporter
spec:
  selector:
    matchLabels:
      app: node-exporter
  template:
    metadata:
      labels:
        app: node-exporter
    spec:
      containers:
      - name: node-exporter
        image: prom/node-exporter:v1.6.1
```

---

### Q2: What is a StatefulSet and when should you use it?

**Answer**: A StatefulSet is a workload controller for managing stateful applications that require stable network identities, persistent storage, and ordered deployment/scaling.

**Key Features**:
1. **Stable Network Identity**: Each pod gets predictable hostname (pod-0, pod-1, pod-2)
2. **Persistent Storage**: Each pod can have dedicated PVC
3. **Ordered Operations**: Sequential creation/deletion
4. **Stable DNS**: Predictable DNS names via Headless Service

**When to Use**:
- Databases (MongoDB, PostgreSQL, MySQL)
- Distributed systems (Kafka, ZooKeeper, etcd)
- Caching layers (Redis Cluster)
- Stateful applications requiring stable identity

**Example**:
```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mongodb
spec:
  serviceName: "mongodb-svc"
  replicas: 3
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
        volumeMounts:
        - name: data
          mountPath: /data/db
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOn
