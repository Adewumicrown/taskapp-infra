#!/bin/bash
set -e

export KOPS_CLUSTER_NAME=taskapp.name.ng
export KOPS_STATE_STORE=s3://taskapp-kops-state-311156639915-us-east-1
export AWS_PROFILE=Taskapp-cluster-ops

echo "===================================="
echo "TaskApp Infrastructure Shutdown"
echo "===================================="

# Step 1: Delete Kops cluster
echo "[1/4] Deleting Kops cluster..."
kops delete cluster --name taskapp.name.ng --yes || echo "Cluster already deleted"

# Step 2: Empty Kops and etcd buckets completely (all versions)
# NOTE: We do NOT empty the Terraform state bucket
echo "[2/4] Emptying Kops S3 buckets (all versions)..."
~/taskapp-infra/scripts/empty_bucket.sh \
  taskapp-kops-state-311156639915-us-east-1

~/taskapp-infra/scripts/empty_bucket.sh \
  taskapp-etcd-backup-311156639915-us-east-1

# Step 3: Disable prevent_destroy and destroy infrastructure
echo "[3/4] Destroying Terraform infrastructure..."
sed -i 's/prevent_destroy = true/prevent_destroy = false/g' \
  ~/taskapp-infra/terraform/modules/s3/main.tf

cd ~/taskapp-infra/terraform
terraform destroy -auto-approve

# Step 4: Restore prevent_destroy
echo "[4/4] Restoring protect settings..."
sed -i 's/prevent_destroy = false/prevent_destroy = true/g' \
  ~/taskapp-infra/terraform/modules/s3/main.tf

echo ""
echo "===================================="
echo "✅ Everything destroyed!"
echo "   Credits protected 💰"
echo "===================================="
