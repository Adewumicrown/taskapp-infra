variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "taskapp"
}

variable "domain_name" {
  description = "Root domain name"
  type        = string
  default     = "taskapp.name.ng"
}
