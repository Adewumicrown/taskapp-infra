#!/bin/bash
set -e

export KOPS_CLUSTER_NAME=taskapp.name.ng
export KOPS_STATE_STORE=s3://taskapp-kops-state-311156639915-us-east-1
export AWS_PROFILE=Taskapp-cluster-ops

echo "===================================="
echo "TaskApp Infrastructure Shutdown"
echo "===================================="

# Step 1: Delete Kops cluster
echo "[1/5] Deleting Kops cluster..."
kops delete cluster --name taskapp.name.ng --yes || echo "Cluster already deleted, continuing..."

# Step 2: Empty all S3 buckets
echo "[2/5] Emptying S3 buckets..."

# Empty Kops state bucket
aws s3 rm s3://taskapp-kops-state-311156639915-us-east-1 \
  --recursive \
  --profile Taskapp-cluster-ops || echo "Kops state bucket already empty"

# Empty etcd backup bucket
aws s3 rm s3://taskapp-etcd-backup-311156639915-us-east-1 \
  --recursive \
  --profile Taskapp-cluster-ops || echo "etcd backup bucket already empty"

# Step 3: Disable prevent_destroy on S3 buckets
echo "[3/5] Disabling prevent_destroy on S3 buckets..."
sed -i 's/prevent_destroy = true/prevent_destroy = false/g' \
  ~/taskapp-infra/terraform/modules/s3/main.tf

# Step 4: Destroy all Terraform infrastructure
echo "[4/5] Destroying all Terraform infrastructure..."
cd ~/taskapp-infra/terraform
terraform destroy -auto-approve

# Step 5: Restore prevent_destroy for next time
echo "[5/5] Restoring prevent_destroy settings..."
sed -i 's/prevent_destroy = false/prevent_destroy = true/g' \
  ~/taskapp-infra/terraform/modules/s3/main.tf

echo ""
echo "===================================="
echo "✅ Everything destroyed!"
echo "   All S3 buckets deleted"
echo "   All AWS resources removed"
echo "   Credits protected 💰"
echo "===================================="

# Step 6: Enable prevent_destroy on S3 buckets
echo "[3/5] Enabling prevent_destroy on S3 buckets..."
sed -i 's/prevent_destroy = false/prevent_destroy = true/g' \
  ~/taskapp-infra/terraform/modules/s3/main.tf
