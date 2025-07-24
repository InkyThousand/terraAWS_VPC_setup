# TerraVPS Image Analysis Application

A Terraform project for provisioning a secure, highly available image analysis application on AWS using serverless technologies.

## Project Overview

This project uses Terraform to create a complete VPC setup in AWS with both public and private subnets across multiple availability zones, providing a secure and resilient foundation for hosting an image analysis application. The infrastructure includes:

- A VPC with a CIDR block of 10.0.0.0/24
- Private subnets across multiple AZs for secure internal resources
- Public subnets across multiple AZs for internet-facing components
- Internet Gateway for public internet access
- NAT Gateway to allow private subnet resources to access the internet
- Application Load Balancer (ALB) for distributing traffic to web application instances
- Auto Scaling Group with 2-4 web application instances for high availability
- S3 bucket for image storage
- SNS topic for event notifications
- Lambda function for image processing with AWS Rekognition
- DynamoDB table for storing image analysis results
- CloudWatch monitoring and auto-scaling policies
- Bastion host for secure SSH access to private resources

## Architecture

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│             │     │             │     │             │
│  Web App    │     │  S3 Bucket  │     │  SNS Topic  │
│  (with UI)  │---->│  (Images)   │---->│  (Events)   │
│             │     │             │     │             │
└─────────────┘     └─────────────┘     └─────────────┘
                                                │
                                                v
                    ┌─────────────┐     ┌─────────────┐
                    │             │     │             │
                    │  AWS        │<----│  Lambda     │
                    │  Rekognition│     │  Function   │
                    │             │---->│             │
                    └─────────────┘     └─────────────┘
                                                │
                                                v
                                        ┌─────────────┐
                                        │             │
                                        │  DynamoDB   │
                                        │  Table      │
                                        │             │
                                        └─────────────┘
```

## Containerized Web Application

The web application is now containerized using Docker and deployed with Amazon ECS (Elastic Container Service). This provides several benefits:

- Consistent environment across all deployments
- No AWS SDK installation issues
- Simplified deployment process
- Better isolation and security
- Easier scaling

The container is built and pushed to Amazon ECR automatically during the Terraform deployment process.

```
webapp/
├── Dockerfile           # Docker configuration for the web application
├── docker-compose.yml   # Docker Compose configuration for local testing
├── composer.json        # PHP dependencies configuration
└── src/                 # Source code for the web application
    ├── index.php        # Main page with image upload form and results display
    ├── upload.php       # Handler for image uploads
    └── health.html      # Health check endpoint for the load balancer
```

## Project Structure

The project is organized into a modular Terraform structure:

```
terraform/
├── modules/
│   ├── networking/       # VPC, subnets, routing, and NAT gateway
│   ├── security/         # Security groups and SSH key pair
│   ├── storage/          # S3 bucket and SNS topic
│   ├── database/         # DynamoDB table
│   ├── lambda/           # Lambda function and IAM roles
│   ├── ecr/              # Elastic Container Registry for Docker images
│   └── ecs/              # Elastic Container Service for running containers
├── environments/
│   └── dev/              # Development environment configuration
└── README.md             # Documentation
```

## Prerequisites

- AWS account with appropriate permissions
- Terraform installed (version 1.0.0 or later)
- AWS CLI configured with valid credentials
- Docker installed (for building and testing the container)

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
   cp ~/.ssh/bastion_key.pub ./terraform/environments/dev/files/
   ```

## Usage

1. Navigate to the environment directory:
   ```bash
   cd terraform/environments/dev
   ```

2. Run the deployment script:
   ```bash
   ./deploy.sh
   ```

   This will:
   - Build the Lambda package
   - Update your IP address in terraform.tfvars
   - Initialize Terraform
   - Apply the Terraform configuration
   - Build and push the Docker image to ECR
   - Deploy the containerized web application to ECS

3. To destroy the infrastructure when no longer needed:
   ```bash
   terraform destroy
   ```

## Accessing the Application

After deployment, you can access the application using the ALB DNS name:

```bash
terraform output alb_dns_name
```

## SSH Access

To SSH to the bastion host:

```bash
ssh -i ~/.ssh/bastion_key ec2-user@$(terraform output -raw bastion_public_ip)
```

## Local Development

To run the web application locally:

```bash
cd webapp
docker-compose up --build
```

Then access the application at http://localhost:8080

## Web Application

The web application provides a simple user interface for:

1. **Image Upload**
   - Form for selecting and uploading images
   - Supports JPG, JPEG, and PNG formats
   - Securely stores images in S3

2. **Analysis Results Display**
   - Shows recently analyzed images
   - Displays detected labels, faces, and moderation results
   - Provides visual indicators for different types of content

3. **Image Management**
   - Generates pre-signed URLs for secure image access
   - Displays image metadata and analysis timestamp
   - Organizes results in a clean, responsive interface

## Security Considerations

This setup implements security best practices by:
- Isolating resources in private subnets
- Using NAT Gateway for secure outbound connectivity
- Implementing security groups with least privilege access
- Limiting public exposure to only necessary resources (ALB and Bastion)
- Using custom SSH key pairs for secure access
- Encrypting data at rest in S3 and DynamoDB

## Cost Optimization

This setup uses cost-effective resources:
- t2.micro for Bastion host (Free Tier eligible)
- t3.micro for web application instances
- Single NAT Gateway to reduce costs
- Serverless components (Lambda, S3, DynamoDB) that scale with usage

For production workloads, consider upgrading instance types and adding redundant NAT Gateways.
