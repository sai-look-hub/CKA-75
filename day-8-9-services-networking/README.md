Day 8-9: Kubernetes Services & Networking Basics

![Kubernetes](https://img.shields.io/badge/Kubernetes-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white)

![CKA Preparation](https://img.shields.io/badge/CKA-Preparation-orange?style=for-the-badge)

![Day 8-9](https://img.shields.io/badge/Day-7--8-blue?style=for-the-badge)

![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)


Part of the 75-Day CKA Preparation Journey

Master Kubernetes Services and Networking - essential skills for the CKA exam and real-world Kubernetes operations.

📋 Table of Contents

Overview
Learning Objectives
Repository Structure
Quick Start
What's Included
Prerequisites
Project Architecture
Usage
Key Concepts
Resources
Contributing
License
Connect


**🎯 Overview**
This repository contains comprehensive materials for Day 7-8 of my CKA certification journey, focusing on Kubernetes Services and Networking Basics.
Duration: 8 hours
Difficulty: Intermediate
CKA Exam Weight: ~20%
What You'll Learn

✅ All 4 Service Types (ClusterIP, NodePort, LoadBalancer, ExternalName)
✅ Service Discovery using DNS
✅ Network Troubleshooting Techniques
✅ Multi-tier Application Architecture
✅ Headless Services for StatefulSets
✅ Real-world Production Patterns


**📚 Repository Structure**
day-7-8-services-networking/
│
├── README.md                          # This file - Quick start guide
├── GUIDE.md                           # Comprehensive learning guide
├── INTERVIEW-QA.md                    # 50+ interview questions & answers
├── COMMANDS-CHEATSHEET.md             # Essential kubectl commands
│
├── manifests/                         # All Kubernetes YAML files
│   ├── 01-namespace.yaml
│   ├── 02-database/
│   │   ├── mysql-statefulset.yaml
│   │   ├── mysql-configmap.yaml
│   │   └── mysql-secret.yaml
│   ├── 03-cache/
│   │   ├── redis-deployment.yaml
│   │   └── redis-service.yaml
│   ├── 04-backend/
│   │   ├── backend-deployment.yaml
│   │   ├── backend-service.yaml
│   │   └── backend-configmap.yaml
│   ├── 05-frontend/
│   │   ├── frontend-deployment.yaml
│   │   ├── frontend-service.yaml
│   │   └── nginx-configmap.yaml
│   ├── 06-monitoring/
│   │   ├── monitoring-deployment.yaml
│   │   └── monitoring-nodeport.yaml
│   ├── 07-external/
│   │   └── external-service.yaml
│   └── complete-project.yaml          # All-in-one deployment
│
├── examples/                          # Service type examples
│   ├── clusterip-example.yaml
│   ├── nodeport-example.yaml
│   ├── loadbalancer-example.yaml
│   ├── externalname-example.yaml
│   ├── headless-example.yaml
│   └── session-affinity-example.yaml
│
├── troubleshooting/
│   ├── debug-commands.md
│   ├── common-issues.md
│   └── network-testing.md
│
├── scripts/
│   ├── deploy.sh                      # Automated deployment
│   ├── cleanup.sh                     # Cleanup resources
│   ├── test.sh                        # Run tests
│   └── monitor.sh                     # Monitor deployment
│
└── diagrams/
    ├── architecture.png
    ├── service-types.png
    └── network-flow.png

**🚀 Quick Start
Prerequisites**

  Kubernetes cluster (v1.24+)
  kubectl configured
  2GB+ free memory
  Basic Kubernetes knowledge
  
  One-Command Deployment
  bash# Clone repository
  git clone https://github.com/yourusername/day-7-8-services-networking.git
  cd day-7-8-services-networking

# Deploy complete project
kubectl apply -f manifests/complete-project.yaml

# Watch deployment progress
kubectl get all -n multi-tier-app -w
Step-by-Step Deployment
bash# 1. Create namespace
kubectl apply -f manifests/01-namespace.yaml

# 2. Deploy database layer
kubectl apply -f manifests/02-database/

# 3. Wait for MySQL to be ready
kubectl wait --for=condition=ready pod -l app=mysql -n multi-tier-app --timeout=180s

# 4. Deploy cache layer
kubectl apply -f manifests/03-cache/

# 5. Deploy backend API
kubectl apply -f manifests/04-backend/

# 6. Deploy frontend
kubectl apply -f manifests/05-frontend/

# 7. Get external IP
kubectl get svc frontend -n multi-tier-app
Verify Deployment
bash# Check all resources
kubectl get all -n multi-tier-app

# Check services
kubectl get svc -n multi-tier-app

# Test backend from within cluster
kubectl run test --image=curlimages/curl -it --rm -n multi-tier-app -- \
  curl http://backend:8080

# Access frontend (replace with your external IP)
curl http://<EXTERNAL-IP>

📦 What's Included
1. Complete Documentation

  GUIDE.md - Deep dive into all concepts
  INTERVIEW-QA.md - 50+ questions with detailed answers
  COMMANDS-CHEATSHEET.md - Quick reference for kubectl commands

2. Production-Ready Project
Multi-tier application demonstrating all service types:

  Frontend (Nginx) - LoadBalancer Service
  Backend API (Node.js) - ClusterIP Service
  Cache (Redis) - ClusterIP Service
  Database (MySQL) - Headless Service (StatefulSet)
  Monitoring - NodePort Service
  External API - ExternalName Service

3. Hands-On Examples

  ClusterIP for internal communication
  NodePort for development access
  LoadBalancer for production exposure
  ExternalName for external service integration
  Headless services for StatefulSets
  Session affinity configuration
  Multi-port services

4. Troubleshooting Guide

  Common networking issues
  DNS resolution problems
  Service endpoint debugging
  Network testing commands
  Real-world scenarios

5. Automation Scripts

  Automated deployment
  Testing scripts
  Cleanup utilities
  Monitoring helpers


**🏗️ Project Architecture**

┌─────────────────────────────────────────────┐
│         Internet/External Users              │
└─────────────────┬───────────────────────────┘
                  │
                  ▼
        ┌─────────────────────┐
        │   LoadBalancer      │ ← External Access (Port 80)
        │   (Frontend)        │
        └──────────┬──────────┘
                   │
                   ▼
        ┌─────────────────────┐
        │   Frontend Pods     │
        │   Nginx + HTML      │
        └──────────┬──────────┘
                   │
                   ▼
        ┌─────────────────────┐
        │   ClusterIP         │ ← Internal Only (Port 8080)
        │   (Backend API)     │
        └──────────┬──────────┘
                   │
           ┌───────┴───────┐
           ▼               ▼
  ┌────────────┐   ┌────────────┐
  │  ClusterIP │   │  Headless  │
  │  (Redis)   │   │  (MySQL)   │
  └────────────┘   └────────────┘
       Cache         Database


Service Types Used:

🌐 LoadBalancer - Frontend (external access)
🔒 ClusterIP - Backend API & Redis (internal only)
🎯 Headless - MySQL StatefulSet (direct pod access)
🔧 NodePort - Monitoring (testing/dev access)
🔗 ExternalName - External API integration


💻 Usage
Test Service Discovery
bash# Test DNS resolution
kubectl run -it --rm debug --image=busybox -n multi-tier-app -- \
  nslookup backend.multi-tier-app.svc.cluster.local

# Test backend connectivity
kubectl run -it --rm test --image=curlimages/curl -n multi-tier-app -- \
  curl http://backend:8080

# Test from another pod
kubectl exec -it <frontend-pod> -n multi-tier-app -- \
  curl http://backend:8080
Test Different Service Types
bash# ClusterIP (internal only)
kubectl run test --image=curlimages/curl -it --rm -n multi-tier-app -- \
  curl http://backend:8080

# NodePort (external via node IP)
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}')
curl http://$NODE_IP:30090

# LoadBalancer (external IP)
EXTERNAL_IP=$(kubectl get svc frontend -n multi-tier-app -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl http://$EXTERNAL_IP
Monitor Services
bash# Watch service changes
kubectl get svc -n multi-tier-app -w

# Check endpoints
kubectl get endpoints -n multi-tier-app

# Describe service
kubectl describe svc frontend -n multi-tier-app

# View service logs
kubectl logs -l app=backend -n multi-tier-app
Cleanup
bash# Delete all resources
kubectl delete namespace multi-tier-app

# Or use cleanup script
./scripts/cleanup.sh

🎓 Key Concepts
Service Types Summary
TypeUse CaseAccessibilityWhen to UseClusterIPInternal communicationCluster-onlyBackend APIs, databases, internal servicesNodePortDevelopment/TestingNode IP + PortDevelopment, on-prem without LBLoadBalancerProductionExternal IPProduction apps, public servicesExternalNameExternal integrationDNS CNAMEExternal databases, third-party APIsHeadlessDirect pod accessPod IPsStatefulSets, peer-to-peer apps
DNS Patterns
bash# Service DNS
<service-name>.<namespace>.svc.cluster.local

# Pod DNS (with headless service)
<pod-name>.<service-name>.<namespace>.svc.cluster.local

# Examples
backend.multi-tier-app.svc.cluster.local
mysql-0.mysql.multi-tier-app.svc.cluster.local
Port Mapping
yamlports:
  - port: 80           # Service port (what clients connect to)
    targetPort: 8080   # Container port (where app listens)
    nodePort: 30080    # Node port (only for NodePort/LoadBalancer)

**📖 Resources
Documentation Files**

  GUIDE.md - Complete learning guide with theory
  INTERVIEW-QA.md - Interview preparation
  COMMANDS-CHEATSHEET.md - Command reference
  Troubleshooting Guide - Debug common issues

Official Kubernetes Docs

Services
DNS for Services
Network Policies

CKA Preparation

CKA Curriculum
Killer.sh Practice Exam
Kubernetes Documentation


**🎯Next Steps**
After completing Day 7-8, continue to:
Day 9-10: Persistent Storage & Volumes

PersistentVolumes (PV)
PersistentVolumeClaims (PVC)
StorageClasses
Volume types and access modes


**🤝 Contributing**
Contributions are welcome! Please feel free to:

  Fork the repository
  Create a feature branch (git checkout -b feature/improvement)
  Commit your changes (git commit -am 'Add new example')
  Push to the branch (git push origin feature/improvement)
  Open a Pull Request

Areas for Contribution

  Additional service examples
  More troubleshooting scenarios
  Translation to other languages
  Improved documentation
  Bug fixes


📝 License
This project is licensed under the MIT License - see the LICENSE file for details.

📞 Connect With Me
I'm documenting my entire CKA journey on LinkedIn!

💼 LinkedIn: www.linkedin.com/in/saikumara
🐙 GitHub: https://github.com/sai-look-hub/CKA-75/
📧 Email: ankadalasaikumar222@gmail.com


**Follow My Journey**

  ⭐ Star this repository
  👁️ Watch for updates
  🔄 Share with your network
  💬 Open issues for questions


⭐ Show Your Support
If you found this helpful:

⭐ Star this repository
🍴 Fork for your own learning
📢 Share with others preparing for CKA
💬 Provide feedback via issues
