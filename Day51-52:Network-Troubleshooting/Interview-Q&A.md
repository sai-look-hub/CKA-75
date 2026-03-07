# 🎤 Interview Q&A: Network Troubleshooting

## Q1: Describe your approach to troubleshooting network issues in Kubernetes.

**Answer:**

I use the **LADDER methodology**:

**L - List Symptoms:**
- What's broken?
- Error messages?
- When did it start?
- What's affected?

**A - Ask Questions:**
- What changed?
- Does DNS work?
- Is it all pods or specific ones?

**D - Diagnose Layer by Layer:**
```
Application → Check logs
Transport   → Test TCP/UDP
Network     → Test IP connectivity
Data Link   → Check CNI
```

**D - Document:**
- Commands run
- Output received
- Findings

**E - Execute Fix:**
- Apply solution
- Verify
- Monitor

**R - Review:**
- Document for runbook
- Add monitoring
- Prevent recurrence

---

## Q2: How do you troubleshoot a pod that cannot connect to a service?

**Answer:**

**Systematic approach:**

**Step 1: Check service exists**
```bash
kubectl get svc <service>
```

**Step 2: Check endpoints**
```bash
kubectl get endpoints <service>
```
If empty → backend pods issue

**Step 3: Check backend pods**
```bash
kubectl get pods -l <selector>
```
If not Running/Ready → fix pods

**Step 4: Test DNS**
```bash
kubectl exec <pod> -- nslookup <service>
```
If fails → DNS issue

**Step 5: Test direct pod IP**
```bash
kubectl exec <pod> -- curl http://<pod-ip>
```
If works → service configuration issue
If fails → network connectivity issue

**Step 6: Check network policies**
```bash
kubectl get networkpolicy
```

**Common solutions:**
- Wrong selector → Fix labels
- No endpoints → Start pods
- DNS issue → Check CoreDNS
- Network policy → Adjust policy

---

## Q3: What tools do you use for network debugging in Kubernetes?

**Answer:**

**Essential tools:**

**1. netshoot container:**
```bash
kubectl run netshoot --rm -it --image=nicolaka/netshoot -- bash
```
Includes: curl, ping, nslookup, dig, tcpdump, traceroute, nmap

**2. kubectl exec:**
```bash
kubectl exec <pod> -- curl http://<service>
kubectl exec <pod> -- nslookup <service>
kubectl exec <pod> -- ping <ip>
```

**3. Service debugging:**
```bash
kubectl get endpoints <service>
kubectl describe svc <service>
```

**4. DNS debugging:**
```bash
kubectl logs -n kube-system -l k8s-app=kube-dns
kubectl exec <pod> -- cat /etc/resolv.conf
```

**5. Network policy checking:**
```bash
kubectl describe networkpolicy <policy>
```

**6. Packet capture:**
```bash
kubectl exec <pod> -- tcpdump -i any -w capture.pcap
```

---

## Q4: How do you troubleshoot DNS issues?

**Answer:**

**Step-by-step:**

**1. Check CoreDNS running:**
```bash
kubectl get pods -n kube-system -l k8s-app=kube-dns
```
If not running → scale deployment

**2. Check service exists:**
```bash
kubectl get svc <service>
```

**3. Test different DNS formats:**
```bash
kubectl exec <pod> -- nslookup <service>
kubectl exec <pod> -- nslookup <service>.<namespace>
kubectl exec <pod> -- nslookup <service>.<namespace>.svc.cluster.local
```

**4. Check /etc/resolv.conf:**
```bash
kubectl exec <pod> -- cat /etc/resolv.conf
```
Should show CoreDNS IP and search domains

**5. Check CoreDNS logs:**
```bash
kubectl logs -n kube-system -l k8s-app=kube-dns
```

**6. Test external DNS:**
```bash
kubectl exec <pod> -- nslookup google.com
```
If fails → upstream DNS issue

**Common issues:**
- CoreDNS pods down
- Network policy blocking port 53
- Wrong namespace
- Service doesn't exist

---

## Q5: How do you debug network policies?

**Answer:**

**Approach:**

**1. List all policies:**
```bash
kubectl get networkpolicy -A
```

**2. Check which policies affect pod:**
```bash
kubectl describe networkpolicy <policy>
```
Look at podSelector

**3. Check pod labels:**
```bash
kubectl get pods --show-labels
```

**4. Test connectivity:**
```bash
kubectl exec <pod-a> -- curl http://<pod-b>
```

**5. Temporarily disable:**
```bash
kubectl delete networkpolicy <policy>
# Test connectivity
# Recreate if needed
```

**6. Check egress rules:**
Important! Egress must allow DNS:
```yaml
egress:
- to:
  - namespaceSelector:
      matchLabels:
        name: kube-system
  ports:
  - protocol: UDP
    port: 53
```

**Common mistakes:**
- Forgot to allow DNS
- Wrong label selectors
- Missing policyTypes
- Namespace label missing
