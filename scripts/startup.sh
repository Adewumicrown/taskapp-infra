#!/bin/bash
set -e

echo "===================================="
echo "TaskApp Infrastructure Startup"
echo "===================================="

# Environment variables
export KOPS_CLUSTER_NAME=taskapp.name.ng
export KOPS_STATE_STORE=s3://taskapp-kops-state-311156639915-us-east-1
export AWS_PROFILE=Taskapp-cluster-ops
export AWS_REGION=us-east-1

# Step 1: Terraform apply
echo "[1/7] Rebuilding AWS infrastructure..."
cd ~/taskapp-infra/terraform
terraform init -reconfigure
terraform apply -auto-approve

# Step 2: Get new IDs
echo "[2/7] Getting new subnet and NAT Gateway IDs..."
VPC_ID=$(terraform output -raw vpc_id)
PRIVATE_SUBNET_0=$(terraform output -json private_subnet_ids | jq -r '.[0]')
PRIVATE_SUBNET_1=$(terraform output -json private_subnet_ids | jq -r '.[1]')
PRIVATE_SUBNET_2=$(terraform output -json private_subnet_ids | jq -r '.[2]')
PUBLIC_SUBNET_0=$(terraform output -json public_subnet_ids | jq -r '.[0]')
PUBLIC_SUBNET_1=$(terraform output -json public_subnet_ids | jq -r '.[1]')
PUBLIC_SUBNET_2=$(terraform output -json public_subnet_ids | jq -r '.[2]')

# Wait for NAT Gateways to be available
echo "Waiting for NAT Gateways to be available..."
sleep 30

# Get NAT Gateway IDs matched to their public subnets
NAT_0=$(aws ec2 describe-nat-gateways \
  --region $AWS_REGION \
  --profile Taskapp-cluster-ops \
  --filter "Name=state,Values=available" \
        "Name=subnet-id,Values=$PUBLIC_SUBNET_0" \
  --query 'NatGateways[0].NatGatewayId' \
  --output text)

NAT_1=$(aws ec2 describe-nat-gateways \
  --region $AWS_REGION \
  --profile Taskapp-cluster-ops \
  --filter "Name=state,Values=available" \
        "Name=subnet-id,Values=$PUBLIC_SUBNET_1" \
  --query 'NatGateways[0].NatGatewayId' \
  --output text)

NAT_2=$(aws ec2 describe-nat-gateways \
  --region $AWS_REGION \
  --profile Taskapp-cluster-ops \
  --filter "Name=state,Values=available" \
        "Name=subnet-id,Values=$PUBLIC_SUBNET_2" \
  --query 'NatGateways[0].NatGatewayId' \
  --output text)

echo "VPC: $VPC_ID"
echo "Public subnets: $PUBLIC_SUBNET_0, $PUBLIC_SUBNET_1, $PUBLIC_SUBNET_2"
echo "Private subnets: $PRIVATE_SUBNET_0, $PRIVATE_SUBNET_1, $PRIVATE_SUBNET_2"
echo "NAT Gateways: $NAT_0, $NAT_1, $NAT_2"

# Step 3: Automatically update cluster.yaml with new IDs
echo "[3/7] Automatically updating cluster.yaml with new IDs..."
python3 << PYEOF
import re

with open('/home/victor/taskapp-infra/terraform/kops/cluster.yaml', 'r') as f:
    content = f.read()

# Update VPC ID
content = re.sub(r'networkID: vpc-\S+', 'networkID: $VPC_ID', content)

# Update public subnets
content = re.sub(
    r'(name: us-east-1a-public\n    type: Public\n    zone: us-east-1a\n    id: )subnet-\S+',
    r'\g<1>$PUBLIC_SUBNET_0', content)
content = re.sub(
    r'(name: us-east-1b-public\n    type: Public\n    zone: us-east-1b\n    id: )subnet-\S+',
    r'\g<1>$PUBLIC_SUBNET_1', content)
content = re.sub(
    r'(name: us-east-1c-public\n    type: Public\n    zone: us-east-1c\n    id: )subnet-\S+',
    r'\g<1>$PUBLIC_SUBNET_2', content)

# Update private subnets with egress
content = re.sub(
    r'(name: us-east-1a-private\n    type: Private\n    zone: us-east-1a\n    id: )subnet-\S+(\n    egress: )nat-\S+',
    r'\g<1>$PRIVATE_SUBNET_0\g<2>$NAT_0', content)
