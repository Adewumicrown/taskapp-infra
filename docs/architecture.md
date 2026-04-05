# TaskApp Architecture Documentation

## Overview

TaskApp is a cloud-native task management application deployed on a production-grade
Kubernetes cluster on AWS. The infrastructure is fully defined as code using Terraform
and Kops, with zero manual console changes.

**Live URLs:**
- Frontend: https://app.taskapp.name.ng
- Backend API: https://backend.taskapp.name.ng/api/health

---

## System Architecture

### High Level Overview
Internet
│
▼
Route53 (DNS)
app.taskapp.name.ng → NGINX Load Balancer
backend.taskapp.name.ng → NGINX Load Balancer
│
▼
AWS Network Load Balancer (internet-facing)
│
▼
NGINX Ingress Controller (2 replicas)
│
├── app.taskapp.name.ng → Frontend Service → Frontend Pods (2 replicas)
│
└── backend.taskapp.name.ng → Backend Service → Backend Pods (2 replicas)
│
▼
PostgreSQL
(StatefulSet)
EBS Volume (10Gi)

---

## Network Architecture

### VPC Design

| Resource | Value | Justification |
|---|---|---|
| VPC CIDR | 10.0.0.0/16 | 65,536 IPs — room for growth |
| Public Subnets | 10.0.1.0/24, 10.0.2.0/24, 10.0.3.0/24 | Load Balancers + NAT Gateways |
| Private Subnets | 10.0.11.0/24, 10.0.12.0/24, 10.0.13.0/24 | Kubernetes nodes |
| Availability Zones | us-east-1a, us-east-1b, us-east-1c | 3 AZ coverage |

### CIDR Allocation Rationale

The `/16` VPC gives 65,536 IP addresses — far more than needed but provides
room for future expansion. Each `/24` subnet provides 256 IPs which is more
than sufficient for the current workload. The gap between public (10.0.1-3.x)
and private (10.0.11-13.x) subnets is intentional — it reserves space for
additional subnet tiers (e.g. database subnets) without renumbering.

### Private Subnet Topology

All Kubernetes nodes run in private subnets with no public IP addresses.
Outbound internet access is provided through NAT Gateways in the public subnets.
This ensures nodes are never directly reachable from the internet.
Private Subnet (nodes)
│
│ outbound traffic
▼
NAT Gateway (public subnet, has Elastic IP)
│
▼
Internet Gateway
│
▼
Internet

---

## High Availability Strategy

### Control Plane HA

Three master nodes are deployed across three separate Availability Zones:

| Master | AZ | Instance Type |
|---|---|---|
| master-us-east-1a | us-east-1a | t3.small |
| master-us-east-1b | us-east-1b | t3.small |
| master-us-east-1c | us-east-1c | t3.small |

etcd runs as a distributed cluster across all three masters. With 3 nodes,
the cluster can survive the loss of 1 master and maintain quorum (2/3 nodes).

### Worker Node HA

Three worker nodes are distributed across three AZs:

| Workers | AZ Distribution | Instance Type |
|---|---|---|
| 3 nodes (min) | one per AZ | t3.micro |
| 6 nodes (max) | autoscaler managed | t3.micro |

### NAT Gateway HA

One NAT Gateway per AZ eliminates the NAT Gateway as a single point of failure:

| NAT Gateway | AZ | Serves |
|---|---|---|
| nat-us-east-1a | us-east-1a | Private subnet us-east-1a |
| nat-us-east-1b | us-east-1b | Private subnet us-east-1b |
| nat-us-east-1c | us-east-1c | Private subnet us-east-1c |

### Application HA

| Component | Replicas | Strategy |
|---|---|---|
| Frontend | 2 | RollingUpdate, maxUnavailable=0 |
| Backend | 2 | RollingUpdate, maxUnavailable=0 |
| Database | 1 | StatefulSet with EBS persist |
| NGINX Ingress | 2 | Spread across worker nodes |

---

## Security Model

### Network Security

- All Kubernetes nodes run in **private subnets** with no public IPs
- Security groups follow **least-privilege** — only required ports open
- NAT Gateways provide **outbound-only** internet access for nodes
- NGINX Ingress is the **single entry point** for all application traffic
- All HTTP traffic is **redirected to HTTPS**

