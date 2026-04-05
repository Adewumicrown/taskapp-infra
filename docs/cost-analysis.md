# TaskApp Cost Analysis

## Overview

This document provides a detailed monthly cost estimation for the TaskApp
production infrastructure on AWS. All prices are based on us-east-1 region
pricing as of April 2026.

---

## Compute Costs (EC2)

### Kubernetes Control Plane (Masters)

| Resource | Instance Type | Count | Hourly Rate | Daily Cost | Monthly Cost |
|---|---|---|---|---|---|
| Master nodes | t3.small | 3 | $0.0208/hr | $1.50 | $45.00 |

### Kubernetes Worker Nodes

| Resource | Instance Type | Count | Hourly Rate | Daily Cost | Monthly Cost |
|---|---|---|---|---|---|
| Worker nodes (min) | t3.micro | 3 | $0.0104/hr | $0.75 | $22.50 |

**Note:** Worker nodes can scale up to 6 with the cluster autoscaler.
Maximum worker cost at full scale: $45.00/month.

---

## Networking Costs

### NAT Gateways

| Resource | Count | Hourly Rate | Data Rate | Daily Cost | Monthly Cost |
|---|---|---|---|---|---|
| NAT Gateways | 3 | $0.045/hr | $0.045/GB | $3.24 | $97.20 |

**Note:** NAT Gateways are the most expensive component.
3 are required for high availability (one per AZ).

### Load Balancers

| Resource | Type | Count | Hourly Rate | Monthly Cost |
|---|---|---|---|---|
| Kubernetes API LB | Classic ELB | 1 | $0.025/hr | $18.00 |
| NGINX Ingress NLB | Network LB | 1 | $0.008/hr | $5.76 |

### Data Transfer

| Resource | Estimated Usage | Rate | Monthly Cost |
|---|---|---|---|
| Outbound data transfer | 10GB/month | $0.09/GB | $0.90 |

---

## Storage Costs (EBS)

| Resource | Size | Type | Monthly Cost |
|---|---|---|---|
| Master node volumes (3) | 64GB each | gp2 | $19.20 |
| Worker node volumes (3) | 128GB each | gp2 | $38.40 |
| PostgreSQL data volume | 10GB | gp2 | $1.00 |

---

## S3 Storage Costs

| Bucket | Estimated Size | Monthly Cost |
|---|---|---|
| Terraform state | < 1MB | < $0.01 |
| Kops state store | < 10MB | < $0.01 |
| etcd backups (30 days) | ~500MB | $0.01 |

---

## DNS Costs (Route53)

| Resource | Count | Monthly Cost |
|---|---|---|
| Hosted Zone | 1 | $0.50 |
| DNS Queries (est.) | 1M queries | $0.40 |

---

## Monthly Cost Summary

| Category | Monthly Cost |
|---|---|
| EC2 — Masters (3x t3.small) | $45.00 |
| EC2 — Workers (3x t3.micro) | $22.50 |
| NAT Gateways (3x) | $97.20 |
| Load Balancers (2x) | $23.76 |
| EBS Volumes | $58.60 |
| Data Transfer | $0.90 |
| S3 Storage | $0.03 |
| Route53 | $0.90 |
| **Total (minimum)** | **$248.89/month** |
| **Total (max scale)** | **~$271.39/month** |

---

## Cost Optimization Strategies

### Implemented
- **t3.micro for workers** — Free tier eligible, saves ~$45/month vs t3.medium
- **30-day etcd backup retention** — Lifecycle policy prevents storage bloat
- **Cluster autoscaler** — Scales down workers when not needed
- **Startup/shutdown scripts** — Destroy infrastructure when not in use

### Potential Future Optimizations

| Strategy | Estimated Saving | Tradeoff |
|---|---|---|
| Spot instances for workers (+5% bonus) | 60-70% worker cost | Interruption risk |
| Reserved instances (1 year) | 30-40% EC2 cost | Upfront commitment |
| Single NAT Gateway (non-HA) | $64.80/month | Single point of failure |
| Migrate to RDS (+5% bonus) | Managed backups | Higher base cost |

### Cost During Development
Since this is a capstone project, infrastructure is destroyed when not in use:

| Scenario | Daily Cost |
|---|---|
| Full cluster running | ~$8.30/day |
| Infrastructure destroyed | ~$0.00/day |
| AWS Credits available | $51.64 |
| Estimated days of runtime | ~10 days |

---

## AWS Budget Alert

A $50 budget alert has been configured in AWS Budgets:
- **Alert at 50%** ($25) — Early warning
- **Alert at 85%** ($42.50) — Approaching limit
- **Alert at 100%** ($50) — Limit reached

---

## Cost Comparison

| Approach | Monthly Cost | Notes |
|---|---|---|
| Our setup (destroy when idle) | ~$0-250 | Scripts automate teardown |
| Always-on production | ~$249/month | Real company cost |
| Managed EKS | ~$290/month | +$73 EKS cluster fee |
| Single-node (non-HA) | ~$80/month | Not production ready |

The infrastructure as code approach means we can recreate the entire
production environment in ~25 minutes from a single script — making
destroy-when-idle a viable cost saving strategy for development.
