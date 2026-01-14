# Day 2-3: Kubernetes Architecture 🏗️

## 🎯 Overview
Understanding how Kubernetes components work together — from `kubectl` to running pods.


**Duration:** 2 Days  
**Difficulty:** Beginner-Intermediate  
**Status:** ✅ Completed

## 📋 What's Covered

### Control Plane Components
- **kube-apiserver** – The Gateway  
- **etcd** – The Database  
- **kube-scheduler** – Pod Placement  
- **kube-controller-manager** – State Reconciliation  

### Worker Node Components
- **kubelet** – Node Agent  
- **kube-proxy** – Network Proxy  
- **Container Runtime** – Container Execution  

## 🚀 Quick Start

### Setup Cluster
```bash
# Option 1: Minikube
minikube start --nodes 2 --driver=docker

# Option 2: Kind
kind create cluster --name cka-cluster


### Explore Components
```bash
# View control plane
kubectl get pods -n kube-system

# Check cluster info
kubectl cluster-info
```

## 📚 Files in This Directory

- **[GUIDE.md](./GUIDE.md)** - Complete step-by-step guide with all commands
- **[interview-questions.md](./interview-questions.md)** - Common interview Q&A
- **diagrams/** - Architecture diagrams

## 💡 Key Learnings

1. API Server is the ONLY component that talks to etcd
2. Controllers continuously reconcile desired vs actual state
3. Scheduler can be bypassed with nodeName
4. etcd backup is CRITICAL (know the commands!)

## 🎓 CKA Exam Tips

**Must Memorize:**
```bash
# etcd backup
ETCDCTL_API=3 etcdctl snapshot save /backup/etcd.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
```

## ✅ Checklist

- [x] Setup cluster
- [x] Explored all components
- [x] Deployed test application
- [x] Practiced etcd backup
- [x] Traced request flow
- [x] Completed experiments

## 🔗 Resources

- [Kubernetes Architecture Docs](https://kubernetes.io/docs/concepts/architecture/)
- [etcd Documentation](https://etcd.io/docs/)

---

**Next:** [Day 4-5: Pods Deep Dive](../Day-04-05-Pods) →
