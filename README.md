# TerraVPS Image Analysis Application

A Terraform project for provisioning a secure, highly available image analysis application on AWS using Python Flask web framework and serverless technologies.

## Project Overview

This project uses Terraform to create a complete VPC setup in AWS with both public and private subnets across multiple availability zones, providing a secure and resilient foundation for hosting an image analysis application. The infrastructure includes:

- A VPC with a CIDR block of 10.0.0.0/24
- Private subnets across multiple AZs for secure internal resources
- Public subnets across multiple AZs for internet-facing components
- Internet Gateway for public internet access
- NAT Gateway to allow private subnet resources to access the internet
- Application Load Balancer (ALB) for distributing traffic to Python Flask web application instances
- Auto Scaling Group with 2-4 Python Flask web application instances for high availability
- S3 bucket for image storage with public read access for uploaded images
- SNS topic for event notifications
- Lambda function for image processing with AWS Rekognition
- DynamoDB table for storing image analysis results
- CloudWatch monitoring and auto-scaling policies
- Bastion host for secure SSH access to private resources
- Nginx reverse proxy for serving Flask application on port 80

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

## Prerequisites

- AWS account with appropriate permissions
- Terraform installed (version 1.0.0 or later)
- AWS CLI configured with valid credentials
- Python 3.x (for local development/testing)
- Basic understanding of Flask web framework

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
7. Build the Lambda package:
   ```bash
   cd lambda
   npm install
   zip -r media_processing.zip index.js node_modules/
   cd ..
   ```
   
   **Note**: The web application now uses Python Flask instead of PHP, which provides:
   - Simpler AWS SDK integration with boto3
   - Better error handling and debugging
   - More reliable dependency management
   - Native JSON handling for DynamoDB responses
8. Review the planned changes:
   ```bash
   terraform plan
   ```
9. Apply the configuration:
   ```bash
   terraform apply
   ```
10. To destroy the infrastructure when no longer needed:
    ```bash
    terraform destroy
    ```

## Project Structure

The project is organized into modular Terraform files:

- `main.tf` - VPC, subnets, routing, and NAT gateway
- `instances.tf` - Bastion host configuration
- `web_app.tf` - Web application launch template and Auto Scaling Group
- `load_balancer.tf` - Application Load Balancer setup
- `media_processing.tf` - S3, SNS, Lambda, and event notifications
- `dynamodb.tf` - DynamoDB table for image analysis results
- `security_groups.tf` - Security group definitions
- `cloudwatch_metric.tf` - CloudWatch alarms and scaling policies
- `variables.tf` - Input variables
- `outputs.tf` - Output values
- `web_app_user_data.sh` - Python Flask web application installation script

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
- **Auto Scaling Group**: Automatically maintains 2-4 web application instances based on demand
- **Application Load Balancer**: Distributes incoming traffic across healthy instances
- **CloudWatch Monitoring**: Automatic scaling based on CPU utilization (70% scale up, 30% scale down)
- **Health Checks**: ALB performs health checks on `/health.html` endpoint

## Security Considerations

This setup implements security best practices by:
- Isolating resources in private subnets
- Using NAT Gateway for secure outbound connectivity
- Implementing security groups with least privilege access
- Limiting public exposure to only necessary resources (ALB and Bastion)
- Using custom SSH key pairs for secure access
- Encrypting data at rest in S3 and DynamoDB
- **S3 Public Access**: Limited public read access only for uploaded images in `/uploads/` folder
- IAM roles for EC2 instances instead of hardcoded credentials
- Nginx reverse proxy for additional security layer

## Image Processing Workflow

### Upload Process:
1. User selects image file through Flask web interface
2. Flask application validates file type (JPG, JPEG, PNG)
3. Image is uploaded directly to S3 bucket using boto3
4. S3 triggers SNS notification on object creation
5. SNS invokes Lambda function for processing

