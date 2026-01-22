****Day 10-11: Kubernetes Namespaces & Labels****

![Kubernetes](https://img.shields.io/badge/Kubernetes-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white)
![CKA Preparation](https://img.shields.io/badge/CKA-Preparation-orange?style=for-the-badge)
![Day 10-11](https://img.shields.io/badge/Day-10--11-blue?style=for-the-badge)
![License: MIT](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)

Part of the 75-Day CKA Preparation Journey

Master Kubernetes resource organization, isolation, and multi-tenancy through Namespaces and Labels.

**📋 Table of Contents**

Overview
Learning Objectives
Repository Structure
Quick Start
What's Included
Prerequisites
Project Architecture
Key Concepts
Resources
Next Steps


**🎯 Overview**
This repository contains comprehensive materials for Day 10-11 of my CKA certification journey, focusing on Namespaces, Labels, and Resource Organization.
Duration: 8 hours
Difficulty: Intermediate
CKA Exam Weight: ~15%
What You'll Master

✅ Namespace design patterns and strategies
✅ Label selectors (equality and set-based)
✅ Annotations for metadata
✅ Resource quotas and limits
✅ Multi-tenant cluster setup
✅ RBAC integration with namespaces
✅ Network isolation
✅ Cost allocation and chargeback


**📚 Repository Structure**
day-10-11-namespaces-labels/
│
├── README.md                          # This file - Quick start
├── GUIDE.md                           # Comprehensive learning guide
├── INTERVIEW-QA.md                    # 60+ interview Q&A
├── COMMANDS-CHEATSHEET.md             # kubectl commands reference
├── TROUBLESHOOTING.md                 # Common issues & solutions
├── LABEL-TAXONOMY.md                  # Label best practices guide
│
├── manifests/                         # All Kubernetes YAML files
│   ├── 01-namespaces/
│   │   ├── tenant-a-namespace.yaml
│   │   ├── tenant-b-namespace.yaml
│   │   ├── tenant-c-namespace.yaml
│   │   └── system-namespaces.yaml
│   ├── 02-resource-quotas/
│   │   ├── tenant-a-quota.yaml
│   │   ├── tenant-b-quota.yaml
│   │   └── tenant-c-quota.yaml
│   ├── 03-limit-ranges/
│   │   ├── tenant-a-limits.yaml
│   │   ├── tenant-b-limits.yaml
│   │   └── tenant-c-limits.yaml
│   ├── 04-rbac/
│   │   ├── tenant-a-rbac.yaml
│   │   ├── tenant-b-rbac.yaml
│   │   └── tenant-c-rbac.yaml
│   ├── 05-network-policies/
│   │   ├── tenant-isolation.yaml
│   │   └── cross-tenant-deny.yaml
│   ├── 06-applications/
│   │   ├── tenant-a-apps.yaml
│   │   ├── tenant-b-apps.yaml
│   │   └── tenant-c-apps.yaml
│   └── complete-multi-tenant.yaml    # All-in-one deployment
│
├── examples/                          # Example patterns
│   ├── namespace-patterns/
│   │   ├── environment-based.yaml
│   │   ├── team-based.yaml
│   │   ├── tenant-based.yaml
│   │   └── application-based.yaml
│   ├── label-examples/
│   │   ├── recommended-labels.yaml
│   │   ├── custom-labels.yaml
│   │   └── label-selectors.yaml
│   └── annotation-examples/
│       ├── deployment-annotations.yaml
│       └── monitoring-annotations.yaml
│
├── scripts/
│   ├── setup-multi-tenant.sh         # Setup multi-tenant cluster
│   ├── create-tenant.sh               # Create new tenant
│   ├── cleanup.sh                     # Cleanup resources
│   ├── validate.sh                    # Validate setup
│   └── monitor-quotas.sh              # Monitor resource usage
│
├── policies/
│   ├── namespace-policy.md            # Namespace governance
│   ├── label-policy.md                # Label standards
│   └── quota-policy.md                # Resource quota guidelines
│
└── diagrams/
    ├── namespace-architecture.png
    ├── multi-tenant-design.png
    ├── label-taxonomy.png
    └── rbac-integration.png

🚀 Quick Start
Prerequisites

Kubernetes cluster (v1.24+)
kubectl configured
Cluster admin access
4GB+ free memory

One-Command Deployment
bash# Clone repository
git clone https://github.com/yourusername/day-10-11-namespaces-labels.git
cd day-10-11-namespaces-labels

# Deploy complete multi-tenant cluster
kubectl apply -f manifests/complete-multi-tenant.yaml

# Verify deployment
kubectl get namespaces
kubectl get resourcequotas --all-namespaces
Step-by-Step Setup
bash# 1. Create namespaces
kubectl apply -f manifests/01-namespaces/

# 2. Apply resource quotas
kubectl apply -f manifests/02-resource-quotas/

# 3. Set limit ranges
kubectl apply -f manifests/03-limit-ranges/

# 4. Configure RBAC
kubectl apply -f manifests/04-rbac/

# 5. Apply network policies
kubectl apply -f manifests/05-network-policies/

# 6. Deploy sample applications
kubectl apply -f manifests/06-applications/

# 7. Verify setup
./scripts/validate.sh
Quick Validation
bash# Check namespaces
kubectl get ns

# Check resource quotas
kubectl get resourcequota -A

# Check limit ranges
kubectl get limitrange -A

# Test label selectors
kubectl get pods -l environment=production
kubectl get pods -l 'tier in (frontend,backend)'

# Verify network isolation
kubectl run test -n tenant-a --image=nginx
kubectl exec -n tenant-a test -- curl tenant-b-service.tenant-b

📦 What's Included
1. Complete Documentation

GUIDE.md - Deep dive into namespaces, labels, and organization
INTERVIEW-QA.md - 60+ questions with detailed answers
COMMANDS-CHEATSHEET.md - Quick reference for all commands
TROUBLESHOOTING.md - Common issues and solutions
LABEL-TAXONOMY.md - Best practices for labeling

2. Production-Ready Multi-Tenant Project

  Tenant A - Startup (Small)

    4 CPU cores, 8Gi memory quota
    Basic applications (web, api, db)
    Network isolation
    RBAC with developer access

  Tenant B - Enterprise (Large)
  
    16 CPU cores, 32Gi memory quota
    Complete microservices stack
    Strict network policies
    RBAC with admin access

Tenant C - Testing (Minimal)

  2 CPU cores, 4Gi memory quota
  Development/testing workloads
  Relaxed policies
  RBAC with tester access

3. Namespace Patterns

  Environment-based (dev/staging/prod)
  Team-based organization
  Tenant-based multi-tenancy
  Application-based grouping
  Hybrid approaches

4. Label Management

  Recommended label schema
  Custom label examples
  Equality-based selectors
  Set-based selectors
  Label best practices

5. Resource Governance

  Resource quotas
  Limit ranges
  Pod security policies
  Network policies
  RBAC integration

6. Automation Scripts

  Multi-tenant setup automation
  Tenant creation wizard
  Resource monitoring
  Validation tools
  Cleanup utilities


🏗️ Project Architecture
Multi-Tenant Cluster Design
┌────────────────────────────────────────────────────────┐
│              Kubernetes Cluster                        │
│  ┌───────────────────────────────────────────────────┐ │
│  │          Control Plane                            │ │
│  │  • API Server  • Scheduler  • Controllers         │ │
│  └───────────────────────────────────────────────────┘ │
│                                                        │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │  Tenant A    │  │  Tenant B    │  │  Tenant C    │  │
│  │  Namespace   │  │  Namespace   │  │  Namespace   │  │
│  ├──────────────┤  ├──────────────┤  ├──────────────┤  │
│  │ Quota:       │  │ Quota:       │  │ Quota:       │  │
│  │ • 4 CPU      │  │ • 16 CPU     │  │ • 2 CPU      │  │
│  │ • 8Gi RAM    │  │ • 32Gi RAM   │  │ • 4Gi RAM    │  │
│  │ • 20 Pods    │  │ • 100 Pods   │  │ • 10 Pods    │  │
│  ├──────────────┤  ├──────────────┤  ├──────────────┤  │
│  │ Limits:      │  │ Limits:      │  │ Limits:      │  │
│  │ • CPU: 2     │  │ • CPU: 4     │  │ • CPU: 1     │  │
│  │ • RAM: 4Gi   │  │ • RAM: 8Gi   │  │ • RAM: 2Gi   │  │
│  ├──────────────┤  ├──────────────┤  ├──────────────┤  │
│  │ RBAC:        │  │ RBAC:        │  │ RBAC:        │  │
│  │ • Developers │  │ • Admins     │  │ • Testers    │  │
│  ├──────────────┤  ├──────────────┤  ├──────────────┤  │
│  │ Network:     │  │ Network:     │  │ Network:     │  │
│  │ • Isolated   │  │ • Isolated   │  │ • Isolated   │  │
│  ├──────────────┤  ├──────────────┤  ├──────────────┤  │
│  │ Apps:        │  │ Apps:        │  │ Apps:        │  │
│  │ • Frontend   │  │ • Frontend   │  │ • Test Apps  │  │
│  │ • Backend    │  │ • Backend    │  │              │  │
│  │ • Database   │  │ • API        │  │              │  │
│  │              │  │ • Cache      │  │              │  │
│  │              │  │ • Queue      │  │              │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
└────────────────────────────────────────────────────────┘
Label Taxonomy
Recommended Kubernetes Labels:
├── app.kubernetes.io/name: application-name
├── app.kubernetes.io/instance: unique-instance-id
├── app.kubernetes.io/version: version-tag
├── app.kubernetes.io/component: component-name
├── app.kubernetes.io/part-of: application-group
└── app.kubernetes.io/managed-by: deployment-tool

Custom Organization Labels:
├── environment: production|staging|development
├── team: frontend|backend|data
├── cost-center: engineering|sales|marketing
├── compliance: pci|hipaa|sox
└── criticality: critical|high|medium|low

💻 Usage
Working with Namespaces
bash# Create namespace
kubectl create namespace my-namespace

# List all namespaces
kubectl get namespaces
kubectl get ns

# Describe namespace
kubectl describe ns my-namespace

# Set default namespace for context
kubectl config set-context --current --namespace=my-namespace

# Delete namespace (and all resources in it)
kubectl delete namespace my-namespace
Working with Labels
bash# Add label to resource
kubectl label pod my-pod environment=production

# Add multiple labels
kubectl label pod my-pod tier=frontend team=web

# Update existing label
kubectl label pod my-pod environment=staging --overwrite

# Remove label
kubectl label pod my-pod environment-

# Show labels
kubectl get pods --show-labels

# Filter by label (equality-based)
kubectl get pods -l environment=production
kubectl get pods -l environment!=development

# Filter by label (set-based)
kubectl get pods -l 'environment in (production,staging)'
kubectl get pods -l 'tier notin (cache,queue)'
kubectl get pods -l environment,tier  # Both must exist
Working with Resource Quotas
bash# Create resource quota
kubectl create quota my-quota \
  --hard=cpu=10,memory=20Gi,pods=20 \
  -n my-namespace

# View quotas
kubectl get resourcequota -n my-namespace

# Describe quota (see usage)
kubectl describe resourcequota my-quota -n my-namespace

# Monitor quota usage
kubectl get resourcequota -A -o json | \
  jq '.items[] | {namespace: .metadata.namespace, used: .status.used, hard: .status.hard}'
Working with Annotations
bash# Add annotation
kubectl annotate pod my-pod description="Production web server"

# Add multiple annotations
kubectl annotate pod my-pod \
  build-version="v1.2.3" \
  deployed-by="jenkins"

# View annotations
kubectl get pod my-pod -o jsonpath='{.metadata.annotations}'

# Remove annotation
kubectl annotate pod my-pod description-

**🎓 Key Concepts**
Namespace Use Cases
PatternUse CaseExampleEnvironmentSeparate dev/staging/proddev, staging, productionTeamOrganize by teamteam-frontend, team-backendTenantMulti-tenant SaaStenant-acme, tenant-globexApplicationGroup by applicationapp-ecommerce, app-analyticsComplianceRegulatory isolationpci-compliant, hipaa-zone
Default Namespaces
default           # Default namespace for resources
kube-system       # Kubernetes system components
kube-public       # Public resources (accessible to all)
kube-node-lease   # Node heartbeat information

**Label Best Practices**

DO:

  ✅ Use consistent naming conventions
  ✅ Include environment, team, version
  ✅ Use recommended Kubernetes labels
  ✅ Keep labels concise and meaningful
  ✅ Document your label schema

DON'T:

  ❌ Use labels for large data (use annotations)
  ❌ Include sensitive information
  ❌ Create too many labels
  ❌ Use spaces or special characters
  ❌ Change labels frequently

Resource Quota Types
  yaml# Compute resources
  cpu: "10"
  memory: 20Gi
  requests.cpu: "10"
  requests.memory: 20Gi
  limits.cpu: "20"
  limits.memory: 40Gi

# Storage resources
  requests.storage: 100Gi
  persistentvolumeclaims: "10"

# Object counts
  pods: "50"
  services: "10"
  configmaps: "20"
  secrets: "20"

📖 Resources
Documentation Files

GUIDE.md - Complete learning guide
INTERVIEW-QA.md - Interview preparation
COMMANDS-CHEATSHEET.md - Command reference
TROUBLESHOOTING.md - Problem solving
LABEL-TAXONOMY.md - Label best practices

Official Kubernetes Docs

  Namespaces
  Labels and Selectors
  Annotations
  Resource Quotas

External Resources

  Kubernetes Label Best Practices
  Multi-Tenancy in Kubernetes


🎯 Next Steps
After completing Day 10-11, continue to:
Day 12-13: ConfigMaps & Secrets

  Configuration management
  Environment variables
  Sensitive data handling
  Volume mounts


🤝 Contributing
Contributions welcome! Please:

  Fork the repository
  Create feature branch
  Commit changes
  Push to branch
  Open Pull Request


📝 License
MIT License - [![License: MIT](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)](https://opensource.org/licenses/MIT)


📞 Connect

💼 LinkedIn: www.linkedin.com/in/saikumara
🐙 GitHub: https://github.com/sai-look-hub/CKA-75/


⭐ Show Support

⭐ Star this repository
🍴 Fork for your learning
📢 Share with others
💬 Provide feedback



Overall Progress: 19% Complete 📈

<div align="center">
Happy Learning! 🚀
Part of the 75-Day CKA Preparation Journey
Made with ❤️ for the Kubernetes Community
</div>
