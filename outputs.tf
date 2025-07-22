# Outputs

output "bastion_public_ip" {
  value       = aws_instance.bastion.public_ip
  description = "Public IP address of the Bastion host"
}

output "wordpress_asg_name" {
  value       = aws_autoscaling_group.wordpress_asg.name
  description = "Name of the WordPress Auto Scaling Group"
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
    
      # From your local machine with agent forwarding enabled
      ssh -A -i ~/.ssh/bastion_key ec2-user@${aws_instance.bastion.public_ip}

      # Then from the bastion host
      ssh ec2-user@<wordpress-private-ip>
    
    🌐 WORDPRESS ACCESS (Secure):
       URL: http://${aws_lb.wordpress_alb.dns_name}
       
    🔒 ARCHITECTURE:
       Internet → Load Balancer (Public) → WordPress (Private) → Database (Private)
  EOT
}

