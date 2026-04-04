output "master_role_arn" {
  description = "ARN of the master node IAM role"
  value       = aws_iam_role.master_node.arn
}

output "worker_role_arn" {
  description = "ARN of the worker node IAM role"
  value       = aws_iam_role.worker_node.arn
}

output "master_instance_profile_name" {
  description = "Name of the master node instance profile"
  value       = aws_iam_instance_profile.master_node.name
}

output "worker_instance_profile_name" {
  description = "Name of the worker node instance profile"
  value       = aws_iam_instance_profile.worker_node.name
}

output "cert_manager_access_key_id" {
  value = aws_iam_access_key.cert_manager.id
}

output "cert_manager_secret_access_key" {
  value     = aws_iam_access_key.cert_manager.secret
  sensitive = true
}
