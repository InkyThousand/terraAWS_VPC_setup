# TerraVPS Setup

A Terraform project for provisioning a secure, highly available Virtual Private Server (VPS) infrastructure on AWS.

## Project Overview

This project uses Terraform to create a complete VPC setup in AWS with both public and private subnets across multiple availability zones, providing a secure and resilient foundation for hosting applications. The infrastructure includes:

- A VPC with a CIDR block of 10.0.0.0/25
- Private subnets across multiple AZs for secure internal resources
- Public subnets across multiple AZs for internet-facing components
- Internet Gateway for public internet access
- NAT Gateways to allow private subnet resources to access the internet
- Application Load Balancer (ALB) for distributing traffic to applications
- RDS database instance in a Multi-AZ configuration for high availability
- Appropriate route tables and security group associations

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
                                           |
                      +-------------------+ | +-------------------+
                      |                   | | |                   |
+---------------------+---+   +-----------+-+-+-------------------+---------------------+
|                         |   |                                   |                     |
| Public Subnet AZ1       |   |      Application Load Balancer    |  Public Subnet AZ2  |
|                         |   |                                   |                     |
| +---------------------+ |   +-------------------+---------------+ +-------------------+
| |                     | |                       |                 |                   |
| |  NAT Gateway AZ1    | |                       |                 |  NAT Gateway AZ2  |
| |                     | |                       |                 |                   |
| +----------+----------+ |                       |                 +---------+---------+
|            |            |                       |                           |         |
+------------+------------+                       |                 +---------+---------+
             |                                    |                           |
             v                                    v                           v
+------------+------------+   +------------------+------------------+---------+---------+
|                         |   |                                     |                   |
| Private Subnet AZ1      |   |                                     | Private Subnet AZ2|
|                         |   |                                     |                   |
| +---------------------+ |   |                                     | +---------------+ |
| |                     | |   |                                     | |               | |
| |  App Servers        +<----+                                     +-+ App Servers   | |
| |                     | |                                         | |               | |
| +---------------------+ |                                         | +---------------+ |
|                         |                                         |                   |
| +---------------------+ |                                         | +---------------+ |
| |                     | |                                         | |               | |
| |  RDS Primary        +<----------------------------------------->+ RDS Standby    | |
| |                     | |           Multi-AZ Replication          | |               | |
| +---------------------+ |                                         | +---------------+ |
|                         |                                         |                   |
+-------------------------+                                         +-------------------+
```

## Prerequisites

- AWS account with appropriate permissions
- Terraform installed (version 1.0.0 or later)
- AWS CLI configured with valid credentials

# Generate the key pair outside of Terraform

1. Generate the key pair locally:

`ssh-keygen -t rsa -b 2048 -f ~/.ssh/bastion_key -N ""`

   a. Make sure you have the private key file (that you generated with ssh-keygen) on your local machine:
   `ls -la ~/.ssh/bastion_key`
   b. Set the correct permissions for your private key file (if not already done):
   `chmod 400 ~/.ssh/bastion_key`

3. Copy the public key to your directory
4. Add the public key file to your GitHub repository
5. Keep the private key secure on your local machine

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
5. Run command to get your IP and set it into variable:
   ```
   ./myIP.sh >> terraform.tfvars
   ```

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
- RDS instance type and configuration
- ALB settings and target groups

## High Availability Features

This infrastructure is designed for high availability and fault tolerance:

- **Multi-AZ Deployment**: Resources are distributed across multiple Availability Zones to protect against AZ failures
- **Application Load Balancer**: Distributes incoming traffic across multiple targets in multiple AZs
- **Multi-AZ RDS**: Database is replicated synchronously to a standby instance in a different AZ
- **Redundant NAT Gateways**: Each AZ has its own NAT Gateway to prevent single points of failure

## Security Considerations

This setup implements security best practices by:
- Isolating resources in private subnets
- Using NAT Gateways for secure outbound connectivity
- Implementing security groups with least privilege access
- Limiting public exposure to only necessary resources (ALB)
- Encrypting data at rest in RDS instances

## Use Cases

This infrastructure is ideal for a variety of applications that require secure, scalable, and highly available hosting:

### Web Applications with Secure Backend
- **Public Subnet**: Host load balancers and web servers that need direct internet access
- **Private Subnet**: Deploy application servers, databases, and other sensitive components that should not be directly accessible from the internet

### Microservices Architecture
- Securely host different microservices across public and private subnets
- Enable controlled communication between services while maintaining security boundaries
- Ensure high availability with multi-AZ deployment and load balancing

### Enterprise Applications
- Support mission-critical applications with high availability requirements
- Implement database redundancy with Multi-AZ RDS
- Scale horizontally behind the Application Load Balancer

### Development and Testing Environments
- Create isolated environments for development, testing, and production
- Maintain consistent networking configurations across all environments

### Compliance-Focused Applications
- Support applications that need to meet PCI DSS, HIPAA, or other compliance requirements
- Implement network segmentation as required by various security frameworks
- Ensure data redundancy and availability with Multi-AZ database deployments

### Hybrid Cloud Connectivity
- Establish a foundation for connecting on-premises infrastructure to AWS resources
- Set up VPN or Direct Connect in the public subnet while keeping sensitive workloads in the private subnet


### Check user-data logs if Wordpress instance had a problem

tail -f /var/log/user-data.log
sudo cat /var/log/dnf-update.log
sudo cat /var/log/dnf-install.log
sudo cat /var/log/wordpress-download.log

### Check cloud-init logs:

sudo tail -f /var/log/cloud-init-output.log
sudo journalctl -u cloud-final