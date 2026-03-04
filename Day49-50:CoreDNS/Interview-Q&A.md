# 🎤 Interview Q&A: CoreDNS

## Q1: What is CoreDNS and how does it work in Kubernetes?

**Answer:**

CoreDNS is the DNS server for Kubernetes, handling service discovery and name resolution.

**How it works:**
1. Pod needs to resolve "backend-service"
2. Checks /etc/resolv.conf → nameserver 10.96.0.10 (CoreDNS)
3. Query sent to CoreDNS
4. CoreDNS kubernetes plugin checks services
5. Returns ClusterIP
6. Pod connects

**Key features:**
- Service discovery
- Plugin-based architecture
- Caching for performance
- Upstream forwarding for external domains

---

## Q2: Explain DNS naming conventions in Kubernetes.

**Answer:**

**Service DNS Format:**
`<service>.<namespace>.svc.<cluster-domain>`

**Examples:**
```
backend (same namespace, short)
backend.default (namespace-qualified)
backend.default.svc (service-qualified)
backend.default.svc.cluster.local (FQDN)
```

**Search domains** in /etc/resolv.conf:
```
search default.svc.cluster.local svc.cluster.local cluster.local
```

This allows short names to work!

---

## Q3: What are the main CoreDNS plugins and their purposes?

**Answer:**

**1. kubernetes** - Service discovery
**2. cache** - Performance (caches responses)
**3. forward** - Upstream DNS for external domains
**4. errors** - Error logging
**5. health** - Health check endpoint
**6. ready** - Readiness endpoint
**7. prometheus** - Metrics

**Example Corefile:**
```
.:53 {
    errors
    kubernetes cluster.local {
        pods insecure
    }
    forward . 8.8.8.8
    cache 30
}
```

---

## Q4: How do you troubleshoot DNS resolution issues?

**Answer:**

**Steps:**

1. **Check CoreDNS pods:**
```bash
kubectl get pods -n kube-system -l k8s-app=kube-dns
```

2. **Check service exists:**
```bash
kubectl get svc <service>
kubectl get endpoints <service>
```

3. **Test resolution:**
```bash
kubectl exec <pod> -- nslookup <service>
```

4. **Check CoreDNS logs:**
```bash
kubectl logs -n kube-system -l k8s-app=kube-dns
```

5. **Verify config:**
```bash
kubectl get cm coredns -n kube-system -o yaml
```

**Common issues:**
- Service doesn't exist
- Wrong namespace
- CoreDNS pods not running
- Network policy blocking port 53

---

## Q5: What are DNS policies in Kubernetes?

**Answer:**

**Four DNS policies:**

**1. ClusterFirst (default):**
- Use CoreDNS for cluster domains
- Forward external to upstream

**2. Default:**
- Use node's DNS
- Bypass CoreDNS

**3. ClusterFirstWithHostNet:**
- For hostNetwork pods
- Still use CoreDNS

**4. None:**
- No automatic DNS
- Must specify dnsConfig

**Example:**
```yaml
dnsPolicy: None
dnsConfig:
  nameservers:
  - 8.8.8.8
```
