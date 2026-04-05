# TaskApp Operations Runbook

## Prerequisites

Ensure the following tools are installed:
- `terraform` >= 1.5.0
- `kops` >= 1.28.0
- `kubectl`
- `helm` >= 3.0
- `aws` CLI configured with `Taskapp-cluster-ops` profile
- `jq`

---

## 1. Deploying the Application

### Full Deployment (from scratch)
```bash
~/taskapp-infra/scripts/startup.sh
```

This script automatically:
1. Provisions AWS infrastructure via Terraform
2. Updates cluster.yaml with new subnet/NAT IDs
3. Creates the Kops Kubernetes cluster
4. Installs NGINX Ingress and cert-manager
5. Updates Route53 DNS records
6. Deploys all application components

**Expected duration:** 25-30 minutes

### Verify Deployment
```bash
# Check cluster health
kops validate cluster --name taskapp.name.ng

# Check all pods running
kubectl get pods

# Check SSL certificates
kubectl get certificates

# Test endpoints
curl -I https://app.taskapp.name.ng
curl -s https://backend.taskapp.name.ng/api/health
```

---

## 2. Destroying the Infrastructure

### Full Teardown
```bash
~/taskapp-infra/scripts/shutdown.sh
```

This script automatically:
1. Deletes the Kops cluster
2. Empties Kops and etcd S3 buckets (all versions)
3. Runs terraform destroy
4. Restores prevent_destroy settings

**Expected duration:** 10-15 minutes

---

## 3. Scaling the Cluster

### Scale Worker Nodes Manually
```bash
# Edit the nodes instance group
kops edit instancegroup nodes --name taskapp.name.ng

# Change minSize and maxSize as needed
# Then apply
kops update cluster --name taskapp.name.ng --yes
kops rolling-update cluster --name taskapp.name.ng --yes
```

### Scale Application Pods
```bash
# Scale frontend
kubectl scale deployment frontend --replicas=3

# Scale backend
kubectl scale deployment backend --replicas=3
```

---

## 4. Rotating Secrets

### Rotate Database Password
```bash
# Generate new password
NEW_PASSWORD=$(openssl rand -base64 32)

# Encode it
NEW_PASSWORD_B64=$(echo -n "$NEW_PASSWORD" | base64)

# Update the secret
kubectl patch secret taskapp-secret \
  -p "{\"data\":{\"DB_PASSWORD\":\"$NEW_PASSWORD_B64\"}}"

# Update the DATABASE_URL secret too
NEW_URL="postgresql://taskapp_user:${NEW_PASSWORD}@postgres-service:5432/taskapp"
NEW_URL_B64=$(echo -n "$NEW_URL" | base64)
kubectl patch secret taskapp-secret \
  -p "{\"data\":{\"DATABASE_URL\":\"$NEW_URL_B64\"}}"

# Update postgres password
kubectl exec -it postgres-0 -- psql -U taskapp_user -d taskapp \
  -c "ALTER USER taskapp_user PASSWORD '$NEW_PASSWORD';"

# Restart backend to pick up new credentials
kubectl rollout restart deployment/backend
```

### Rotate JWT Secret
```bash
# Generate new JWT secret
NEW_JWT=$(openssl rand -base64 64)
NEW_JWT_B64=$(echo -n "$NEW_JWT" | base64)

# Update the secret
kubectl patch secret taskapp-secret \
  -p "{\"data\":{\"JWT_SECRET\":\"$NEW_JWT_B64\"}}"

# Restart backend
kubectl rollout restart deployment/backend
```

### Rotate cert-manager AWS Credentials
```bash
# Apply new Terraform to generate new access key
cd ~/taskapp-infra/terraform
terraform apply -target=module.iam.aws_iam_access_key.cert_manager

# Update the Kubernetes secret
ACCESS_KEY_ID=$(terraform output -raw cert_manager_access_key_id)
SECRET_KEY=$(terraform output -raw cert_manager_secret_access_key)

kubectl create secret generic route53-credentials \
  --namespace cert-manager \
  --from-literal=access-key-id="$ACCESS_KEY_ID" \
  --from-literal=secret-access-key="$SECRET_KEY" \
  --dry-run=client -o yaml | kubectl apply -f -

# Restart cert-manager
kubectl rollout restart deployment/cert-manager -n cert-manager
```

---

## 5. Troubleshooting Common Failures

### Pod in CrashLoopBackOff
```bash
# Check logs
kubectl logs <pod-name> --previous

# Check events
kubectl describe pod <pod-name>

# Check resource constraints
kubectl top pods
```

### Database Connection Failure
```bash
# Verify postgres is running
kubectl get pods -l app=postgres

# Check postgres logs
kubectl logs postgres-0

# Test connection from backend pod
kubectl exec -it <backend-pod> -- python -c "
import os; print('DB URL:', os.environ.get('DATABASE_URL'))
"
```

### SSL Certificate Not Issuing
```bash
# Check certificate status
kubectl describe certificate taskapp-frontend-tls
kubectl describe certificate taskapp-backend-tls

# Check challenges
kubectl get challenges
kubectl describe challenges

# Check cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager --tail=50
```

### Cluster Validation Failing
```bash
# Export fresh kubeconfig
kops export kubeconfig --name taskapp.name.ng --admin

# Check node status
kubectl get nodes

# Check system pods
kubectl get pods -n kube-system

# Full validation
kops validate cluster --name taskapp.name.ng --wait 10m
```

### NGINX Ingress Not Routing
```bash
# Check ingress
kubectl get ingress
kubectl describe ingress taskapp-ingress

# Check NGINX pods
kubectl get pods -n ingress-nginx

# Check NGINX logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx --tail=50
```

---

## 6. Database Backup and Restore

### Manual Database Backup
```bash
# Create a backup
kubectl exec -it postgres-0 -- pg_dump \
  -U taskapp_user taskapp > taskapp_backup_$(date +%Y%m%d).sql

# Upload to S3
aws s3 cp taskapp_backup_$(date +%Y%m%d).sql \
  s3://taskapp-etcd-backup-311156639915-us-east-1/db-backups/ \
  --profile Taskapp-cluster-ops
```

### Restore Database
```bash
# Copy backup to pod
kubectl cp taskapp_backup.sql postgres-0:/tmp/

# Restore
kubectl exec -it postgres-0 -- psql \
  -U taskapp_user -d taskapp -f /tmp/taskapp_backup.sql
```

---

## 7. Zero-Downtime Deployment

### Deploy New Application Version
```bash
# Update image tag in deployment
kubectl set image deployment/backend \
  backend=adewumicrown/taskapp-backend:v2

# Watch rolling update
kubectl rollout status deployment/backend

# Rollback if needed
kubectl rollout undo deployment/backend
```
