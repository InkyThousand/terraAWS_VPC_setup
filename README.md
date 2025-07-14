# TerraVPS Setup

A Terraform project for provisioning a secure, highly available Virtual Private Server (VPS) infrastructure on AWS with WordPress hosting capabilities.

## Project Overview

This project uses Terraform to create a complete VPC setup in AWS with both public and private subnets across multiple availability zones, providing a secure and resilient foundation for hosting WordPress applications. The infrastructure includes:

- A VPC with a CIDR block of 10.0.0.0/24
- Private subnets across multiple AZs for secure internal resources
- Public subnets across multiple AZs for internet-facing components
- Internet Gateway for public internet access
- NAT Gateway to allow private subnet resources to access the internet
- Application Load Balancer (ALB) for distributing traffic to WordPress instances
- Auto Scaling Group with 2-4 WordPress instances for high availability
- RDS MySQL database instance in a Multi-AZ configuration
- CloudWatch monitoring and auto-scaling policies
- Bastion host for secure SSH access to private resources

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
| |  Bastion Host       | |                       |                 |                   |
| |  NAT Gateway        | |                       |                 |                   |
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
| |  WordPress ASG      +<----+                                     +-+ WordPress ASG | |
| |  (2-4 instances)    | |                                         | | (2-4 instances)| |
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

## SSH Key Setup

1. Generate the SSH key pair locally:
   ```bash
   ssh-keygen -t rsa -b 2048 -f ~/.ssh/bastion_key -N ""
   ```

2. Verify the key files were created:
   ```bash
   ls -la ~/.ssh/bastion_key*
   ```

3. Set correct permissions for the private key:
   ```bash
   chmod 400 ~/.ssh/bastion_key
   ```

4. Copy the public key to your project directory:
   ```bash
   cp ~/.ssh/bastion_key.pub ./bastion_key.pub
   ```

5. Add the public key file (`bastion_key.pub`) to your repository
6. **Never commit the private key** - keep it secure on your local machine

## Usage

1. Clone this repository
2. Navigate to the project directory
3. Set up your SSH key (see SSH Key Setup section above)
4. Initialize Terraform:
   ```bash
   terraform init
   ```
5. Get your current IP and add it to terraform.tfvars:
   ```bash
   ./myIP.sh >> terraform.tfvars
   ```
6. Review and customize `terraform.tfvars` if needed:
   ```bash
   cat terraform.tfvars
   ```
7. Review the planned changes:
   ```bash
   terraform plan
   ```
8. Apply the configuration:
   ```bash
   terraform apply
   ```
9. To destroy the infrastructure when no longer needed:
   ```bash
   terraform destroy
   ```

## Project Structure

The project is organized into modular Terraform files:

- `main.tf` - VPC, subnets, routing, and NAT gateway
- `inctances.tf` - Bastion host configuration
- `webserver.tf` - WordPress launch template
- `autoscaling.tf` - Auto Scaling Group configuration
- `load_balancer.tf` - Application Load Balancer setup
- `rds.tf` - RDS MySQL database configuration
- `security_groups.tf` - Security group definitions
- `cloudwatch_metric.tf` - CloudWatch alarms and scaling policies
- `variables.tf` - Input variables
- `outputs.tf` - Output values
- `user_data.sh` - WordPress installation script

## Configuration

Customize the following in `terraform.tfvars`:

- `aws_region` - AWS region (default: eu-central-1)
- `my_ip` - Your public IP for SSH access
- `environment` - Environment name (default: dev)

Additional customization available in `variables.tf`:
- VPC and subnet CIDR blocks
- Instance types and scaling parameters

## High Availability Features

This infrastructure is designed for high availability and fault tolerance:

- **Multi-AZ Deployment**: Resources are distributed across multiple Availability Zones
- **Auto Scaling Group**: Automatically maintains 2-4 WordPress instances based on demand
- **Application Load Balancer**: Distributes incoming traffic across healthy instances
- **Multi-AZ RDS**: Database is replicated synchronously to a standby instance
- **CloudWatch Monitoring**: Automatic scaling based on CPU utilization (70% scale up, 30% scale down)
- **Health Checks**: ALB performs health checks on `/health.html` endpoint

## Security Considerations

This setup implements security best practices by:
- Isolating resources in private subnets
- Using NAT Gateway for secure outbound connectivity
- Implementing security groups with least privilege access
- Limiting public exposure to only necessary resources (ALB and Bastion)
- Using custom SSH key pairs for secure access
- Encrypting data at rest in RDS instances

## Use Cases

This infrastructure is ideal for a variety of applications that require secure, scalable, and highly available hosting:

### Web Applications with Secure Backend
- **Public Subnet**: Host load balancers and bastion hosts that need direct internet access
- **Private Subnet**: Deploy WordPress instances, databases, and other sensitive components

### WordPress Hosting Platform
- Scalable WordPress hosting with automatic load balancing
- Database redundancy with Multi-AZ RDS
- Automatic scaling based on traffic demands

### Development and Testing Environments
- Create isolated environments for development, testing, and production
- Maintain consistent networking configurations across all environments

### Enterprise Applications
- Support mission-critical applications with high availability requirements
- Implement database redundancy with Multi-AZ RDS
- Scale horizontally behind the Application Load Balancer

## Accessing Your Infrastructure

After deployment, Terraform will output connection instructions. You can:

1. **Access WordPress**: Use the Load Balancer DNS name provided in outputs
2. **SSH to Bastion**: Use your private key to connect to the bastion host
3. **Monitor Instances**: Check Auto Scaling Group in AWS Console

## Troubleshooting

### Check WordPress instance logs:
```bash
# SSH to bastion first, then to WordPress instance
sudo tail -f /var/log/user-data.log
sudo cat /var/log/dnf-update.log
sudo cat /var/log/dnf-install.log
sudo cat /var/log/wordpress-download.log
```

### Check cloud-init logs:
```bash
sudo tail -f /var/log/cloud-init-output.log
sudo journalctl -u cloud-final
```

### Test load balancer:
Visit `http://<ALB-DNS>/info.php` to see which instance is serving requests

## Auto Scaling Behavior

- **Scale Up**: When CPU utilization > 70% for 2 consecutive periods (4 minutes)
- **Scale Down**: When CPU utilization < 30% for 2 consecutive periods (4 minutes)
- **Min Instances**: 2
- **Max Instances**: 4
- **Health Check**: ELB health checks with 5-minute grace period

## Cost Optimization

This setup uses cost-effective resources:
- t2.micro for Bastion host (Free Tier eligible)
- t3.micro for WordPress instances
- db.t3.micro for RDS (Free Tier eligible)
- Single NAT Gateway to reduce costs

For production workloads, consider upgrading instance types and adding redundant NAT Gateways.