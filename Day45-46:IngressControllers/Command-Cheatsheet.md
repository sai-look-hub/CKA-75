# 📋 Command Cheatsheet: Ingress Controllers

---

## 🔍 Ingress Information

```bash
# List ingresses
kubectl get ingress
kubectl get ing

# Describe ingress
kubectl describe ingress <ingress-name>

# Get ingress in YAML
kubectl get ing <ingress-name> -o yaml

# Get ingress hosts
kubectl get ing -o custom-columns=\
NAME:.metadata.name,\
HOSTS:.spec.rules[*].host

# Get ingress with addresses
kubectl get ing -o wide
```

---

## 🎮 NGINX Ingress Controller

```bash
# Install with Helm
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm install ingress-nginx ingress-nginx/ingress-nginx -n ingress-nginx --create-namespace

# Install with manifests
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.0/deploy/static/provider/cloud/deploy.yaml

# Check controller pods
kubectl get pods -n ingress-nginx

# Check controller service
kubectl get svc -n ingress-nginx

# Get external IP
kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

# Controller logs
kubectl logs -n ingress-nginx <controller-pod>

# Follow logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller -f

# Restart controller
kubectl rollout restart deployment -n ingress-nginx ingress-nginx-controller
```

---

## 🛠️ Ingress Operations

```bash
# Create ingress
kubectl create ingress simple --rule="example.com/path=service:80"

# Create with TLS
kubectl create ingress tls-example \
  --rule="example.com/*=web:80,tls=example-tls"

# Update ingress
kubectl edit ingress <ingress-name>

# Delete ingress
kubectl delete ingress <ingress-name>

# Apply from file
kubectl apply -f ingress.yaml

# Dry run
kubectl apply -f ingress.yaml --dry-run=client
```

---

## 🔒 TLS/Certificate Management

```bash
# Create TLS secret from files
kubectl create secret tls my-tls-secret \
  --cert=tls.crt \
  --key=tls.key

# Create self-signed cert
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt \
  -subj "/CN=example.com"

# View TLS secret
kubectl get secret <tls-secret> -o yaml

# Check certificate expiry
kubectl get secret <tls-secret> -o jsonpath='{.data.tls\.crt}' | \
  base64 -d | openssl x509 -noout -enddate

# List all TLS secrets
kubectl get secrets -o json | \
  jq -r '.items[] | select(.type=="kubernetes.io/tls") | .metadata.name'
```

---

## 📜 cert-manager Commands

```bash
# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.0/cert-manager.yaml

# Check cert-manager
kubectl get pods -n cert-manager

# Create ClusterIssuer
kubectl apply -f cluster-issuer.yaml

# List issuers
kubectl get clusterissuer
kubectl get issuer

# List certificates
kubectl get certificate
kubectl get cert

# Describe certificate
kubectl describe certificate <cert-name>

# Check certificate status
kubectl get cert <cert-name> -o jsonpath='{.status.conditions[0].message}'

# Force certificate renewal
kubectl delete secret <cert-secret>
# cert-manager will recreate

# cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager -f
```

---

## 🧪 Testing Ingress

```bash
# Get ingress IP
INGRESS_IP=$(kubectl get ing <ingress> -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Test HTTP
curl http://$INGRESS_IP/

# Test with Host header
curl -H "Host: example.com" http://$INGRESS_IP/

# Test HTTPS (insecure)
curl -k https://$INGRESS_IP/

# Test HTTPS with Host
curl -k -H "Host: example.com" https://$INGRESS_IP/

# Check response headers
curl -I http://$INGRESS_IP/

# Test specific path
curl http://$INGRESS_IP/api/test

# Verbose output
curl -v http://$INGRESS_IP/
```

---

## 📊 Monitoring & Debugging

```bash
# Check ingress events
kubectl get events --field-selector involvedObject.name=<ingress>

# Check backend service
kubectl get svc <backend-service>
kubectl get endpoints <backend-service>

# Test backend directly
kubectl run test --rm -it --image=busybox -- \
  wget -qO- http://<service-name>

# Check ingress class
kubectl get ingressclass

# Describe ingress class
kubectl describe ingressclass nginx

# Check controller config
kubectl get cm -n ingress-nginx ingress-nginx-controller -o yaml

# Check controller metrics
kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller-metrics 10254:10254
curl http://localhost:10254/metrics
```

---

## 🔍 Troubleshooting Commands

```bash
# Check if ingress has address
kubectl get ing <ingress> -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

# Check ingress rules
kubectl get ing <ingress> -o jsonpath='{.spec.rules[*]}'

# Check backend service exists
kubectl get svc <backend-service>

# Check pods behind service
kubectl get endpoints <backend-service>

# Verify pod labels match service selector
kubectl get pods -l app=<label>

# Check ingress controller is running
kubectl get pods -n ingress-nginx -l app.kubernetes.io/component=controller

# Exec into controller pod
kubectl exec -it -n ingress-nginx <controller-pod> -- /bin/bash

# Check nginx config in controller
kubectl exec -n ingress-nginx <controller-pod> -- cat /etc/nginx/nginx.conf

# Test from inside cluster
kubectl run test --rm -it --image=nicolaka/netshoot -- bash
# Then: curl http://<ingress-ip>
```

---

## 💡 Useful One-Liners

```bash
# List all ingresses with hosts
kubectl get ing -A -o custom-columns=\
NAMESPACE:.metadata.namespace,\
NAME:.metadata.name,\
HOSTS:.spec.rules[*].host,\
ADDRESS:.status.loadBalancer.ingress[0].ip

# Find ingresses without TLS
kubectl get ing -A -o json | \
  jq -r '.items[] | select(.spec.tls==null) | "\(.metadata.namespace)/\(.metadata.name)"'

# Count ingresses per namespace
kubectl get ing -A --no-headers | awk '{print $1}' | sort | uniq -c

# Get all TLS secrets used by ingresses
kubectl get ing -A -o json | \
  jq -r '.items[].spec.tls[]?.secretName' | sort -u

# Check which ingresses use specific service
kubectl get ing -A -o json | \
  jq -r --arg svc "my-service" '.items[] | 
    select(.spec.rules[].http.paths[].backend.service.name==$svc) | 
    "\(.metadata.namespace)/\(.metadata.name)"'

# List all ingress annotations
kubectl get ing <ingress> -o jsonpath='{.metadata.annotations}'
```

---

**Pro Tip:** Set up aliases for common ingress operations!

```bash
alias king='kubectl get ingress'
alias king-watch='kubectl get ingress -w'
alias king-yaml='kubectl get ingress -o yaml'
```
