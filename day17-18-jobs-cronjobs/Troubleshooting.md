# Jobs & CronJobs Troubleshooting Guide

## Table of Contents
1. [Job Issues](#job-issues)
2. [CronJob Issues](#cronjob-issues)
3. [Parallel Processing Issues](#parallel-processing-issues)
4. [Resource Issues](#resource-issues)
5. [Common Errors](#common-errors)
6. [Debugging Strategies](#debugging-strategies)

---

## Job Issues

### Issue 1: Job Never Completes

**Symptoms**:
```
NAME        COMPLETIONS   DURATION   AGE
my-job      0/1           10m        10m
```

**Diagnosis**:
```bash
# Check job status
kubectl describe job my-job

# Check pods
kubectl get pods -l job-name=my-job

# Check pod logs
kubectl logs <pod-name>

# Check container exit code
kubectl get pod <pod-name> -o jsonpath='{.status.containerStatuses[0].state.terminated.exitCode}'
```

**Common Causes & Solutions**:

**1. Container doesn't exit (stays running)**:
```yaml
# Wrong - stays running
containers:
- name: task
  image: nginx  # Web server never exits
  
# Correct - exits after task
containers:
- name: task
  image: busybox
  command: ['sh', '-c', 'echo done && exit 0']
```

**2. Non-zero exit code**:
```bash
# Check exit code
kubectl logs <pod-name>

# Container must exit with code 0 for success
```

Fix:
```yaml
containers:
- name: task
  image: myapp:1.0
  command:
  - sh
  - -c
  - |
    ./run-task.sh
    EXIT_CODE=$?
    if [ $EXIT_CODE -eq 0 ]; then
      echo "Success!"
      exit 0
    else
      echo "Failed with code $EXIT_CODE"
      exit $EXIT_CODE
    fi
```

**3. Wrong restartPolicy**:
```yaml
# Wrong
restartPolicy: Always  # Not allowed for Jobs!

# Correct
restartPolicy: Never     # or OnFailure
```

---

### Issue 2: Job Keeps Failing and Restarting

**Symptoms**:
```
NAME        COMPLETIONS   DURATION   AGE
my-job      0/1           5m         5m

# Many failed pods
kubectl get pods
NAME           READY   STATUS    RESTARTS   AGE
my-job-abc     0/1     Error     0          4m
my-job-def     0/1     Error     0          3m
my-job-ghi     0/1     Error     0          2m
my-job-jkl     0/1     Error     0          1m
```

**Diagnosis**:
```bash
# Check job events
kubectl describe job my-job | grep -A 10 Events

# Check backoffLimit
kubectl get job my-job -o jsonpath='{.spec.backoffLimit}'

# Check failed pods
kubectl get pods -l job-name=my-job --field-selector status.phase=Failed
```

**Solutions**:

**1. Set appropriate backoffLimit**:
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: my-job
spec:
  backoffLimit: 3  # Stop after 3 failures
```

**2. Fix application logic**:
```bash
# Debug with logs
kubectl logs <failed-pod-name>

# Check environment
kubectl exec <running-pod> -- env

# Test locally first
docker run myapp:1.0 ./run-task.sh
```

**3. Use OnFailure restart policy**:
```yaml
spec:
  template:
    spec:
      restartPolicy: OnFailure  # Restart container, not pod
```

---

### Issue 3: Too Many Failed Pods Accumulating

**Symptoms**:
```bash
kubectl get pods | grep Error | wc -l
# Shows 50+ failed pods
```

**Diagnosis**:
```bash
# Check TTL setting
kubectl get job my-job -o jsonpath='{.spec.ttlSecondsAfterFinished}'
```

**Solutions**:

**1. Enable TTL controller**:
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: my-job
spec:
  ttlSecondsAfterFinished: 100  # Delete 100s after completion
```

**2. Manual cleanup**:
```bash
# Delete failed pods
kubectl delete pods --field-selector status.phase=Failed

# Delete completed jobs
kubectl delete jobs --field-selector status.successful=1
```

**3. Automated cleanup script**:
```bash
#!/bin/bash
# cleanup-old-jobs.sh

# Delete completed jobs older than 24 hours
kubectl get jobs -o json | \
  jq -r '.items[] | select(.status.completionTime != null) | 
         select((now - (.status.completionTime | fromdateiso8601)) > 86400) | 
         .metadata.name' | \
  xargs -r kubectl delete job

# Delete failed jobs older than 1 hour
kubectl get jobs -o json | \
  jq -r '.items[] | select(.status.failed != null) | 
         select((now - (.status.startTime | fromdateiso8601)) > 3600) | 
         .metadata.name' | \
  xargs -r kubectl delete job
```

---

### Issue 4: Job Times Out

**Symptoms**:
```
NAME        COMPLETIONS   DURATION   AGE
long-job    0/1           1h         1h

# Job status shows DeadlineExceeded
kubectl get job long-job -o jsonpath='{.status.conditions[0].reason}'
# Output: DeadlineExceeded
```

**Diagnosis**:
```bash
# Check activeDeadlineSeconds
kubectl get job long-job -o jsonpath='{.spec.activeDeadlineSeconds}'

# Check how long job has been running
kubectl get job long-job -o jsonpath='{.status.startTime}'
```

**Solutions**:

**1. Increase timeout**:
```yaml
spec:
  activeDeadlineSeconds: 7200  # 2 hours instead of 1
```

**2. Optimize job performance**:
- Reduce data processing scope
- Increase resources
- Optimize algorithm
- Use parallelism

**3. Break into smaller jobs**:
```yaml
# Instead of one long job
# Create multiple smaller jobs
apiVersion: batch/v1
kind: Job
metadata:
  name: process-batch-1
spec:
  activeDeadlineSeconds: 600  # 10 minutes each
  template:
    spec:
      containers:
      - name: processor
        image: processor:1.0
        args: ['--batch=1']
      restartPolicy: Never
```

---

### Issue 5: Parallel Jobs Not Working as Expected

**Symptoms**:
- Expected 10 parallel pods, only 2 running
- Jobs completing sequentially instead of parallel

**Diagnosis**:
```bash
# Check parallelism setting
kubectl get job my-job -o jsonpath='{.spec.parallelism}'

# Check active pods
kubectl get pods -l job-name=my-job --field-selector status.phase=Running

# Check node resources
kubectl top nodes

# Check resource quotas
kubectl describe resourcequota
```

**Common Causes & Solutions**:

**1. Insufficient cluster resources**:
```bash
# Check available resources
kubectl describe nodes | grep -A 5 "Allocated resources"

# Solution: Scale cluster or reduce resource requests
```

**2. Resource quotas limiting pods**:
```bash
# Check quota
kubectl get resourcequota

# Solution: Increase quota or reduce parallel count
```

**3. Parallelism not set**:
```yaml
# Wrong
spec:
  completions: 10
  # Missing parallelism - defaults to 1

# Correct
spec:
  completions: 10
  parallelism: 5  # 5 concurrent pods
```

---

## CronJob Issues

### Issue 6: CronJob Not Running

**Symptoms**:
```bash
kubectl get cronjobs
NAME          SCHEDULE      SUSPEND   ACTIVE   LAST SCHEDULE   AGE
my-cronjob    0 2 * * *     False     0        <none>          10m
```

**Diagnosis**:
```bash
# Check if suspended
kubectl get cronjob my-cronjob -o jsonpath='{.spec.suspend}'

# Check schedule
kubectl get cronjob my-cronjob -o jsonpath='{.spec.schedule}'

# Check controller manager logs
kubectl logs -n kube-system kube-controller-manager-<node>
```

**Solutions**:

**1. CronJob is suspended**:
```bash
# Check
kubectl get cronjob my-cronjob -o yaml | grep suspend

# Resume
kubectl patch cronjob my-cronjob -p '{"spec":{"suspend":false}}'
```

**2. Invalid schedule syntax**:
```yaml
# Wrong
schedule: "60 * * * *"  # Invalid (minute must be 0-59)

# Correct
schedule: "0 * * * *"   # Every hour

# Validate at https://crontab.guru/
```

**3. Time hasn't come yet**:
```bash
# For schedule "0 2 * * *" (2 AM daily)
# CronJob will only run at 2 AM
# Wait or test with frequent schedule:
schedule: "*/1 * * * *"  # Every minute for testing
```

---

### Issue 7: CronJob Runs Multiple Times

**Symptoms**:
```bash
kubectl get jobs
NAME                   COMPLETIONS   AGE
my-cronjob-123         1/1           5m
my-cronjob-124         1/1           5m
my-cronjob-125         1/1           5m
# Multiple jobs for same schedule time
```

**Diagnosis**:
```bash
# Check concurrency policy
kubectl get cronjob my-cronjob -o jsonpath='{.spec.concurrencyPolicy}'

# Check job history
kubectl get jobs --sort-by=.metadata.creationTimestamp
```

**Solutions**:

**1. Set concurrencyPolicy to Forbid**:
```yaml
spec:
  concurrencyPolicy: Forbid  # Don't run if previous still running
  schedule: "*/5 * * * *"
```

**2. Reduce job execution time**:
- Optimize job code
- Increase resources
- Break into smaller tasks

**3. Adjust schedule**:
```yaml
# If job takes 10 minutes, don't schedule every 5 minutes
# Wrong
schedule: "*/5 * * * *"  # Job takes 10 min

# Correct
schedule: "*/15 * * * *"  # Job takes 10 min, schedule every 15
```

---

### Issue 8: CronJob Missing Schedules

**Symptoms**:
```
Warning: Too many missed start times (> 100). Set or decrease .spec.startingDeadlineSeconds
```

**Diagnosis**:
```bash
# Check starting deadline
kubectl get cronjob my-cronjob -o jsonpath='{.spec.startingDeadlineSeconds}'

# Check controller manager logs
kubectl logs -n kube-system <controller-manager-pod> | grep cronjob
```

**Causes**:
1. Controller manager was down
2. System clock skew
3. Cluster resource constraints
4. startingDeadlineSeconds too short

**Solutions**:

**1. Set startingDeadlineSeconds**:
```yaml
spec:
  schedule: "0 2 * * *"
  startingDeadlineSeconds: 600  # 10 minutes grace period
```

**2. After fixing, reset missed count**:
```bash
# Delete and recreate CronJob
kubectl get cronjob my-cronjob -o yaml > cronjob-backup.yaml
kubectl delete cronjob my-cronjob
kubectl apply -f cronjob-backup.yaml
```

---

### Issue 9: Job History Growing Too Large

**Symptoms**:
```bash
kubectl get jobs | wc -l
# Shows 100+ old jobs

kubectl get pods | grep Completed | wc -l
# Shows 200+ completed pods
```

**Diagnosis**:
```bash
# Check history limits
kubectl get cronjob my-cronjob -o yaml | grep JobsHistoryLimit
```

**Solutions**:

**1. Set appropriate history limits**:
```yaml
spec:
  successfulJobsHistoryLimit: 3  # Keep 3 successful
  failedJobsHistoryLimit: 1      # Keep 1 failed
```

**2. Manual cleanup**:
```bash
# Delete old successful jobs
kubectl delete jobs --field-selector status.successful=1

# Delete completed pods
kubectl delete pods --field-selector status.phase=Succeeded
```

**3. Automated cleanup**:
```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: cleanup-old-jobs
spec:
  schedule: "0 0 * * *"  # Daily cleanup
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: job-cleanup-sa
          containers:
          - name: cleanup
            image: bitnami/kubectl:latest
            command:
            - sh
            - -c
            - |
              # Delete successful jobs older than 7 days
              kubectl delete jobs --field-selector status.successful=1 \
                -l cleanup=true \
                $(kubectl get jobs -o name --field-selector status.successful=1 | \
                  xargs -I {} sh -c 'kubectl get {} -o jsonpath="{.metadata.name} {.status.completionTime}" | \
                  awk -v d=$(date -d "7 days ago" +%s) "{if(system(\"date -d \" $2 \" +%s\") < d) print $1}"')
          restartPolicy: Never
```

---

## Parallel Processing Issues

### Issue 10: Uneven Work Distribution

**Symptoms**:
- Some workers finish quickly, others take long
- Inefficient resource utilization

**Diagnosis**:
```bash
# Monitor pod completion times
kubectl get pods -l job-name=my-job \
  -o custom-columns=NAME:.metadata.name,START:.status.startTime,END:.status.containerStatuses[0].state.terminated.finishedAt

# Check if using work queue vs fixed completions
kubectl get job my-job -o jsonpath='{.spec.completions}'
```

**Solutions**:

**1. Use work queue pattern**:
```yaml
spec:
  parallelism: 10
  # No completions - workers pull from queue
  template:
    spec:
      containers:
      - name: worker
        image: worker:1.0
        command:
        - sh
        - -c
        - |
          while true; do
            TASK=$(redis-cli lpop work-queue)
            [ -z "$TASK" ] && exit 0
            process_task "$TASK"
          done
```

**2. Use indexed jobs for even distribution**:
```yaml
spec:
  completions: 100
  parallelism: 10
  completionMode: Indexed
```

---

## Resource Issues

### Issue 11: Out of Memory (OOM) Kills

**Symptoms**:
```bash
kubectl get pods -l job-name=my-job
NAME        READY   STATUS      RESTARTS   AGE
my-job-abc  0/1     OOMKilled   0          1m
```

**Diagnosis**:
```bash
# Check pod events
kubectl describe pod my-job-abc | grep -A 5 OOMKilled

# Check resource limits
kubectl get job my-job -o jsonpath='{.spec.template.spec.containers[0].resources}'
```

**Solutions**:

**1. Increase memory limits**:
```yaml
spec:
  template:
    spec:
      containers:
      - name: processor
        resources:
          requests:
            memory: "2Gi"
          limits:
            memory: "4Gi"  # Increase this
```

**2. Optimize application**:
- Process data in smaller batches
- Use streaming instead of loading all in memory
- Fix memory leaks

**3. Use multiple smaller jobs**:
```yaml
# Instead of one job processing 1GB
# Create 10 jobs processing 100MB each
```

---

## Common Errors

### Error 1: "Job has reached the specified backoff limit"

**Error Message**:
```
Job has reached the specified backoff limit
```

**Meaning**: Job failed `backoffLimit` times and stopped retrying.

**Solution**:
```yaml
# Increase backoffLimit
spec:
  backoffLimit: 5  # Try 5 times instead of 3

# Or fix the underlying issue
# Check logs:
kubectl logs <failed-pod-name>
```

---

### Error 2: "Job was active longer than specified deadline"

**Error Message**:
```
Job was active longer than specified deadline
```

**Meaning**: Job exceeded `activeDeadlineSeconds`.

**Solution**:
```yaml
# Increase deadline
spec:
  activeDeadlineSeconds: 7200  # 2 hours

# Or optimize job to run faster
```

---

### Error 3: "invalid schedule"

**Error Message**:
```
The CronJob "my-cronjob" is invalid: spec.schedule: Invalid value: "invalid": invalid schedule: Expected exactly 5 fields, found 6: invalid
```

**Solution**:
```yaml
# Wrong
schedule: "0 0 0 * * *"  # 6 fields (seconds not supported)

# Correct
schedule: "0 0 * * *"    # 5 fields (min, hour, day, month, weekday)

# Validate at: https://crontab.guru/
```

---

### Error 4: "Forbidden: pod does not have a ServiceAccount"

**Solution**:
```yaml
spec:
  template:
    spec:
      serviceAccountName: job-sa  # Specify ServiceAccount
      # or use default
      automountServiceAccountToken: false  # If not needed
```

---

## Debugging Strategies

### Strategy 1: Enable Detailed Logging

**In Job**:
```yaml
spec:
  template:
    spec:
      containers:
      - name: task
        image: myapp:1.0
        command:
        - sh
        - -c
        - |
          set -x  # Enable bash debug mode
          echo "Starting job at $(date)"
          echo "Environment: $(env | sort)"
          ./run-task.sh
          EXIT_CODE=$?
          echo "Finished with exit code: $EXIT_CODE"
          exit $EXIT_CODE
```

### Strategy 2: Interactive Debugging

```bash
# Create a debug pod with same spec
kubectl run debug-job --image=myapp:1.0 -it --rm -- /bin/bash

# Inside pod, run commands manually
./run-task.sh

# Check environment
env | sort

# Test with different parameters
./run-task.sh --verbose --debug
```

### Strategy 3: Check Events Timeline

```bash
# Get all events for job
kubectl get events --field-selector involvedObject.name=my-job --sort-by='.lastTimestamp'

# Get all events in namespace
kubectl get events --sort-by='.lastTimestamp'

# Watch events in real-time
kubectl get events --watch
```

### Strategy 4: Examine Job Controller Logs

```bash
# Get controller manager logs
kubectl logs -n kube-system kube-controller-manager-<node> | grep job-controller

# Look for job-related errors
kubectl logs -n kube-system kube-controller-manager-<node> | grep "my-job"
```

---

## Quick Fixes Checklist

### Job Not Running
- [ ] Check restartPolicy (must be Never or OnFailure)
- [ ] Verify container exits with code 0
- [ ] Check resource availability
- [ ] Review pod logs for errors

### Job Keeps Failing
- [ ] Increase backoffLimit
- [ ] Fix application logic
- [ ] Check environment variables
- [ ] Verify secrets/configmaps exist

### CronJob Not Triggering
- [ ] Verify suspend: false
- [ ] Validate schedule syntax
- [ ] Check time is correct
- [ ] Review controller manager logs

### Too Many Failed Pods
- [ ] Enable ttlSecondsAfterFinished
- [ ] Set appropriate backoffLimit
- [ ] Clean up manually
- [ ] Fix root cause

---

## Prevention Best Practices

1. **Always set resource limits**
2. **Enable TTL for automatic cleanup**
3. **Use appropriate restart policies**
4. **Set reasonable backoffLimit**
5. **Configure activeDeadlineSeconds**
6. **Test jobs before deploying CronJobs**
7. **Monitor job success/failure rates**
8. **Implement proper logging**
9. **Use idempotent operations**
10. **Document expected behavior**

---

**Remember**: Most job issues are application-level, not Kubernetes-level. Always check application logs first!