### Analysis Process (Lambda + Rekognition):
1. **Object and Scene Detection**
   - AWS Rekognition identifies objects, scenes, and concepts
   - Automatically tags images with relevant labels
   - Provides confidence scores for each detection

2. **Face Detection**
   - Detects faces in images
   - Counts the number of faces present
   - Analyzes facial attributes

3. **Content Moderation**
   - Scans images for inappropriate content
   - Flags potentially unsafe or offensive material
   - Helps maintain content standards

4. **Results Storage**
   - Analysis results stored in DynamoDB
   - Includes image metadata, labels, face count, moderation flags
   - Timestamp and unique image ID for tracking

### Display Process:
1. Flask application queries DynamoDB for recent analyses
2. Generates direct S3 URLs for image display
3. Renders results using Jinja2 templates
4. Real-time updates as new images are processed

## Web Application (Python Flask)

The Python Flask web application provides a simple user interface for:

1. **Image Upload**
   - HTML form for selecting and uploading images
   - Supports JPG, JPEG, and PNG formats
   - Directly uploads images to S3 using boto3 SDK
   - Automatic unique filename generation using UUID

2. **Analysis Results Display**
   - Shows recently analyzed images from DynamoDB
   - Displays detected labels, faces, and moderation results
   - Uses direct S3 URLs for image display (public read access)
   - Provides visual indicators for different types of content

3. **Technical Stack**
   - Python 3 with Flask web framework
   - boto3 for AWS SDK integration
   - Nginx reverse proxy for production deployment
   - Systemd service for application management
   - Jinja2 templates for HTML rendering

## Accessing Your Infrastructure

After deployment, Terraform will output connection instructions. You can:

1. **Access Web Application**: Use the Load Balancer DNS name provided in outputs
2. **SSH to Bastion**: Use your private key to connect to the bastion host
3. **SSH to Private Instances**: Use SSH Agent Forwarding to access web application instances
4. **Monitor Instances**: Check Auto Scaling Group in AWS Console

### SSH Access Instructions

**Connect to Bastion Host:**
```bash
ssh -i ~/.ssh/bastion_key ec2-user@<bastion-public-ip>
```

**Connect to Private Web App Instances (via SSH Agent Forwarding):**
```bash
# From your local machine with agent forwarding enabled
ssh -A -i ~/.ssh/bastion_key ec2-user@<bastion-public-ip>

# Then from the bastion host
ssh ec2-user@<web-app-private-ip>
```

**Note**: SSH Agent Forwarding (`-A` flag) allows secure access to private instances without copying your private key to the bastion host.

## Troubleshooting

### Check web application instance logs:
```bash
# SSH to bastion first, then to web app instance
sudo tail -f /var/log/user-data.log
sudo journalctl -u httpd
```

### Check Lambda function logs:
```bash
# Using AWS CLI
aws logs describe-log-groups --log-group-name-prefix "/aws/lambda/dev-image-processing"
aws logs get-log-events --log-group-name "/aws/lambda/dev-image-processing" --log-stream-name <log-stream-name>
```

### Test image upload:
```bash
# Upload an image directly to S3
aws s3 cp test-image.jpg s3://<your-bucket-name>/uploads/test-image.jpg
```

## Auto Scaling Behavior

- **Scale Up**: When CPU utilization > 70% for 2 consecutive periods (4 minutes)
- **Scale Down**: When CPU utilization < 30% for 2 consecutive periods (4 minutes)
- **Min Instances**: 2
- **Max Instances**: 4
- **Health Check**: ELB health checks with 5-minute grace period

## Cost Optimization

This setup uses cost-effective resources:
- t2.micro for Bastion host (Free Tier eligible)
- t3.micro for web application instances
- Single NAT Gateway to reduce costs
- Serverless components (Lambda, S3, DynamoDB) that scale with usage

For production workloads, consider upgrading instance types and adding redundant NAT Gateways.
