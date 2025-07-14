terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.3.0"
    }
  }
  required_version = ">= 1.0.0"
}

provider "aws" {
  # Uses current AWS CLI profile region if aws_region not specified
  region = var.aws_region
}
