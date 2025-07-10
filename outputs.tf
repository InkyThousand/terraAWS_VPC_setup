# Outputs
output "ssh_key_path" {
  value       = local_file.private_key.filename
  description = "Path to the SSH private key file"
}

output "bastion_public_ip" {
  value       = aws_instance.bastion.public_ip
  description = "Public IP address of the Bastion host"
}



output "wordpress_private_ip" {
  value       = aws_instance.wordpress.private_ip
  description = "Private IP address of the WordPress Server"
}

output "load_balancer_dns" {
  value       = aws_lb.wordpress_alb.dns_name
  description = "DNS name of the Application Load Balancer"
}

output "wordpress_url" {
  value       = "http://${aws_lb.wordpress_alb.dns_name}"
  description = "URL to access WordPress through Load Balancer"
}

output "database_endpoint" {
  value       = aws_db_instance.wordpress_db.endpoint
  description = "RDS database endpoint"
  sensitive   = true
}

output "random_password" {
  value = random_password.db_password.result
  description = "DB Password - only for TEST"
  sensitive   = true
}

output "connection_instructions" {
  value = <<-EOT
    
    === CONNECTION INSTRUCTIONS ===
    
    1. SSH to Bastion host:
       ssh -i ${local_file.private_key.filename} ec2-user@${aws_instance.bastion.public_ip}
    
    2. From Bastion, SSH to WordPress:
       First, copy your SSH key to the Bastion:
       scp -i ${local_file.private_key.filename} ${local_file.private_key.filename} ec2-user@${aws_instance.bastion.public_ip}:~/
       
       Then SSH to the WordPress server:
       ssh -i ~/ssh-key-${var.environment}.pem ec2-user@${aws_instance.wordpress.private_ip}
    
    🌐 WORDPRESS ACCESS (Secure):
       URL: http://${aws_lb.wordpress_alb.dns_name}
       
    🔒 ARCHITECTURE:
       Internet → Load Balancer (Public) → WordPress (Private) → Database (Private)
  EOT
}

