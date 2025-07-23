# Image Analysis Application - Installation Guide

This guide provides step-by-step instructions for deploying the Image Analysis Application on AWS.

## Prerequisites

1. **AWS CLI** installed and configured with appropriate permissions
2. **Terraform** (v1.0.0 or later) installed
3. **Node.js** and **npm** installed (for Lambda package)
4. **SSH key pair** generated for bastion host access

## Step 1: Prepare Your Environment

### Clone the Repository
```bash
git clone <your-repo-url>
cd terraVPSsetup
```

### Generate SSH Key (if not already done)
```bash
ssh-keygen -t rsa -b 2048 -f ~/.ssh/bastion_key -N ""
chmod 400 ~/.ssh/bastion_key
cp ~/.ssh/bastion_key.pub ./bastion_key.pub
```

## Step 2: Build the Lambda Package

```bash
# Navigate to Lambda directory
cd lambda

# Install dependencies
npm install

# Create the deployment package
zip -r media_processing.zip index.js node_modules/

# Return to project root
cd ..
```

## Step 3: Configure Terraform Variables

Create a `terraform.tfvars` file with your settings:

```bash
cat > terraform.tfvars << EOF
aws_region = "us-east-1"  # Change to your preferred region
environment = "dev"
my_ip = "$(curl -s https://checkip.amazonaws.com)/32"  # Your current IP
EOF
```

## Step 4: Deploy the Infrastructure

```bash
# Initialize Terraform
terraform init

# Validate the configuration
terraform validate

# Review the execution plan
terraform plan

# Apply the configuration
terraform apply -auto-approve
```

## Step 5: Verify Deployment

### Check Terraform Outputs
```bash
terraform output
```

### Connect to Bastion Host
```bash
ssh -i ~/.ssh/bastion_key ec2-user@$(terraform output -raw bastion_public_ip)
```

### From Bastion, Get Web App Instance IPs
```bash
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=WebApp-ASG-dev" \
  --query "Reservations[].Instances[].PrivateIpAddress" \
  --output text
```

### Connect to a Web App Instance
```bash
ssh ec2-user@<private-ip-from-above>
```

### Check Web Server Status
```bash
sudo systemctl status httpd
sudo tail -f /var/log/user-data.log
```

## Step 6: Test the Application

1. Open the web application URL from Terraform outputs:
   ```bash
   echo "http://$(terraform output -raw load_balancer_dns)"
   ```

2. Upload an image through the web interface

3. Wait a few seconds for processing

4. Refresh the page to see analysis results

## Step 7: Verify Backend Components

### Check S3 Bucket
```bash
aws s3 ls s3://$(terraform output -raw image_storage_bucket)
```

### Check DynamoDB Table
```bash
aws dynamodb scan \
  --table-name $(terraform output -raw dynamodb_table) \
  --limit 5
```

### Check Lambda Logs
```bash
aws logs describe-log-groups \
  --log-group-name-prefix "/aws/lambda/$(terraform output -raw image_processing_lambda)"
```

## Troubleshooting

### Web Application Not Accessible
- Check security groups to ensure port 80 is open
- Verify ALB health checks are passing
- Check web server logs: `sudo journalctl -u httpd`

### Image Upload Fails
- Check S3 bucket permissions
- Verify IAM role permissions for web app instances
- Check web server error logs

### Image Analysis Not Working
- Check Lambda function logs in CloudWatch
- Verify SNS topic policy allows S3 to publish
- Check DynamoDB table permissions

### SSH Connection Issues
- Verify your IP is in the security group
- Check SSH key permissions (should be 400)
- Ensure bastion host is running

## Cleanup

When you're done with the application, you can destroy all resources:

```bash
terraform destroy -auto-approve
```

## Architecture Diagram

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
