# Lessons Learned: Week 1-2 CKA Journey

> **Real mistakes, hard-won insights, and practical wisdom from building a production 3-tier application**

---

## Table of Contents

- [Week 1 Lessons](#week-1-lessons)
- [Week 2 Lessons](#week-2-lessons)
- [Major Mistakes & Fixes](#major-mistakes--fixes)
- [Best Practices Discovered](#best-practices-discovered)
- [Time-Saving Tips](#time-saving-tips)
- [What I'd Do Differently](#what-id-do-differently)
- [Unexpected Discoveries](#unexpected-discoveries)

---

## Week 1 Lessons

### Day 1-2: Kubernetes Architecture

**Lesson 1: Understanding the Control Plane is Critical**

**What I Learned:**
- The API server is the ONLY component that talks to etcd
- Everything goes through the API server (kubectl, controllers, kubelet)
- Understanding this flow helped me debug so many issues later

**Mistake:**
I thought kubelet could update etcd directly. It can't.

**Impact:**
Wasted time troubleshooting pod status issues by looking at the wrong component.

---

### Day 3-4: Pods & ReplicaSets

**Lesson 2: Never Deploy Bare Pods in Production**

**What Happened:**
```yaml
# I created this initially (BAD!)
apiVersion: v1
kind: Pod
metadata:
  name: backend
# No recovery if it dies!
```

**The Problem:**
Pod died → Lost forever → Manual recreation required

**The Fix:**
```yaml
# Always use Deployments
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
spec:
  replicas: 3
# Automatic recovery, rolling updates, etc.
```

**Takeaway:** Deployments are almost always the right choice.

---

**Lesson 3: Init Containers Save Lives**

**Problem:**
Backend started before database was ready → Crash loop

**Solution:**
```yaml
initContainers:
- name: wait-for-db
  image: busybox
  command: ['sh', '-c', 'until nc -z postgres 5432; do sleep 2; done']
```

**Takeaway:** Always wait for dependencies in init containers.

---

### Day 5-6: Deployments

**Lesson 4: Rolling Updates Aren't Automatic Zero-Downtime**

**Mistake:**
```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1
    maxUnavailable: 1  # This caused brief downtime!
```

**The Problem:**
With `maxUnavailable: 1`, one pod could go down before new one was ready.

**The Fix:**
```yaml
rollingUpdate:
  maxSurge: 1
  maxUnavailable: 0  # Never allow pods to go unavailable
```

**Takeaway:** For zero downtime, set `maxUnavailable: 0`.

---

**Lesson 5: Rollback is Your Friend**

**What Happened:**
Deployed broken version → Production down → Panic!

**The Save:**
```bash
kubectl rollout undo deployment/backend
# Instant rollback to previous version
```

**Takeaway:** Always know how to rollback. Practice it in dev.

---

### Day 7-8: Services & Networking

**Lesson 6: Services DON'T Work Without Endpoints**

**Frustrating Experience:**
```bash
kubectl get svc backend
# NAME      TYPE        CLUSTER-IP   
# backend   ClusterIP   10.96.0.50   

kubectl get endpoints backend
# NAME      ENDPOINTS
# backend   <none>    # No endpoints!
```

**The Problem:**
Service selector didn't match pod labels.

```yaml
# Service
selector:
  app: backend
  tier: api

# Pod (WRONG)
labels:
  app: backend
  # Missing tier: api
```

**Takeaway:** Service selectors must EXACTLY match pod labels.

---

**Lesson 7: LoadBalancer on Local Cluster = Pending Forever**

**Mistake:**
Used LoadBalancer type on local Minikube/Kind cluster.

```bash
kubectl get svc
# EXTERNAL-IP: <pending>  # Forever!
```

**Why:**
LoadBalancer requires cloud provider or MetalLB.

**Solution for Local Development:**
```bash
# Use NodePort instead
kubectl patch svc frontend -p '{"spec":{"type":"NodePort"}}'

# Or use port-forward
kubectl port-forward svc/frontend 8080:80
```

**Takeaway:** LoadBalancer only works with cloud providers or MetalLB.

---

**Lesson 8: DNS is Not Magic**

**Problem:**
```bash
curl http://backend:8080  # Worked
curl http://backend.production:8080  # Worked
curl http://backend.production.svc.cluster.local:8080  # Worked

# But from different namespace:
curl http://backend:8080  # FAILED!
```

**Why:**
Short names only work in the same namespace.

**Solution:**
Always use FQDN for cross-namespace communication:
```
backend.production.svc.cluster.local
```

**Takeaway:** DNS short names are namespace-scoped.

---

## Week 2 Lessons

### Day 10-11: Namespaces & Labels

**Lesson 9: Namespaces ≠ Network Isolation**

**Huge Misconception:**
I thought namespaces provided network isolation. They don't!

**What Happened:**
Dev pods could talk to production database. 😱

**What I Learned:**
- Namespaces are for organization, not security
- Network isolation requires Network Policies
- Always implement both for production

```yaml
# Required for actual isolation
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-from-other-namespaces
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector: {}
```

**Takeaway:** Namespaces organize. Network Policies isolate.

---

**Lesson 10: Label Everything Consistently**

**Early Approach (BAD):**
```yaml
# Inconsistent labels across resources
Pod: app=backend, env=prod
Service: application=backend, environment=production
Deployment: app=api, env=production
```

**Problems:**
- Hard to query resources
- Selectors didn't match
- Confused team members

**Better Approach:**
```yaml
# Consistent label schema everywhere
labels:
  app.kubernetes.io/name: ecommerce
  app.kubernetes.io/component: backend
  environment: production
  tier: backend
```

**Takeaway:** Define label schema early and stick to it religiously.

---

**Lesson 11: Resource Quotas Prevent Disasters**

**What Happened:**
Dev team deployed huge workload → Consumed entire cluster → Production impacted

**The Fix:**
```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: dev-quota
  namespace: development
spec:
  hard:
    requests.cpu: "4"
    requests.memory: "8Gi"
    pods: "20"
```

**Takeaway:** Always set resource quotas per namespace.

---

### Day 12-13: Configuration Management

**Lesson 12: Secrets Aren't Really Secret (By Default)**

**Shocking Discovery:**
```bash
# Anyone with kubectl access can do this:
kubectl get secret db-secret -o yaml
# Shows base64 encoded password

echo "cGFzc3dvcmQxMjM=" | base64 -d
# password123  # Decoded!
```

**What This Means:**
- Base64 ≠ Encryption
- Need to enable encryption at rest
- RBAC must restrict secret access

**Takeaway:** Enable encryption at rest and use strict RBAC for secrets.

---

**Lesson 13: Environment Variables Don't Update**

**Frustrating Experience:**
```bash
# Updated ConfigMap
kubectl edit cm backend-config

# Waited for pods to pick up changes... nothing happened!
```

**Why:**
Environment variables are set when pod starts. They never update.

**Solutions:**
```bash
# Option 1: Restart deployment
kubectl rollout restart deployment/backend

# Option 2: Use volume mounts (auto-update)
volumeMounts:
- name: config
  mountPath: /etc/config
```

**Takeaway:** Volume mounts auto-update. Environment variables don't.

---

**Lesson 14: Never Put Secrets in ConfigMaps**

**Embarrassing Mistake:**
```yaml
# DON'T DO THIS!
apiVersion: v1
kind: ConfigMap
data:
  DB_PASSWORD: "password123"  # Visible to everyone!
```

**Why It's Bad:**
- ConfigMaps have looser RBAC by default
- Often committed to Git
- Not encrypted

**Correct Approach:**
```yaml
apiVersion: v1
kind: Secret
stringData:
  DB_PASSWORD: "password123"
```

**Takeaway:** Secrets for sensitive data. ConfigMaps for public config.

---

## Major Mistakes & Fixes

### Mistake 1: No Resource Limits

**What I Did:**
Deployed pods without resource limits.

**What Happened:**
One pod consumed entire node → Node crash → All pods on that node died

**The Fix:**
```yaml
resources:
  requests:
    cpu: "100m"
    memory: "128Mi"
  limits:
    cpu: "200m"
    memory: "256Mi"
```

**Lesson:** ALWAYS set resource requests and limits.

---

### Mistake 2: Single Replica in Production

**What I Did:**
```yaml
spec:
  replicas: 1  # Bad idea!
```

**What Happened:**
Pod crashed → Entire service down → Angry users

**The Fix:**
```yaml
spec:
  replicas: 3  # Minimum for production
```

**Lesson:** Multiple replicas = High availability

---

### Mistake 3: No Health Checks

**What I Did:**
Deployed without liveness/readiness probes.

**What Happened:**
- Crashed pods stayed in "Running" state
- Load balancer sent traffic to dead pods
- Users got errors

**The Fix:**
```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 8080
readinessProbe:
  httpGet:
    path: /ready
    port: 8080
```

**Lesson:** Health checks are non-negotiable.

---

### Mistake 4: Using `latest` Tag

**What I Did:**
```yaml
image: myapp:latest
```

**What Happened:**
- Can't rollback (which version is "latest"?)
- Unpredictable deployments
- Hard to debug

**The Fix:**
```yaml
image: myapp:v2.1.0  # Specific version
```

**Lesson:** Always use specific image tags.

---

### Mistake 5: Forgetting to Wait for Database

**What I Did:**
Backend started immediately, tried to connect to database.

**What Happened:**
Backend crashed because database wasn't ready yet.

**The Fix:**
```yaml
initContainers:
- name: wait-for-db
  image: busybox
  command:
  - sh
  - -c
  - |
    until nc -z postgres 5432; do
      echo "Waiting for database..."
      sleep 2
    done
```

**Lesson:** Always wait for dependencies.

---

## Best Practices Discovered

### 1. The Power of Labels

**Discovery:**
Well-designed labels make everything easier.

**My Label Schema:**
```yaml
labels:
  app.kubernetes.io/name: ecommerce
  app.kubernetes.io/instance: ecommerce-prod
  app.kubernetes.io/version: "2.1.0"
  app.kubernetes.io/component: frontend
  environment: production
  tier: frontend
```

**Benefits:**
```bash
# Easy queries
kubectl get pods -l environment=production
kubectl get all -l tier=backend
kubectl logs -l app.kubernetes.io/name=ecommerce --tail=100

# Powerful selectors
kubectl get pods -l 'tier in (frontend,backend)'
```

---

### 2. The Pod Anti-Affinity Pattern

**Discovery:**
Spread pods across nodes for better availability.

```yaml
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 100
      podAffinityTerm:
        labelSelector:
          matchExpressions:
          - key: app
            operator: In
            values:
            - backend
        topologyKey: kubernetes.io/hostname
```

**Result:**
Node failure only takes down some pods, not all.

---

### 3. The Init Container Pattern

**Discovery:**
Init containers solve startup dependencies beautifully.

**Use Cases:**
- Wait for database
- Run migrations
- Download configuration
- Check prerequisites

---

### 4. The Immutable ConfigMap Pattern

**Discovery:**
Immutable ConfigMaps prevent accidental changes.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config-v1
immutable: true  # Can't be modified
data:
  API_URL: "https://api.example.com"
```

**Benefits:**
- Can't accidentally change production config
- Better performance (K8s doesn't watch for changes)
- Forced versioning (must create new ConfigMap)

---

## Time-Saving Tips

### 1. Use `kubectl` Aliases

**My .bashrc:**
```bash
alias k='kubectl'
alias kgp='kubectl get pods'
alias kgs='kubectl get svc'
alias kdp='kubectl describe pod'
alias kl='kubectl logs -f'
alias kex='kubectl exec -it'
```

**Time Saved:** Hours per week

---

### 2. The `--dry-run` Trick

**Discovery:**
Generate YAML without creating resources.

```bash
# Generate deployment YAML
kubectl create deployment nginx --image=nginx \
  --dry-run=client -o yaml > deployment.yaml

# Generate service YAML
kubectl expose deployment nginx --port=80 \
  --dry-run=client -o yaml > service.yaml
```

**Time Saved:** Tons! No more writing YAML from scratch.

---

### 3. The `kubectl diff` Command

**Discovery:**
See what will change before applying.

```bash
kubectl diff -f deployment.yaml
# Shows exact changes that will be made
```

**Benefit:** Avoid surprises in production.

---

### 4. Use `stern` for Multi-Pod Logs

**Discovery:**
Following logs from multiple pods is painful with kubectl.

```bash
# Instead of this:
kubectl logs -f pod1 &
kubectl logs -f pod2 &
kubectl logs -f pod3 &

# Use stern:
stern backend
# Tails logs from ALL backend pods
```

---

## What I'd Do Differently

### 1. Start with Namespaces Day 1

**What I Did:**
Put everything in `default` namespace initially.

**What I'd Do:**
Create `dev`, `staging`, `production` namespaces from the start.

---

### 2. Define Label Schema First

**What I Did:**
Made up labels as I went → Inconsistent mess

**What I'd Do:**
Define complete label schema before creating any resources.

---

### 3. Enable Metrics Server Early

**What I Did:**
Installed metrics server in Week 2 when I needed HPA.

**What I'd Do:**
Install day 1 to see resource usage from the start.

---

### 4. Use Helm Earlier

**What I Did:**
Managed 50+ YAML files manually.

**What I'd Do:**
Learn Helm in Week 1, package apps properly.

---

## Unexpected Discoveries

### Discovery 1: StatefulSets Are Special

**Surprise:**
StatefulSets create pods with predictable names and persistent identities.

```
postgres-0
postgres-1
postgres-2
# Not random names like deployments
```

**Why It Matters:**
Perfect for databases that need stable network IDs.

---

### Discovery 2: Services Are Just iptables Rules

**Mind-Blowing:**
Services don't actually exist. They're just iptables rules managed by kube-proxy!

```bash
# On a node:
sudo iptables-save | grep backend
# Shows NAT rules for service
```

---

### Discovery 3: kubectl Can Do Math

**Useful Discovery:**
```bash
# Get total CPU requests
kubectl get pods -A -o json | \
  jq '[.items[].spec.containers[].resources.requests.cpu | select(. != null)] | add'
```

---

## Key Takeaways

### Technical

1. **Services need endpoints** - Label selectors must match
2. **Namespaces don't isolate networks** - Use Network Policies
3. **Secrets aren't encrypted by default** - Enable encryption at rest
4. **Environment variables don't update** - Use volume mounts
5. **Always set resource limits** - Prevents node crashes
6. **Multiple replicas** = High availability
7. **Health checks** are critical
8. **Init containers** solve dependencies

### Operational

1. **Start organized** - Namespaces, labels, structure from day 1
2. **Test in dev** - Never experiment in production
3. **Know how to rollback** - Practice it
4. **Monitor everything** - Logs, metrics, events
5. **Document as you go** - Future you will thank you

### Personal

1. **Mistakes are valuable** - I learned more from failures than successes
2. **Read error messages carefully** - They actually help
3. **Google is your friend** - Someone has hit your error before
4. **Community is amazing** - Kubernetes Slack is incredibly helpful
5. **Patience pays off** - Some concepts took days to click

---

## Final Thoughts

**Week 1:**
"Kubernetes is impossible and I'll never understand it."

**Week 2:**
"Oh! It's just APIs, YAML, and labels. I can do this!"

**Biggest Lesson:**
Kubernetes seems complex, but it's built on simple, composable primitives. Master the basics, and everything else follows.

**What's Next:**
- Deeper dive into storage
- StatefulSets advanced patterns
- Service meshes
- Helm charts
- GitOps workflows

---

**Progress: 27% CKA Complete**

*The journey continues! Week 3, here we come!* 🚀

---

**End of Lessons Learned**