content = re.sub(
    r'(name: us-east-1b-private\n    type: Private\n    zone: us-east-1b\n    id: )subnet-\S+(\n    egress: )nat-\S+',
    r'\g<1>$PRIVATE_SUBNET_1\g<2>$NAT_1', content)
content = re.sub(
    r'(name: us-east-1c-private\n    type: Private\n    zone: us-east-1c\n    id: )subnet-\S+(\n    egress: )nat-\S+',
    r'\g<1>$PRIVATE_SUBNET_2\g<2>$NAT_2', content)

with open('/home/victor/taskapp-infra/terraform/kops/cluster.yaml', 'w') as f:
    f.write(content)

print("cluster.yaml updated successfully!")
PYEOF

# Step 4: Recreate Kops cluster
echo "[4/7] Creating Kops cluster..."
kops create -f ~/taskapp-infra/terraform/kops/cluster.yaml
kops create secret sshpublickey admin \
  -i ~/.ssh/taskapp-cluster.pub \
  --name taskapp.name.ng
kops update cluster --name taskapp.name.ng --yes --admin

# Step 5: Wait for cluster
echo "[5/7] Waiting for cluster to be ready (~15 minutes)..."
sleep 500
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

# Wait for NGINX load balancer
echo "Waiting for NGINX load balancer..."
echo "This may take 2-3 minutes..."
for i in {1..20}; do
  ELB=$(kubectl get svc -n ingress-nginx ingress-nginx-controller \
    -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
  if [ ! -z "$ELB" ] && [ "$ELB" != "null" ]; then
    echo "Load balancer ready: $ELB"
    break
  fi
  echo "Waiting... ($i/20)"
  sleep 15
done

# Automatically update Route53 DNS records
echo "Updating Route53 DNS records..."
aws route53 change-resource-record-sets \
  --profile Taskapp-cluster-ops \
  --hosted-zone-id Z0925897Z02UN1WIO0T6 \
  --change-batch "{
    \"Changes\": [
      {
        \"Action\": \"UPSERT\",
        \"ResourceRecordSet\": {
          \"Name\": \"app.taskapp.name.ng\",
          \"Type\": \"CNAME\",
          \"TTL\": 300,
          \"ResourceRecords\": [{\"Value\": \"$ELB\"}]
        }
      },
      {
        \"Action\": \"UPSERT\",
        \"ResourceRecordSet\": {
          \"Name\": \"backend.taskapp.name.ng\",
          \"Type\": \"CNAME\",
          \"TTL\": 300,
          \"ResourceRecords\": [{\"Value\": \"$ELB\"}]
        }
      }
    ]
  }"

echo "DNS records updated with: $ELB"

# Step 7: Deploy application
echo "[7/7] Deploying application..."
kubectl apply -f ~/taskapp-infra/k8s/base/secrets/configmap.yaml
kubectl apply -f ~/taskapp-infra/k8s/base/secrets/secret.yaml
kubectl apply -f ~/taskapp-infra/k8s/base/database/postgres.yaml

echo "Waiting for database..."
kubectl rollout status statefulset/postgres --timeout=120s

kubectl apply -f ~/taskapp-infra/k8s/base/backend/deployment.yaml
kubectl apply -f ~/taskapp-infra/k8s/base/frontend/deployment.yaml

# Install cert-manager credentials and ClusterIssuer
cd ~/taskapp-infra/terraform
ACCESS_KEY_ID=$(terraform output -raw cert_manager_access_key_id)
SECRET_KEY=$(terraform output -raw cert_manager_secret_access_key)

kubectl create secret generic route53-credentials \
  --namespace cert-manager \
  --from-literal=access-key-id="$ACCESS_KEY_ID" \
  --from-literal=secret-access-key="$SECRET_KEY" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f ~/taskapp-infra/k8s/base/cert-manager/clusterissuer.yaml
kubectl apply -f ~/taskapp-infra/k8s/base/ingress/ingress.yaml

echo ""
echo "===================================="
echo "✅ TaskApp is up and running!"
echo "===================================="
echo "Frontend: https://app.taskapp.name.ng"
echo "Backend:  https://backend.taskapp.name.ng/api/health"
echo "ELB:      $ELB"
echo ""
kubectl get pods
