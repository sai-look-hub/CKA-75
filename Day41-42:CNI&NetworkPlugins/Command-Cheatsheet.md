# 📋 Command Cheatsheet: CNI & Network Plugins

---

## 🔍 CNI Status & Information

```bash
# Check which CNI is installed
ls /etc/cni/net.d/
cat /etc/cni/net.d/*.conf

# Check CNI binaries
ls /opt/cni/bin/

# Check node pod CIDR
kubectl get nodes -o jsonpath='{.items[*].spec.podCIDR}'

# Get service CIDR
kubectl cluster-info dump | grep -m 1 service-cluster-ip-range

# Check kubelet CNI config
ps aux | grep kubelet | grep -E 'cni|network'
```

---

## 🚀 Flannel Commands

```bash
# Install Flannel
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

# Check Flannel pods
kubectl get pods -n kube-flannel

# Check Flannel config
kubectl get configmap -n kube-flannel kube-flannel-cfg -o yaml

# Get Flannel logs
kubectl logs -n kube-flannel <flannel-pod>

# Check Flannel DaemonSet
kubectl get daemonset -n kube-flannel

# Restart Flannel
kubectl rollout restart daemonset -n kube-flannel kube-flannel-ds
```

---

## 🛡️ Calico Commands

```bash
# Install Calico
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/tigera-operator.yaml
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/custom-resources.yaml

# Check Calico status
kubectl get tigerastatus

# Check Calico pods
kubectl get pods -n calico-system

# Install calicoctl
curl -L https://github.com/projectcalico/calico/releases/download/v3.27.0/calicoctl-linux-amd64 -o calicoctl
chmod +x calicoctl
sudo mv calicoctl /usr/local/bin/

# Check Calico node status
sudo calicoctl node status

# View IP pools
calicoctl get ippool -o wide

# View Calico nodes
calicoctl get nodes

# Check BGP peer status
sudo calicoctl node status

# Get workload endpoints
calicoctl get workloadendpoints -A

# View Calico configuration
calicoctl get felixconfiguration default -o yaml
```

---

## 🌊 Weave Commands

```bash
# Install Weave
kubectl apply -f https://github.com/weaveworks/weave/releases/download/v2.8.1/weave-daemonset-k8s.yaml

# Check Weave pods
kubectl get pods -n kube-system -l name=weave-net

# Check Weave status
kubectl exec -n kube-system weave-net-<xxx> -c weave -- /home/weave/weave --local status

# View Weave connections
kubectl exec -n kube-system weave-net-<xxx> -c weave -- /home/weave/weave --local status connections

# Check Weave logs
kubectl logs -n kube-system weave-net-<xxx> -c weave
```

---

## 🔵 Cilium Commands

```bash
# Install Cilium CLI
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
curl -L --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-amd64.tar.gz
tar xzvfC cilium-linux-amd64.tar.gz /usr/local/bin
rm cilium-linux-amd64.tar.gz

# Install Cilium
cilium install --version 1.15.0

# Check Cilium status
cilium status

# Detailed status
cilium status --wait

# Run connectivity test
cilium connectivity test

# Check Cilium pods
kubectl get pods -n kube-system -l k8s-app=cilium

# Enable Hubble (observability)
cilium hubble enable

# Port-forward Hubble
cilium hubble port-forward &

# Install Hubble CLI
HUBBLE_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/hubble/master/stable.txt)
curl -L --remote-name-all https://github.com/cilium/hubble/releases/download/$HUBBLE_VERSION/hubble-linux-amd64.tar.gz
tar xzvfC hubble-linux-amd64.tar.gz /usr/local/bin
rm hubble-linux-amd64.tar.gz

# Observe traffic
hubble observe

# Observe specific pod
hubble observe --pod <pod-name>

# Observe flows
hubble observe --type drop

# Get Cilium endpoint list
kubectl get ciliumendpoints -A
```

---

## 🔐 Network Policy Commands

```bash
# List network policies
kubectl get networkpolicy -A

# Describe network policy
kubectl describe networkpolicy <policy-name>

# Create deny-all ingress
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-ingress
spec:
  podSelector: {}
  policyTypes:
  - Ingress
EOF

# Create allow policy
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
EOF

# Delete network policy
kubectl delete networkpolicy <policy-name>

# Check policies affecting a pod
kubectl describe pod <pod-name> | grep -A 10 "Network Policy"
```

