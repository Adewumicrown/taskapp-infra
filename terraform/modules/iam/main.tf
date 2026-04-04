# ─── Kops Admin Role ───────────────────────────────────────────────────────
resource "aws_iam_policy" "kops_admin" {
  name        = "${var.project_name}-kops-admin-policy"
  description = "Permissions for Kops to create and manage clusters"
  policy      = data.aws_iam_policy_document.kops_admin.json
}

# Attach kops admin policy to your existing IAM user (Taskapp-cluster-ops)
resource "aws_iam_user_policy_attachment" "kops_admin" {
  user       = "Taskapp-cluster-ops"
  policy_arn = aws_iam_policy.kops_admin.arn
}

# ─── Master Node Role ──────────────────────────────────────────────────────
resource "aws_iam_role" "master_node" {
  name               = "${var.project_name}-master-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
  description        = "Role assumed by Kubernetes master nodes"

  tags = {
    Name    = "${var.project_name}-master-role"
    Project = var.project_name
  }
}

resource "aws_iam_policy" "master_node" {
  name        = "${var.project_name}-master-policy"
  description = "Permissions for Kubernetes master nodes"
  policy      = data.aws_iam_policy_document.master_node.json
}

resource "aws_iam_role_policy_attachment" "master_node" {
  role       = aws_iam_role.master_node.name
  policy_arn = aws_iam_policy.master_node.arn
}

# Instance profile — attaches the master role to EC2 instances
resource "aws_iam_instance_profile" "master_node" {
  name = "${var.project_name}-master-profile"
  role = aws_iam_role.master_node.name
}

# ─── Worker Node Role ──────────────────────────────────────────────────────
resource "aws_iam_role" "worker_node" {
  name               = "${var.project_name}-worker-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
  description        = "Role assumed by Kubernetes worker nodes"

  tags = {
    Name    = "${var.project_name}-worker-role"
    Project = var.project_name
  }
}

resource "aws_iam_policy" "worker_node" {
  name        = "${var.project_name}-worker-policy"
  description = "Permissions for Kubernetes worker nodes"
  policy      = data.aws_iam_policy_document.worker_node.json
}

resource "aws_iam_role_policy_attachment" "worker_node" {
  role       = aws_iam_role.worker_node.name
  policy_arn = aws_iam_policy.worker_node.arn
}

# Instance profile — attaches the worker role to EC2 instances
resource "aws_iam_instance_profile" "worker_node" {
  name = "${var.project_name}-worker-profile"
  role = aws_iam_role.worker_node.name
}

resource "aws_iam_user" "cert_manager" {
  name = "${var.project_name}-cert-manager"
  tags = {
    Project = var.project_name
  }
}

resource "aws_iam_policy" "cert_manager_route53" {
  name        = "${var.project_name}-cert-manager-route53"
  description = "Allows cert-manager to manage Route53 records for SSL"
  policy      = data.aws_iam_policy_document.cert_manager_route53.json
}

resource "aws_iam_user_policy_attachment" "cert_manager" {
  user       = aws_iam_user.cert_manager.name
  policy_arn = aws_iam_policy.cert_manager_route53.arn
}

resource "aws_iam_access_key" "cert_manager" {
  user = aws_iam_user.cert_manager.name
}
