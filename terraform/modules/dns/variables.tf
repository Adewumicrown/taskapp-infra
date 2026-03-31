variable "domain_name" {
  description = "Root domain name"
  type        = string
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "frontend_subdomain" {
  description = "Subdomain for the frontend"
  type        = string
  default     = "app"
}

variable "backend_subdomain" {
  description = "Subdomain for the backend API"
  type        = string
  default     = "api"
}

variable "load_balancer_hostname" {
  description = "Hostname of the load balancer (set after cluster is created)"
  type        = string
  default     = ""
}