---

## 🧪 Network Testing

```bash
# Create test pods
kubectl run test-1 --image=busybox --command -- sleep 3600
kubectl run test-2 --image=nginx

# Get pod IPs
kubectl get pods -o wide

# Test connectivity
kubectl exec test-1 -- ping -c 3 <test-2-ip>

# Test DNS
kubectl exec test-1 -- nslookup kubernetes.default

# Test service connectivity
kubectl exec test-1 -- wget -qO- http://<service-name>

# Advanced network testing pod
kubectl run netshoot --rm -it --image=nicolaka/netshoot -- /bin/bash

# Inside netshoot:
# ping <ip>
# curl <url>
# nslookup <hostname>
# traceroute <ip>
# tcpdump -i any
```

---

## 🔍 Debugging Network Issues

```bash
# Check pod networking
kubectl get pods -o wide

# Describe pod for network info
kubectl describe pod <pod-name>

# Check pod network namespace
kubectl exec <pod> -- ip addr
kubectl exec <pod> -- ip route

# Check DNS resolution
kubectl exec <pod> -- nslookup kubernetes.default

# Check service endpoints
kubectl get endpoints <service-name>

# Test service connectivity
kubectl run curl --image=curlimages/curl -it --rm -- curl http://<service>:<port>

# Check kube-proxy
kubectl get pods -n kube-system -l k8s-app=kube-proxy
kubectl logs -n kube-system <kube-proxy-pod>

# Check CoreDNS
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl logs -n kube-system <coredns-pod>

# Get iptables rules (on node)
sudo iptables-save | grep <service-name>

# Check routes (on node)
ip route
```

---

## 📊 Performance Testing

```bash
# Install iperf3 pods
kubectl run iperf-server --image=networkstatic/iperf3 -- iperf3 -s
kubectl run iperf-client --image=networkstatic/iperf3 -- sleep 3600

# Get server IP
SERVER_IP=$(kubectl get pod iperf-server -o jsonpath='{.status.podIP}')

# Run bandwidth test
kubectl exec iperf-client -- iperf3 -c $SERVER_IP -t 30

# Test latency
kubectl exec iperf-client -- ping -c 100 $SERVER_IP

# Parallel streams
kubectl exec iperf-client -- iperf3 -c $SERVER_IP -P 10 -t 30
```

---

## 🛠️ CNI Troubleshooting

```bash
# Check CNI plugin logs
kubectl logs -n <cni-namespace> <cni-pod>

# Restart CNI
kubectl rollout restart daemonset -n <cni-namespace> <cni-daemonset>

# Check CNI configuration
cat /etc/cni/net.d/*.conf

# Verify CNI binaries
ls -la /opt/cni/bin/

# Check kubelet CNI directory
ls -la /var/lib/cni/

# Remove CNI configuration (for reinstall)
sudo rm -f /etc/cni/net.d/*

# Restart kubelet
sudo systemctl restart kubelet

# Check kubelet logs
sudo journalctl -u kubelet | grep -i cni
```

---

## 💡 Useful One-Liners

```bash
# Get all pod IPs
kubectl get pods -A -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.podIP}{"\n"}{end}'

# Count pods per node
kubectl get pods -A -o json | jq '.items | group_by(.spec.nodeName) | .[] | {node: .[0].spec.nodeName, count: length}'

# Find pods without IP
kubectl get pods -A -o json | jq -r '.items[] | select(.status.podIP==null) | "\(.metadata.namespace)/\(.metadata.name)"'

# Check network policies per namespace
kubectl get networkpolicy -A --no-headers | awk '{print $1}' | sort | uniq -c

# Test connectivity to all pods
for pod in $(kubectl get pods -o name); do
  echo "Testing $pod"
  kubectl exec ${pod#pod/} -- ping -c 1 8.8.8.8 > /dev/null 2>&1 && echo "✓" || echo "✗"
done
```

---

**Pro Tip:** Create aliases for frequently used commands!
