output "zone_id" {
  description = "Route53 Hosted Zone ID"
  value       = data.aws_route53_zone.main.zone_id
}

output "zone_name_servers" {
  description = "Name servers for the hosted zone"
  value       = data.aws_route53_zone.main.name_servers
}

output "frontend_url" {
  description = "Frontend application URL"
  value       = "https://${var.frontend_subdomain}.${var.domain_name}"
}

output "backend_url" {
  description = "Backend API URL"
  value       = "https://${var.backend_subdomain}.${var.domain_name}"
}
