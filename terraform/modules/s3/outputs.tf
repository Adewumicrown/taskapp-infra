output "kops_state_bucket" {
  description = "Name of the Kops state store bucket"
  value       = aws_s3_bucket.kops_state.id
}

output "kops_state_bucket_arn" {
  description = "ARN of the Kops state store bucket"
  value       = aws_s3_bucket.kops_state.arn
}

output "etcd_backup_bucket" {
  description = "Name of the etcd backup bucket"
  value       = aws_s3_bucket.etcd_backup.id
}

output "etcd_backup_bucket_arn" {
  description = "ARN of the etcd backup bucket"
  value       = aws_s3_bucket.etcd_backup.arn
}
