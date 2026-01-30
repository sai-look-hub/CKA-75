# Jobs & CronJobs Interview Questions & Answers

## Basic Level Questions

### Q1: What is a Kubernetes Job and when would you use it?

**Answer**: A Job is a Kubernetes controller that creates one or more pods and ensures that a specified number of them successfully terminate. Unlike Deployments that run continuously, Jobs run to completion and then stop.

**Use Cases**:
- Database migrations
- Batch data processing
- Report generation
- Backup operations
- One-time administrative tasks
- ETL (Extract, Transform, Load) operations

**Key Characteristics**:
- Runs until successful completion
- Automatic retries on failure
- Supports parallel execution
- Pods are not deleted automatically (for debugging)

**Example**:
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: data-migration
spec:
  template:
    spec:
      containers:
      - name: migrate
        image: migration-tool:1.0
        command: ['./migrate.sh']
      restartPolicy: Never
```

---

### Q2: What's the difference between a Job and a CronJob?

**Answer**:

| Aspect | Job | CronJob |
|--------|-----|---------|
| **Execution** | Runs once | Runs on schedule |
| **Trigger** | Manual | Automatic (cron) |
| **Use Case** | One-time tasks | Recurring tasks |
| **Scheduling** | Immediate | Cron syntax |
| **Example** | DB migration | Daily backup |

**Job Example**:
```bash
kubectl create job backup --image=backup:1.0 -- ./backup.sh
```

**CronJob Example**:
```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: daily-backup
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: backup:1.0
          restartPolicy: OnFailure
```

**When to use**:
- **Job**: Run database migration after deployment
- **CronJob**: Daily backup, weekly reports, hourly sync

---

### Q3: Explain completions and parallelism in Jobs.

**Answer**:

**Completions**: Number of successful pod completions required for job to complete.

**Parallelism**: Number of pods running concurrently.

**Examples**:

**1. Single execution (default)**:
```yaml
spec:
  completions: 1      # Default
  parallelism: 1      # Default
```
Behavior: One pod, runs once

**2. Sequential execution**:
```yaml
spec:
  completions: 5
  parallelism: 1
```
Behavior: 5 pods run one after another

**3. Parallel execution**:
```yaml
spec:
  completions: 10
  parallelism: 3
```
Behavior: 10 total, 3 running at a time

**4. Work queue pattern**:
```yaml
spec:
  parallelism: 5
  # completions not set
```
Behavior: 5 workers process queue until empty

**Execution Timeline Example**:
```
completions: 6, parallelism: 2

Time 0s:  Pod-1 Running, Pod-2 Running
Time 10s: Pod-1 Complete, Pod-2 Running, Pod-3 Starting
Time 15s: Pod-2 Complete, Pod-3 Running, Pod-4 Starting
Time 25s: Pod-3 Complete, Pod-4 Running, Pod-5 Starting
Time 30s: Pod-4 Complete, Pod-5 Running, Pod-6 Starting
Time 40s: Pod-5 Complete, Pod-6 Running
Time 50s: Pod-6 Complete → Job Complete
```

---

### Q4: What restart policies are allowed for Jobs?

**Answer**: Jobs support two restart policies:

**1. Never**:
```yaml
restartPolicy: Never
```
- If container fails → Create new pod
- Good for: Non-idempotent operations
- Each failure counts against backoffLimit

**2. OnFailure**:
```yaml
restartPolicy: OnFailure
```
- If container fails → Restart container in same pod
- Good for: Idempotent operations
- More efficient (reuses pod)

**Always is NOT allowed**:
```yaml
restartPolicy: Always  # ❌ Not allowed for Jobs
```

**Comparison**:
```
Container fails with restartPolicy: Never
Pod-1 (Failed) → Pod-2 (Created) → Pod-3 (Created)

