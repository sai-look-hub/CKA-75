# Day 17-18: Jobs & CronJobs - Complete Guide

## Table of Contents
1. [Introduction](#introduction)
2. [Jobs Deep Dive](#jobs-deep-dive)
3. [CronJobs Mastery](#cronjobs-mastery)
4. [Parallel Processing](#parallel-processing)
5. [Job Patterns](#job-patterns)
6. [Scheduling & Automation](#scheduling--automation)
7. [Real-World Projects](#real-world-projects)
8. [Best Practices](#best-practices)
9. [Troubleshooting](#troubleshooting)

---

## Introduction

### What are Jobs?

A **Job** creates one or more Pods and ensures that a specified number of them successfully terminate. Jobs track the successful completions and when a specified number of successful completions is reached, the Job itself is complete.

**Key Characteristics**:
- Run to completion (not continuous)
- Retry on failure
- Parallel execution support
- Automatic pod cleanup
- Guaranteed completion

### What are CronJobs?

A **CronJob** creates Jobs on a repeating schedule. One CronJob object is like one line of a crontab (cron table) file on a Unix system - it runs a job periodically on a given schedule.

**Key Characteristics**:
- Scheduled execution
- Creates Jobs automatically
- Recurring tasks
- Concurrency control
- History management

---

## Jobs Deep Dive

### Basic Job Example

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: hello-job
spec:
  template:
    spec:
      containers:
      - name: hello
        image: busybox:1.34
        command: ['sh', '-c', 'echo "Hello from Job!" && sleep 5']
      restartPolicy: Never
```

**Key Components**:
- `template`: Pod template (like Deployment)
- `restartPolicy`: Must be `Never` or `OnFailure`
- No `replicas` field (use `completions` instead)

### Completions and Parallelism

#### Completions

Specifies how many successful Pod completions are needed:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: completion-job
spec:
  completions: 5        # Run 5 successful pods
  template:
    spec:
      containers:
      - name: worker
        image: busybox:1.34
        command: ['sh', '-c', 'echo "Processing..." && sleep 2']
      restartPolicy: Never
```

**Behavior**: Creates pods sequentially until 5 succeed.

#### Parallelism

Specifies how many pods should run concurrently:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: parallel-job
spec:
  completions: 10       # Total successful completions
  parallelism: 3        # Run 3 pods at a time
  template:
    spec:
      containers:
      - name: worker
        image: busybox:1.34
        command: ['sh', '-c', 'echo "Worker $HOSTNAME" && sleep 5']
      restartPolicy: Never
```

**Behavior**: 
- Creates 3 pods initially
- When one completes, starts another
- Continues until 10 successful completions

#### Combinations

| Completions | Parallelism | Behavior |
|-------------|-------------|----------|
| 1 (default) | 1 (default) | Single pod, runs once |
| 5 | 1 | 5 pods, one at a time (sequential) |
| 5 | 3 | 5 pods total, 3 concurrent |
| unset | 5 | Work queue pattern (runs until queue empty) |

### Restart Policies

**Never**:
```yaml
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: task
        image: task-runner:1.0
```
- Pod fails → New pod created
- Good for: Non-idempotent operations

**OnFailure**:
```yaml
spec:
  template:
    spec:
      restartPolicy: OnFailure
      containers:
      - name: task
        image: task-runner:1.0
```
- Pod fails → Container restarted in same pod
- Good for: Idempotent operations, saves pod overhead

**Always**: Not allowed for Jobs!

### Retry Mechanism (backoffLimit)

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: retry-job
spec:
  backoffLimit: 3       # Retry up to 3 times
  template:
    spec:
      containers:
      - name: flaky-task
        image: flaky-app:1.0
        command: ['./run-task.sh']
      restartPolicy: Never
```

**Backoff Behavior**:
- Initial delay: 10s
- Max delay: 6m
- Exponential backoff: 10s, 20s, 40s, ...
- After `backoffLimit` failures, Job marked as failed

### Timeouts (activeDeadlineSeconds)

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: timeout-job
spec:
  activeDeadlineSeconds: 3600    # 1 hour timeout
  backoffLimit: 3
  template:
    spec:
      containers:
      - name: long-task
        image: processor:1.0
        command: ['./process-data.sh']
      restartPolicy: OnFailure
```

**Behavior**:
- Job terminates after 3600 seconds (1 hour)
- All pods killed
- Job marked as failed with reason `DeadlineExceeded`
- Useful to prevent runaway jobs

### Automatic Cleanup (TTL)

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: cleanup-job
spec:
  ttlSecondsAfterFinished: 86400    # Delete after 24 hours
  template:
    spec:
      containers:
      - name: task
        image: task:1.0
      restartPolicy: Never
```

**Behavior**:
- Job automatically deleted 24 hours after completion
- Prevents accumulation of old jobs
- Pods also deleted
- Set to `0` for immediate deletion

### Pod Failure Policy (v1.25+)

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: failure-policy-job
spec:
  backoffLimit: 6
  podFailurePolicy:
    rules:
    - action: FailJob
      onExitCodes:
        containerName: main
        operator: In
        values: [42]
    - action: Ignore
      onPodConditions:
      - type: DisruptionTarget
  template:
    spec:
      containers:
      - name: main
        image: processor:1.0
      restartPolicy: Never
```

**Actions**:
- `FailJob`: Immediately fail the job
- `Ignore`: Ignore the failure, don't count against backoffLimit
- `Count`: Count against backoffLimit (default)

---

## CronJobs Mastery

### Basic CronJob

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: hello-cronjob
spec:
  schedule: "*/1 * * * *"    # Every minute
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: hello
            image: busybox:1.34
            command: ['sh', '-c', 'date; echo "Hello from CronJob"']
          restartPolicy: OnFailure
```

### Cron Schedule Syntax

**Format**: `minute hour day month weekday`

```
 ┌────────── minute (0 - 59)
 │ ┌──────── hour (0 - 23)
 │ │ ┌────── day of month (1 - 31)
 │ │ │ ┌──── month (1 - 12)
 │ │ │ │ ┌── day of week (0 - 6) (Sunday=0)
 │ │ │ │ │
 * * * * *
```

**Common Examples**:

```yaml
# Every minute
schedule: "* * * * *"

# Every 5 minutes
schedule: "*/5 * * * *"

# Every hour at minute 0
schedule: "0 * * * *"

# Every day at 2:30 AM
schedule: "30 2 * * *"

# Every Monday at 9 AM
schedule: "0 9 * * 1"

# Every 1st of month at midnight
schedule: "0 0 1 * *"

# Weekdays at 6 PM
schedule: "0 18 * * 1-5"

# Every 6 hours
schedule: "0 */6 * * *"

# Multiple times: 8 AM, noon, 6 PM
# Use separate CronJobs instead
```

**Special Characters**:
- `*` : Any value
- `,` : List (e.g., `1,15` = 1st and 15th)
- `-` : Range (e.g., `1-5` = Monday to Friday)
- `/` : Step (e.g., `*/5` = every 5 units)

### Concurrency Policies

#### Allow (Default)
```yaml
spec:
  concurrencyPolicy: Allow
  schedule: "*/1 * * * *"
```
- Multiple jobs can run concurrently
- No restrictions
- Use for: Independent tasks

#### Forbid
```yaml
spec:
  concurrencyPolicy: Forbid
  schedule: "0 2 * * *"
```
- Skip new job if previous still running
- Prevents overlapping
- Use for: Backups, long-running tasks

#### Replace
```yaml
spec:
  concurrencyPolicy: Replace
  schedule: "*/5 * * * *"
```
- Cancel old job, start new one
- Ensures latest run
- Use for: Status updates, current data processing

**Example with Forbid**:
```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: backup-db
spec:
  schedule: "0 2 * * *"
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 7
  failedJobsHistoryLimit: 3
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: backup-tool:1.0
            command: ['./backup.sh']
          restartPolicy: OnFailure
```

### History Management

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: cleanup-cronjob
spec:
  schedule: "0 0 * * *"
  successfulJobsHistoryLimit: 3    # Keep 3 successful jobs
  failedJobsHistoryLimit: 1        # Keep 1 failed job
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: cleanup
            image: cleanup:1.0
          restartPolicy: OnFailure
```

**Defaults**:
- `successfulJobsHistoryLimit`: 3
- `failedJobsHistoryLimit`: 1

**Benefits**:
- Prevents clutter
- Maintains debugging history
- Controls resource usage

### Starting Deadline

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: deadline-cronjob
spec:
  schedule: "0 2 * * *"
  startingDeadlineSeconds: 300    # Must start within 5 minutes
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: task
            image: task:1.0
          restartPolicy: OnFailure
```

**Behavior**:
- If job can't start within 300s, counted as missed
- After 100 missed schedules, CronJob stops creating jobs
- Useful for time-sensitive tasks

### Suspend CronJob

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: maintenance-job
spec:
  schedule: "0 * * * *"
  suspend: true        # Temporarily disabled
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: task
            image: task:1.0
          restartPolicy: OnFailure
```

**Use Cases**:
- Maintenance windows
- Debugging
- Temporary disable
- Testing

**Toggle via kubectl**:
```bash
# Suspend
kubectl patch cronjob maintenance-job -p '{"spec":{"suspend":true}}'

# Resume
kubectl patch cronjob maintenance-job -p '{"spec":{"suspend":false}}'
```

---

## Parallel Processing

### Fixed Completion Count Pattern

Process exactly N items with M workers:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: parallel-processing
spec:
  completions: 100      # Process 100 items
  parallelism: 10       # Use 10 workers
  template:
    spec:
      containers:
      - name: worker
        image: data-processor:1.0
        env:
        - name: ITEM_ID
          value: "$(JOB_COMPLETION_INDEX)"
      restartPolicy: Never
```

**Execution**:
```
Time 0s:  10 pods running (0-9)
Time 10s: 10 pods running (10-19)
...
Time 90s: 10 pods running (90-99)
Time 100s: All complete
```

### Work Queue Pattern

Workers pull tasks from a queue:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: work-queue
spec:
  completions: null      # No fixed count
  parallelism: 5         # 5 workers
  template:
    spec:
      containers:
      - name: worker
        image: queue-worker:1.0
        env:
        - name: QUEUE_URL
          value: "redis://queue:6379"
        command:
        - ./worker.sh
        - --queue=$(QUEUE_URL)
      restartPolicy: OnFailure
```

**Worker Logic**:
```bash
#!/bin/bash
while true; do
  TASK=$(redis-cli lpop tasks)
  if [ -z "$TASK" ]; then
    # Queue empty, exit successfully
    exit 0
  fi
  process_task "$TASK"
done
```

### Indexed Jobs (v1.24+)

Each pod gets a unique completion index:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: indexed-job
spec:
  completions: 5
  parallelism: 3
  completionMode: Indexed
  template:
    spec:
      containers:
      - name: worker
        image: processor:1.0
        env:
        - name: INDEX
          valueFrom:
            fieldRef:
              fieldPath: metadata.annotations['batch.kubernetes.io/job-completion-index']
        command:
        - sh
        - -c
        - |
          echo "Processing item $INDEX"
          ./process.sh --index=$INDEX
      restartPolicy: Never
```

**Behavior**:
- Pod 0 processes index 0
- Pod 1 processes index 1
- ...
- Pod 4 processes index 4

---

## Job Patterns

### Pattern 1: Database Migration

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: db-migration
  namespace: production
spec:
  backoffLimit: 0        # No retries (migrations should be idempotent)
  activeDeadlineSeconds: 600
  template:
    metadata:
      labels:
        app: db-migration
    spec:
      serviceAccountName: migration-sa
      containers:
      - name: migrate
        image: flyway:9.0
        command:
        - flyway
        - migrate
        env:
        - name: FLYWAY_URL
          value: "jdbc:postgresql://postgres:5432/mydb"
        - name: FLYWAY_USER
          valueFrom:
            secretKeyRef:
              name: db-secret
              key: username
        - name: FLYWAY_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-secret
              key: password
      restartPolicy: Never
```

### Pattern 2: Data Backup

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: postgres-backup
spec:
  schedule: "0 2 * * *"       # Daily at 2 AM
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 7
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: postgres:15
            command:
            - sh
            - -c
            - |
              BACKUP_FILE="/backups/backup-$(date +%Y%m%d-%H%M%S).sql"
              pg_dump -h $DB_HOST -U $DB_USER -d $DB_NAME > $BACKUP_FILE
              gzip $BACKUP_FILE
              echo "Backup completed: $BACKUP_FILE.gz"
            env:
            - name: DB_HOST
              value: "postgres.default.svc.cluster.local"
            - name: DB_USER
              valueFrom:
                secretKeyRef:
                  name: db-secret
                  key: username
            - name: DB_NAME
              value: "production"
            - name: PGPASSWORD
              valueFrom:
                secretKeyRef:
                  name: db-secret
                  key: password
            volumeMounts:
            - name: backups
              mountPath: /backups
          restartPolicy: OnFailure
          volumes:
          - name: backups
            persistentVolumeClaim:
              claimName: backup-pvc
```

### Pattern 3: Report Generation

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: weekly-report
spec:
  schedule: "0 9 * * 1"       # Monday at 9 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: report
            image: report-generator:1.0
            command:
            - python
            - generate_report.py
            - --start-date=$(date -d '7 days ago' +%Y-%m-%d)
            - --end-date=$(date +%Y-%m-%d)
            - --output=/reports/weekly-$(date +%Y%m%d).pdf
            volumeMounts:
            - name: reports
              mountPath: /reports
          restartPolicy: OnFailure
          volumes:
          - name: reports
            persistentVolumeClaim:
              claimName: reports-pvc
```

### Pattern 4: Cleanup Tasks

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: cleanup-old-data
spec:
  schedule: "0 1 * * *"       # Daily at 1 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: cleanup
            image: postgres:15
            command:
            - sh
            - -c
            - |
              psql -h $DB_HOST -U $DB_USER -d $DB_NAME <<EOF
              DELETE FROM logs WHERE created_at < NOW() - INTERVAL '30 days';
              DELETE FROM temp_data WHERE created_at < NOW() - INTERVAL '7 days';
              VACUUM ANALYZE logs;
              VACUUM ANALYZE temp_data;
              EOF
            env:
            - name: DB_HOST
              value: "postgres.default.svc.cluster.local"
            - name: DB_USER
              valueFrom:
                secretKeyRef:
                  name: db-secret
                  key: username
            - name: PGPASSWORD
              valueFrom:
                secretKeyRef:
                  name: db-secret
                  key: password
            - name: DB_NAME
              value: "production"
          restartPolicy: OnFailure
```

---

## Real-World Projects

### Project 1: ETL Data Pipeline

**Architecture**:
```
Extract (Job) → Transform (Job) → Load (Job)
     ↓              ↓                ↓
   S3 → Kafka → PostgreSQL
```

**Extract Job**:
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: etl-extract
spec:
  completions: 10
  parallelism: 5
  ttlSecondsAfterFinished: 86400
  template:
    spec:
      containers:
      - name: extract
        image: etl-extractor:2.0
        env:
        - name: SOURCE_BUCKET
          value: "s3://raw-data/"
        - name: OUTPUT_TOPIC
          value: "extracted-data"
        command:
        - python
        - extract.py
        resources:
          limits:
            memory: "2Gi"
            cpu: "1"
          requests:
            memory: "1Gi"
            cpu: "500m"
      restartPolicy: OnFailure
```

**Transform Job**:
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: etl-transform
spec:
  completions: 10
  parallelism: 3
  template:
    spec:
      containers:
      - name: transform
        image: etl-transformer:2.0
        env:
        - name: INPUT_TOPIC
          value: "extracted-data"
        - name: OUTPUT_TOPIC
          value: "transformed-data"
        command:
        - python
        - transform.py
        resources:
          limits:
            memory: "4Gi"
            cpu: "2"
      restartPolicy: OnFailure
```

**Load Job**:
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: etl-load
spec:
  completions: 1
  parallelism: 1
  template:
    spec:
      containers:
      - name: load
        image: etl-loader:2.0
        env:
        - name: INPUT_TOPIC
          value: "transformed-data"
        - name: DB_HOST
          value: "postgres.default.svc.cluster.local"
        - name: DB_USER
          valueFrom:
            secretKeyRef:
              name: db-secret
              key: username
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-secret
              key: password
        command:
        - python
        - load.py
      restartPolicy: OnFailure
```

### Project 2: Scheduled Operations

**Hourly Data Sync**:
```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: hourly-sync
spec:
  schedule: "0 * * * *"
  concurrencyPolicy: Forbid
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: sync
            image: data-sync:1.0
            command: ['./sync.sh']
          restartPolicy: OnFailure
```

**Daily Backup**:
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
            command: ['./backup.sh']
            volumeMounts:
            - name: backups
              mountPath: /backups
          restartPolicy: OnFailure
          volumes:
          - name: backups
            persistentVolumeClaim:
              claimName: backup-pvc
```

---

## Best Practices

### Job Best Practices

1. **Always Set Resource Limits**
```yaml
resources:
  limits:
    memory: "2Gi"
    cpu: "1"
  requests:
    memory: "1Gi"
    cpu: "500m"
```

2. **Use Appropriate Restart Policy**
```yaml
restartPolicy: OnFailure  # For idempotent tasks
restartPolicy: Never      # For non-idempotent tasks
```

3. **Configure Retries**
```yaml
backoffLimit: 3  # Retry 3 times
```

4. **Set Timeouts**
```yaml
activeDeadlineSeconds: 3600  # 1 hour max
```

5. **Enable Auto-Cleanup**
```yaml
ttlSecondsAfterFinished: 86400  # 24 hours
```

6. **Implement Idempotency**
- Design jobs to be safely re-run
- Use unique identifiers
- Check before creating/modifying

7. **Log to Persistent Storage**
- Don't rely on pod logs
- Use external logging (ELK, Loki)
- Store results in databases/object storage

### CronJob Best Practices

1. **Test Schedule Syntax**
```bash
# Use https://crontab.guru/ to validate
```

2. **Set Concurrency Policy**
```yaml
concurrencyPolicy: Forbid  # For backups, long tasks
concurrencyPolicy: Allow   # For independent tasks
concurrencyPolicy: Replace # For status updates
```

3. **Configure History Limits**
```yaml
successfulJobsHistoryLimit: 3
failedJobsHistoryLimit: 1
```

4. **Set Starting Deadline**
```yaml
startingDeadlineSeconds: 300  # 5 minutes
```

5. **Use Suspend for Maintenance**
```yaml
suspend: true  # Temporarily disable
```

6. **Monitor Executions**
- Alert on failures
- Track missed schedules
- Monitor execution time

7. **Handle Timezone**
- CronJobs use controller manager timezone
- Document expected timezone
- Consider UTC for clarity

---

## Summary

**Jobs** provide:
✅ Run-to-completion workloads
✅ Parallel processing
✅ Automatic retries
✅ Guaranteed completion
✅ Resource management

**CronJobs** enable:
✅ Scheduled automation
✅ Recurring tasks
✅ Backup strategies
✅ Maintenance operations
✅ Report generation

**Key Takeaways**:
- Use Jobs for one-time batch processing
- Use CronJobs for scheduled recurring tasks
- Configure retries and timeouts appropriately
- Enable TTL for automatic cleanup
- Monitor job executions and failures
- Test schedules before deploying
- Implement idempotent operations

**Next Steps**: Day 19-20 - Manual Schedling & Node Selection
