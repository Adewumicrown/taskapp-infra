#!/bin/bash
set -e

echo "===================================="
echo "TaskApp Infrastructure Startup"
echo "===================================="

# Environment variables
export KOPS_CLUSTER_NAME=taskapp.name.ng
export KOPS_STATE_STORE=s3://taskapp-kops-state-311156639915-us-east-1
export AWS_PROFILE=Taskapp-cluster-ops

# Step 1: Terraform apply
echo "[1/7] Rebuilding AWS infrastructure..."
cd ~/taskapp-infra/terraform
terraform apply -auto-approve

# Step 2: Get new IDs
echo "[2/7] Getting new subnet and NAT Gateway IDs..."
VPC_ID=$(terraform output -raw vpc_id)
PRIVATE_SUBNETS=($(terraform output -json private_subnet_ids | jq -r '.[]'))
PUBLIC_SUBNETS=($(terraform output -json public_subnet_ids | jq -r '.[]'))

NAT_INFO=$(aws ec2 describe-nat-gateways \
  --region us-east-1 \
  --profile Taskapp-cluster-ops \
  --filter "Name=state,Values=available" \
  --query 'NatGateways[*].{ID:NatGatewayId,Subnet:SubnetId}' \
  --output json)

# Step 3: Update cluster.yaml with new IDs
echo "[3/7] Updating cluster.yaml with new IDs..."
python3 - << PYEOF
import json
import subprocess

# Get NAT gateway info
nat_info = json.loads("""$NAT_INFO""")
public_subnets = "${PUBLIC_SUBNETS[@]}".split()
private_subnets = "${PRIVATE_SUBNETS[@]}".split()

# Map NAT gateways to AZs
nat_map = {}
for nat in nat_info:
    subnet = nat['Subnet']
    if subnet in public_subnets:
        idx = public_subnets.index(subnet)
        nat_map[idx] = nat['ID']

# Read cluster.yaml
with open('/root/taskapp-infra/terraform/kops/cluster.yaml', 'r') as f:
    content = f.read()

# These will be replaced manually - print values for reference
print("VPC ID:", "$VPC_ID")
print("Public subnets:", public_subnets)
print("Private subnets:", private_subnets)
print("NAT mapping:", nat_map)
PYEOF

echo ""
echo "⚠️  Please update cluster.yaml manually with the above IDs"
echo "    Then press ENTER to continue..."
read

# Step 4: Recreate Kops cluster
echo "[4/7] Creating Kops cluster..."
kops create -f ~/taskapp-infra/terraform/kops/cluster.yaml
kops create secret sshpublickey admin \
  -i ~/.ssh/taskapp-cluster.pub \
  --name taskapp.name.ng
kops update cluster --name taskapp.name.ng --yes --admin

# Step 5: Wait for cluster
echo "[5/7] Waiting for cluster to be ready (this takes ~15 minutes)..."
sleep 600
kops export kubeconfig --name taskapp.name.ng --admin
kops validate cluster --wait 10m

# Step 6: Install Helm charts
echo "[6/7] Installing NGINX Ingress and cert-manager..."
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add jetstack https://charts.jetstack.io
helm repo update

helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.replicaCount=2 \
  --set controller.service.type=LoadBalancer \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-type"=nlb

helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set crds.enabled=true

echo "Waiting for NGINX load balancer..."
sleep 60
ELB=$(kubectl get svc -n ingress-nginx ingress-nginx-controller \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "New ELB: $ELB"

echo ""
echo "⚠️  Update Route53 DNS records with new ELB: $ELB"
echo "    Then press ENTER to continue..."
read

# Step 7: Deploy application
echo "[7/7] Deploying application..."
kubectl apply -f ~/taskapp-infra/k8s/base/secrets/configmap.yaml
kubectl apply -f ~/taskapp-infra/k8s/base/secrets/secret.yaml
kubectl apply -f ~/taskapp-infra/k8s/base/database/postgres.yaml

echo "Waiting for database..."
kubectl rollout status statefulset/postgres

kubectl apply -f ~/taskapp-infra/k8s/base/backend/deployment.yaml
kubectl apply -f ~/taskapp-infra/k8s/base/frontend/deployment.yaml

# Install cert-manager secret and ClusterIssuer
kubectl create secret generic route53-credentials \
  --namespace cert-manager \
  --from-literal=secret-access-key="$(terraform output -raw cert_manager_secret_access_key)" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f ~/taskapp-infra/k8s/base/cert-manager/clusterissuer.yaml
kubectl apply -f ~/taskapp-infra/k8s/base/ingress/ingress.yaml

echo ""
echo "===================================="
echo "✅ TaskApp is up and running!"
echo "===================================="
echo "Frontend: https://app.taskapp.name.ng"
echo "Backend:  https://backend.taskapp.name.ng/api/health"
echo ""
kubectl get pods
