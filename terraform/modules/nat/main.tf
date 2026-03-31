# Elastic IPs for NAT Gateways
# Each NAT Gateway needs a static public IP address
resource "aws_eip" "nat" {
  count  = length(var.public_subnet_ids)
  domain = "vpc"

  tags = {
    Name    = "${var.project_name}-nat-eip-${count.index + 1}"
    Project = var.project_name
  }
}

# NAT Gateways — one per public subnet (one per AZ)
resource "aws_nat_gateway" "main" {
  count         = length(var.public_subnet_ids)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = var.public_subnet_ids[count.index]

  tags = {
    Name    = "${var.project_name}-nat-${count.index + 1}"
    Project = var.project_name
  }

  # IGW must exist before NAT Gateway can be created
  depends_on = [aws_eip.nat]
}

# Private route tables — one per AZ
# Each private subnet routes internet traffic through its own NAT Gateway
resource "aws_route_table" "private" {
  count  = length(var.private_subnet_ids)
  vpc_id = data.aws_subnet.private[count.index].vpc_id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = {
    Name    = "${var.project_name}-private-rt-${count.index + 1}"
    Project = var.project_name
  }
}

# Look up subnet details to get VPC ID
data "aws_subnet" "private" {
  count = length(var.private_subnet_ids)
  id    = var.private_subnet_ids[count.index]
}

# Associate each private subnet with its own route table
resource "aws_route_table_association" "private" {
  count          = length(var.private_subnet_ids)
  subnet_id      = var.private_subnet_ids[count.index]
  route_table_id = aws_route_table.private[count.index].id
}
