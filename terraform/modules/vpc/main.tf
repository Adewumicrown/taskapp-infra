# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name    = "${var.project_name}-vpc"
    Project = var.project_name
  }
}

# Internet Gateway — allows public subnets to reach the internet
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name    = "${var.project_name}-igw"
    Project = var.project_name
  }
}

# Public subnets — one per AZ
resource "aws_subnet" "public" {
  count             = length(var.public_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  # Instances launched here get a public IP automatically
  map_public_ip_on_launch = true

  lifecycle {
    ignore_changes = [tags]
  }

  tags = {
    Name                     = "${var.project_name}-public-${var.availability_zones[count.index]}"
    Project                  = var.project_name
    Type                     = "public"
    # These tags are required by Kops and the AWS Load Balancer Controller
    "kubernetes.io/role/elb" = "1"
  }
}

# Private subnets — one per AZ
resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  # No public IPs — nodes stay private
  map_public_ip_on_launch = false

  lifecycle {
    ignore_changes = [tags]
  }

  tags = {
    Name                              = "${var.project_name}-private-${var.availability_zones[count.index]}"
    Project                           = var.project_name
    Type                              = "private"
    # Required by Kops for internal load balancers
    "kubernetes.io/role/internal-elb" = "1"
  }
}

# Route table for public subnets — sends internet traffic through the IGW
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name    = "${var.project_name}-public-rt"
    Project = var.project_name
  }
}

# Associate public route table with each public subnet
resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}
