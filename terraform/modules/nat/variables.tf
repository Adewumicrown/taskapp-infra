variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "public_subnet_ids" {
  description = "IDs of public subnets to place NAT Gateways in"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks of private subnets"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "IDs of private subnets to route through NAT"
  type        = list(string)
}
