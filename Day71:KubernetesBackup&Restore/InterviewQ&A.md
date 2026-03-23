# 🎤 Interview Q&A: Backup & Restore - Day 71

## Q1: Why is backing up etcd critical in Kubernetes?

**Answer:**

**etcd is the single source of truth** for the entire Kubernetes cluster.

**What etcd stores:**
- All cluster state
- All resources (Pods, Services, Deployments)
- ConfigMaps and Secrets
- RBAC policies
- Everything!

**If etcd is lost:**
```
Cluster state = Gone
All resources = Gone
Configurations = Gone
Secrets = Gone

Result: Must rebuild entire cluster from scratch
```

**With etcd backup:**
```
Restore snapshot → Full cluster state restored
All resources back → Zero manual recreation
Complete recovery → Minutes, not days
```

**Best practices:**
- Daily backups minimum
- Off-cluster storage
- Test restores monthly
- Retention: 30 days+

---

## Q2: Explain the complete etcd backup and restore process.

**Answer:**

**Backup Process:**

**1. Create snapshot:**
```bash
ETCDCTL_API=3 etcdctl snapshot save backup.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
```

**2. Verify:**
```bash
ETCDCTL_API=3 etcdctl snapshot status backup.db
```

**3. Store off-cluster:**
```bash
aws s3 cp backup.db s3://backups/
```

**Restore Process:**

**1. Stop API server:**
```bash
mv /etc/kubernetes/manifests/kube-apiserver.yaml /tmp/
```

**2. Restore snapshot:**
```bash
ETCDCTL_API=3 etcdctl snapshot restore backup.db \
  --data-dir=/var/lib/etcd-restore
```

**3. Update etcd manifest:**
```yaml
# Change data directory in etcd.yaml
volumes:
- hostPath:
    path: /var/lib/etcd-restore  # Changed
```

**4. Restart API server:**
```bash
mv /tmp/kube-apiserver.yaml /etc/kubernetes/manifests/
```

**5. Verify:**
```bash
kubectl get nodes
kubectl get pods -A
```

**Critical:** Always backup before upgrades!

---

## Q3: How do you automate etcd backups in production?

**Answer:**

**Multiple approaches:**

**1. CronJob on host:**
```bash
# /usr/local/bin/etcd-backup.sh
#!/bin/bash
ETCDCTL_API=3 etcdctl snapshot save \
  /backup/etcd-$(date +%Y%m%d).db \
  [etcd options...]

# Upload to S3
aws s3 cp /backup/etcd-$(date +%Y%m%d).db s3://backups/

# Clean old backups
find /backup -mtime +30 -delete

# Crontab
0 2 * * * /usr/local/bin/etcd-backup.sh
```

**2. Kubernetes CronJob:**
```yaml
apiVersion: batch/v1
kind: CronJob
spec:
  schedule: "0 2 * * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            command: ["/bin/sh", "-c"]
            args:
            - |
              etcdctl snapshot save /backup/etcd-$(date +%Y%m%d).db
              aws s3 cp /backup/etcd-$(date +%Y%m%d).db s3://backups/
```

**3. Monitoring:**
```bash
# Check backup age
AGE=$(stat -c %Y /backup/etcd-latest.db)
if [ $AGE -gt 86400 ]; then
  alert "Backup older than 24 hours!"
fi
```

**Best practices:**
- Daily backups minimum
- Store in S3/cloud storage
- Different region than cluster
- Retention: 30 days daily, 12 months monthly
- Alert on backup failures
- Test restores monthly

---

## Q4: What's the difference between etcd backups and Velero?

**Answer:**

**etcd Backups:**

**Scope:** Cluster state only
```
- All Kubernetes resources
- ConfigMaps, Secrets
- RBAC, Services
```

**Does NOT include:**
- Persistent Volume data
- Application state in PVs

**Use for:**
- Cluster-level DR
- Cluster migration
- Version rollback

**Velero:**

**Scope:** Application + Data
```
- Kubernetes resources
- Persistent Volume snapshots
- Complete application state
```

**Includes:**
- PV data (database contents, files)
- Application-specific backups
- Namespace-level backups

**Use for:**
- Application DR
- Namespace migration
- PV backup/restore

**Complete Strategy:**
```
etcd backups    → Cluster recovery
Velero backups  → Application/data recovery
Both together   → Complete DR solution
```

**Example:**
```bash
# Daily etcd backup
Backs up: Cluster state

# Daily Velero backup
velero backup create prod --include-namespaces production
Backs up: Apps + Databases

# Recovery
etcd restore     → Cluster state
Velero restore   → Application data
```

---

## Q5: How do you test disaster recovery procedures?

**Answer:**

**Testing strategy:**

**1. Schedule regular DR drills:**
```
Monthly: Restore test
Quarterly: Full DR drill
Yearly: Multi-site failover
```

**2. Test restore procedure:**
```bash
# Create test cluster
# Restore backup
# Validate all resources
# Document time taken
```

**3. Measure RTO/RPO:**
```
RTO (Recovery Time Objective):
- Start: Disaster occurs
- End: System operational
- Target: < 1 hour

RPO (Recovery Point Objective):
- How much data can be lost
- Backup frequency determines this
- Target: < 1 hour (hourly backups)
```

**4. Validation checklist:**
```
- [ ] All nodes ready
- [ ] All pods running
- [ ] Applications accessible
- [ ] Data integrity verified
- [ ] No errors in logs
```

**5. Document lessons learned:**
```
What worked:
- Automated scripts saved time
- S3 storage reliable

What didn't:
- Missing certificate backups
- Network connectivity issues

Improvements:
- Add certificate backup
- Document network requirements
```

**6. Update procedures:**
- Fix identified issues
- Update documentation
- Train team members
- Improve automation

**Best practice:** Treat DR tests like production incidents - time everything, document everything.