Container fails with restartPolicy: OnFailure  
Pod-1 (Container restart 1) → (Container restart 2) → (Container restart 3)
```

**When to use**:
- **Never**: Database migration (don't want to retry mid-migration)
- **OnFailure**: Data processing (safe to retry from beginning)

---

### Q5: Explain cron schedule syntax in Kubernetes CronJobs.

**Answer**:

**Format**: `minute hour day month weekday`
```
 ┌───────────── minute (0 - 59)
 │ ┌───────────── hour (0 - 23)
 │ │ ┌───────────── day of month (1 - 31)
 │ │ │ ┌───────────── month (1 - 12)
 │ │ │ │ ┌───────────── day of week (0 - 6) (Sunday=0)
 │ │ │ │ │
 * * * * *
```

**Common Examples**:

```yaml
# Every minute
schedule: "* * * * *"

# Every 5 minutes
schedule: "*/5 * * * *"

# Every hour at :00
schedule: "0 * * * *"

# Every hour at :30
schedule: "30 * * * *"

# Every day at 2:30 AM
schedule: "30 2 * * *"

# Every Monday at 9 AM
schedule: "0 9 * * 1"

# Every 1st of month at midnight
schedule: "0 0 1 * *"

# Weekdays (Mon-Fri) at 6 PM
schedule: "0 18 * * 1-5"

# Every 6 hours
schedule: "0 */6 * * *"

# Multiple specific times (not supported - use separate CronJobs)
```

**Special Characters**:
- `*`: Any value
- `,`: List (1,15 = 1st and 15th)
- `-`: Range (1-5 = Mon to Fri)
- `/`: Step (*/5 = every 5 units)

**Validation**: Use https://crontab.guru/

---

## Intermediate Level Questions

### Q6: How do you handle job failures and retries?

**Answer**: Jobs provide several mechanisms for handling failures:

**1. backoffLimit** (number of retries):
```yaml
spec:
  backoffLimit: 3  # Retry 3 times
```

**Backoff Behavior**:
- Initial delay: 10s
- Max delay: 6 minutes
- Exponential: 10s, 20s, 40s, 80s, 160s, 320s (6m)

**2. Restart Policy**:
```yaml
restartPolicy: OnFailure  # Retry in same pod
restartPolicy: Never      # Create new pod
```

**3. activeDeadlineSeconds** (timeout):
```yaml
spec:
  activeDeadlineSeconds: 600  # Kill after 10 minutes
```

**4. Pod Failure Policy** (Kubernetes 1.25+):
```yaml
spec:
  podFailurePolicy:
    rules:
    - action: FailJob
      onExitCodes:
        containerName: main
        operator: In
        values: [42]  # Fail immediately on exit code 42
    - action: Ignore
      onPodConditions:
      - type: DisruptionTarget  # Ignore evictions
```

**Complete Example**:
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: resilient-job
spec:
  backoffLimit: 4
  activeDeadlineSeconds: 3600
  template:
    spec:
      containers:
      - name: task
        image: flaky-app:1.0
        command: ['./run.sh']
      restartPolicy: OnFailure
```

**Best Practices**:
- Set backoffLimit based on expected failure rate
- Use OnFailure for idempotent tasks
- Set activeDeadlineSeconds to prevent runaway jobs
- Log failures for debugging
- Implement exponential backoff in application

---

### Q7: Explain CronJob concurrency policies.

**Answer**: ConcurrencyPolicy controls how CronJobs handle overlapping executions:

**1. Allow (Default)**:
```yaml
spec:
  concurrencyPolicy: Allow
```
- Multiple jobs can run simultaneously
- No restrictions
- **Use for**: Independent tasks that can overlap

**Example Scenario**:
```
Schedule: */5 * * * * (every 5 minutes)
Job duration: 7 minutes

Time 00:00 → Job-1 starts
Time 00:05 → Job-2 starts (Job-1 still running)
Time 00:07 → Job-1 completes
Time 00:10 → Job-3 starts (Job-2 still running)
```

**2. Forbid**:
```yaml
spec:
  concurrencyPolicy: Forbid
```
- Skip new job if previous still running
- **Use for**: Backups, long-running tasks, resource-intensive jobs

