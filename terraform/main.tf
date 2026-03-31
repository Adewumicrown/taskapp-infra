terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = "Taskapp-cluster-ops"
}


module "vpc" {
  source       = "./modules/vpc"
  project_name = var.project_name
}


module "nat" {
  source               = "./modules/nat"
  project_name         = var.project_name
  public_subnet_ids    = module.vpc.public_subnet_ids
  private_subnet_ids   = module.vpc.private_subnet_ids
  private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]

  # NAT module depends on VPC being created first
  depends_on = [module.vpc]
}

module "iam" {
  source         = "./modules/iam"
  project_name   = var.project_name
  aws_account_id = "311156639915"
}

module "dns" {
  source      = "./modules/dns"
  domain_name = var.domain_name
  project_name = var.project_name
}
