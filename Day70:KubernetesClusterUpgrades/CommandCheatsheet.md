# 📋 Command Cheatsheet: Cluster Upgrades - Day 71

## 🔍 Check Version Information
```bash
# Cluster version
kubectl version --short

# Node versions
kubectl get nodes
kubectl get nodes -o wide

# Component versions
kubectl get pods -n kube-system -o yaml | grep "image:"

# kubeadm version
kubeadm version
```

## 💾 Backup Commands
```bash
# Backup etcd
ETCDCTL_API=3 etcdctl snapshot save backup.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# Verify backup
ETCDCTL_API=3 etcdctl snapshot status backup.db

# Restore backup
ETCDCTL_API=3 etcdctl snapshot restore backup.db \
  --data-dir /var/lib/etcd-restore
```

## 🎛️ Control Plane Upgrade
```bash
# Check available versions
apt update
apt-cache madison kubeadm | grep 1.29

# Upgrade kubeadm
apt-mark unhold kubeadm
apt-get update && apt-get install -y kubeadm=1.29.0-00
apt-mark hold kubeadm

# Plan upgrade
kubeadm upgrade plan

# Apply upgrade
kubeadm upgrade apply v1.29.0

# Drain node
kubectl drain <node> --ignore-daemonsets --delete-emptydir-data

# Upgrade kubelet
apt-mark unhold kubelet kubectl
apt-get update && apt-get install -y kubelet=1.29.0-00 kubectl=1.29.0-00
apt-mark hold kubelet kubectl

systemctl daemon-reload
systemctl restart kubelet

# Uncordon node
kubectl uncordon <node>
```

## 💻 Worker Node Upgrade
```bash
# Drain node
kubectl drain <node> --ignore-daemonsets --delete-emptydir-data --force

# On worker node:
apt-mark unhold kubeadm kubelet kubectl
apt-get update && apt-get install -y \
  kubeadm=1.29.0-00 \
  kubelet=1.29.0-00 \
  kubectl=1.29.0-00
apt-mark hold kubeadm kubelet kubectl

kubeadm upgrade node

systemctl daemon-reload
systemctl restart kubelet

# Uncordon
kubectl uncordon <node>
```

## ✅ Validation Commands
```bash
# Check nodes
kubectl get nodes

# Check pods
kubectl get pods -A

# Component status
kubectl get componentstatuses

# System pods
kubectl get pods -n kube-system

# Check for errors
kubectl get events -A | grep -i error

# Resource usage
kubectl top nodes
kubectl top pods -A
```

## 💡 Useful One-Liners
```bash
# List all node versions
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.nodeInfo.kubeletVersion}{"\n"}{end}'

# Check if all nodes upgraded
kubectl get nodes -o json | jq '.items[].status.nodeInfo.kubeletVersion'

# Count pods per node
kubectl get pods -A -o wide | awk '{print $8}' | sort | uniq -c
```
