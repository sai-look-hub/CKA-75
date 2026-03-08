# 📋 Command Cheatsheet: Week 7-8 Project

## 🚀 Quick Start

```bash
# Deploy entire application
kubectl apply -f ecommerce-complete.yaml

# Check deployment
kubectl get all -n ecommerce

# Get Ingress IP
kubectl get ingress -n ecommerce
```

## 🔍 Service Testing

```bash
# Test frontend
curl -H "Host: ecommerce.example.com" http://<INGRESS-IP>/

# Test backend API
curl -H "Host: ecommerce.example.com" http://<INGRESS-IP>/api/

# Test admin
curl -H "Host: ecommerce.example.com" http://<INGRESS-IP>/admin/
```

## 🌐 Network Connectivity

```bash
# Get pod names
FRONTEND_POD=$(kubectl get pod -n ecommerce -l tier=frontend -o jsonpath='{.items[0].metadata.name}')
BACKEND_POD=$(kubectl get pod -n ecommerce -l tier=backend -o jsonpath='{.items[0].metadata.name}')

# Test Frontend → Backend
kubectl exec -n ecommerce $FRONTEND_POD -- curl http://backend:8080

# Test Backend → Database
kubectl exec -n ecommerce $BACKEND_POD -- nc -zv database 5432

# Test DNS
kubectl exec -n ecommerce $FRONTEND_POD -- nslookup backend
```

## 🔒 Network Policy Testing

```bash
# List policies
kubectl get networkpolicy -n ecommerce

# Describe policy
kubectl describe networkpolicy <policy> -n ecommerce

# Test blocked connection (Frontend → Database)
kubectl exec -n ecommerce $FRONTEND_POD -- timeout 5 nc -zv database 5432
# Should timeout!
```

## 🧪 Debugging

```bash
# Use debug pod
kubectl exec -n ecommerce netshoot -it -- bash

# Inside netshoot:
curl http://backend:8080
nslookup frontend
ping database
nc -zv backend 8080
```

## 📊 Monitoring

```bash
# Check all pods
kubectl get pods -n ecommerce -o wide

# Check endpoints
kubectl get endpoints -n ecommerce

# Check Ingress
kubectl describe ingress -n ecommerce

# Check logs
kubectl logs -n ecommerce deployment/backend
kubectl logs -n ecommerce deployment/frontend
```

## 🔧 Troubleshooting

```bash
# CoreDNS check
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl logs -n kube-system -l k8s-app=kube-dns

# Ingress controller check
kubectl get pods -n ingress-nginx
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller

# Network policy debugging
kubectl get networkpolicy -n ecommerce
kubectl delete networkpolicy <policy> -n ecommerce  # Temporary test
```

## 💡 Useful One-Liners

```bash
# Test all services
for svc in frontend backend admin database; do
  echo "Testing $svc..."
  kubectl exec -n ecommerce netshoot -- timeout 3 curl -s http://$svc || echo "Failed"
done

# Get all IPs
kubectl get pods -n ecommerce -o custom-columns=NAME:.metadata.name,IP:.status.podIP

# Check network policy coverage
kubectl get pods -n ecommerce --show-labels
```
