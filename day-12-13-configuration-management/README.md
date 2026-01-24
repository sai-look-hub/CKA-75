****Day 12-13: Kubernetes Configuration Management****

https://img.shields.io/badge/Kubernetes-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white
https://img.shields.io/badge/CKA-Preparation-orange?style=for-the-badge
https://img.shields.io/badge/Day-12--13-blue?style=for-the-badge
https://img.shields.io/badge/Security-Focused-red?style=for-the-badge

**Part of the 75-Day CKA Preparation Journey
**
Master external configuration management with ConfigMaps, Secrets, and secure practices for production workloads.

📋 Table of Contents

	Overview
	Learning Objectives
	Repository Structure
	Quick Start
	What's Included
	Project Architecture
	Security Considerations
	Key Concepts
	Resources


🎯 Overview
This repository contains comprehensive materials for Day 12-13 of my CKA certification journey, focusing on ConfigMaps, Secrets, and Configuration Management.
Duration: 8 hours
Difficulty: Intermediate
CKA Exam Weight: ~10%
Security Focus: High 🔐
What You'll Master

✅ ConfigMap creation and usage patterns
✅ Secret types and management
✅ Environment variable injection
✅ Volume-mounted configurations
✅ Encryption at rest
✅ Secret rotation strategies
✅ External secret manager integration
✅ 12-Factor app configuration
✅ Security best practices


📚 Repository Structure
day-12-13-configuration-management/
│
├── README.md                          # This file
├── GUIDE.md                           # Comprehensive learning guide
├── INTERVIEW-QA.md                    # 70+ interview questions
├── COMMANDS-CHEATSHEET.md             # kubectl commands reference
├── TROUBLESHOOTING.md                 # Common issues & solutions
├── SECURITY-GUIDE.md                  # Security best practices
│
├── manifests/                         # All Kubernetes YAML files
│   ├── 01-configmaps/
│   │   ├── literal-configmap.yaml
│   │   ├── file-configmap.yaml
│   │   ├── env-file-configmap.yaml
│   │   ├── immutable-configmap.yaml
│   │   └── multi-key-configmap.yaml
│   ├── 02-secrets/
│   │   ├── opaque-secret.yaml
│   │   ├── tls-secret.yaml
│   │   ├── docker-registry-secret.yaml
│   │   ├── basic-auth-secret.yaml
│   │   └── ssh-auth-secret.yaml
│   ├── 03-environment-configs/
│   │   ├── development/
│   │   │   ├── app-config.yaml
│   │   │   └── app-secrets.yaml
│   │   ├── staging/
│   │   │   ├── app-config.yaml
│   │   │   └── app-secrets.yaml
│   │   └── production/
│   │       ├── app-config.yaml
│   │       └── app-secrets.yaml
│   ├── 04-applications/
│   │   ├── env-var-app.yaml
│   │   ├── volume-mount-app.yaml
│   │   ├── configmap-envfrom-app.yaml
│   │   ├── secret-volume-app.yaml
│   │   └── complete-app.yaml
│   ├── 05-security/
│   │   ├── encryption-config.yaml
│   │   ├── rbac-secrets.yaml
│   │   └── pod-security-policy.yaml
│   └── complete-project.yaml          # All-in-one deployment
│
├── examples/                          # Configuration patterns
│   ├── patterns/
│   │   ├── database-config.yaml
│   │   ├── api-config.yaml
│   │   ├── feature-flags.yaml
│   │   ├── multi-tenant-config.yaml
│   │   └── canary-config.yaml
│   ├── secret-providers/
│   │   ├── vault-integration.yaml
│   │   ├── aws-secrets-manager.yaml
│   │   ├── azure-key-vault.yaml
│   │   └── external-secrets-operator.yaml
│   └── rotation/
│       ├── manual-rotation.md
│       ├── automated-rotation.yaml
│       └── zero-downtime-rotation.yaml
│
├── scripts/
│   ├── create-configmap.sh            # ConfigMap creation helper
│   ├── create-secret.sh               # Secret creation helper
│   ├── rotate-secrets.sh              # Secret rotation automation
│   ├── encrypt-at-rest.sh             # Enable encryption
│   ├── validate-config.sh             # Validate configurations
│   └── cleanup.sh                     # Cleanup resources
│
├── configs/                           # Sample configuration files
│   ├── app.properties
│   ├── database.conf
│   ├── nginx.conf
│   ├── application.yaml
│   └── feature-flags.json
│
└── security/
    ├── encryption-config.yaml         # Encryption at rest config
    ├── audit-policy.yaml              # Audit policy for secrets
    ├── rbac-policies.yaml             # RBAC for config access
    └── secret-scanning.md             # Secret scanning guide