### IAM Security

- **No root account usage** — dedicated IAM user for cluster operations
- **Separate roles** for cluster creation vs cluster operations
- **Instance profiles** attached to EC2 nodes — no hardcoded credentials
- **Least privilege** — each role has only the permissions it needs

| Role | Purpose | Key Permissions |
|---|---|---|
| taskapp-master-role | Kubernetes masters | EC2, ELB, Autoscaling, S3 |
| taskapp-worker-role | Kubernetes workers | EC2 describe, S3 read, ECR |
| taskapp-cert-manager | SSL certificate automation | Route53 record management |

### Secret Management

- Database credentials stored as **Kubernetes Secrets** (base64 encoded)
- Secrets never committed to Git in plain text
- cert-manager AWS credentials stored as **Kubernetes Secret** in cert-manager namespace
- JWT secret stored as **Kubernetes Secret**
- All sensitive values referenced via `secretKeyRef` in pod specs

### SSL/TLS

- Valid SSL certificates issued by **Let's Encrypt** via cert-manager
- **DNS01 challenge** used for domain verification (more reliable than HTTP01)
- Certificates **auto-renew** 30 days before expiry
- **HSTS** enabled via NGINX ingress annotations

---

## Infrastructure as Code

### Terraform Modules

| Module | Resources | Purpose |
|---|---|---|
| vpc | VPC, subnets, IGW, route tables | Network foundation |
| nat | NAT Gateways, Elastic IPs, private routes | Private subnet internet access |
| iam | Roles, policies, instance profiles | Least-privilege permissions |
| dns | Route53 hosted zone, DNS records | Domain management |
| s3 | Kops state, etcd backup buckets | State and backup storage |

### Remote State

Terraform state is stored remotely in S3 with DynamoDB locking:

| Resource | Name | Purpose |
|---|---|---|
| S3 Bucket | taskapp-terraform-state-victor-311156639915-us-east-1 | State storage |
| DynamoDB Table | taskapp-terraform-locks | State locking |

State locking prevents concurrent modifications that could corrupt infrastructure.

### Kubernetes Cluster (Kops)

| Specification | Value |
|---|---|
| Kubernetes Version | 1.28.0 |
| CNI Plugin | Calico (NetworkPolicy support) |
| Cluster Topology | Private (no public node IPs) |
| API Access | Public Load Balancer |
| etcd Backup | Daily to S3 |
| Storage | AWS EBS CSI Driver (gp2) |

---

## Application Stack

| Component | Technology | Replicas | Resources |
|---|---|---|---|
| Frontend | React + TypeScript + Nginx | 2 | 128Mi-256Mi RAM |
| Backend | Flask + Gunicorn | 2 | 526Mi RAM (fixed) |
| Database | PostgreSQL 15 | 1 | 256Mi-512Mi RAM |

### Data Persistence

PostgreSQL data is stored on an AWS EBS volume with `Retain` policy:
- Volume survives pod deletion and rescheduling
- Data persists through rolling updates
- Manual snapshot backup strategy documented in runbook

---

## DNS Architecture
taskapp.name.ng (registered at Go54)
│
│ NS delegation
▼
AWS Route53 Hosted Zone (Z0925897Z02UN1WIO0T6)
│
├── app.taskapp.name.ng     → CNAME → NGINX NLB
├── backend.taskapp.name.ng → CNAME → NGINX NLB
└── api.taskapp.name.ng     → A     → Kubernetes API LB (Kops managed)

---

## Cost Analysis

See `docs/cost-analysis.md` for detailed monthly cost breakdown.

**Estimated daily cost when running:**
| Resource | Daily Cost |
|---|---|
| 3x t3.small masters | ~$3.60 |
| 3x t3.micro workers | ~$1.50 |
| 3x NAT Gateways | ~$3.24 |
| Load Balancers | ~$0.50 |
| EBS Volumes | ~$0.50 |
| **Total** | **~$9.34/day** |

---

## Deployment Pipeline

All infrastructure changes follow this workflow:
Developer → Git commit → terraform plan (review) → terraform apply
→ kops update cluster (review) → kops update --yes

No manual AWS console changes are permitted. All changes must go through
Terraform or Kops to maintain infrastructure immutability.