**Example Scenario**:
```
Schedule: */5 * * * *
Job duration: 7 minutes

Time 00:00 → Job-1 starts
Time 00:05 → Skipped (Job-1 running)
Time 00:07 → Job-1 completes
Time 00:10 → Job-2 starts
```

**3. Replace**:
```yaml
spec:
  concurrencyPolicy: Replace
```
- Cancel old job, start new one
- **Use for**: Status updates, current data only matters

**Example Scenario**:
```
Schedule: */5 * * * *
Job duration: 7 minutes

Time 00:00 → Job-1 starts
Time 00:05 → Job-1 terminated, Job-2 starts
Time 00:10 → Job-2 terminated, Job-3 starts
```

**Real-World Examples**:

**Database Backup (Forbid)**:
```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: db-backup
spec:
  schedule: "0 2 * * *"
  concurrencyPolicy: Forbid  # Don't start if previous backup running
```

**Health Check (Replace)**:
```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: health-check
spec:
  schedule: "*/1 * * * *"
  concurrencyPolicy: Replace  # Only latest check matters
```

**Log Processing (Allow)**:
```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: process-logs
spec:
  schedule: "*/10 * * * *"
  concurrencyPolicy: Allow  # Independent log batches
```

---

### Q8: How do you clean up completed Jobs?

**Answer**: Several approaches for cleaning up Jobs:

**1. TTL Controller (Recommended)**:
```yaml
spec:
  ttlSecondsAfterFinished: 100  # Delete 100s after completion
```

**Behavior**:
- Automatic cleanup
- Applies to successful and failed jobs
- Set to `0` for immediate deletion
- Requires TTL controller enabled (default in K8s 1.23+)

**2. CronJob History Limits**:
```yaml
spec:
  successfulJobsHistoryLimit: 3  # Keep 3 successful
  failedJobsHistoryLimit: 1      # Keep 1 failed
```

**Default Values**:
- successfulJobsHistoryLimit: 3
- failedJobsHistoryLimit: 1

**3. Manual Cleanup**:
```bash
# Delete all completed jobs
kubectl delete jobs --field-selector status.successful=1

# Delete jobs older than 24 hours
kubectl get jobs -o json | \
  jq -r '.items[] | 
    select(.status.completionTime != null) | 
    select((now - (.status.completionTime | fromdateiso8601)) > 86400) | 
    .metadata.name' | \
  xargs kubectl delete job

# Delete failed jobs
kubectl delete jobs --field-selector status.failed!=0
```

**4. Automated Cleanup CronJob**:
```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: cleanup-jobs
spec:
  schedule: "0 0 * * *"  # Daily
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: job-cleaner
          containers:
          - name: cleanup
            image: bitnami/kubectl:latest
            command:
            - sh
            - -c
            - kubectl delete jobs --field-selector status.successful=1
          restartPolicy: Never
```

**Best Practice**:
- Use TTL for Jobs
- Use history limits for CronJobs
- Set up monitoring for job accumulation
- Regular manual audits

---

### Q9: What is the work queue pattern in Jobs?

**Answer**: Work queue pattern allows multiple workers to process items from a shared queue until it's empty.

**Configuration**:
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: queue-workers
spec:
  parallelism: 5      # 5 workers
  # NO completions field - runs until queue empty
  template:
    spec:
      containers:
      - name: worker
        image: queue-processor:1.0
        env:
        - name: QUEUE_URL
          value: "redis://queue:6379"
      restartPolicy: OnFailure
```

**Worker Logic**:
```python
import redis

def worker():
    r = redis.Redis(host='queue', port=6379)
    
    while True:
        # Pop item from queue
        item = r.lpop('work-queue')
        
        if not item:
            # Queue empty - exit successfully
            print("Queue empty, worker exiting")
            sys.exit(0)
        
        # Process item
        process(item)
