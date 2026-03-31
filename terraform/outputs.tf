output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "nat_public_ips" {
  description = "NAT Gateway public IPs"
  value       = module.nat.nat_public_ips
}

output "master_instance_profile" {
  description = "Master node instance profile name"
  value       = module.iam.master_instance_profile_name
}

output "worker_instance_profile" {
  description = "Worker node instance profile name"
  value       = module.iam.worker_instance_profile_name
}

output "hosted_zone_id" {
  description = "Route53 Hosted Zone ID"
  value       = module.dns.zone_id
}

output "frontend_url" {
  description = "Frontend URL"
  value       = module.dns.frontend_url
}

output "backend_url" {
  description = "Backend URL"
  value       = module.dns.backend_url
}

output "kops_state_bucket" {
  description = "Kops state store bucket name"
  value       = module.s3.kops_state_bucket
}

output "etcd_backup_bucket" {
  description = "etcd backup bucket name"
  value       = module.s3.etcd_backup_bucket
}
