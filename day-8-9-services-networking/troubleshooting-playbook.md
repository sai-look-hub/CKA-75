# Kubernetes Services - Troubleshooting Playbook

> **Comprehensive guide for diagnosing and fixing service and networking issues**

---

## Table of Contents

- [Quick Diagnostic Commands](#quick-diagnostic-commands)
- [Issue 1: Service Not Accessible](#issue-1-service-not-accessible)
- [Issue 2: No Endpoints](#issue-2-no-endpoints)
- [Issue 3: DNS Not Resolving](#issue-3-dns-not-resolving)
- [Issue 4: LoadBalancer Pending](#issue-4-loadbalancer-pending)
- [Issue 5: NodePort Not Working](#issue-5-nodeport-not-working)
- [Issue 6: Intermittent Connection Failures](#issue-6-intermittent-connection-failures)
- [Issue 7: High Latency](#issue-7-high-latency)
- [Issue 8: Service Returns 503](#issue-8-service-returns-503)
- [Issue 9: Cross-Namespace Communication Fails](#issue-9-cross-namespace-communication-fails)
- [Issue 10: StatefulSet Pods Can't Communicate](#issue-10-statefulset-pods-cant-communicate)

---

## Quick Diagnostic Commands

```bash
# 1. Check service exists and has correct configuration
kubectl get svc <service-name>
kubectl describe svc <service-name>

# 2. Check endpoints (should show pod IPs)
kubectl get ep <service-name>

# 3. Check pods are running and ready
kubectl get pods -l app=<label>

# 4. Test DNS resolution
kubectl run -it --rm debug --image=busybox -- nslookup <service-name>

# 5. Test service connectivity
kubectl run -it --rm test --image=curlimages/curl -- curl http://<service-name>:<port>

# 6. Check kube-proxy
kubectl get pods -n kube-system -l k8s-app=kube-proxy
kubectl logs -n kube-system -l k8s-app=kube-proxy | tail -50
```

---

## Issue 1: Service Not Accessible

### Symptoms
```
Error: Connection refused
Error: Timeout
curl: (7) Failed to connect to service
```

### Diagnostic Steps

**Step 1: Verify Service Exists**
```bash
kubectl get svc <service-name>

# Expected output should show:
# NAME      TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)
# myservice ClusterIP   10.96.0.50      <none>        80/TCP
```

**Step 2: Check Service Endpoints**
```bash
kubectl get ep <service-name>

# Expected output:
# NAME      ENDPOINTS
# myservice 10.244.1.5:8080,10.244.1.6:8080

# If empty: selector mismatch or no ready pods
```

**Step 3: Verify Label Match**
```bash
# Get service selector
kubectl describe svc <service-name> | grep Selector

# Get pod labels
kubectl get pods --show-labels

# Compare - they must match exactly
```

**Step 4: Check Pod Status**
```bash
kubectl get pods -l app=<label> -o wide

# All pods should be:
# - STATUS: Running
# - READY: 1/1 (or your container count)
```

**Step 5: Test Pod Directly (Bypass Service)**
```bash
# Get pod IP
POD_IP=$(kubectl get pod <pod-name> -o jsonpath='{.status.podIP}')

# Test directly
kubectl run test --image=curlimages/curl -it --rm -- curl http://$POD_IP:8080

# If this works but service doesn't: service configuration issue
# If this fails: application issue
```

**Step 6: Check Readiness Probes**
```bash
kubectl describe pod <pod-name> | grep -A 5 Readiness

# If failing:
# - Application not listening on correct port
# - Application taking too long to start
# - Probe path incorrect
```

### Solutions

**Solution 1: Fix Label Mismatch**
```bash
# Update pod labels to match service selector
kubectl label pods <pod-name> app=<correct-label> --overwrite

# Or update service selector
kubectl patch svc <service-name> -p '{"spec":{"selector":{"app":"correct-label"}}}'
```

**Solution 2: Fix Port Configuration**
```yaml
# Ensure targetPort matches container port
spec:
  ports:
    - port: 80          # Service port
      targetPort: 8080  # Must match containerPort in pod
```

**Solution 3: Adjust Readiness Probe**
```bash
# Temporarily remove readiness probe to test
kubectl patch deployment <deployment-name> -p '{"spec":{"template":{"spec":{"containers":[{"name":"app","readinessProbe":null}]}}}}'

# Or increase initialDelaySeconds
kubectl patch deployment <deployment-name> -p '{"spec":{"template":{"spec":{"containers":[{"name":"app","readinessProbe":{"initialDelaySeconds":30}}]}}}}'
```

---

## Issue 2: No Endpoints

### Symptoms
```bash
kubectl get ep <service-name>
# Shows: <none> or empty
```

### Root Causes
1. Selector doesn't match any pods
2. No pods exist
3. All pods are not ready
4. Pods exist in different namespace

### Diagnostic Steps

**Step 1: Check Selector**
```bash
# Get service selector
SELECTOR=$(kubectl get svc <service-name> -o jsonpath='{.spec.selector}')
echo "Service Selector: $SELECTOR"

# Find matching pods
kubectl get pods -l app=<value-from-selector> --all-namespaces
```

**Step 2: Check Pod Readiness**
```bash
kubectl get pods -l app=<label> -o json | jq '.items[] | {name: .metadata.name, ready: .status.conditions[] | select(.type=="Ready") | .status}'
```

**Step 3: Check Namespace**
```bash
# Service namespace
kubectl get svc <service-name> -o jsonpath='{.metadata.namespace}'

# Pod namespace
kubectl get pods -l app=<label> --all-namespaces
```

### Solutions

**Solution 1: Fix Selector**
```bash
# Check exact pod labels
kubectl get pods <pod-name> -o jsonpath='{.metadata.labels}'

# Update service selector to match
kubectl patch svc <service-name> -p '{"spec":{"selector":{"app":"correct-value","tier":"api"}}}'
```

**Solution 2: Create Pods**
```bash
# If no pods exist, create deployment
kubectl create deployment <name> --image=<image> --replicas=3

# Label pods correctly
kubectl label pods -l app=<old-label> app=<new-label> --overwrite
```

**Solution 3: Fix Pod Health**
```bash
# Check why pods are not ready
kubectl describe pod <pod-name> | grep -A 20 Conditions

# Check logs
kubectl logs <pod-name>

# Common fixes:
# - Fix application startup
# - Adjust readiness probe
# - Fix resource limits
```

---

## Issue 3: DNS Not Resolving

### Symptoms
```
nslookup: can't resolve '<service-name>'
dial tcp: lookup <service-name> on 10.96.0.10:53: no such host
```

### Diagnostic Steps

**Step 1: Check CoreDNS Pods**
```bash
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Should show 2+ pods in Running state
# NAME                       READY   STATUS
# coredns-xxxxxxxxxx-xxxxx   1/1     Running
# coredns-xxxxxxxxxx-xxxxx   1/1     Running
```

**Step 2: Check CoreDNS Logs**
```bash
kubectl logs -n kube-system -l k8s-app=kube-dns --tail=50

# Look for errors like:
# - plugin/errors: lookup failure
# - connection refused
# - timeout
```

**Step 3: Test Basic DNS**
```bash
# Test Kubernetes DNS
kubectl run -it --rm debug --image=busybox -- nslookup kubernetes.default

# Expected output:
# Server:    10.96.0.10
# Address 1: 10.96.0.10 kube-dns.kube-system.svc.cluster.local
# Name:      kubernetes.default
# Address 1: 10.96.0.1 kubernetes.default.svc.cluster.local
```

**Step 4: Check DNS Configuration in Pod**
```bash
kubectl run -it --rm debug --image=busybox -- cat /etc/resolv.conf

# Expected output:
# nameserver 10.96.0.10
# search default.svc.cluster.local svc.cluster.local cluster.local
# options ndots:5
```

**Step 5: Test Service DNS**
```bash
# Short name (same namespace)
kubectl run -it --rm debug --image=busybox -- nslookup <service-name>

# With namespace
kubectl run -it --rm debug --image=busybox -- nslookup <service-name>.<namespace>

# Full FQDN
kubectl run -it --rm debug --image=busybox -- nslookup <service-name>.<namespace>.svc.cluster.local
```

### Solutions

**Solution 1: Restart CoreDNS**
```bash
kubectl rollout restart deployment/coredns -n kube-system

# Wait for rollout
kubectl rollout status deployment/coredns -n kube-system
```

**Solution 2: Check CoreDNS ConfigMap**
```bash
kubectl get configmap coredns -n kube-system -o yaml

# Should contain forward to upstream DNS
# Example:
.:53 {
    errors
    health {
       lameduck 5s
    }
    ready
    kubernetes cluster.local in-addr.arpa ip6.arpa {
       pods insecure
       fallthrough in-addr.arpa ip6.arpa
    }
    forward . /etc/resolv.conf
    cache 30
}
```

**Solution 3: Fix DNS Policy in Pod**
```yaml
# Ensure pod has correct DNS policy
spec:
  dnsPolicy: ClusterFirst  # Default, use cluster DNS
  # Or
  dnsPolicy: Default  # Use node's DNS
```

**Solution 4: Scale CoreDNS**
```bash
# If DNS is slow, scale up CoreDNS
kubectl scale deployment/coredns --replicas=3 -n kube-system
```

---

## Issue 4: LoadBalancer Pending

### Symptoms
```bash
kubectl get svc
# EXTERNAL-IP shows <pending>
```

### Diagnostic Steps

**Step 1: Check Service Description**
```bash
kubectl describe svc <service-name>

# Look at Events section for errors:
# - "cloud provider not configured"
# - "Failed to create load balancer"
# - "quota exceeded"
```

**Step 2: Verify Cloud Provider**
```bash
# Check if cluster has cloud provider configured
kubectl get nodes -o jsonpath='{.items[*].spec.providerID}'

# Should show provider-specific IDs:
# AWS: aws:///us-east-1a/i-xxxxx
# GCP: gce://project-id/us-central1-a/instance-name
# Azure: azure:///subscriptions/xxx/resourceGroups/xxx
```

**Step 3: Check Cloud Provider Controller**
```bash
# AWS
kubectl get pods -n kube-system -l k8s-app=aws-cloud-controller-manager

# GCP
kubectl get pods -n kube-system -l component=cloud-controller-manager

# Azure
kubectl get pods -n kube-system -l component=cloud-controller-manager
```

### Solutions

**Solution 1: Wait for Provisioning**
```bash
# LoadBalancer provisioning can take 2-5 minutes
kubectl get svc <service-name> -w

# Check cloud provider console for LB creation progress
```

**Solution 2: Check Cloud Provider Quotas**
```bash
# AWS
aws elbv2 describe-load-balancers --region <region>
aws service-quotas get-service-quota --service-code elasticloadbalancing --quota-code L-<quota-code>

# GCP
gcloud compute addresses list
gcloud compute forwarding-rules list

# Azure
az network lb list
```

**Solution 3: Use NodePort Instead (Temporary)**
```bash
kubectl patch svc <service-name> -p '{"spec":{"type":"NodePort"}}'

# Access via NodePort
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}')
NODE_PORT=$(kubectl get svc <service-name> -o jsonpath='{.spec.ports[0].nodePort}')
curl http://$NODE_IP:$NODE_PORT
```

**Solution 4: Install MetalLB (On-Premises)**
```bash
# For bare-metal/on-prem clusters
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.0/config/manifests/metallb-native.yaml

# Configure IP address pool
cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: first-pool
  namespace: metallb-system
spec:
  addresses:
  - 192.168.1.240-192.168.1.250
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: empty
  namespace: metallb-system
EOF
```

**Solution 5: Check Service Annotations**
```yaml
# For AWS
metadata:
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
    service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"

# For GCP
metadata:
  annotations:
    cloud.google.com/load-balancer-type: "External"

# For Azure
metadata:
  annotations:
    service.beta.kubernetes.io/azure-load-balancer-internal: "false"
```

---

## Issue 5: NodePort Not Working

### Symptoms
```
Connection refused when accessing <NodeIP>:<NodePort>
curl: (7) Failed to connect to <node-ip> port <node-port>
```

### Diagnostic Steps

**Step 1: Verify NodePort Service**
```bash
kubectl get svc <service-name>

# Check TYPE is NodePort and NodePort is assigned
# TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)
# NodePort    10.96.0.50     <none>        80:30080/TCP
```

**Step 2: Get NodePort and Node IPs**
```bash
# Get NodePort
NODE_PORT=$(kubectl get svc <service-name> -o jsonpath='{.spec.ports[0].nodePort}')
echo "NodePort: $NODE_PORT"

# Get Node IPs
kubectl get nodes -o wide
# or
kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="ExternalIP")].address}'
```

**Step 3: Check Firewall Rules**
```bash
# On each node, check if port is open
sudo iptables -L -n | grep <node-port>

# Check if kube-proxy created the rules
sudo iptables -t nat -L -n | grep <node-port>
```

**Step 4: Test from Node Itself**
```bash
# SSH to node
ssh <node-ip>

# Test locally
curl localhost:<node-port>

# If this works, firewall blocking external access
```

### Solutions

**Solution 1: Open Firewall**
```bash
# AWS Security Group
aws ec2 authorize-security-group-ingress \
  --group-id sg-xxxxx \
  --protocol tcp \
  --port <node-port> \
  --cidr 0.0.0.0/0

# GCP Firewall Rule
gcloud compute firewall-rules create allow-nodeport \
  --allow tcp:<node-port> \
  --source-ranges 0.0.0.0/0

# Azure NSG
az network nsg rule create \
  --resource-group <rg> \
  --nsg-name <nsg-name> \
  --name allow-nodeport \
  --priority 100 \
  --source-address-prefixes '*' \
  --destination-port-ranges <node-port> \
  --access Allow \
  --protocol Tcp
```

**Solution 2: Use Correct Node IP**
```bash
# If ExternalIP not available, use InternalIP for testing
kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}'

# Or use hostname
kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="Hostname")].address}'
```

**Solution 3: Check kube-proxy**
```bash
# Ensure kube-proxy is running
kubectl get pods -n kube-system -l k8s-app=kube-proxy

# Check logs
kubectl logs -n kube-system -l k8s-app=kube-proxy | grep -i error

# Restart kube-proxy if needed
kubectl delete pods -n kube-system -l k8s-app=kube-proxy
```

**Solution 4: Verify Service Backend**
```bash
# Ensure endpoints exist
kubectl get ep <service-name>

# Test service internally first
kubectl run test --image=curlimages/curl -it --rm -- curl http://<service-name>
```

---

## Issue 6: Intermittent Connection Failures

### Symptoms
```
Some requests succeed, others fail
Random 503 or 504 errors
Inconsistent response times
```

### Diagnostic Steps

**Step 1: Check Pod Health**
```bash
# Are some pods crashing?
kubectl get pods -l app=<label> -w

# Check restart count
kubectl get pods -l app=<label> -o jsonpath='{.items[*].status.containerStatuses[*].restartCount}'

# Check for CrashLoopBackOff or Error
kubectl get pods -l app=<label> | grep -E "CrashLoop|Error"
```

**Step 2: Check Readiness Probes**
```bash
# Are pods failing readiness checks?
kubectl describe pods -l app=<label> | grep -A 5 "Readiness"

# Check events
kubectl get events --field-selector involvedObject.name=<pod-name> | grep Readiness
```

**Step 3: Check Resource Limits**
```bash
# Are pods being OOMKilled or throttled?
kubectl describe pod <pod-name> | grep -A 5 "Last State"

# Check resource usage
kubectl top pods -l app=<label>

# Check limits
kubectl describe pod <pod-name> | grep -A 10 "Limits"
```

**Step 4: Check Endpoints Stability**
```bash
# Watch endpoints for changes
kubectl get ep <service-name> -w

# Endpoints shouldn't change frequently
```

### Solutions

**Solution 1: Fix Readiness Probes**
```yaml
# Increase probe thresholds
readinessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 30  # Increase
  periodSeconds: 10
  failureThreshold: 3      # Increase
  timeoutSeconds: 5        # Increase
```

**Solution 2: Increase Resources**
```yaml
resources:
  requests:
    memory: "256Mi"  # Increase
    cpu: "250m"      # Increase
  limits:
    memory: "512Mi"  # Increase
    cpu: "500m"      # Increase
```

**Solution 3: Add Liveness Probe**
```yaml
# Restart unhealthy pods automatically
livenessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 60
  periodSeconds: 10
```

**Solution 4: Scale Up**
```bash
# More replicas = more resilience
kubectl scale deployment <name> --replicas=5
```

---

## Issue 7: High Latency

### Symptoms
```
Slow response times
Timeouts
High response time in metrics
```

### Diagnostic Steps

**Step 1: Measure Latency**
```bash
# Test from within cluster
kubectl run test --image=curlimages/curl -it --rm -- time curl http://<service-name>

# Test specific pod
POD_IP=$(kubectl get pod <pod-name> -o jsonpath='{.status.podIP}')
kubectl run test --image=curlimages/curl -it --rm -- time curl http://$POD_IP:8080

# Compare service vs direct pod access
```

**Step 2: Check Pod Resources**
```bash
# High CPU = throttling
kubectl top pods -l app=<label>

# Check for throttling
kubectl describe pod <pod-name> | grep -i throttl
```

**Step 3: Check Network Policies**
```bash
# Network policies can add latency
kubectl get networkpolicy

# Temporarily remove to test
kubectl delete networkpolicy <policy-name>
```

**Step 4: Check DNS Latency**
```bash
# Test DNS resolution time
kubectl run test --image=tutum/dnsutils -it --rm -- time nslookup <service-name>

# Should be < 10ms
```

### Solutions

**Solution 1: Use Topology-Aware Routing**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: myservice
  annotations:
    service.kubernetes.io/topology-aware-hints: auto
spec:
  selector:
    app: myapp
  ports:
    - port: 80
```

**Solution 2: Use externalTrafficPolicy: Local**
```yaml
# Reduces hops for LoadBalancer/NodePort
spec:
  externalTrafficPolicy: Local
```

**Solution 3: Scale DNS**
```bash
# More CoreDNS pods = lower DNS latency
kubectl scale deployment/coredns --replicas=5 -n kube-system
```

**Solution 4: Optimize Application**
```bash
# Check application logs for slow queries
kubectl logs <pod-name> | grep -i "slow"

# Enable connection pooling
# Optimize database queries
# Add caching layer
```

---

## Issue 8: Service Returns 503

### Symptoms
```
HTTP 503 Service Unavailable
Backend pods exist but service returns 503
```

### Diagnostic Steps

**Step 1: Check Endpoints**
```bash
kubectl get ep <service-name>

# Should show pod IPs
# If empty = no ready pods
```

**Step 2: Check Pod Readiness**
```bash
kubectl get pods -l app=<label>

# All should be READY 1/1
# If 0/1, check readiness probe
```

**Step 3: Check Application Health**
```bash
# Check logs
kubectl logs -l app=<label> --tail=100

# Common causes:
# - Database connection failed
# - Dependency not ready
# - Configuration error
```

**Step 4: Test Pod Directly**
```bash
POD_IP=$(kubectl get pod <pod-name> -o jsonpath='{.status.podIP}')
kubectl run test --image=curlimages/curl -it --rm -- curl http://$POD_IP:8080

# If this works, service configuration issue
# If fails, application issue
```

### Solutions

**Solution 1: Fix Readiness Probe**
```bash
# Check probe configuration
kubectl describe pod <pod-name> | grep -A 10 Readiness

# Adjust probe
kubectl patch deployment <name> -p '{"spec":{"template":{"spec":{"containers":[{"name":"app","readinessProbe":{"initialDelaySeconds":60}}]}}}}'
```

**Solution 2: Check Dependencies**
```bash
# Is database ready?
kubectl get pods -l app=database

# Can pods reach database?
kubectl exec <pod-name> -- nc -zv database 3306
```

**Solution 3: Check Resource Limits**
```bash
# OOMKilled pods show as ready but fail requests
kubectl describe pod <pod-name> | grep -A 5 "Last State"

# Increase memory limits
kubectl set resources deployment <name> --limits=memory=512Mi
```

**Solution 4: Rolling Restart**
```bash
# Sometimes pods just need a restart
kubectl rollout restart deployment <name>
```

---

## Issue 9: Cross-Namespace Communication Fails

### Symptoms
```
Cannot reach service in different namespace
Connection timeout across namespaces
```

### Diagnostic Steps

**Step 1: Test DNS Resolution**
```bash
# From pod in namespace-a
kubectl exec -it <pod-name> -n namespace-a -- \
  nslookup <service-name>.namespace-b.svc.cluster.local
```

**Step 2: Check Network Policies**
```bash
# List policies in both namespaces
kubectl get networkpolicy -n namespace-a
kubectl get networkpolicy -n namespace-b

# Describe policies
kubectl describe networkpolicy -n namespace-b
```

**Step 3: Test Connectivity**
```bash
kubectl run test -n namespace-a --image=curlimages/curl -it --rm -- \
  curl http://<service-name>.namespace-b:80
```

### Solutions

**Solution 1: Use FQDN**
```bash
# Always use full service name
http://<service>.namespace-b.svc.cluster.local

# Not just
http://<service>  # Only works in same namespace
```

**Solution 2: Allow Network Policy**
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-namespace-a
  namespace: namespace-b
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: namespace-a
    ports:
    - protocol: TCP
      port: 8080
```

**Solution 3: Label Namespaces**
```bash
# Network policies use namespace labels
kubectl label namespace namespace-a name=namespace-a
kubectl label namespace namespace-b name=namespace-b
```

---

## Issue 10: StatefulSet Pods Can't Communicate

### Symptoms
```
Pods in StatefulSet cannot reach each other
Headless service not working
```

### Diagnostic Steps

**Step 1: Check Headless Service**
```bash
kubectl get svc <service-name>

# clusterIP should be "None"
# NAME      TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)
# mysql     ClusterIP   None         <none>        3306/TCP
```

**Step 2: Check DNS for Individual Pods**
```bash
# Should resolve to pod IP
kubectl run test --image=busybox -it --rm -- \
  nslookup mysql-0.mysql.default.svc.cluster.local
```

**Step 3: Check serviceName in StatefulSet**
```bash
kubectl get statefulset <name> -o yaml | grep serviceName

# Should match headless service name
```

### Solutions

**Solution 1: Ensure Headless Service**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: mysql
spec:
  clusterIP: None  # Critical for headless
  selector:
    app: mysql
  ports:
    - port: 3306
```

**Solution 2: Match serviceName**
```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mysql
spec:
  serviceName: mysql  # Must match service name
  replicas: 3
  selector:
    matchLabels:
      app: mysql
```

**Solution 3: Test Individual Pod DNS**
```bash
# Each pod should have DNS
for i in {0..2}; do
  kubectl run test --image=busybox -it --rm -- \
    nslookup mysql-$i.mysql.default.svc.cluster.local
done
```

---

**End of Troubleshooting Playbook**