```

**How it Works**:
```
Queue: [Item1, Item2, Item3, ... Item100]

Time 0s:
  Worker-1 → Item1
  Worker-2 → Item2
  Worker-3 → Item3
  Worker-4 → Item4
  Worker-5 → Item5

Time 10s:
  Worker-1 completes Item1 → Item6
  Worker-2 completes Item2 → Item7
  ...

Time 200s:
  All items processed
  Workers find empty queue
  All workers exit 0
  Job completes
```

**Benefits**:
- Dynamic workload
- Efficient resource usage
- Handles varying task sizes
- Easy to add/remove workers

**Use Cases**:
- Image processing
- Video encoding
- Data transformation
- Email sending

---

### Q10: How do you monitor and debug Jobs?

**Answer**:

**Monitoring**:

**1. Check Job Status**:
```bash
# List jobs
kubectl get jobs

# Detailed status
kubectl describe job my-job

# Watch job progress
kubectl get jobs -w
```

**2. Check Pods**:
```bash
# List pods for job
kubectl get pods -l job-name=my-job

# Check pod status
kubectl get pods -l job-name=my-job -o wide

# Count successes/failures
kubectl get pods -l job-name=my-job --field-selector status.phase=Succeeded
kubectl get pods -l job-name=my-job --field-selector status.phase=Failed
```

**3. View Logs**:
```bash
# All pods in job
kubectl logs -l job-name=my-job

# Specific pod
kubectl logs my-job-abc123

# Follow logs
kubectl logs -f my-job-abc123

# Previous container logs (if restarted)
kubectl logs my-job-abc123 --previous
```

**4. Check Events**:
```bash
# Job events
kubectl describe job my-job | grep Events -A 10

# All events
kubectl get events --field-selector involvedObject.name=my-job

# Sorted by time
kubectl get events --sort-by='.lastTimestamp'
```

**Debugging**:

**1. Check Exit Codes**:
```bash
kubectl get pod my-job-abc -o jsonpath='{.status.containerStatuses[0].state.terminated.exitCode}'
```

**2. Exec into Running Pod**:
```bash
# If pod still running
kubectl exec -it my-job-abc -- /bin/bash

# Run commands manually
./run-task.sh --debug
```

**3. Debug Pod with Same Spec**:
```bash
# Extract job pod spec
kubectl get job my-job -o yaml > debug-job.yaml

# Modify to pod and run interactively
kubectl run debug --rm -it --image=myapp:1.0 -- /bin/bash
```

**4. Check Resources**:
```bash
# Resource requests/limits
kubectl get job my-job -o jsonpath='{.spec.template.spec.containers[0].resources}'

# Actual usage (if metrics-server installed)
kubectl top pods -l job-name=my-job
```

**Metrics to Monitor**:
- Job completion rate
- Average completion time
- Failure rate
- Resource utilization
- Queue depth (for work queue pattern)

**Alerts to Set**:
- Job failure
- Job timeout
- Repeated failures
- Resource exhaustion
- Long execution time

---

## Advanced Level Questions

### Q11: How would you implement a data processing pipeline with Jobs?

**Answer**: Multi-stage ETL pipeline using Jobs:

**Architecture**:
```
Stage 1: Extract → Stage 2: Transform → Stage 3: Load
   (10 parallel)      (5 parallel)         (1 sequential)
```

**Implementation**:

**Stage 1: Extract Job**:
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: etl-extract
  labels:
    pipeline: etl
    stage: extract
spec:
  completions: 100      # 100 files to extract
  parallelism: 10       # 10 workers
  backoffLimit: 3
  ttlSecondsAfterFinished: 86400
  template:
    spec:
      containers:
      - name: extractor
        image: etl:2.0
        env:
        - name: STAGE
          value: "extract"
        - name: OUTPUT_QUEUE
          value: "transform-queue"
        command: ['python', 'extract.py']
        resources:
          limits:
            memory: "2Gi"
            cpu: "1"
      restartPolicy: OnFailure
```

