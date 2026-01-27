# 3-Tier Application Troubleshooting Guide

> **Common issues and solutions for the production 3-tier application**

---

## Table of Contents

- [Quick Diagnostic Commands](#quick-diagnostic-commands)
- [Frontend Issues](#frontend-issues)
- [Backend Issues](#backend-issues)
- [Database Issues](#database-issues)
- [Network Connectivity](#network-connectivity)
- [Resource Problems](#resource-problems)
- [Storage Issues](#storage-issues)
- [Configuration Problems](#configuration-problems)

---

## Quick Diagnostic Commands

### Check Everything

```bash
# Overall status
kubectl get all -n production

# Check pods status
kubectl get pods -n production -o wide

# Check services
kubectl get svc -n production

# Check endpoints
kubectl get ep -n production

# Check recent events
kubectl get events -n production --sort-by='.lastTimestamp' | tail -20

# Check resource usage
kubectl top nodes
kubectl top pods -n production
```

### Pod-Specific Diagnostics

```bash
# View logs
kubectl logs <pod-name> -n production

# Follow logs
kubectl logs -f <pod-name> -n production

# Previous logs (if crashed)
kubectl logs <pod-name> -n production --previous

# Logs from all pods with label
kubectl logs -l app=backend -n production --tail=100

# Describe pod
kubectl describe pod <pod-name> -n production

# Execute commands in pod
kubectl exec -it <pod-name> -n production -- sh

# Port forward for testing
kubectl port-forward <pod-name> -n production 8080:8080
```

---

## Frontend Issues

### Issue 1: LoadBalancer Stuck in Pending

**Symptoms:**
```bash
kubectl get svc frontend -n production
# EXTERNAL-IP shows <pending>
```

**Diagnosis:**
```bash
# Check service events
kubectl describe svc frontend -n production

# Look for error messages like:
# "Error creating load balancer"
# "Quota exceeded"
```

**Solutions:**

**Option 1: Cloud Provider Issues**
```bash
# Verify cloud provider is configured
kubectl get nodes -o jsonpath='{.items[*].spec.providerID}'

# Check cloud provider quota
# AWS: aws elbv2 describe-load-balancers
# GCP: gcloud compute addresses list
# Azure: az network lb list
```

**Option 2: Use NodePort for Testing**
```bash
# Temporarily switch to NodePort
kubectl patch svc frontend -n production -p '{"spec":{"type":"NodePort"}}'

# Get NodePort
NODE_PORT=$(kubectl get svc frontend -n production -o jsonpath='{.spec.ports[0].nodePort}')
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}')

# Access application
curl http://$NODE_IP:$NODE_PORT
```

**Option 3: Install MetalLB (On-Premises)**
```bash
# Install MetalLB
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.0/config/manifests/metallb-native.yaml

# Configure IP pool
cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: production-pool
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

---

### Issue 2: Frontend Can't Reach Backend

**Symptoms:**
```
Browser console shows:
- Failed to fetch
- CORS errors
- Network errors
```

**Diagnosis:**
```bash
# Test from frontend pod
FRONTEND_POD=$(kubectl get pods -n production -l tier=frontend -o jsonpath='{.items[0].metadata.name}')

kubectl exec -it $FRONTEND_POD -n production -- sh

# Inside pod:
wget -O- http://backend:8080
curl http://backend:8080

# Check if backend service exists
nslookup backend.production.svc.cluster.local
```

**Solutions:**

**Check Backend Service:**
```bash
# Verify backend service
kubectl get svc backend -n production

# Check endpoints
kubectl get ep backend -n production
# Should show pod IPs

# If no endpoints, check pod labels
kubectl get pods -l tier=backend -n production --show-labels
kubectl describe svc backend -n production | grep Selector
```

**Check Network Policy:**
```bash
# List network policies
kubectl get networkpolicy -n production

# Describe policy
kubectl describe networkpolicy allow-frontend-to-backend -n production

# Temporarily delete policy to test
kubectl delete networkpolicy allow-frontend-to-backend -n production
# Test connection
# Then recreate policy
```

**Fix Nginx Configuration:**
```bash
# Check nginx config
kubectl get cm frontend-config -n production -o yaml

# Update if needed
kubectl edit cm frontend-config -n production

# Restart frontend pods to reload config
kubectl rollout restart deployment/frontend -n production
```

---

### Issue 3: Frontend Pods CrashLooping

**Symptoms:**
```bash
kubectl get pods -n production
# frontend-xxx  0/1  CrashLoopBackOff
```

**Diagnosis:**
```bash
# Check pod logs
kubectl logs frontend-xxx -n production

# Check previous logs
kubectl logs frontend-xxx -n production --previous

# Describe pod
kubectl describe pod frontend-xxx -n production
```

**Common Causes & Solutions:**

**Cause 1: Nginx Config Error**
```bash
# Test nginx config syntax
kubectl exec -it frontend-xxx -n production -- nginx -t

# Fix ConfigMap
kubectl edit cm frontend-config -n production
```

**Cause 2: Resource Limits Too Low**
```bash
# Check resource usage
kubectl top pod frontend-xxx -n production

# Increase limits
kubectl patch deployment frontend -n production -p '{"spec":{"template":{"spec":{"containers":[{"name":"nginx","resources":{"limits":{"memory":"512Mi"}}}]}}}}'
```

**Cause 3: Volume Mount Issue**
```bash
# Check volumes
kubectl describe pod frontend-xxx -n production | grep -A 10 Volumes

# Verify ConfigMap exists
kubectl get cm frontend-config -n production
```

---

## Backend Issues

### Issue 1: Backend Pods Not Ready

**Symptoms:**
```bash
kubectl get pods -n production
# backend-xxx  0/1  Running  (but not READY)
```

**Diagnosis:**
```bash
# Check readiness probe
kubectl describe pod backend-xxx -n production | grep -A 10 Readiness

# Check logs
kubectl logs backend-xxx -n production

# Test health endpoint
kubectl exec -it backend-xxx -n production -- curl localhost:8080/health
```

**Solutions:**

**Fix Readiness Probe:**
```bash
# If probe path is wrong
kubectl patch deployment backend -n production -p '{"spec":{"template":{"spec":{"containers":[{"name":"api","readinessProbe":{"httpGet":{"path":"/"}}}]}}}}'

# Increase initial delay
kubectl patch deployment backend -n production -p '{"spec":{"template":{"spec":{"containers":[{"name":"api","readinessProbe":{"initialDelaySeconds":30}}]}}}}'
```

**Check Dependencies:**
```bash
# Can backend reach database?
kubectl exec -it backend-xxx -n production -- sh
nc -zv postgres.production.svc.cluster.local 5432

# Can backend reach Redis?
nc -zv redis.production.svc.cluster.local 6379
```

---

### Issue 2: Backend Can't Connect to Database

**Symptoms:**
```
Backend logs show:
- Connection timeout
- Connection refused
- Authentication failed
```

**Diagnosis:**
```bash
# Check database pods
kubectl get pods -l app=postgres -n production

# Check database service
kubectl get svc postgres -n production

# Test DNS from backend
kubectl exec -it backend-xxx -n production -- sh
nslookup postgres.production.svc.cluster.local

# Test connection
nc -zv postgres 5432
```

**Solutions:**

**Check Service and Endpoints:**
```bash
# Verify headless service
kubectl get svc postgres -n production
# clusterIP should be "None"

# Check endpoints
kubectl get ep postgres -n production
# Should show StatefulSet pod IPs

# If no endpoints, check StatefulSet
kubectl get statefulset postgres -n production
```

**Verify Credentials:**
```bash
# Check secret exists
kubectl get secret backend-secret -n production

# Verify password in secret
kubectl get secret backend-secret -n production -o jsonpath='{.data.DB_PASSWORD}' | base64 -d

# Check if backend is using correct secret
kubectl describe pod backend-xxx -n production | grep -A 5 "Environment Variables from"
```

**Check Network Policy:**
```bash
# Verify network policy allows backend → database
kubectl get networkpolicy allow-backend-to-database -n production

# Test without network policy
kubectl delete networkpolicy allow-backend-to-database -n production
# Test connection
# Recreate policy if needed
```

---

### Issue 3: Backend High CPU/Memory

**Symptoms:**
```bash
kubectl top pods -n production
# backend-xxx shows high CPU/memory usage
```

**Diagnosis:**
```bash
# Check resource usage
kubectl top pod backend-xxx -n production

# Check limits
kubectl describe pod backend-xxx -n production | grep -A 10 Limits

# Check for memory leaks in logs
kubectl logs backend-xxx -n production | grep -i "memory\|oom"

# Check events for OOMKilled
kubectl get events -n production | grep OOMKilled
```

**Solutions:**

**Increase Resources:**
```bash
# Increase limits
kubectl patch deployment backend -n production -p '{
  "spec":{
    "template":{
      "spec":{
        "containers":[{
          "name":"api",
          "resources":{
            "requests":{"cpu":"500m","memory":"512Mi"},
            "limits":{"cpu":"1000m","memory":"1Gi"}
          }
        }]
      }
    }
  }
}'
```

**Scale Horizontally:**
```bash
# Increase replicas
kubectl scale deployment backend -n production --replicas=10

# Or let HPA handle it
kubectl get hpa backend-hpa -n production
```

**Optimize Application:**
```bash
# Check connection pool settings
kubectl get cm backend-config -n production -o yaml

# Increase pool limits if needed
kubectl patch cm backend-config -n production -p '{"data":{"DB_POOL_MAX":"20"}}'
kubectl rollout restart deployment/backend -n production
```

---

## Database Issues

### Issue 1: StatefulSet Pods Stuck in Pending

**Symptoms:**
```bash
kubectl get pods -n production
# postgres-0  0/1  Pending
```

**Diagnosis:**
```bash
# Describe pod
kubectl describe pod postgres-0 -n production

# Common messages:
# "no persistent volumes available"
# "insufficient cpu/memory"
```

**Solutions:**

**PVC Issue:**
```bash
# Check PVC status
kubectl get pvc -n production

# If no PVs available, create StorageClass
kubectl get storageclass

# For testing, create local PV (not for production!)
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: postgres-pv-0
spec:
  capacity:
    storage: 100Gi
  accessModes:
  - ReadWriteOnce
  hostPath:
    path: /data/postgres-0
EOF
```

**Resource Issue:**
```bash
# Check node resources
kubectl top nodes

# If insufficient, scale down other apps or add nodes

# Or reduce database resource requests
kubectl patch statefulset postgres -n production -p '{
  "spec":{
    "template":{
      "spec":{
        "containers":[{
          "name":"postgres",
          "resources":{
            "requests":{"cpu":"250m","memory":"512Mi"}
          }
        }]
      }
    }
  }
}'
```

---

### Issue 2: Database Connection Refused

**Symptoms:**
```
Backend logs:
- Connection refused to postgres
- Timeout connecting to database
```

**Diagnosis:**
```bash
# Check if postgres pods are running
kubectl get pods -l app=postgres -n production

# Check if postgres is listening
kubectl exec -it postgres-0 -n production -- pg_isready -U postgres

# Test connection from backend pod
kubectl exec -it backend-xxx -n production -- sh
telnet postgres.production.svc.cluster.local 5432
```

**Solutions:**

**Check Pod Status:**
```bash
# If pod is not ready
kubectl describe pod postgres-0 -n production

# Check logs
kubectl logs postgres-0 -n production

# Common issues in logs:
# - Permission denied on /var/lib/postgresql/data
# - Port already in use
# - Configuration error
```

**Fix Headless Service:**
```bash
# Verify headless service
kubectl get svc postgres -n production -o yaml

# clusterIP must be "None"
# If not, update:
kubectl patch svc postgres -n production -p '{"spec":{"clusterIP":"None"}}'
```

**DNS Resolution:**
```bash
# Test DNS
kubectl run -it --rm debug --image=busybox -n production -- \
  nslookup postgres.production.svc.cluster.local

# Should return pod IPs, not a ClusterIP
```

---

### Issue 3: Data Loss After Pod Restart

**Symptoms:**
```
Database is empty after pod restart
All data disappeared
```

**Diagnosis:**
```bash
# Check if PVC exists
kubectl get pvc -n production

# Check PVC status
kubectl describe pvc postgres-data-postgres-0 -n production

# Verify PV
kubectl get pv
```

**Solutions:**

**Check Volume Mount:**
```bash
# Verify volume is mounted
kubectl exec -it postgres-0 -n production -- df -h | grep postgresql

# Should show persistent volume, not emptyDir
```

**Check PGDATA Path:**
```bash
# Verify PGDATA is set correctly
kubectl exec -it postgres-0 -n production -- env | grep PGDATA

# Should be: /var/lib/postgresql/data/pgdata
```

**Restore from Backup:**
```bash
# If you have backups
kubectl exec -it postgres-0 -n production -- sh

# Inside pod:
pg_restore -U postgres -d ecommerce /backup/latest.dump
```

---

## Network Connectivity

### Issue 1: Pods Can't Talk to Each Other

**Symptoms:**
```
Connection timeout between pods
Pods can't resolve service names
```

**Diagnosis:**
```bash
# Test DNS
kubectl run -it --rm debug --image=busybox -n production -- \
  nslookup backend.production.svc.cluster.local

# Test connectivity
kubectl run -it --rm debug --image=nicolaka/netshoot -n production -- \
  curl http://backend:8080
```

**Solutions:**

**Check CoreDNS:**
```bash
# Check CoreDNS pods
kubectl get pods -n kube-system -l k8s-app=kube-dns

# If not running, check logs
kubectl logs -n kube-system -l k8s-app=kube-dns

# Restart CoreDNS
kubectl rollout restart deployment/coredns -n kube-system
```

**Check Network Policies:**
```bash
# List all network policies
kubectl get networkpolicy -n production

# If too restrictive, temporarily delete
kubectl delete networkpolicy -n production --all
# Test connectivity
# Then recreate policies
```

**Check kube-proxy:**
```bash
# Verify kube-proxy is running
kubectl get pods -n kube-system -l k8s-app=kube-proxy

# Check logs for errors
kubectl logs -n kube-system -l k8s-app=kube-proxy | tail -50
```

---

## Resource Problems

### Issue 1: Pods Being Evicted

**Symptoms:**
```bash
kubectl get pods -n production
# STATUS: Evicted
```

**Diagnosis:**
```bash
# Check pod description
kubectl describe pod <evicted-pod> -n production

# Common reasons:
# - Node out of memory
# - Node out of disk space
# - Exceeded resource quota
```

**Solutions:**

**Node Resources:**
```bash
# Check node resources
kubectl top nodes
kubectl describe nodes

# If disk full, clean up
# If memory full, scale down or add nodes
```

**Resource Quota:**
```bash
# Check quota usage
kubectl describe resourcequota production-quota -n production

# If exceeded, either:
# 1. Increase quota
kubectl edit resourcequota production-quota -n production

# 2. Or scale down pods
kubectl scale deployment backend -n production --replicas=3
```

---

### Issue 2: HPA Not Scaling

**Symptoms:**
```
HPA exists but pods not scaling
Always at min replicas
```

**Diagnosis:**
```bash
# Check HPA status
kubectl get hpa -n production

# Describe HPA
kubectl describe hpa backend-hpa -n production

# Check metrics server
kubectl top nodes
kubectl top pods -n production
```

**Solutions:**

**Install Metrics Server:**
```bash
# If metrics not available
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# For testing (insecure)
kubectl patch deployment metrics-server -n kube-system -p '{"spec":{"template":{"spec":{"containers":[{"name":"metrics-server","args":["--kubelet-insecure-tls"]}]}}}}'
```

**Check Resource Metrics:**
```bash
# Verify pods have resource requests set
kubectl get deployment backend -n production -o yaml | grep -A 5 resources

# HPA needs resources.requests to calculate percentage
```

---

## Storage Issues

### Issue 1: PVC Stuck in Pending

**Symptoms:**
```bash
kubectl get pvc -n production
# STATUS: Pending
```

**Diagnosis:**
```bash
# Describe PVC
kubectl describe pvc postgres-data-postgres-0 -n production

# Common errors:
# "no persistent volumes available"
# "storageclass not found"
```

**Solutions:**

**Create StorageClass:**
```bash
# Check available storage classes
kubectl get storageclass

# Create default storage class (example for local testing)
cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: standard
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
EOF
```

**Manual PV Creation (Testing Only):**
```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: postgres-pv-0
spec:
  capacity:
    storage: 100Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: standard
  hostPath:
    path: /data/postgres-0
EOF
```

---

## Configuration Problems

### Issue 1: ConfigMap Changes Not Applied

**Symptoms:**
```
Updated ConfigMap but pods still use old values
Environment variables not updating
```

**Solution:**
```bash
# ConfigMap updates don't auto-restart pods
# Must restart deployment
kubectl rollout restart deployment/backend -n production

# Or delete pods (deployment will recreate)
kubectl delete pods -l app=backend -n production

# Volume-mounted ConfigMaps update automatically (eventually)
# But environment variables NEVER update until pod restart
```

---

### Issue 2: Secret Not Found

**Symptoms:**
```
Pod logs: "secret not found"
Pod stuck in CreateContainerConfigError
```

**Diagnosis:**
```bash
# Check if secret exists
kubectl get secret backend-secret -n production

# Describe pod
kubectl describe pod backend-xxx -n production
```

**Solution:**
```bash
# Create missing secret
kubectl create secret generic backend-secret \
  --from-literal=DB_PASSWORD=password \
  -n production

# Or apply from file
kubectl apply -f backend-secret.yaml
```

---

## Emergency Procedures

### Complete Reset

```bash
# Delete all resources (WARNING: DESTRUCTIVE)
kubectl delete namespace production

# Recreate
kubectl apply -f manifests/complete-3-tier-app.yaml

# Wait for deployment
kubectl wait --for=condition=ready pod -l tier=frontend -n production --timeout=300s
```

### Rollback Deployment

```bash
# View rollout history
kubectl rollout history deployment/backend -n production

# Rollback to previous
kubectl rollout undo deployment/backend -n production

# Rollback to specific revision
kubectl rollout undo deployment/backend -n production --to-revision=2
```

### Force Delete Stuck Pod

```bash
# Graceful delete
kubectl delete pod postgres-0 -n production --grace-period=30

# Force delete (last resort)
kubectl delete pod postgres-0 -n production --grace-period=0 --force
```

---

**End of Troubleshooting Guide**
