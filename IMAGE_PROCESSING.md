# Image Processing Application

This document explains the image processing application architecture and deployment process.

## Architecture Overview

The application uses a serverless architecture for image processing:

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

## Components

1. **Web Application**: Simple PHP application for uploading and viewing images
2. **S3 Bucket**: Stores uploaded images and triggers events
3. **SNS Topic**: Routes events from S3 to Lambda
4. **Lambda Function**: Processes images using AWS Rekognition
5. **DynamoDB Table**: Stores image analysis results

## Deployment Process

The deployment is split into two steps:

1. **Infrastructure Deployment** (Terraform):
   - Creates VPC, subnets, security groups
   - Sets up EC2 instances with basic web server
   - Creates S3, SNS, Lambda, and DynamoDB resources

2. **Application Deployment** (deploy_app.sh):
   - Installs the AWS SDK on web servers
   - Deploys PHP application files
   - Configures the application with resource names

## How It Works

1. **Image Upload**:
   - User uploads an image through the web interface
   - PHP saves the image locally and uploads to S3
   - S3 event notification triggers SNS

2. **Image Processing**:
   - SNS notifies Lambda function
   - Lambda retrieves image from S3
   - Lambda uses Rekognition to analyze the image
   - Lambda stores results in DynamoDB

3. **Results Display**:
   - Web application queries DynamoDB for analysis results
   - Results are displayed with the image on the web page
   - Pre-signed URLs are used to securely access S3 images

## Deployment Instructions

1. Deploy the infrastructure:
   ```bash
   terraform apply
   ```

2. Deploy the application:
   ```bash
   ./deploy_app.sh
   ```

3. Access the application:
   - Use the ALB DNS name from Terraform outputs
   - Navigate to the web interface in a browser

## Troubleshooting

### Web Application Issues
- Check Apache logs: `sudo tail -f /var/log/httpd/error_log`
- Check PHP logs: `sudo tail -f /var/log/php-fpm/error.log`
- Verify AWS SDK installation: `ls -la /var/www/html/aws-sdk/`

### S3 Upload Issues
- Check IAM permissions for EC2 instances
- Verify S3 bucket exists: `aws s3 ls`
- Test S3 access: `aws s3 ls s3://<bucket-name>`

### Lambda Processing Issues
- Check CloudWatch logs for Lambda function
- Verify SNS topic and subscription
- Test Lambda function manually
