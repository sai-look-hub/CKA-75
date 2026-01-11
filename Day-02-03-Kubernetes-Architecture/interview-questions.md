# Interview Questions - Kubernetes Architecture

## Q1: What happens when you run `kubectl create deployment nginx --replicas=3`?

**Answer:**
1. kubectl sends HTTP request to API Server
2. API Server authenticates & authorizes the request
3. API Server validates the Deployment spec
4. API Server writes Deployment object to etcd
5. Deployment Controller watches etcd, detects new Deployment
6. Deployment Controller creates ReplicaSet object
7. ReplicaSet Controller creates 3 Pod objects
8. Scheduler watches for unscheduled pods, assigns them to nodes
9. kubelet on each node watches API Server, sees new pods assigned
10. kubelet tells Container Runtime to pull nginx image and start containers
11. kubelet reports pod status back to API Server
12. API Server updates etcd with actual state

---

## Q2: What is stored in etcd?

**Answer:**
etcd stores all cluster state:
- All Kubernetes objects (Pods, Services, Deployments, etc.)
- Cluster configuration
- Secrets and ConfigMaps
- Network policies
- RBAC policies
- Node information

It's the single source of truth for the cluster.

---

## Q3: Can you explain the difference between kubelet and kube-proxy?

**Answer:**
- **kubelet**: 
  - Runs on every node
  - Manages pod lifecycle (create, start, stop, delete)
  - Reports node and pod status to API Server
  - Runs health checks
  
- **kube-proxy**:
  - Runs on every node
  - Manages network rules (iptables/IPVS)
  - Implements Kubernetes Services
  - Handles load balancing across pod replicas

---

## Q4: What happens if the API Server goes down?

**Answer:**
- kubectl commands will fail (can't communicate with cluster)
- New pods cannot be scheduled
- Controllers cannot make changes
- **BUT** existing pods continue running because kubelet manages them independently
- Once API Server recovers, everything syncs back up

---

## Q5: How does the Scheduler decide where to place a pod?

**Answer:**
Two-phase process:

**1. Filtering (Feasibility Check):**
- Removes nodes that don't meet requirements
- Checks: resource availability, node selectors, taints/tolerations, affinity rules

**2. Scoring (Prioritization):**
- Ranks remaining nodes based on:
  - Resource balance
  - Pod spreading
  - Affinity preferences
  - Image locality

Pod is assigned to highest-scoring node.

---

## Q6: Can you bypass the Kubernetes Scheduler?

**Answer:**
Yes, using `nodeName` in pod spec:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx
spec:
  nodeName: worker-node-1  # Bypasses scheduler
  containers:
  - name: nginx
    image: nginx
```

Pod is immediately assigned to specified node without going through scheduler.

---

## Q7: What is the role of Controllers in Kubernetes?

**Answer:**
Controllers implement the control loop:
1. Watch desired state (from etcd via API Server)
2. Observe actual state
3. Make changes to match desired state
4. Repeat continuously

Examples:
- **Node Controller**: Monitors node health
- **Replication Controller**: Maintains correct number of pod replicas
- **Endpoints Controller**: Populates Endpoints objects
- **Service Account Controller**: Creates default service accounts

---

## Q8: How do you backup and restore etcd?

**Answer:**

**Backup:**
```bash
ETCDCTL_API=3 etcdctl snapshot save /backup/etcd.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
```

**Restore:**
```bash
ETCDCTL_API=3 etcdctl snapshot restore /backup/etcd.db \
  --data-dir=/var/lib/etcd-restore
```

Then update etcd pod/service to use new data directory.

---

## Q9: What is the Container Runtime Interface (CRI)?

**Answer:**
CRI is a plugin interface that allows kubelet to use different container runtimes without recompiling.

**Supported runtimes:**
- containerd (most common)
- CRI-O
- Docker (deprecated, removed in v1.24)

kubelet communicates with runtime via CRI API to:
- Pull images
- Create/start/stop containers
- Get container status

---

## Q10: How do Kubernetes components communicate?

**Answer:**
- **All components → API Server**: REST API over HTTPS
- **API Server → etcd**: gRPC
- **kubelet ← API Server**: Watch mechanism (long-lived HTTP connections)
- **Controllers watch API Server**: For changes via watch API
- **Scheduler watches API Server**: For unscheduled pods

**Key Point:** Only API Server talks to etcd directly. All other components go through API Server.

---

## Q11: What happens if etcd goes down?

**Answer:**
- Cluster continues functioning temporarily
- Existing pods keep running
- **BUT** no state changes can be saved:
  - Can't create new pods
  - Can't update resources
  - Can't delete resources
- Once etcd recovers, operations resume

**This is why HA etcd (3 or 5 nodes) is critical in production!**

---

## Q12: Explain static pods

**Answer:**
Static pods are managed directly by kubelet, not by API Server.

**Characteristics:**
- Defined in manifest files on node (usually `/etc/kubernetes/manifests/`)
- kubelet automatically creates them
- Cannot be managed by kubectl (read-only)
- Used for control plane components (API Server, Scheduler, etc.)

**Use case:** Bootstrap control plane components before API Server is running.

---

## Tips for CKA Exam:

1. ✅ Know etcd backup/restore commands by heart
2. ✅ Understand component communication flow
3. ✅ Know which components are pods vs systemd services
4. ✅ Practice troubleshooting component failures
5. ✅ Be able to read and explain pod/deployment flow