**🚀 Quick Start**
Prerequisites

Kubernetes cluster (v1.24+)
kubectl configured
Basic understanding of Pods
2GB+ free memory

5-Minute Setup
bash# Clone repository
git clone https://github.com/yourusername/day-12-13-configuration-management.git
cd day-12-13-configuration-management

# Deploy complete project
kubectl apply -f manifests/complete-project.yaml

# Verify deployment
kubectl get configmaps
kubectl get secrets
kubectl get pods
Step-by-Step Deployment
bash# 1. Create ConfigMaps
kubectl apply -f manifests/01-configmaps/

# 2. Create Secrets
kubectl apply -f manifests/02-secrets/

# 3. Deploy environment-specific configs
kubectl apply -f manifests/03-environment-configs/development/

# 4. Deploy applications
kubectl apply -f manifests/04-applications/

# 5. Verify configurations
./scripts/validate-config.sh
Quick Examples
Create ConfigMap from literal:
bashkubectl create configmap app-config \
  --from-literal=APP_ENV=production \
  --from-literal=LOG_LEVEL=info
Create Secret from file:
bashkubectl create secret generic db-secret \
  --from-file=username.txt \
  --from-file=password.txt
Create TLS Secret:
bashkubectl create secret tls tls-secret \
  --cert=path/to/cert.crt \
  --key=path/to/cert.key

📦 What's Included
1. Complete Documentation

GUIDE.md - Deep dive into ConfigMaps and Secrets
INTERVIEW-QA.md - 70+ questions with answers
COMMANDS-CHEATSHEET.md - Quick reference
TROUBLESHOOTING.md - Common issues and solutions
SECURITY-GUIDE.md - Security hardening

2. Production-Ready Project
12-Factor Application with External Configuration:
Development Environment:

ConfigMap with dev settings
Secrets for dev credentials
Feature flags enabled
Debug logging
Local database connection

Staging Environment:

ConfigMap with staging settings
Secrets for staging credentials
Staging API endpoints
Standard logging
Staging database connection

Production Environment:

Immutable ConfigMap
Encrypted secrets
Production API endpoints
Minimal logging
Production database with TLS
High availability configuration

3. Configuration Patterns

Database connection management
API endpoint configuration
Feature flags system
Multi-tenant configurations
Canary deployment configs
A/B testing settings
TLS certificate management
Docker registry credentials

4. Security Implementation

Encryption at rest setup
RBAC for secret access
Secret rotation automation
External secret manager integration
Audit logging configuration
Secret scanning tools
Vulnerability scanning

5. Automation Scripts

ConfigMap generation
Secret creation and encoding
Automated secret rotation
Configuration validation
Security hardening
Cleanup utilities


🏗️ Project Architecture
Application Configuration Flow
┌─────────────────────────────────────────────────────────┐
│                   Configuration Sources                 │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐      │
│  │ ConfigMaps  │  │   Secrets   │  │  External   │      │
│  │             │  │             │  │   Vault     │      │
│  │ • API URLs  │  │ • Passwords │  │             │      │
│  │ • Features  │  │ • API Keys  │  │ • DB Creds  │      │
│  │ • Settings  │  │ • Certs     │  │ • API Keys  │      │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘      │
│         │                 │                 │           │
└─────────┼─────────────────┼─────────────────┼───────────┘
          │                 │                 │
          ▼                 ▼                 ▼