**Stage 2: Transform Job** (triggered after Extract):
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: etl-transform
  labels:
    pipeline: etl
    stage: transform
spec:
  parallelism: 5
  template:
    spec:
      containers:
      - name: transformer
        image: etl:2.0
        env:
        - name: INPUT_QUEUE
          value: "transform-queue"
        - name: OUTPUT_QUEUE
          value: "load-queue"
        command: ['python', 'transform.py']
      restartPolicy: OnFailure
```

**Stage 3: Load Job**:
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: etl-load
spec:
  completions: 1
  template:
    spec:
      containers:
      - name: loader
        image: etl:2.0
        env:
        - name: INPUT_QUEUE
          value: "load-queue"
        - name: DB_HOST
          value: "postgres:5432"
        command: ['python', 'load.py']
      restartPolicy: OnFailure
```

**Orchestration Script**:
```bash
#!/bin/bash
set -e

echo "Starting ETL Pipeline"

# Stage 1: Extract
echo "Stage 1: Extract"
kubectl apply -f extract-job.yaml
kubectl wait --for=condition=complete --timeout=3600s job/etl-extract

# Stage 2: Transform
echo "Stage 2: Transform"
kubectl apply -f transform-job.yaml
kubectl wait --for=condition=complete --timeout=1800s job/etl-transform

# Stage 3: Load
echo "Stage 3: Load"
kubectl apply -f load-job.yaml
kubectl wait --for=condition=complete --timeout=900s job/etl-load

echo "ETL Pipeline Complete"
```

**With Argo Workflows** (Better approach):
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: etl-pipeline-
spec:
  entrypoint: etl
  templates:
  - name: etl
    steps:
    - - name: extract
        template: extract-job
    - - name: transform
        template: transform-job
    - - name: load
        template: load-job
  
  - name: extract-job
    resource:
      action: create
      manifest: |
        apiVersion: batch/v1
        kind: Job
        ...
```

**Monitoring**:
```bash
# Monitor pipeline
watch 'kubectl get jobs -l pipeline=etl'

# Check progress
kubectl get jobs -l pipeline=etl -o custom-columns=\
NAME:.metadata.name,\
STAGE:.metadata.labels.stage,\
COMPLETIONS:.status.succeeded/:.spec.completions,\
DURATION:.status.completionTime
```

---

### Q12: How do you handle timezone issues with CronJobs?

**Answer**:

**Problem**: CronJobs use the timezone of the kube-controller-manager, which is typically UTC.

**Solutions**:

**1. Use UTC and document** (Recommended):
```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: daily-report
  annotations:
    description: "Runs at 2 AM EST (7 AM UTC)"
spec:
  schedule: "0 7 * * *"  # 2 AM EST = 7 AM UTC
```

**2. Timezone field** (Kubernetes 1.25+):
```yaml
spec:
  schedule: "0 2 * * *"
  timeZone: "America/New_York"
```

**3. Handle in container**:
```yaml
spec:
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: task
            image: task:1.0
            env:
            - name: TZ
              value: "America/New_York"
            command:
            - sh
            - -c
            - |
              echo "Current time: $(date)"
              echo "UTC time: $(date -u)"
              ./run-task.sh
```

**4. Calculate schedule in UTC**:
```bash
# Want: 2 AM EST daily
# EST is UTC-5

# Non-DST (EST): 2 AM EST = 7 AM UTC
schedule: "0 7 * * *"

# DST (EDT): 2 AM EDT = 6 AM UTC
# Need two CronJobs or use timeZone field
```

**Best Practices**:
- Use UTC for simplicity
- Document intended local time
- Use `timeZone` field if available
- Test schedule changes around DST
- Monitor for missed schedules

---

## Scenario-Based Questions

### Q13: Design a backup strategy using CronJobs.

**Answer**: Multi-tier backup strategy:

**1. Hourly Incremental Backups**:
```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: hourly-backup
spec:
  schedule: "0 * * * *"
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 24
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: backup:1.0
            command:
            - sh
            - -c
            - |
              TIMESTAMP=$(date +%Y%m%d-%H%M)
              pg_dump --incremental /backups/hourly-$TIMESTAMP.sql
            volumeMounts:
            - name: backups
              mountPath: /backups
          restartPolicy: OnFailure
          volumes:
          - name: backups
            persistentVolumeClaim:
              claimName: backup-pvc
