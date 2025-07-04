# TerraVPS Setup

A Terraform project for provisioning a secure Virtual Private Server (VPS) infrastructure on AWS.

## Project Overview

This project uses Terraform to create a complete VPC setup in AWS with both public and private subnets, providing a secure foundation for hosting applications. The infrastructure includes:

- A VPC with a CIDR block of 10.0.0.0/25
- A private subnet (10.0.0.0/26) for secure internal resources
- A public subnet (10.0.0.64/28) for internet-facing components
- Internet Gateway for public internet access
- NAT Gateway to allow private subnet resources to access the internet
- Appropriate route tables and associations

## Architecture

```
                                  +----------------+
                                  |                |
                                  |    Internet    |
                                  |                |
                                  +--------+-------+
                                           |
                                           |
                                  +--------v-------+
                                  |                |
                                  | Internet       |
                                  | Gateway (IGW)  |
                                  |                |
                                  +--------+-------+
                                           |
+----------------------------------+       |       +----------------------------------+
|                                  |       |       |                                  |
|  Public Subnet (10.0.0.64/28)    +-------+       |  Private Subnet (10.0.0.0/26)   |
|                                  |               |                                  |
|  +----------------------------+  |               |  +----------------------------+  |
|  |                            |  |               |  |                            |  |
|  |  NAT Gateway               |  |               |  |  Private Resources         |  |
|  |                            |  |               |  |                            |  |
|  +-------------+--------------+  |               |  +----------------------------+  |
|                |                 |               |                                  |
+----------------+-----------------+               +----------------------------------+
                 |
                 | (Outbound traffic from private subnet)
                 v
        +------------------+
        |                  |
        |    Internet      |
        |                  |
        +------------------+
```

## Prerequisites

- AWS account with appropriate permissions
- Terraform installed (version 1.0.0 or later)
- AWS CLI configured with valid credentials

## Usage

1. Clone this repository
2. Navigate to the project directory
3. Initialize Terraform:
   ```
   terraform init
   ```
4. Review the planned changes:
   ```
   terraform plan
   ```
5. Run command to get you IP and set in into variable
   ./myIP.sh >> terraform.tfvars

6. Apply the configuration:
   ```
   terraform apply
   ```
7. To destroy the infrastructure when no longer needed:
   ```
   terraform destroy
   ```

## Configuration

The main configuration is defined in `main.tf`. You can customize the following parameters:

- AWS region (currently set to us-west-2)
- VPC CIDR block
- Subnet CIDR blocks
- Availability zones

## Security Considerations

This setup implements security best practices by:
- Isolating resources in a private subnet
- Using a NAT Gateway for secure outbound connectivity
- Limiting public exposure to only necessary resources

## Use Cases

This infrastructure is ideal for a variety of applications that require secure, scalable hosting:

### Web Applications with Secure Backend
- **Public Subnet**: Host load balancers, API gateways, and web servers that need direct internet access
- **Private Subnet**: Deploy application servers, databases, and other sensitive components that should not be directly accessible from the internet

### Microservices Architecture
- Securely host different microservices across public and private subnets
- Enable controlled communication between services while maintaining security boundaries

### Development and Testing Environments
- Create isolated environments for development, testing, and production
- Maintain consistent networking configurations across all environments

### Compliance-Focused Applications
- Support applications that need to meet PCI DSS, HIPAA, or other compliance requirements
- Implement network segmentation as required by various security frameworks

### Hybrid Cloud Connectivity
- Establish a foundation for connecting on-premises infrastructure to AWS resources
- Set up VPN or Direct Connect in the public subnet while keeping sensitive workloads in the private subnet
