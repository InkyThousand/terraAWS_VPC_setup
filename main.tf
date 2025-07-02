terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "6.0.0"
    }
  }
}

provider "aws" {
    region = "us-west-2"
   //Configuration options
}

# Creating a VPC with a CIDR block of 10.0.0.0/24
resource "aws_vpc" "myVPC" {
  cidr_block = "10.0.0.0/25"

  tags = {
    Name = "myVPC"
  }

}

# Create Private Subnet
resource "aws_subnet" "privateSubnet" {
  vpc_id = aws_vpc.myVPC.id
  cidr_block = "10.0.0.0/26"
  availability_zone = "us-west-2a"
  tags = {
    Name = "privateSubnet"
  }
}

# Create Public Subnet
resource "aws_subnet" "publicSubnet" {
  vpc_id = aws_vpc.myVPC.id
  cidr_block = "10.0.0.64/28"
  availability_zone = "us-west-2a"

  map_public_ip_on_launch = true # Enable Public IP on launch

  tags = {
    Name = "publicSubnet"
  }
}   

# Create Internet Gateway
resource "aws_internet_gateway" "myIGW" {
  vpc_id = aws_vpc.myVPC.id

  tags = {
    Name = "myIGW"
  }
}

# Create Route Table
resource "aws_route_table" "myPublicRouteTable" {
  vpc_id = aws_vpc.myVPC.id

  // Create Route to Internet Gateway
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.myIGW.id
  }
  
  tags = {
    Name = "myPublic RouteTable"
  }
}

# Associate Route Table with Public Subnet
resource "aws_route_table_association" "public" {
  subnet_id = aws_subnet.publicSubnet.id
  route_table_id = aws_route_table.myPublicRouteTable.id
}

###################################################

# Allocate Elastic IP for NAT Gateway
resource "aws_eip" "elasticIP" {
  domain = "vpc"
}

# Create NAT Gateway in the public subnet
resource "aws_nat_gateway" "myNATGateway" {
  allocation_id = aws_eip.elasticIP.id
  subnet_id = aws_subnet.publicSubnet.id

  tags = {
    Name="myNATGateway"
  }
}

###################################################

# Create Route Table for Private Subnet
resource "aws_route_table" "myPrivateRouteTable" {
  vpc_id = aws_vpc.myVPC.id
  route {
      cidr_block = "0.0.0.0/0"
      nat_gateway_id = aws_nat_gateway.myNATGateway.id // Create Route to NAT Gateway in Private Route Table
  }

  tags = {
    Name="myPrivateRouteTable"
  }
  
}

# Associate Private Route Table with Private Subnet
resource "aws_route_table_association" "private" {
  subnet_id = aws_subnet.privateSubnet.id
  route_table_id = aws_route_table.myPrivateRouteTable.id
}


# VPC setup completed successfully!