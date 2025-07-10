# Security Groups

# Create Bastion Security Group
resource "aws_security_group" "bastion_sg" {
  name        = "BastionSecurityGroup"
  description = "Security group for Bastion host - Restrict SSH access to specified IP"
  vpc_id      = aws_vpc.myVPC.id

  ingress {
    description = "SSH access from specified IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "BastionSecurityGroup"
    Environment = var.environment
    Terraform   = "true"
  }
}



# Get the latest Amazon Linux 2023 AMI ID with SSM Parameter 
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-6.1-x86_64"
}

# Generate a new private key
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create AWS key pair using the generated public key
resource "aws_key_pair" "generated_key" {
  key_name   = "terraform-${var.environment}-key"
  public_key = tls_private_key.ssh_key.public_key_openssh
}

# Save private key to a file (be careful with this in production)
resource "local_file" "private_key" {
  content         = tls_private_key.ssh_key.private_key_pem
  filename        = "${path.module}/ssh-key-${var.environment}.pem"
  file_permission = "0600"
}

# Launch a Bastion EC2 instance in the public subnet
resource "aws_instance" "bastion" {
  ami                    = data.aws_ssm_parameter.al2023.value
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.publicSubnet.id
  vpc_security_group_ids = [aws_security_group.bastion_sg.id]
  key_name               = aws_key_pair.generated_key.key_name

  user_data = <<-EOF
    #!/bin/bash
    # Update system packages
    dnf update -y
        
    
    # 1. Disabling root login via SSH by setting PermitRootLogin to 'no'
    # 2. Disabling password authentication by setting PasswordAuthentication to 'no' (forcing key-based auth only)
    sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
    systemctl restart sshd # 3. Restarting the SSH daemon to apply these changes
  EOF

  tags = {
    Name        = "Bastion-${var.environment}"
    Environment = var.environment
    Terraform   = "true"
  }
}



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
  sensitive   = true // true - for production
}

output "random_password" {
  value = random_password.db_password.result
  description = "DB Password - only for TEST"
  sensitive   = true // true - for production
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
