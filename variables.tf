variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "vpc_cidr_block" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/24"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.0.0.0/26"
}

variable "public_subnet2_cidr" {
  description = "CIDR block for the second public subnet"
  type        = string
  default     = "10.0.0.64/26"
}

variable "private_subnet_cidr" {
  description = "CIDR block for the private subnet"
  type        = string
  default     = "10.0.0.128/26"
}

variable "private_subnet2_cidr" {
  description = "CIDR block for the second private subnet"
  type        = string
  default     = "10.0.0.192/26"
}


variable "my_ip" {
  description = "Your current public IP with CIDR notation (e.g., 203.0.113.0/32)"
  type        = string
}
