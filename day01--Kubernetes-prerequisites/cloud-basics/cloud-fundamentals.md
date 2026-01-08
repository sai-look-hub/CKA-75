## Cloud Computing Concepts

### 1. Cloud Service Models

**IaaS (Infrastructure as a Service)**
- Virtual machines, storage, networks
- Examples: AWS EC2, Azure VMs, Google Compute Engine
- User manages: OS, middleware, runtime, applications
- Provider manages: Hardware, networking, virtualization

**PaaS (Platform as a Service)**
- Application hosting platforms
- Examples: Heroku, Google App Engine, AWS Elastic Beanstalk
- User manages: Applications, data
- Provider manages: Runtime, OS, middleware, infrastructure

**SaaS (Software as a Service)**
- Ready-to-use applications
- Examples: Gmail, Salesforce, Office 365
- User manages: Configuration, data
- Provider manages: Everything else

**CaaS (Container as a Service)**
- Container orchestration platforms
- Examples: AWS ECS, Google Kubernetes Engine (GKE), Azure AKS
- Kubernetes fits here

### 2. Cloud Deployment Models

**Public Cloud**
- Shared infrastructure
- Pay-as-you-go pricing
- Examples: AWS, Azure, GCP
- Benefits: Scalability, no hardware management
- Considerations: Less control, potential compliance issues

**Private Cloud**
- Dedicated infrastructure for single organization
- On-premises or hosted
- Benefits: More control, enhanced security
- Considerations: Higher costs, requires management

**Hybrid Cloud**
- Combination of public and private
- Data and apps shared between them
- Use cases: Burst to cloud, sensitive data on-prem

**Multi-Cloud**
- Using multiple cloud providers
- Avoid vendor lock-in
- Use best services from each provider

### 3. Cloud Compute Services

**Virtual Machines**
```yaml
# AWS EC2 instance types
t3.micro:    1 vCPU, 1 GB RAM
t3.medium:   2 vCPU, 4 GB RAM
m5.large:    2 vCPU, 8 GB RAM
c5.xlarge:   4 vCPU, 8 GB RAM
```

**Serverless Computing**
- AWS Lambda, Azure Functions, Google Cloud Functions
- Event-driven execution
- Pay only for execution time
- Auto-scaling

**Container Services**
```bash
# AWS
ECS (Elastic Container Service)
EKS (Elastic Kubernetes Service)
Fargate (Serverless containers)

# Azure
AKS (Azure Kubernetes Service)
ACI (Azure Container Instances)

# GCP
GKE (Google Kubernetes Engine)
Cloud Run
```

### 4. Cloud Storage Services

**Object Storage**
- AWS S3, Azure Blob Storage, Google Cloud Storage
- Stores files as objects
- Highly scalable, durable
- Use cases: Backups, media files, static websites

**Block Storage**
- AWS EBS, Azure Managed Disks, Google Persistent Disk
- Attached to VMs like hard drives
- Low latency, high performance
- Use cases: Databases, boot volumes

**File Storage**
- AWS EFS, Azure Files, Google Filestore
- Network file system (NFS)
- Shared across multiple instances
- Use cases: Shared application data

### 5. Cloud Networking

**Virtual Private Cloud (VPC)**
```yaml
VPC Components:
  - Subnets (Public, Private)
  - Internet Gateway
  - NAT Gateway
  - Route Tables
  - Security Groups
  - Network ACLs
```

**Example VPC Architecture**
```
VPC: 10.0.0.0/16
├── Public Subnet: 10.0.1.0/24
│   └── Load Balancer, Bastion Host
├── Private Subnet: 10.0.2.0/24
│   └── Application Servers
└── Private Subnet: 10.0.3.0/24
    └── Database Servers
```

**Load Balancers**
- Application Load Balancer (Layer 7)
- Network Load Balancer (Layer 4)
- Classic Load Balancer (Legacy)

### 6. Cloud Security

**Identity and Access Management (IAM)**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Resource": "arn:aws:s3:::my-bucket/*"
    }
  ]
}
```

**Security Best Practices**
- Principle of least privilege
- Enable MFA (Multi-Factor Authentication)
- Encrypt data at rest and in transit
- Regular security audits
- Use security groups and network ACLs
- Implement logging and monitoring

### 7. Cloud Cost Management

**Cost Optimization Strategies**
- Right-sizing instances
- Reserved instances for predictable workloads
- Spot instances for fault-tolerant workloads
- Auto-scaling to match demand
- Use lifecycle policies for storage
- Monitor and alert on costs

**Pricing Models**
- On-Demand: Pay by hour/second
- Reserved: Commit 1-3 years for discount
- Spot: Bid on unused capacity
- Savings Plans: Flexible commitment-based discounts

### 8. High Availability and Disaster Recovery

**Availability Zones (AZ)**
- Multiple isolated locations within a region
- Deploy across AZs for fault tolerance

**Regions**
- Geographic areas with multiple AZs
- Choose region based on latency, compliance, costs

**HA Architecture Example**
```yaml
Region: us-east-1
├── AZ 1 (us-east-1a)
│   ├── Web Server 1
│   └── Database Primary
├── AZ 2 (us-east-1b)
│   ├── Web Server 2
│   └── Database Replica
└── AZ 3 (us-east-1c)
    └── Web Server 3
```

**Disaster Recovery Strategies**
- Backup and Restore (Lowest cost, highest RTO/RPO)
- Pilot Light (Core services always running)
- Warm Standby (Scaled-down version running)
- Multi-Site (Full environment in multiple regions)

### 9. Cloud-Native Architecture

**Microservices**
- Small, independent services
- Communicate via APIs
- Independently deployable
- Technology agnostic

**12-Factor App Principles**
1. Codebase: One codebase in version control
2. Dependencies: Explicitly declare dependencies
3. Config: Store config in environment
4. Backing services: Treat as attached resources
5. Build, release, run: Strict separation
6. Processes: Execute as stateless processes
7. Port binding: Export services via port binding
8. Concurrency: Scale out via process model
9. Disposability: Fast startup and graceful shutdown
10. Dev/prod parity: Keep environments similar
11. Logs: Treat logs as event streams
12. Admin processes: Run as one-off processes

### 10. Cloud Monitoring and Logging

**Monitoring Metrics**
- CPU utilization
- Memory usage
- Disk I/O
- Network traffic
- Application response time
- Error rates

**Logging Services**
- AWS CloudWatch Logs
- Azure Monitor Logs
- Google Cloud Logging
- Centralized logging (ELK Stack, Splunk)

**Alerting**
```yaml
Alert Rules:
  - CPU > 80% for 5 minutes
  - Memory > 90% for 3 minutes
  - HTTP 5xx errors > 10/minute
  - Application health check fails
```

---
