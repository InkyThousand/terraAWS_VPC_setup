# Outputs

output "bastion_public_ip" {
  value       = aws_instance.bastion.public_ip
  description = "Public IP address of the Bastion host"
}

output "web_app_asg_name" {
  value       = aws_autoscaling_group.web_app_asg.name
  description = "Name of the Web App Auto Scaling Group"
}

output "load_balancer_dns" {
  value       = aws_lb.web_app_alb.dns_name
  description = "DNS name of the Application Load Balancer"
}

output "web_app_url" {
  value       = "http://${aws_lb.web_app_alb.dns_name}"
  description = "URL to access the Web Application through Load Balancer"
}

output "image_storage_bucket" {
  value       = aws_s3_bucket.image_storage.id
  description = "S3 bucket for image storage"
}

output "dynamodb_table" {
  value       = aws_dynamodb_table.image_analysis.name
  description = "DynamoDB table for image analysis results"
}

output "image_processing_lambda" {
  value       = aws_lambda_function.image_processing.function_name
  description = "Lambda function name for image processing"
}

output "connection_instructions" {
  value = <<-EOT
    
    === CONNECTION INSTRUCTIONS ===
    
      # From your local machine with agent forwarding enabled
      ssh -A -i ~/.ssh/bastion_key ec2-user@${aws_instance.bastion.public_ip}

      # Then from the bastion host
      ssh ec2-user@<web-app-private-ip>
    
    🌐 WEB APP ACCESS (Secure):
       URL: http://${aws_lb.web_app_alb.dns_name}
       
    🔒 ARCHITECTURE:
       Internet → Load Balancer (Public) → Web App (Private) → DynamoDB & S3
       
    📷 IMAGE PROCESSING:
       S3 Bucket: ${aws_s3_bucket.image_storage.id}
       Image uploads → S3 → SNS → Lambda → Rekognition → DynamoDB
  EOT
}
