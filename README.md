# TaskApp Cloud-Native Deployment

Production-grade Kubernetes deployment of TaskApp on AWS using Kops and Terraform.

## Live URLs
- **Frontend:** https://app.taskapp.name.ng
- **Backend API:** https://backend.taskapp.name.ng/api/health

## Architecture
- **Kubernetes:** 3-master HA cluster across 3 Availability Zones
- **Infrastructure:** Terraform IaC with remote state
- **SSL:** Auto-renewing Let's Encrypt certificates via cert-manager
- **Networking:** Private subnet topology with NAT Gateways

## Quick Start

### Start everything
```bash
~/taskapp-infra/scripts/startup.sh
```

### Stop everything
```bash
~/taskapp-infra/scripts/shutdown.sh
```

## Repository Structure
taskapp-infra/
├── terraform/          # AWS infrastructure (VPC, IAM, DNS, S3)
│   └── modules/
│       ├── vpc/        # VPC, subnets, route tables
│       ├── nat/        # NAT Gateways
│       ├── iam/        # IAM roles and policies
│       ├── dns/        # Route53
│       └── s3/         # State and backup buckets
├── kops/               # Kubernetes cluster specification
├── k8s/                # Kubernetes manifests
│   └── base/
│       ├── frontend/   # React app deployment
│       ├── backend/    # Flask API deployment
│       ├── database/   # PostgreSQL StatefulSet
│       ├── ingress/    # NGINX Ingress rules
│       ├── secrets/    # ConfigMaps and Secrets
│       └── cert-manager/ # SSL certificate issuer
├── scripts/            # Automation scripts
│   ├── startup.sh      # Full environment startup
│   └── shutdown.sh     # Full environment teardown
└── docs/               # Documentation
├── architecture.md # System design and decisions
├── runbook.md      # Operational procedures
├── cost-analysis.md # Monthly cost breakdown
└── failover-evidence.md # HA test results

## Documentation
- [Architecture](docs/architecture.md)
- [Runbook](docs/runbook.md)
- [Cost Analysis](docs/cost-analysis.md)
- [HA Failover Evidence](docs/failover-evidence.md)

## Tech Stack
| Layer | Technology |
|---|---|
| Cloud | AWS |
| IaC | Terraform |
| Kubernetes | Kops 1.28 |
| Container Runtime | containerd |
| CNI | Calico |
| Ingress | NGINX |
| SSL | cert-manager + Let's Encrypt |
| Frontend | React + TypeScript + Vite |
| Backend | Flask + Gunicorn |
| Database | PostgreSQL 15 |
