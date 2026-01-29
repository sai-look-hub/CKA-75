# Day 17-18: Jobs & CronJobs

## 📋 Overview

Master **Kubernetes Jobs and CronJobs** for batch processing, scheduled tasks, and automation workloads. Learn to build robust data processing pipelines and automate recurring tasks.

## 🎯 Learning Objectives

By the end of this module, you will:

- ✅ Understand Jobs and their use cases
- ✅ Master CronJob scheduling with cron syntax
- ✅ Implement parallel processing with Jobs
- ✅ Configure retry strategies and timeouts
- ✅ Manage job history and cleanup
- ✅ Build production data processing pipelines
- ✅ Automate backups and maintenance tasks
- ✅ Troubleshoot job failures
- ✅ Optimize job performance

## 📚 Topics Covered

### Jobs
- Job fundamentals and lifecycle
- Completions and parallelism
- Restart policies
- Retry mechanisms (backoffLimit)
- Timeouts (activeDeadlineSeconds)
- TTL for automatic cleanup
- Work queue pattern

### CronJobs
- Cron schedule syntax
- Job template management
- Concurrency policies
- History limits
- Suspend/resume functionality
- Timezone considerations
- Schedule validation

### Batch Processing
- Parallel data processing
- ETL pipelines
- Resource optimization
- Error handling
- Monitoring and alerts

## 🚀 Projects

### Project 1: Data Processing Pipeline
Complete ETL (Extract, Transform, Load) pipeline:
- **Extract**: Parallel file processing (10 workers)
- **Transform**: Data validation and transformation
- **Load**: Database loading with transactions
- **Cleanup**: Automatic cleanup after 24 hours

### Project 2: Automated Operations
Production-ready scheduled tasks:
- **Hourly Sync**: Data synchronization every hour
- **Daily Backup**: Database backup at 2 AM
- **Weekly Reports**: Generate reports every Sunday
- **Monthly Cleanup**: Purge old data first day of month

## 📁 Repository Structure

```
day17-18-jobs-cronjobs/
├── README.md                          # This file
├── GUIDE.md                          # Comprehensive guide
├── INTERVIEW-QA.md                   # Interview questions
├── COMMANDS-CHEATSHEET.md            # Quick reference
├── TROUBLESHOOTING.md                # Common issues
│
├── scripts/
│   ├── job-operations.sh             # Job management
│   ├── cronjob-operations.sh         # CronJob management
│   └── complete-management.sh        # All-in-one script
│
└── yaml-examples/
    ├── 01-basic-jobs/
    │   ├── simple-job.yaml
    │   ├── parallel-job.yaml
    │   ├── completion-job.yaml
    │   └── work-queue-job.yaml
    │
    ├── 02-advanced-jobs/
    │   ├── job-with-ttl.yaml
    │   ├── job-with-timeout.yaml
    │   ├── job-with-retries.yaml
    │   └── indexed-job.yaml
    │
    ├── 03-cronjobs/
    │   ├── simple-cronjob.yaml
    │   ├── backup-cronjob.yaml
    │   ├── cleanup-cronjob.yaml
    │   └── suspended-cronjob.yaml
    │
    ├── 04-data-pipeline/
    │   ├── etl-extract-job.yaml
    │   ├── etl-transform-job.yaml
    │   ├── etl-load-job.yaml
    │   ├── sync-cronjob.yaml
    │   └── deploy.sh
    │
    └── 05-scheduled-tasks/
        ├── backup-cronjob.yaml
        ├── report-cronjob.yaml
        ├── cleanup-cronjob.yaml
        ├── health-check-cronjob.yaml
        └── certificate-renewal-cronjob.yaml
```

## 🛠️ Prerequisites

- Kubernetes cluster (v1.21+)
- kubectl configured
- Basic understanding of Pods
- familiarity with cron syntax (helpful)

## 🚀 Quick Start

### Run a Simple Job

```bash
# Create and run a job
kubectl create job hello --image=busybox -- echo "Hello from Job!"

# Check job status
kubectl get jobs
kubectl describe job hello

# View pod logs
kubectl logs job/hello

# Delete job
kubectl delete job hello
```

### Create a CronJob

