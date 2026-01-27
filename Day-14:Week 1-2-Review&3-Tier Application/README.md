![Kubernetes](https://img.shields.io/badge/Kubernetes-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white)
![CKA Progress](https://img.shields.io/badge/CKA-27%25%20Complete-orange?style=for-the-badge)
![Status](https://img.shields.io/badge/Status-Production%20Ready-success?style=for-the-badge)


****Week 1-2 Milestone: Complete 3-Tier Production Application****

Comprehensive review of core Kubernetes concepts with hands-on implementation of a production-grade 3-tier application.

📋 Table of Contents

Overview
What We've Learned
Project Architecture
Quick Start
Repository Structure
Deployment Guide
Key Concepts Review
Troubleshooting
Resources


🎯 Overview
This repository contains the culmination of Week 1-2 learning - a complete, production-ready 3-tier application that integrates all core Kubernetes concepts.
Days Covered: 1-15
Duration: 2 weeks (60+ hours)
Difficulty: Intermediate
CKA Progress: 27% Complete
Project Highlights

✅ Production-Ready - All best practices implemented
✅ Multi-Environment - Dev, Staging, Production configs
✅ Highly Available - Multiple replicas, health checks
✅ Scalable - HPA configured, resource limits set
✅ Secure - RBAC, Network Policies, Secrets management
✅ Observable - Logging, monitoring, health endpoints
✅ Well-Documented - Complete guides and troubleshooting


📚 What We've Learned
Week 1: Foundation (Days 1-8)
Day 1-2: Kubernetes Architecture

Control Plane components
Worker Node components
etcd, API Server, Scheduler, Controllers
kubelet, kube-proxy, Container Runtime

Day 3-4: Pods & ReplicaSets

Pod lifecycle and management
Multi-container pods
Init containers and sidecar patterns
ReplicaSets for replication
Pod templates and selectors

Day 5-6: Deployments

Deployment strategies
Rolling updates and rollbacks
Blue-green deployments
Canary releases
Deployment history

Day 7-8: Services & Networking

ClusterIP for internal communication
NodePort for development access
LoadBalancer for production
Headless services for StatefulSets
Service discovery and DNS

Week 2: Organization & Configuration (Days 9-15)
Day 9: Review & Practice

Hands-on lab exercises
Troubleshooting practice
Interview question review

Day 10-11: Namespaces & Labels

Namespace strategies
Label taxonomy
Resource quotas
Limit ranges
Multi-tenant isolation
RBAC basics

Day 12-13: Configuration Management

ConfigMaps for application config
Secrets for sensitive data
Environment variables vs volume mounts
Immutable configurations
Secret encryption at rest
External secret managers

Day 14-15: Integration & Review

Putting it all together
3-tier application deployment
Best practices implementation
Production readiness checklist


🏗️ Project Architecture
High-Level Overview
┌─────────────────────────────────────────────────────────────┐
│                    Production Namespace                     │
│                                                             │
│  ┌────────────────────────────────────────────────────┐     │
│  │                  Frontend Tier                     │     │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐          │     │
│  │  │ React    │  │ React    │  │ React    │          │     │
│  │  │ + Nginx  │  │ + Nginx  │  │ + Nginx  │          │     │
│  │  └────┬─────┘  └────┬─────┘  └────┬─────┘          │     │
│  └───────┼─────────────┼─────────────┼────────────────┘     │
│          └─────────────┴─────────────┘                      │
│                        │                                    │
│           ┌────────────▼─────────────┐                      │
│           │   LoadBalancer Service   │                      │
│           │   External IP: Public    │                      │
│           └────────────┬─────────────┘                      │
│                        │                                    │
│  ┌─────────────────────▼───────────────────────────── ─┐    │
│  │                  Backend Tier                       │    │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌────┐      │    │
│  │  │ Node.js  │ │ Node.js  │ │ Node.js  │ │... │      │    │
│  │  │   API    │ │   API    │ │   API    │ │ x5 │      │    │
│  │  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┘      │    │
│  └───────┼────────────┼────────────┼─────────────────--┘    │
│          └────────────┴────────────┘                        │
│                       │                                     │
│          ┌────────────▼──────────────┐                      │
│          │   ClusterIP Service       │                      │
│          │   Internal Only           │                      │
│          └────────────┬──────────────┘                      │
│                       │                                     │
│     ┌─────────────────┼─────────────────┐                   │
│     │                 │                 │                   │
│     ▼                 ▼                 ▼                   │
│  ┌──────────┐  ┌──────────┐  ┌──────────────┐               │
│  │          │  │          │  │              │               │
│  │ PostgreSQL PostgreSQL │  │ Redis Cache   │               │
│  │ Primary  │  │ Replica  │  │              │               │
│  │          │  │          │  │              │               │
│  │ StatefulSet StatefulSet   ClusterIP      │               │
│  │          │  │          │  │              │               │
│  └──────────┘  └──────────┘  └──────────────┘               │
│       │              │                                      │
│       └──────────────┘                                      │
│              │                                              │
│    ┌─────────▼────────────┐                                 │
│    │  Headless Service    │                                 │
│    │  StatefulSet DNS     │                                 │
│    └──────────────────────┘                                 │
│              │                                              │
│    ┌─────────▼────────────┐                                 │
│    │ PersistentVolumeClaim│                                 │
│    │   Storage 100Gi      │                                 │
│    └──────────────────────┘                                 │
└─────────────────────────────────────────────────────────────┘
Component Details
Frontend Tier

Technology: React with Nginx
Replicas: 3
Service Type: LoadBalancer
Scaling: HPA (3-10 pods)
Configuration: ConfigMap for API endpoints
Resources:

Requests: 100m CPU, 128Mi RAM
Limits: 200m CPU, 256Mi RAM



Backend Tier

Technology: Node.js/Express API
Replicas: 5
Service Type: ClusterIP
Scaling: HPA (5-20 pods)
Configuration:

ConfigMap for app settings
Secrets for API keys


Resources:

Requests: 250m CPU, 256Mi RAM
Limits: 500m CPU, 512Mi RAM



Database Tier

Technology: PostgreSQL 14
Deployment: StatefulSet
Replicas: 3 (1 primary + 2 replicas)
Service Type: Headless
Storage: PersistentVolumeClaim (100Gi)
Configuration: Secrets for credentials
Resources:

Requests: 500m CPU, 1Gi RAM
Limits: 1000m CPU, 2Gi RAM



Cache Layer

Technology: Redis
Replicas: 1 (or 3 for HA)
Service Type: ClusterIP
Configuration: ConfigMap
Resources:

Requests: 100m CPU, 128Mi RAM
Limits: 200m CPU, 256Mi RAM




🚀 Quick Start
Prerequisites

Kubernetes cluster (v1.24+)
kubectl configured
8GB+ available memory
LoadBalancer support (cloud or MetalLB)
Storage provisioner

5-Minute Deployment
bash# 
Clone repository
git clone https://github.com/yourusername/cka-week1-2-review.git
cd cka-week1-2-review

# Deploy production environment
./deploy.sh production

# Wait for deployment (2-3 minutes)
kubectl wait --for=condition=ready pod -l tier=frontend -n production --timeout=300s

# Get application URL
kubectl get svc frontend -n production
Verify Deployment
bash# Check all resources
kubectl get all -n production

# Test frontend
EXTERNAL_IP=$(kubectl get svc frontend -n production -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl http://$EXTERNAL_IP

# Test backend (from within cluster)
kubectl run test --image=curlimages/curl -it --rm -n production -- \
  curl http://backend:8080/api/health

# Check database
kubectl exec -it postgres-0 -n production -- psql -U postgres -c "\l"


cka-week1-2-review/
│
├── README.md                          # This file
├── GUIDE.md                           # Comprehensive review guide
├── INTERVIEW-QA.md                    # 200+ interview questions
├── TROUBLESHOOTING.md                 # Common issues & solutions
├── LESSONS-LEARNED.md                 # Key takeaways
│
├── manifests/                         # All Kubernetes manifests
│   ├── 00-namespace/
│   │   ├── development.yaml
│   │   ├── staging.yaml
│   │   └── production.yaml
│   │
│   ├── 01-frontend/
│   │   ├── configmap.yaml
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   └── hpa.yaml
│   │
│   ├── 02-backend/
│   │   ├── configmap.yaml
│   │   ├── secret.yaml
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   └── hpa.yaml
│   │
│   ├── 03-database/
│   │   ├── configmap.yaml
│   │   ├── secret.yaml
│   │   ├── statefulset.yaml
│   │   ├── service-headless.yaml
│   │   └── pvc.yaml
│   │
│   ├── 04-cache/
│   │   ├── configmap.yaml
│   │   ├── deployment.yaml
│   │   └── service.yaml
│   │
│   ├── 05-security/
│   │   ├── rbac.yaml
│   │   ├── network-policies.yaml
│   │   └── pod-security-policy.yaml
│   │
│   ├── 06-monitoring/
│   │   ├── prometheus.yaml
│   │   └── grafana.yaml
│   │
│   └── complete/
│       ├── development-complete.yaml
│       ├── staging-complete.yaml
│       └── production-complete.yaml
│
├── app/                               # Application source code
│   ├── frontend/
│   │   ├── src/
│   │   ├── Dockerfile
│   │   ├── nginx.conf
│   │   └── package.json
│   │
│   ├── backend/
│   │   ├── src/
│   │   ├── Dockerfile
│   │   └── package.json
│   │
│   └── database/
│       └── init-scripts/
│
├── scripts/
│   ├── deploy.sh                      # Deployment automation
│   ├── cleanup.sh                     # Cleanup script
│   ├── test.sh                        # Integration tests
│   ├── scale.sh                       # Scaling utilities
│   ├── backup.sh                      # Backup database
│   └── restore.sh                     # Restore database
│
├── monitoring/
│   ├── dashboards/
│   └── alerts/
│
├── docs/
│   ├── architecture.md
│   ├── deployment-guide.md
│   ├── operations-guide.md
│   └── security-guide.md
│
└── tests/
    ├── integration/
    ├── smoke/
    └── load/


📖 Deployment Guide
Step-by-Step Deployment
Step 1: Create Namespaces
bash# Create all namespaces
kubectl apply -f manifests/00-namespace/

# Verify
kubectl get namespaces
Step 2: Deploy Database Tier
bash# Apply secrets
kubectl apply -f manifests/03-database/secret.yaml -n production

# Apply ConfigMap
kubectl apply -f manifests/03-database/configmap.yaml -n production

# Deploy StatefulSet
kubectl apply -f manifests/03-database/statefulset.yaml -n production

# Create headless service
kubectl apply -f manifests/03-database/service-headless.yaml -n production

# Wait for database
kubectl wait --for=condition=ready pod -l app=postgres -n production --timeout=300s

# Verify
kubectl get statefulset -n production
kubectl get pvc -n production
Step 3: Deploy Cache Layer
bash# Apply ConfigMap
kubectl apply -f manifests/04-cache/configmap.yaml -n production

# Deploy Redis
kubectl apply -f manifests/04-cache/deployment.yaml -n production
kubectl apply -f manifests/04-cache/service.yaml -n production

# Wait for Redis
kubectl wait --for=condition=ready pod -l app=redis -n production --timeout=120s
Step 4: Deploy Backend Tier
bash# Apply ConfigMap
kubectl apply -f manifests/02-backend/configmap.yaml -n production

# Apply Secrets
kubectl apply -f manifests/02-backend/secret.yaml -n production

# Deploy backend
kubectl apply -f manifests/02-backend/deployment.yaml -n production
kubectl apply -f manifests/02-backend/service.yaml -n production

# Apply HPA
kubectl apply -f manifests/02-backend/hpa.yaml -n production

# Wait for backend
kubectl wait --for=condition=ready pod -l app=backend -n production --timeout=180s
Step 5: Deploy Frontend Tier
bash# Apply ConfigMap
kubectl apply -f manifests/01-frontend/configmap.yaml -n production

# Deploy frontend
kubectl apply -f manifests/01-frontend/deployment.yaml -n production
kubectl apply -f manifests/01-frontend/service.yaml -n production

# Apply HPA
kubectl apply -f manifests/01-frontend/hpa.yaml -n production

# Wait for frontend
kubectl wait --for=condition=ready pod -l app=frontend -n production --timeout=180s
Step 6: Apply Security Policies
bash# Apply RBAC
kubectl apply -f manifests/05-security/rbac.yaml -n production

# Apply Network Policies
kubectl apply -f manifests/05-security/network-policies.yaml -n production
Step 7: Verify Deployment
bash# Check all resources
kubectl get all -n production

# Check services
kubectl get svc -n production

# Get frontend URL
FRONTEND_URL=$(kubectl get svc frontend -n production -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Application available at: http://$FRONTEND_URL"

# Run smoke tests
./scripts/test.sh production

🎓 Key Concepts Review
Services Summary
Service TypeUse CaseExample in ProjectClusterIPInternal communicationBackend API, Redis CacheLoadBalancerExternal accessFrontend applicationHeadlessDirect pod accessPostgreSQL StatefulSet
ConfigMaps vs Secrets
AspectConfigMapsSecretsIn ProjectAPI endpoints, app configsDB passwords, API keysSecurityPlain textBase64 + encryption at restBest ForNon-sensitive configCredentials, certificates
Resource Management
yaml# Every container has:
resources:
  requests:  # Guaranteed
    cpu: "250m"
    memory: "256Mi"
  limits:    # Maximum allowed
    cpu: "500m"
    memory: "512Mi"
Health Checks
yaml# Implemented in all containers
livenessProbe:   # Restart if unhealthy
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 10

readinessProbe:  # Remove from service if not ready
  httpGet:
    path: /ready
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 5

🔧 Troubleshooting
Common Issues
Issue 1: Frontend Can't Reach Backend
Symptoms:
Failed to fetch data from API
CORS errors in browser
Debug:
bash# Check backend service
kubectl get svc backend -n production

# Check backend endpoints
kubectl get endpoints backend -n production

# Test from frontend pod
kubectl exec -it <frontend-pod> -n production -- curl http://backend:8080/health
Solution:
bash# Verify service selector matches pod labels
kubectl describe svc backend -n production | grep Selector
kubectl get pods -l app=backend -n production --show-labels
Issue 2: Database Connection Failed
Symptoms:
Backend logs show: "Connection refused to postgres"
Debug:
bash# Check StatefulSet
kubectl get statefulset postgres -n production

# Check pods
kubectl get pods -l app=postgres -n production

# Check headless service
kubectl get svc postgres -n production

# Test DNS
kubectl run test --image=busybox -it --rm -n production -- \
  nslookup postgres.production.svc.cluster.local
Solution:
bash# Verify connection string in backend ConfigMap
kubectl get cm backend-config -n production -o yaml

# Should be: postgres.production.svc.cluster.local:5432
Issue 3: Pods Stuck in Pending
Symptoms:
Pods show STATUS: Pending
Never reach Running state
Debug:
bash# Describe pod
kubectl describe pod <pod-name> -n production

# Check events
kubectl get events -n production --sort-by='.lastTimestamp'

# Check resource quotas
kubectl describe resourcequota -n production
Solution:
bash# If insufficient resources:
kubectl top nodes
kubectl top pods -n production

# Scale down or increase cluster resources
Quick Diagnostic Commands
bash# Check everything
kubectl get all -n production

# Pod status
kubectl get pods -n production -o wide

# Pod logs
kubectl logs -f <pod-name> -n production

# Previous pod logs (if crashed)
kubectl logs <pod-name> -n production --previous

# Events
kubectl get events -n production --sort-by='.lastTimestamp'

# Resource usage
kubectl top pods -n production
kubectl top nodes

# Service endpoints
kubectl get endpoints -n production

# Network connectivity test
kubectl run netshoot --image=nicolaka/netshoot -it --rm -n production -- bash

📊 Monitoring & Observability
Health Endpoints
bash# Frontend health
curl http://$FRONTEND_URL/health

# Backend health (from within cluster)
kubectl run test --image=curlimages/curl -it --rm -n production -- \
  curl http://backend:8080/api/health

# Database health
kubectl exec -it postgres-0 -n production -- \
  pg_isready -U postgres
Metrics
bash# Pod metrics
kubectl top pods -n production

# Node metrics
kubectl top nodes

# HPA status
kubectl get hpa -n production

# Resource quota usage
kubectl describe resourcequota -n production
Logging
bash# View logs
kubectl logs -f deployment/backend -n production

# Logs from all pods with label
kubectl logs -l app=backend -n production --tail=100

# Logs with timestamps
kubectl logs deployment/backend -n production --timestamps

# Follow logs from multiple pods
stern backend -n production

📖 Resources
Documentation

GUIDE.md - Complete review of Week 1-2 concepts
INTERVIEW-QA.md - 200+ interview questions
TROUBLESHOOTING.md - Detailed troubleshooting guide
LESSONS-LEARNED.md - Key takeaways and mistakes

Architecture Diagrams

docs/architecture.md - Detailed architecture
docs/network-flow.md - Network traffic flow
docs/security.md - Security implementation

Scripts

scripts/deploy.sh - Automated deployment
scripts/test.sh - Integration tests
scripts/backup.sh - Database backup


🎯 What's Next
Week 3 Preview (Days 16-22)

Day 15-16: Persistent Storage & Volumes
Day 17-18: StatefulSets Deep Dive
Day 19-20: DaemonSets & Jobs
Day 21: Week 3 Review


📊 Progress Tracker

 Week 1 (Days 1-8): Foundation ✅
 Week 2 (Days 9-14): Organization & Config ✅
 Week 3 (Days 15-21): Storage & Workloads
 Week 4 (Days 22-28): Scheduling & Lifecycle
 ...continuing to Day 75

Overall Progress: 27% Complete 📈

<div align="center">
🎉 Week 1-2 Complete! 🎉
Production-ready skills acquired!
Made with ❤️ and lots of ☕

⭐ Star this repo | 🍴 Fork for your learning | 📢 Share your progress
</div>