┌────────────────────────────────────────────────────────┐
│              Injection Methods                         │
├────────────────────────────────────────────────────────┤
│                                                        │
│  ┌──────────────────┐         ┌──────────────────┐     │
│  │ Environment Vars │         │  Volume Mounts   │     │
│  │                  │         │                  │     │
│  │  env:            │         │  volumeMounts:   │     │
│  │  - name: API_URL │         │  - name: config  │     │
│  │    valueFrom:    │         │    mountPath:    │     │
│  │      configMap   │         │      /etc/config │     │
│  └────────┬─────────┘         └────────┬─────────┘     │
│           │                            │               │
└───────────┼────────────────────────────┼───────────────┘
            │                            │
            ▼                            ▼
┌────────────────────────────────────────────────────────┐
│                   Application Pod                      │
├────────────────────────────────────────────────────────┤
│                                                        │
│  ┌─────────────────────────────────────────────── ─┐   │
│  │           Application Container                 │   │
│  │                                                 │   │
│  │  • Reads environment variables                  │   │
│  │  • Reads files from /etc/config                 │   │
│  │  • Connects to database using credentials       │   │
│  │  • Uses feature flags for behavior              │   │
│  │  • Logs to configured output                    │   │
│  └─────────────────────────────────────────────────┘   │
│                                                        │
└────────────────────────────────────────────────────────┘
Configuration Hierarchy
Production Application
├── Base Configuration (ConfigMap)
│   ├── Application name
│   ├── Default settings
│   └── Common endpoints
├── Environment Configuration (ConfigMap)
│   ├── Environment-specific URLs
│   ├── Feature flags
│   └── Logging levels
├── Sensitive Data (Secrets)
│   ├── Database credentials
│   ├── API keys
│   ├── TLS certificates
│   └── OAuth tokens
└── External Configuration (Vault/AWS)
    ├── Rotated secrets
    ├── Compliance-required data
    └── Shared secrets

🔒 Security Considerations
⚠️ Critical Security Facts
1. Secrets are NOT Encrypted by Default
bash# Secrets are only base64 encoded
echo "password123" | base64
# Output: cGFzc3dvcmQxMjM=

# Anyone can decode
echo "cGFzc3dvcmQxMjM=" | base64 -d
# Output: password123
2. Enable Encryption at Rest
yaml# Required for production!
# See security/encryption-config.yaml
3. Use RBAC to Restrict Access
yaml# Limit who can read secrets
# See security/rbac-policies.yaml
Security Checklist
☑ Encryption at rest enabled
☑ RBAC configured for secrets
☑ Secrets never in Git
☑ Secret rotation implemented
☑ Audit logging enabled
☑ External secret manager (recommended)
☑ Least privilege principle
☑ Secret scanning in CI/CD
☑ Regular security audits
☑ Immutable ConfigMaps in production
Security Best Practices
DO:

✅ Enable encryption at rest for etcd
✅ Use RBAC to limit secret access
✅ Rotate secrets regularly
✅ Use external secret managers (Vault, AWS Secrets Manager)
✅ Implement audit logging
✅ Use separate secrets per environment
✅ Mount secrets as volumes (not env vars) when possible
✅ Use immutable ConfigMaps in production

DON'T:

❌ Commit secrets to Git
❌ Share secrets across environments
❌ Give broad RBAC permissions
❌ Use same secrets for dev and prod
❌ Ignore secret rotation
❌ Assume base64 is encryption
❌ Store secrets in ConfigMaps
❌ Log secret values


💻 Usage
Working with ConfigMaps
bash# Create from literal values
kubectl create configmap app-config \
  --from-literal=APP_NAME=myapp \
  --from-literal=LOG_LEVEL=info

# Create from file
kubectl create configmap nginx-config \
  --from-file=nginx.conf

# Create from directory
kubectl create configmap app-configs \
  --from-file=./configs/

# Create from env file
kubectl create configmap env-config \
  --from-env-file=./app.env

# Get ConfigMap
kubectl get configmap app-config

# Describe ConfigMap
kubectl describe configmap app-config

# Get ConfigMap data
kubectl get configmap app-config -o yaml

# Edit ConfigMap
kubectl edit configmap app-config

# Delete ConfigMap
kubectl delete configmap app-config
Working with Secrets
bash# Create generic secret from literal
kubectl create secret generic db-secret \
  --from-literal=username=admin \
  --from-literal=password=secret123

# Create from file
kubectl create secret generic ssh-secret \
  --from-file=id_rsa=~/.ssh/id_rsa