```bash
# Create CronJob that runs every minute
kubectl create cronjob hello-cron \
  --schedule="*/1 * * * *" \
  --image=busybox \
  -- echo "Hello from CronJob!"

# Watch jobs being created
kubectl get jobs --watch

# Check cronjob status
kubectl get cronjobs
kubectl describe cronjob hello-cron

# Suspend cronjob
kubectl patch cronjob hello-cron -p '{"spec":{"suspend":true}}'

# Delete cronjob
kubectl delete cronjob hello-cron
```

### Deploy Data Pipeline

```bash
# Navigate to data pipeline project
cd yaml-examples/04-data-pipeline/

# Deploy ETL pipeline
./deploy.sh

# Monitor job execution
kubectl get jobs -w
kubectl get pods

# Check logs
kubectl logs job/etl-extract
kubectl logs job/etl-transform
kubectl logs job/etl-load
```

## 📊 Key Concepts

### Job Patterns

#### 1. Single Pod Job
```yaml
spec:
  completions: 1      # Run once
  parallelism: 1      # One pod
```

#### 2. Parallel Fixed Completion
```yaml
spec:
  completions: 10     # 10 successful completions
  parallelism: 3      # 3 pods at a time
```

#### 3. Work Queue Pattern
```yaml
spec:
  completions: null   # Run until queue empty
  parallelism: 5      # 5 workers
```

### CronJob Schedules

| Schedule | Description | When it Runs |
|----------|-------------|--------------|
| `*/5 * * * *` | Every 5 minutes | :00, :05, :10, ... |
| `0 * * * *` | Every hour | :00 of every hour |
| `0 2 * * *` | Daily at 2 AM | 02:00 every day |
| `0 0 * * 0` | Weekly (Sunday) | Sunday at midnight |
| `0 0 1 * *` | Monthly | 1st of month at midnight |
| `0 9 * * 1-5` | Weekdays at 9 AM | Mon-Fri at 09:00 |

### Concurrency Policies

| Policy | Behavior | Use Case |
|--------|----------|----------|
| **Allow** | Multiple jobs can run concurrently | Independent tasks |
| **Forbid** | Skip new if previous still running | Backups, long tasks |
| **Replace** | Cancel old, start new | Latest data only |

## 🎓 Important Configurations

### Job Settings

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: example-job
spec:
  completions: 5                      # Run 5 times
  parallelism: 2                      # 2 concurrent pods
  backoffLimit: 3                     # Retry 3 times on failure
  activeDeadlineSeconds: 3600         # 1 hour timeout
  ttlSecondsAfterFinished: 86400      # Delete after 24 hours
  template:
    spec:
      restartPolicy: OnFailure        # Restart on failure
      containers:
      - name: processor
        image: data-processor:1.0
        resources:
          limits:
            memory: "2Gi"
            cpu: "1"
```

### CronJob Settings

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: backup
spec:
  schedule: "0 2 * * *"               # Daily at 2 AM
  concurrencyPolicy: Forbid           # Don't run concurrent
  successfulJobsHistoryLimit: 3       # Keep 3 successful
  failedJobsHistoryLimit: 1           # Keep 1 failed
  startingDeadlineSeconds: 300        # Start within 5 minutes
  suspend: false                      # Enabled
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: OnFailure
          containers:
          - name: backup
            image: backup-tool:1.0
```

## 📈 Architecture Diagrams

### Job Execution Flow
```
┌─────────────────────────────────────┐
│        Job Controller               │
│                                     │
│  ┌──────────┐  ┌──────────┐         │
│  │  Pod 1   │  │  Pod 2   │         │
│  │ Running  │  │ Running  │         │
│  └──────────┘  └──────────┘         │
│        ↓              ↓             │
│  ┌──────────┐  ┌──────────┐         │
│  │  Pod 3   │  │  Pod 4   │         │
│  │ Pending  │  │ Pending  │         │
│  └──────────┘  └──────────┘         │
│                                     │
│  completions: 4, parallelism: 2     │
└─────────────────────────────────────┘
```

### CronJob Schedule
```
┌─────────────────────────────────────┐
│         CronJob Controller          │
│                                     │
│   Schedule: "0 2 * * *"             │
│                                     │
│   02:00 ──► Creates Job-1           │
│   02:00 ──► (next day) Job-2        │
│   02:00 ──► (next day) Job-3        │
│                                     │
│   History:                          │
│   ├── Job-3 (Success) ✓             │
│   ├── Job-2 (Success) ✓             │
│   └── Job-1 (deleted)               │
└─────────────────────────────────────┘
```

## 🔍 Quick Commands