```

**2. Daily Full Backups**:
```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: daily-backup
spec:
  schedule: "0 2 * * *"
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 7
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: backup:1.0
            command:
            - sh
            - -c
            - |
              DATE=$(date +%Y%m%d)
              pg_dump -Fc mydb > /backups/daily-$DATE.backup
              gzip /backups/daily-$DATE.backup
              
              # Upload to S3
              aws s3 cp /backups/daily-$DATE.backup.gz \
                s3://backups/daily/$DATE.backup.gz
          restartPolicy: OnFailure
```

**3. Weekly Archive**:
```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: weekly-archive
spec:
  schedule: "0 3 * * 0"  # Sunday 3 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: archive
            image: backup:1.0
            command:
            - sh
            - -c
            - |
              WEEK=$(date +%Y-W%V)
              tar czf /backups/weekly-$WEEK.tar.gz /backups/daily-*
              aws s3 cp /backups/weekly-$WEEK.tar.gz \
                s3://backups/weekly/
          restartPolicy: OnFailure
```

**4. Monthly Long-term Archive**:
```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: monthly-archive
spec:
  schedule: "0 4 1 * *"  # 1st of month, 4 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: archive
            image: backup:1.0
            command:
            - sh
            - -c
            - |
              MONTH=$(date +%Y-%m)
              # Full backup
              pg_dump -Fc mydb > /backups/monthly-$MONTH.backup
              # Compress and encrypt
              gzip /backups/monthly-$MONTH.backup
              openssl enc -aes-256-cbc -in /backups/monthly-$MONTH.backup.gz \
                -out /backups/monthly-$MONTH.backup.gz.enc
              # Upload to glacier
              aws s3 cp /backups/monthly-$MONTH.backup.gz.enc \
                s3://backups/monthly/ --storage-class GLACIER
          restartPolicy: OnFailure
```

**5. Cleanup Old Backups**:
```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: cleanup-backups
spec:
  schedule: "0 5 * * *"  # Daily cleanup
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: cleanup
            image: backup:1.0
            command:
            - sh
            - -c
            - |
              # Delete hourly backups older than 24h
              find /backups/hourly-* -mtime +1 -delete
              
              # Delete daily backups older than 7 days
              find /backups/daily-* -mtime +7 -delete
              
              # Delete weekly backups older than 4 weeks
              find /backups/weekly-* -mtime +28 -delete
          restartPolicy: OnFailure
```

**Monitoring**:
```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: backup-verification
spec:
  schedule: "0 6 * * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: verify
            image: backup:1.0
            command:
            - sh
            - -c
            - |
              # Verify latest backup
              LATEST=$(ls -t /backups/daily-* | head -1)
              pg_restore --list $LATEST
              
              # Alert if verification fails
              if [ $? -ne 0 ]; then
                curl -X POST https://alerts.example.com/webhook \
                  -d '{"text":"Backup verification failed!"}'
                exit 1
              fi
          restartPolicy: Never
```

**Benefits**:
- Multiple recovery points
- Incremental saves space
- Long-term archival
- Automatic cleanup
- Verification built-in

---

**Key Takeaways**:
- Jobs are for one-time tasks, CronJobs for scheduled tasks
- Use appropriate completions and parallelism for workload
- Configure retries with backoffLimit
- Enable TTL for automatic cleanup
- Choose right concurrencyPolicy for CronJobs
- Monitor job success/failure rates
- Test schedules before production
- Implement proper error handling

**Next Topic**: Services & Ingress
