# Import the existing hosted zone we created manually
# This tells Terraform to manage it without recreating it
data "aws_route53_zone" "main" {
  name         = var.domain_name
  private_zone = false
}

# Frontend DNS record — app.taskapp.name.ng
# We use a conditional so this only creates when
# a load balancer hostname is provided
resource "aws_route53_record" "frontend" {
  count   = var.load_balancer_hostname != "" ? 1 : 0
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "${var.frontend_subdomain}.${var.domain_name}"
  type    = "CNAME"
  ttl     = 300
  records = [var.load_balancer_hostname]
}

# Backend DNS record — api.taskapp.name.ng
resource "aws_route53_record" "backend" {
  count   = var.load_balancer_hostname != "" ? 1 : 0
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "${var.backend_subdomain}.${var.domain_name}"
  type    = "CNAME"
  ttl     = 300
  records = [var.load_balancer_hostname]
}
