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

# Create Security Group for Web Server
resource "aws_security_group" "webserver_sg" {
  name        = "WebServerSecurityGroup"
  description = "Security group for web servers in private subnet"
  vpc_id      = aws_vpc.myVPC.id

  # SSH access from Bastion only
  ingress {
    description     = "SSH from Bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  # HTTP access
  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS access
  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "WebServerSecurityGroup"
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
    
    # Install useful tools
    dnf install -y htop tmux vim
    
    # Configure SSH hardening
    sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
    systemctl restart sshd
  EOF

  tags = {
    Name        = "Bastion-${var.environment}"
    Environment = var.environment
    Terraform   = "true"
  }
}

# Launch web server in private subnet
resource "aws_instance" "webserver" {
  ami                    = data.aws_ssm_parameter.al2023.value
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.privateSubnet.id
  vpc_security_group_ids = [aws_security_group.webserver_sg.id]
  key_name               = aws_key_pair.generated_key.key_name
  
  user_data = <<-EOF
    #!/bin/bash
    # Update system packages
    dnf update -y
    
    # Install Apache web server
    dnf install -y httpd
    
    # Start and enable Apache
    systemctl start httpd
    systemctl enable httpd
    
    # Create a simple index page
    cat > /var/www/html/index.html << 'HTMLEND'
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>TerraVPS Web Server</title>
        <style>
            body {
                font-family: Arial, sans-serif;
                max-width: 800px;
                margin: 0 auto;
                padding: 20px;
                line-height: 1.6;
            }
            h1 {
                color: #0066cc;
            }
            .container {
                border: 1px solid #ddd;
                padding: 20px;
                border-radius: 5px;
            }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>Hello from TerraVPS WebServer!</h1>
            <p>This server is running in a private subnet and was deployed using Terraform.</p>
            <p>Environment: ${var.environment}</p>
            <p>Server Time: <span id="server-time"></span></p>
        </div>
        <script>
            document.getElementById('server-time').textContent = new Date().toLocaleString();
        </script>
    </body>
    </html>
    HTMLEND
    
    # Set proper permissions
    chmod 644 /var/www/html/index.html
  EOF

  tags = {
    Name        = "WebServer-${var.environment}"
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

output "webserver_private_ip" {
  value       = aws_instance.webserver.private_ip
  description = "Private IP address of the Web Server"
}

output "connection_instructions" {
  value = <<-EOT
    
    === CONNECTION INSTRUCTIONS ===
    
    1. SSH to Bastion host:
       ssh -i ${local_file.private_key.filename} ec2-user@${aws_instance.bastion.public_ip}
    
    2. From Bastion, SSH to WebServer:
       First, copy your SSH key to the Bastion:
       scp -i ${local_file.private_key.filename} ${local_file.private_key.filename} ec2-user@${aws_instance.bastion.public_ip}:~/
       
       Then SSH to the WebServer:
       ssh -i ~/ssh-key-${var.environment}.pem ec2-user@${aws_instance.webserver.private_ip}
    
    3. To access the web server from your local machine:
       Set up SSH port forwarding:
       ssh -i ${local_file.private_key.filename} -L 8080:${aws_instance.webserver.private_ip}:80 ec2-user@${aws_instance.bastion.public_ip}
       
       Then open http://localhost:8080 in your browser
  EOT
}
