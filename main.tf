provider "aws" {
  # Uses current AWS CLI profile region if aws_region not specified
  region = var.aws_region
}

# Get current AWS region
data "aws_region" "current" {}

# Get available AZs in current region
data "aws_availability_zones" "available" {
  state = "available"
}

# Creating a VPC with specified CIDR block
resource "aws_vpc" "myVPC" {
  cidr_block           = var.vpc_cidr_block

  tags = {
    Name        = "myVPC"
    Environment = var.environment
    Terraform   = "true"
  }
}

# Create Private Subnet
resource "aws_subnet" "privateSubnet" {
  vpc_id            = aws_vpc.myVPC.id
  cidr_block        = var.private_subnet_cidr
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name        = "privateSubnet"
    Environment = var.environment
    Terraform   = "true"
  }
}

# Create second private subnet for RDS (requires 2 AZs)
resource "aws_subnet" "privateSubnet2" {
  vpc_id            = aws_vpc.myVPC.id
  cidr_block        = var.private_subnet2_cidr
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name        = "privateSubnet2"
    Environment = var.environment
    Terraform   = "true"
  }
}

# Create Public Subnet
resource "aws_subnet" "publicSubnet" {
  vpc_id                  = aws_vpc.myVPC.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true # Enable Public IP on launch

  tags = {
    Name        = "publicSubnet"
    Environment = var.environment
    Terraform   = "true"
  }
}

# Create second public subnet for ALB (requires 2 AZs)
resource "aws_subnet" "publicSubnet2" {
  vpc_id                  = aws_vpc.myVPC.id
  cidr_block              = var.public_subnet2_cidr
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name        = "publicSubnet2"
    Environment = var.environment
    Terraform   = "true"
  }
}   

# Create Internet Gateway
resource "aws_internet_gateway" "myIGW" {
  vpc_id = aws_vpc.myVPC.id

  tags = {
    Name        = "myIGW"
    Environment = var.environment
    Terraform   = "true"
  }
}

# Create Public Route Table
resource "aws_route_table" "myPublicRouteTable" {
  vpc_id = aws_vpc.myVPC.id

  # Create Route to Internet Gateway
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.myIGW.id
  }
  
  tags = {
    Name        = "myPublicRouteTable"
    Environment = var.environment
    Terraform   = "true"
  }
}

# Associate Route Table with Public Subnets
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.publicSubnet.id
  route_table_id = aws_route_table.myPublicRouteTable.id
}

resource "aws_route_table_association" "public2" {
  subnet_id      = aws_subnet.publicSubnet2.id
  route_table_id = aws_route_table.myPublicRouteTable.id
}

# Allocate Elastic IP for NAT Gateway
resource "aws_eip" "elasticIP" {
  domain = "vpc"
  
  tags = {
    Name        = "NAT-Gateway-EIP"
    Environment = var.environment
    Terraform   = "true"
  }
}

# Create NAT Gateway in the public subnet
resource "aws_nat_gateway" "myNATGateway" {
  allocation_id = aws_eip.elasticIP.id
  subnet_id     = aws_subnet.publicSubnet.id

  tags = {
    Name        = "myNATGateway"
    Environment = var.environment
    Terraform   = "true"
  }
  
  # To ensure proper ordering, add an explicit dependency on the Internet Gateway
  depends_on = [aws_internet_gateway.myIGW]
}

# Create Route Table for Private Subnet
resource "aws_route_table" "myPrivateRouteTable" {
  vpc_id = aws_vpc.myVPC.id
  
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.myNATGateway.id # Create Route to NAT Gateway in Private Route Table
  }

  tags = {
    Name        = "myPrivateRouteTable"
    Environment = var.environment
    Terraform   = "true"
  }
}

# Associate Private Route Table with Private Subnets
resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.privateSubnet.id
  route_table_id = aws_route_table.myPrivateRouteTable.id
}

resource "aws_route_table_association" "private2" {
  subnet_id      = aws_subnet.privateSubnet2.id
  route_table_id = aws_route_table.myPrivateRouteTable.id
}

# Wait for NAT Gateway to be fully operational
resource "time_sleep" "wait_for_nat_gateway" {
  depends_on = [
    aws_nat_gateway.myNATGateway,
    aws_route_table_association.private
  ]

  create_duration = "120s"
}