# Create TLS secret
kubectl create secret tls tls-secret \
  --cert=server.crt \
  --key=server.key

# Create Docker registry secret
kubectl create secret docker-registry regcred \
  --docker-server=docker.io \
  --docker-username=user \
  --docker-password=pass \
  --docker-email=user@example.com

# Get secrets (data is hidden)
kubectl get secrets

# Describe secret (shows keys, not values)
kubectl describe secret db-secret

# Get secret data (base64 encoded)
kubectl get secret db-secret -o yaml

# Decode secret value
kubectl get secret db-secret -o jsonpath='{.data.password}' | base64 -d

# Delete secret
kubectl delete secret db-secret
Using ConfigMaps in Pods
As Environment Variables:
yamlenv:
- name: APP_NAME
  valueFrom:
    configMapKeyRef:
      name: app-config
      key: APP_NAME

# Or load all keys
envFrom:
- configMapRef:
    name: app-config
As Volume Mounts:
yamlvolumes:
- name: config-volume
  configMap:
    name: app-config

containers:
- name: app
  volumeMounts:
  - name: config-volume
    mountPath: /etc/config
Using Secrets in Pods
As Environment Variables:
yamlenv:
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: db-secret
      key: password
As Volume Mounts:
yamlvolumes:
- name: secret-volume
  secret:
    secretName: db-secret

containers:
- name: app
  volumeMounts:
  - name: secret-volume
    mountPath: /etc/secrets
    readOnly: true

**🎓 Key Concepts**
ConfigMap vs Secret
FeatureConfigMapSecretPurposeNon-sensitive configurationSensitive dataEncodingPlain textBase64Size Limit1MB1MBRBACStandardMore restrictiveEncryptionNoOptional (at rest)Use CasesAPI URLs, feature flagsPasswords, keys, certificatesBest PracticeImmutable in prodRotate regularly
Environment Variables vs Volume Mounts
AspectEnvironment VariablesVolume MountsUpdatesRequires pod restartAuto-updates (eventually consistent)Use CaseSimple key-value pairsConfiguration filesVisibilityVisible in pod specNot visible in pod specSecurityLess secure (visible)More securePerformanceFaster accessSlight overheadSizeLimitedLarger files supported
Secret Types
yaml# Opaque (default) - arbitrary key-value pairs
type: Opaque

# kubernetes.io/service-account-token
type: kubernetes.io/service-account-token

# kubernetes.io/dockercfg
type: kubernetes.io/dockercfg

# kubernetes.io/dockerconfigjson
type: kubernetes.io/dockerconfigjson

# kubernetes.io/basic-auth
type: kubernetes.io/basic-auth

# kubernetes.io/ssh-auth
type: kubernetes.io/ssh-auth

# kubernetes.io/tls
type: kubernetes.io/tls

# bootstrap.kubernetes.io/token
type: bootstrap.kubernetes.io/token

📖 Resources
Documentation Files

GUIDE.md - Complete learning guide
INTERVIEW-QA.md - Interview preparation
COMMANDS-CHEATSHEET.md - Command reference
TROUBLESHOOTING.md - Problem solving
SECURITY-GUIDE.md - Security best practices

Official Kubernetes Docs

ConfigMaps
Secrets
Encrypting Secret Data at Rest

External Tools

HashiCorp Vault
External Secrets Operator
Sealed Secrets
AWS Secrets Manager
Azure Key Vault


🎯 Next Steps
After completing Day 12-13, continue to:
Day 14-15: Persistent Storage & Volumes

PersistentVolumes (PV)
PersistentVolumeClaims (PVC)
StorageClasses
Volume types


📊 Progress Tracker

 Day 1-2: Kubernetes Architecture
 Day 3-4: Pods & ReplicaSets
 Day 5-6: Deployments
 Day 7-8: Services & Networking
 Day 9: Review
 Day 10-11: Namespaces & Labels
 Day 12-13: Configuration Management ← You are here
 Day 14-15: Persistent Storage
 ...continuing to Day 75

Overall Progress: 24% Complete 📈

<div align="center">
Happy Learning! 🚀
Part of the 75-Day CKA Preparation Journey
Made with ❤️ and ☕
</div>