```bash
# Jobs
kubectl get jobs
kubectl describe job <n>
kubectl logs job/<n>
kubectl delete job <n>

# CronJobs
kubectl get cronjobs
kubectl describe cronjob <n>
kubectl get jobs --watch
kubectl patch cronjob <n> -p '{"spec":{"suspend":true}}'

# Debugging
kubectl get pods -l job-name=<n>
kubectl logs <pod-name>
kubectl describe pod <n>
kubectl get events --sort-by='.lastTimestamp'
```

## 💡 Pro Tips

### Job Best Practices
- Always set `backoffLimit` for retries
- Use `activeDeadlineSeconds` to prevent runaway jobs
- Enable TTL cleanup with `ttlSecondsAfterFinished`
- Set resource limits to prevent cluster issues
- Use `OnFailure` restart policy for retries
- Implement idempotent operations
- Log to persistent storage

### CronJob Best Practices
- Test schedule syntax before deploying
- Use `Forbid` concurrency for backups
- Set appropriate history limits
- Configure `startingDeadlineSeconds`
- Monitor for missed schedules
- Document timezone expectations
- Keep job execution time short
- Handle timezone changes

## 🐛 Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| Job never completes | Wrong exit code | Return 0 on success |
| Too many failed pods | No backoffLimit | Set backoffLimit: 3 |
| CronJob not running | Wrong schedule | Validate cron syntax |
| Pods accumulating | No TTL | Set ttlSecondsAfterFinished |
| Out of memory | No resource limits | Define limits |

## 📖 Documentation Files

| File | Description | Lines |
|------|-------------|-------|
| **GUIDE.md** | Complete guide with examples | ~2500 |
| **INTERVIEW-QA.md** | 25 interview Q&A | ~2000 |
| **COMMANDS-CHEATSHEET.md** | Quick command reference | ~400 |
| **TROUBLESHOOTING.md** | Common issues & solutions | ~1200 |
| **Scripts** | Automation scripts | ~900 |
| **YAML Examples** | 25+ production examples | ~1500 |

## 🎯 Learning Path

### Day 1: Jobs Fundamentals
1. Create simple jobs
2. Understand completions vs parallelism
3. Configure retry mechanisms
4. Practice job cleanup

### Day 2: CronJobs & Automation
1. Master cron syntax
2. Deploy scheduled tasks
3. Configure concurrency policies
4. Build data pipeline
5. Troubleshoot issues

## 🧪 Hands-On Exercises

1. **Exercise 1**: Create job that runs 10 times, 3 parallel
2. **Exercise 2**: Schedule daily backup at 2 AM
3. **Exercise 3**: Build parallel data processing pipeline
4. **Exercise 4**: Implement job with automatic cleanup
5. **Exercise 5**: Debug failed CronJob schedule

## 📚 Additional Resources

- [Kubernetes Jobs Documentation](https://kubernetes.io/docs/concepts/workloads/controllers/job/)
- [CronJob Documentation](https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/)
- [Cron Syntax Validator](https://crontab.guru/)
- [Job Patterns Guide](https://kubernetes.io/docs/concepts/workloads/controllers/job/#job-patterns)

## 🎓 CKA Exam Preparation

### Must Know Topics
- Create Jobs with completions/parallelism
- Write CronJobs with correct schedule
- Troubleshoot failed jobs
- Configure retry mechanisms
- Set up job cleanup
- Understand restart policies
- Manage job history

### Practice Scenarios
1. Create job that processes 100 items, 10 at a time
2. Schedule backup to run daily at midnight
3. Debug why CronJob skips executions
4. Implement job timeout and retries
5. Configure parallel processing pipeline

## 🚀 Next Steps

After completing this module:
1. ✅ Automate routine operations with CronJobs
2. ✅ Build data processing pipelines
3. ✅ Implement backup strategies
4. ✅ Practice troubleshooting scenarios
5. ✅ Move to **Day 19-20: Services & Ingress**

## 📞 Support & Feedback

- Questions? Check TROUBLESHOOTING.md
- Issues? Review INTERVIEW-QA.md
- Need help? Use automation scripts
- Practice? Run hands-on exercises

---

**🎯 Current Status**: Day 17-18 Complete  
**📈 Progress**: 24% of Kubernetes Learning Path  
**⏭️ Next Module**: Day 19-20 - Manual Scheduling & Node Selection
**🎓 Certification Ready**: CKA/CKAD Prep On Track

---

*Master batch processing and automation in Kubernetes! 🚀*
