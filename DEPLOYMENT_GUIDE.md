# TerraVPS Image Analysis Application Deployment Guide

## Overview

This guide provides step-by-step instructions for deploying the TerraVPS Image Analysis Application, which meets the following requirements:

1. A Simple Web Page with An Image Upload Form
2. Images are saved to S3
3. S3 Triggers SNS -> Lambda -> Rekognition for Image Analysis
4. Results Are Stored in DynamoDB
5. Results Appear on the Web Page with Descriptions from the Analysis

## Prerequisites

- AWS account with appropriate permissions
- Terraform installed (version 1.0.0 or later)
- AWS CLI configured with valid credentials
- SSH key pair for accessing EC2 instances

## Deployment Steps

### 1. Set Up SSH Key

```bash
# Generate SSH key pair
ssh-keygen -t rsa -b 2048 -f ~/.ssh/bastion_key -N ""

# Set correct permissions
chmod 400 ~/.ssh/bastion_key

# Copy public key to project directory
cp ~/.ssh/bastion_key.pub ./bastion_key.pub
```

### 2. Configure AWS Credentials

```bash
# Configure AWS CLI
aws configure

# Verify credentials
aws sts get-caller-identity
```

### 3. Update IP Address

```bash
# Get your current IP address and update terraform.tfvars
./myIP.sh >> terraform.tfvars

# Verify terraform.tfvars
cat terraform.tfvars
```

### 4. Build Lambda Package

```bash
# Navigate to Lambda directory
cd lambda

# Install dependencies and create zip package
npm install
zip -r media_processing.zip index.js node_modules/

# Return to project root
cd ..
```

### 5. Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Preview changes
terraform plan

# Deploy infrastructure
terraform apply
```

### 6. Deploy Web Application

```bash
# Deploy the web application to EC2 instances
./deploy_app.sh
```

### 7. Access the Application

```bash
# Get the ALB DNS name
terraform output alb_dns_name

# Open in web browser
http://<alb_dns_name>
```

## Testing the Application

1. **Upload Images**:
   - Use the web interface to upload JPG or PNG images
   - Try different types of images (objects, faces, etc.)

2. **View Analysis Results**:
   - Refresh the page after a few seconds
   - Check that uploaded images appear with analysis results
   - Verify labels, face detection, and content moderation results

3. **Verify Backend Processing**:
   - Check S3 bucket for uploaded images
   - Verify DynamoDB table contains analysis results
   - Review Lambda logs for processing details

## Troubleshooting

### Web Application Issues

```bash
# SSH to bastion host
ssh -i ~/.ssh/bastion_key ec2-user@<bastion-public-ip>

# SSH to web app instance
ssh ec2-user@<web-app-private-ip>

# Check Apache logs
sudo tail -f /var/log/httpd/error_log

# Check user data script logs
sudo cat /var/log/user-data.log
```

### Lambda Function Issues

```bash
# Check Lambda logs
aws logs describe-log-groups --log-group-name-prefix "/aws/lambda/dev-image-processing"
aws logs get-log-events --log-group-name "/aws/lambda/dev-image-processing" --log-stream-name <latest-stream>
```

### S3 and DynamoDB Issues

```bash
# List S3 bucket contents
aws s3 ls s3://<bucket-name>/uploads/ --recursive

# Scan DynamoDB table
aws dynamodb scan --table-name dev-image-analysis --limit 10
```

## Cleanup

When you're done with the application, you can destroy the infrastructure:

```bash
terraform destroy
```

## Architecture

The application uses the following AWS services:

- **VPC**: Network isolation with public and private subnets
- **EC2**: Web servers running in an Auto Scaling Group
- **ALB**: Load balancer for distributing traffic
- **S3**: Storage for uploaded images
- **SNS**: Event notifications for S3 uploads
- **Lambda**: Serverless processing of images
- **Rekognition**: AI-powered image analysis
- **DynamoDB**: NoSQL database for storing analysis results

## Security Considerations

- Web servers are protected by security groups
- S3 bucket has public access blocked
- IAM roles follow least privilege principle
- Images are accessed via pre-signed URLs
- Content moderation flags inappropriate images
